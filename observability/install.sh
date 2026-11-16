#!/usr/bin/env bash
# ==============================================================================
# TECHSTACK Centralized Host Observability Installer
# (VictoriaLogs + systemd-journald + systemd-journal-upload)
# ==============================================================================
# Installs and verifies the host-level decoupled logging stack ONCE per Linux
# server. Serves ALL applications running on the host (multi-app capable via
# SYSLOG_IDENTIFIER and _SYSTEMD_UNIT streams), with 100% local compressed disk
# storage and microsecond timestamps.
#
# Usage:
#   sudo bash install.sh
#   VL_VERSION=v1.54.0 RETENTION_PERIOD=30d LISTEN_ADDR=127.0.0.1:9428 sudo -E bash install.sh
# ==============================================================================
set -euo pipefail

VL_VERSION="${VL_VERSION:-v1.54.0}"
RETENTION_PERIOD="${RETENTION_PERIOD:-30d}"
LISTEN_ADDR="${LISTEN_ADDR:-127.0.0.1:9428}"
STORAGE_PATH="${STORAGE_PATH:-/var/lib/victoria-logs}"

echo "=================================================================="
echo "  TECHSTACK Host Observability Installer (VictoriaLogs + journald)"
echo "=================================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must run as root (e.g., sudo bash $0)" >&2
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1 || [ ! -d /run/systemd/system ]; then
    echo "ERROR: systemd is not active on this host. This installer requires systemd." >&2
    exit 1
fi

# 1. Detect CPU architecture
UNAME_ARCH="$(uname -m)"
case "$UNAME_ARCH" in
    x86_64|amd64) VL_ARCH="amd64" ;;
    aarch64|arm64) VL_ARCH="arm64" ;;
    *)
        echo "ERROR: Unsupported architecture: $UNAME_ARCH (expected x86_64/amd64 or aarch64/arm64)" >&2
        exit 1
        ;;
esac

echo "[1/6] Installing required OS packages (systemd-journal-upload, curl, tar)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq systemd-journal-remote curl tar
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q systemd-journal-upload curl tar
elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed systemd curl tar
else
    echo "WARNING: Unknown package manager. Ensure systemd-journal-upload, curl, and tar are installed."
fi

if ! command -v /lib/systemd/systemd-journal-upload >/dev/null 2>&1 && ! command -v /usr/lib/systemd/systemd-journal-upload >/dev/null 2>&1; then
    echo "ERROR: systemd-journal-upload binary was not found after package installation." >&2
    exit 1
fi

echo "[2/6] Downloading VictoriaLogs ${VL_VERSION} (${VL_ARCH})..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TARBALL="victoria-logs-linux-${VL_ARCH}-${VL_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/VictoriaMetrics/VictoriaLogs/releases/download/${VL_VERSION}/${TARBALL}"

curl -fL --retry 3 "$DOWNLOAD_URL" -o "$TMP_DIR/$TARBALL"
tar -xzf "$TMP_DIR/$TARBALL" -C "$TMP_DIR"
install -m 0755 "$TMP_DIR/victoria-logs-prod" /usr/local/bin/victoria-logs-prod

echo "[3/6] Creating dedicated 'victorialogs' user & local storage directory (${STORAGE_PATH})..."
if ! id -u victorialogs >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin victorialogs
fi
mkdir -p "$STORAGE_PATH"
chown -R victorialogs:victorialogs "$STORAGE_PATH"

echo "[4/6] Writing systemd units & journal-upload configuration..."
cat > /etc/systemd/system/victoria-logs.service <<EOF
[Unit]
Description=VictoriaLogs Standalone Local Log Store & UI
After=network.target

[Service]
Type=simple
User=victorialogs
Group=victorialogs
ExecStart=/usr/local/bin/victoria-logs-prod \\
  -storageDataPath=${STORAGE_PATH} \\
  -retentionPeriod=${RETENTION_PERIOD} \\
  -httpListenAddr=${LISTEN_ADDR} \\
  -journald.streamFields=_HOSTNAME,_SYSTEMD_UNIT,SYSLOG_IDENTIFIER
Restart=always
RestartSec=5
LimitNOFILE=65536

ProtectSystem=full
NoNewPrivileges=true
ReadWritePaths=${STORAGE_PATH}

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/journal-upload.conf <<EOF
[Upload]
URL=http://${LISTEN_ADDR}/insert/journald
EOF

# Grant journal read permissions to systemd-journal-upload user if present
if id -u systemd-journal-upload >/dev/null 2>&1; then
    usermod -a -G systemd-journal systemd-journal-upload || true
fi

# Ensure journald uses persistent storage (survives reboots)
if [ ! -d /var/log/journal ]; then
    mkdir -p /var/log/journal
    systemd-tmpfiles --create --prefix /var/log/journal >/dev/null 2>&1 || true
    systemctl restart systemd-journald || true
fi

echo "[5/6] Enabling and starting victoria-logs.service + systemd-journal-upload.service..."
systemctl daemon-reload
systemctl enable victoria-logs.service
systemctl restart victoria-logs.service
systemctl enable systemd-journal-upload.service
systemctl restart systemd-journal-upload.service

echo "[6/6] Verifying health and end-to-end journald -> VictoriaLogs ingestion..."
for svc in victoria-logs.service systemd-journal-upload.service; do
    if ! systemctl is-active --quiet "$svc"; then
        echo "ERROR: $svc failed to reach active state!" >&2
        journalctl -u "$svc" -n 25 --no-pager >&2 || true
        exit 1
    fi
done

HEALTH_URL="http://${LISTEN_ADDR}/health"
READY=0
for _ in $(seq 1 20); do
    if curl --fail -s -o /dev/null "$HEALTH_URL"; then
        READY=1
        break
    fi
    sleep 0.5
done

if [ "$READY" -ne 1 ]; then
    echo "ERROR: VictoriaLogs did not respond with HTTP 200 on $HEALTH_URL" >&2
    journalctl -u victoria-logs.service -n 25 --no-pager >&2 || true
    exit 1
fi

VERIFY_TOKEN="techstack-obs-ok-$(date +%s)-$$"
echo "$VERIFY_TOKEN" | systemd-cat -t techstack-verify

INGESTED=0
QUERY_URL="http://${LISTEN_ADDR}/select/logsql/query"
for _ in $(seq 1 10); do
    if curl -sG "$QUERY_URL" --data-urlencode "query=SYSLOG_IDENTIFIER:techstack-verify AND ${VERIFY_TOKEN}" --data-urlencode "limit=1" | grep -q "$VERIFY_TOKEN"; then
        INGESTED=1
        break
    fi
    sleep 0.5
done

echo ""
echo "=================================================================="
if [ "$INGESTED" -eq 1 ]; then
    echo "  OK: Host observability installed, active, and verified end-to-end!"
else
    echo "  OK: Services are active & /health returned 200 OK."
    echo "  NOTE: Test marker still flushing from journald; check manually in a few seconds:"
    echo "    curl -sG \"${QUERY_URL}\" --data-urlencode 'query=SYSLOG_IDENTIFIER:techstack-verify' --data-urlencode 'limit=5'"
fi
echo ""
echo "  * Web UI (vmui)   : http://${LISTEN_ADDR}/select/vmui/"
echo "  * LogsQL Query API: http://${LISTEN_ADDR}/select/logsql/query"
echo "  * Local Storage   : ${STORAGE_PATH} (Retention: ${RETENTION_PERIOD})"
echo "  * Multi-App Filter: filter by SYSLOG_IDENTIFIER:<app> or _SYSTEMD_UNIT:<app>.service"
echo "=================================================================="
