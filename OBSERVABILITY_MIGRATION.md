# Observability Migration Guide: Flat Logs / In-App `/api/logs` $\rightarrow$ `VictoriaLogs` (Linux `systemd-journald` & Windows `ship-logs.ps1`)

This guide explains how to set up decoupled local logging into standalone **`VictoriaLogs` (`127.0.0.1:9428`)** for your project's target operating system:
* **Linux Server Targets:** Sections 1–3 (`observability/install.sh`, `systemd-journald`, `start.sh`/`stop.sh`).
* **Windows-Only / Local Windows Targets:** [Section 4](#4-windows-local-observability-setup-installps1--ship-logsps1--ordered-lifecycle) (`observability/install.ps1` + `ship-logs.ps1` orchestrated by `start.ps1` and `stop.ps1`, with **no `systemd` or `.sh` scripts needed**).

*(Use only the platform section that matches where your project runs, plus the shared application instrumentation rules in [BACKEND_TECHSTACK.md](file:///C:/GIT/TECHSTACK/BACKEND_TECHSTACK.md#L580-L691).)*

---

## 1. Host Prerequisites & Installation (Linux Targets Only — Once Per Host)

VictoriaLogs and `systemd-journal-upload` are **host-level infrastructure services** installed **once** on the production server—completely separate from your application repositories. A single host installation automatically collects and separates logs for **all** applications on that machine (e.g., `musicbot`, `api-server`, `worker-daemon`) via `SYSLOG_IDENTIFIER` and `_SYSTEMD_UNIT`.

### 1.1 Automated Centralized Installer (`observability/install.sh`)
This repository provides a self-contained installer at [observability/install.sh](file:///C:/GIT/TECHSTACK/observability/install.sh) that installs required packages, downloads `victoria-logs-prod` for your CPU architecture (`amd64` / `arm64`), configures persistent `journald` + `victoria-logs.service` + `systemd-journal-upload.service`, and verifies end-to-end ingestion automatically:

```bash
# Zero-residue one-liner directly from GitHub (streams via stdin, cleans temp tarball on exit)
curl -fsSL https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/observability/install.sh | sudo bash

# Or run from a local clone:
# sudo bash observability/install.sh
```

If you prefer manual step-by-step installation or want to inspect what `install.sh` configures, follow Sections 1.2–1.6 below.

### 1.2 System Packages Required
Install `systemd-journal-upload` (packaged inside `systemd-journal-remote` on Debian/Ubuntu/Raspberry Pi OS) along with `curl` and `tar`:

```bash
# Debian / Ubuntu / Raspberry Pi OS
sudo apt-get update && sudo apt-get install -y systemd-journal-remote curl tar

# Fedora / RHEL / Rocky
# sudo dnf install -y systemd-journal-upload curl tar
```

### 1.3 Download & Install VictoriaLogs Binary (100% Local Storage)
Download the single-binary release matching your host CPU (`amd64` for x86_64 servers, `arm64` for Raspberry Pi / ARM64):

```bash
VL_VERSION="v1.54.0"
# Use "amd64" for x86_64 or "arm64" for AArch64 / Raspberry Pi
VL_ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')"

curl -fL "https://github.com/VictoriaMetrics/VictoriaLogs/releases/download/${VL_VERSION}/victoria-logs-linux-${VL_ARCH}-${VL_VERSION}.tar.gz" -o /tmp/victoria-logs.tar.gz
tar -xzf /tmp/victoria-logs.tar.gz -C /tmp
sudo install -m 0755 /tmp/victoria-logs-prod /usr/local/bin/victoria-logs-prod
rm -f /tmp/victoria-logs.tar.gz /tmp/victoria-logs-prod
```

### 1.4 Create Dedicated User & Local Storage Directory
```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin victorialogs
sudo mkdir -p /var/lib/victoria-logs
sudo chown -R victorialogs:victorialogs /var/lib/victoria-logs
```

### 1.5 Configure & Enable `victoria-logs.service`
Create `/etc/systemd/system/victoria-logs.service`:

```ini
[Unit]
Description=VictoriaLogs Standalone Local Log Store & UI
After=network.target

[Service]
Type=simple
User=victorialogs
Group=victorialogs
ExecStart=/usr/local/bin/victoria-logs-prod \
  -storageDataPath=/var/lib/victoria-logs \
  -retentionPeriod=30d \
  -httpListenAddr=127.0.0.1:9428 \
  -journald.streamFields=_HOSTNAME,_SYSTEMD_UNIT,SYSLOG_IDENTIFIER
Restart=always
RestartSec=5
LimitNOFILE=65536

ProtectSystem=full
NoNewPrivileges=true
ReadWritePaths=/var/lib/victoria-logs

[Install]
WantedBy=multi-user.target
```

> [!CAUTION]
> Always bind `-httpListenAddr=127.0.0.1:9428` (or a private Tailscale IP). Never expose port `9428` publicly on `0.0.0.0` without authentication.

### 1.6 Configure & Enable `systemd-journal-upload`
Create `/etc/systemd/journal-upload.conf`:

```ini
[Upload]
URL=http://127.0.0.1:9428/insert/journald
```

Grant journal read permission, cap `journald` local cache size if needed (recommended on small SD cards via `/etc/systemd/journald.conf`, e.g. `SystemMaxUse=500M`), and start both services:

```bash
sudo usermod -a -G systemd-journal systemd-journal-upload 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl enable --now victoria-logs.service
sudo systemctl enable --now systemd-journal-upload.service
```

Verify both services are active:
```bash
sudo systemctl status victoria-logs.service systemd-journal-upload.service --no-pager
```

---

## 2. Migrating an Existing Application Infrastructure

### Step 1: Update `Cargo.toml` for Structured JSON & Readable Panics
1. Add the `"json"` feature to `tracing-subscriber` so production logs emit parseable JSON fields (`level`, `target`, `duration_ms`, etc.).
2. Change `strip = true` to `strip = "debuginfo"` so release panic backtraces retain readable function names.

```toml
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

[profile.release]
opt-level = 3
lto = "fat"
codegen-units = 1
panic = "abort"
strip = "debuginfo"
```

### Step 2: Update `src/main.rs` (JSON in PROD, Panic Hook, Boot Error Stderr)
1. Print explicit `eprintln!` if config loading fails before `tracing` initializes (`journald` timestamps and captures `stderr` automatically).
2. Enable `tracing_subscriber::fmt::layer().json()` in PROD (`DISCORD_PROFILE=PROD` or `LOG_FORMAT=json`), keeping human-readable formatting in DEV.
3. Install a `std::panic::set_hook` wrapper capturing `std::backtrace::Backtrace::force_capture()` and emitting an `error!(target: "panic", ...)` event before the process aborts.

### Step 3: Instrument Slow Paths & Child Process `stderr`
To answer *"why is PROD slow?"* via LogsQL:
* Wrap HTTP routing with an Axum latency middleware logging numeric `duration_ms` (`warn!` above e.g. `1000ms`).
* Record `Instant::now()` and log `duration_ms` around external CLI calls (`yt-dlp`, `ffmpeg`), AI/LLM requests, and DB queries.
* Replace `Stdio::null()` on child process `stderr` with `Stdio::inherit()` (while keeping quiet CLI flags like `-v warning`) so real subprocess failures reach `journald` $\rightarrow$ `VictoriaLogs`.

### Step 4: Update `start.sh` & `stop.sh`
1. **Fail-Fast Logging Pre-Flight Check (`start.sh`):**
   Before starting the application, `start.sh` MUST verify `victoria-logs.service` and `systemd-journal-upload.service` are running via `systemctl is-active --quiet`. If either is stopped, abort (`exit 1`) and print the exact `sudo systemctl enable --now ...` command (and installer path) needed to turn them on.
2. **Route `stdout` & `stderr` into `journald` (`start.sh`):**
   If the application is not yet migrated to its own `systemd` unit (`myapp.service`), replace plain `nohup ... > app.log 2>&1 &` with bash process substitution into `systemd-cat`:
   ```bash
   export RUST_BACKTRACE="${RUST_BACKTRACE:-1}"
   nohup "$RELEASE_BIN" < /dev/null > >(tee -a "$RUNNER_LOG" | systemd-cat -t myapp) 2>&1 &
   APP_PID=$!
   ```
   * `$!` remains the exact application PID for `bot.pid`.
   * Startup logs, runtime logs, panic traces, child `stderr`, and **graceful shutdown / exiting logs** are all flushed through the pipe into `journald` with microsecond timestamps and uploaded to VictoriaLogs.
   * *(Recommended end-state for Linux PROD: run the app directly under its own `systemd` service unit with `StandardOutput=journal` and `StandardError=journal` so kernel signals like `SIGKILL` / `OOMKilled` are also recorded.)*
3. **Never Stop VictoriaLogs in `stop.sh`:**
   `stop.sh` must ONLY stop the application PID (and reverse proxy/tunnel if applicable). Leaving `victoria-logs.service` and `systemd-journal-upload.service` running guarantees that **exiting and crash logs are preserved and queryable while the application is offline or redeploying**.

### Step 5: Remove Legacy In-App `/api/logs` Endpoints
1. Search all Web (`src/`) and Mobile (`lib/`) client codebases for references to `/api/logs` (or `getLogs`).
2. Delete the legacy route and flat-file tailing handler from your backend router (`src/api/mod.rs` + `src/api/routes.rs`).

---

## 3. Post-Migration Verification

1. **Test Start Script Guard:**
   Temporarily stop `systemd-journal-upload.service` (or verify on a fresh host), run `./start.sh`, and confirm it exits non-zero and prints the exact `sudo systemctl enable --now ...` command.
2. **Verify Ingestion & Timestamps:**
   Start the logging services and app, then query VictoriaLogs locally:
   ```bash
   curl -sG "http://127.0.0.1:9428/select/logsql/query" \
     --data-urlencode 'query=SYSLOG_IDENTIFIER:myapp _time:5m' \
     --data-urlencode 'limit=10'
   ```
3. **Verify Exiting Logs Survive Stop:**
   Run `./stop.sh`, wait 2 seconds, and query again—confirm the `[Shutdown]` exiting lines appear in VictoriaLogs with timestamps while the app is stopped.
4. **Access Web UI (`vmui`) Safely Over SSH Tunnel (No Tailscale Required):**
   Run the helper script from your workstation to open the tunnel and launch your default browser straight to `http://localhost:9428/select/vmui/`:
   ```powershell
   # Windows PowerShell (auto-reads SSH_HOST/HOSTNAME, SSH_USER/USER, SSH_PORT/PORT from .\.env or TECHSTACK\.env)
   C:\GIT\TECHSTACK\observability\open-logs.ps1
   # Or specify a host / .env explicitly:
   C:\GIT\TECHSTACK\observability\open-logs.ps1 <user>@<prod-host>
   C:\GIT\TECHSTACK\observability\open-logs.ps1 -EnvFile path\to\.env
   ```
   ```bash
   # Linux / macOS
   bash /path/to/TECHSTACK/observability/open-logs.sh [<user>@<prod-host>]
   ```
   *(Or manually: `ssh -N -L 9428:127.0.0.1:9428 <user>@<prod-host>` and open `http://localhost:9428/select/vmui/`.)*

---

## 4. Windows Local Observability Setup (`install.ps1` + `ship-logs.ps1` + Ordered Lifecycle)

Because Windows does not have `systemd-journald` or `systemd-journal-upload`, Windows machines run standalone `victoria-logs-prod.exe` plus a zero-dependency PowerShell shipper (`observability/ship-logs.ps1`), orchestrated directly by `start.ps1` and `stop.ps1`.

### 4.1 One-Line Windows Installation (No Admin / UAC Required)

```powershell
irm https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/observability/install.ps1 | iex
```

* Installs `victoria-logs-prod.exe` into `%LOCALAPPDATA%\VictoriaLogs\bin\victoria-logs-prod.exe` and stores compressed logs in `%LOCALAPPDATA%\VictoriaLogs\data\`.
* Temporary zip archives are extracted to `$env:TEMP` and deleted immediately after verification.

### 4.2 Ordered Process Lifecycle (`start.ps1` & `stop.ps1`)

Use the templates in [`build-start-separation/examples/start.ps1.template`](./build-start-separation/examples/start.ps1.template) and [`build-start-separation/examples/stop.ps1.template`](./build-start-separation/examples/stop.ps1.template):

1. **Startup Order (`start.ps1`):**
   1. Start `victoria-logs-prod.exe` bound to `127.0.0.1:9428` (or reuse an existing healthy instance on `9428`) and wait for `/health` `200 OK`.
   2. Start `observability/ship-logs.ps1` tailing `.logs\*.log` (`FileShare.ReadWrite | FileShare.Delete` so apps never hit file locks).
   3. Launch Backend (with `RUST_LOG=info` / `LOG_FORMAT=json`) and Frontend, redirecting `stdout`/`stderr` to `.logs\*.log`.
   4. Persist `logger_pid`, `logger_owned`, `logger_port`, `shipper_pid`, `backend_pid`, and `frontend_pid` into `.pids`.
2. **Shutdown Order (`stop.ps1`):**
   1. Terminate Frontend & Backend process trees and sweep app ports (explicitly skipping `logger_port`).
   2. **Confirm** every application PID is gone and every application port is closed. If an app fails to stop, abort logger shutdown so crash diagnostics continue to flow.
   3. Signal `.logs\.stop-shipper` and wait for `.logs\.shipper-flushed` (trailing `stdout`/`stderr` flushed cleanly to `127.0.0.1:9428/insert/jsonline`).
   4. Terminate `VictoriaLogs` **last** (pass `-KeepLogger` to keep `http://127.0.0.1:9428/select/vmui/` up for post-mortem inspection).

