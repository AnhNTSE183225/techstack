#!/usr/bin/env bash
# ==============================================================================
# Setup Local Security Audit Skills & Gitleaks (Linux / macOS)
# ==============================================================================
# Clones upstream security skills into the GITIGNORED `security-audit/vendor/`
# folder so they remain local and are never committed to TECHSTACK.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$SCRIPT_DIR/vendor"
mkdir -p "$VENDOR_DIR"

echo "[1/3] Checking Gitleaks CLI..."
if ! command -v gitleaks &>/dev/null; then
    echo "  Installing Gitleaks to /usr/local/bin..."
    curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/main/scripts/install.sh | sudo sh -s -- -b /usr/local/bin || \
        echo "  WARN: Install Gitleaks manually from https://github.com/gitleaks/gitleaks/releases"
else
    echo "  [OK] Gitleaks installed: $(gitleaks version)"
fi

sync_repo() {
    local name="$1" url="$2"
    local dest="$VENDOR_DIR/$name"
    if [ -d "$dest/.git" ]; then
        git -C "$dest" pull --ff-only
    else
        rm -rf "$dest"
        git clone --depth 1 "$url" "$dest"
    fi
    echo "  [OK] Ready at $dest"
}

echo "[2/3] Syncing vibe-security-skill..."
sync_repo "vibe-security-skill" "https://github.com/raroque/vibe-security-skill.git"

echo "[3/3] Syncing security-audit-skill..."
sync_repo "security-audit-skill" "https://github.com/cloudflare/security-audit-skill.git"

echo ""
echo "Security skills ready in $VENDOR_DIR (gitignored)."
