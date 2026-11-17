# TECHSTACK — Reference Architecture & Standards

Centralized architectural blueprints, engineering rules, agent skills, and host infrastructure automation for high-performance bare-metal Rust backends, SolidJS/React frontends, and Flutter mobile clients.

---

## Quick Start: One-Line Host Observability Setup (Linux PROD)

Install the decoupled **VictoriaLogs + `systemd-journald`** logging stack once per Linux server (multi-app capable, 100% local compressed disk storage, microsecond timestamps) **without cloning the repo or leaving installer files behind**:

```bash
curl -fsSL https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/observability/install.sh | sudo bash
```

* **Zero Residue:** `curl` streams [observability/install.sh](observability/install.sh) directly to `sudo bash` over `stdin` without saving an installer script on disk, and temporary download tarballs are auto-cleaned via `trap 'rm -rf "$TMP_DIR"' EXIT`.
* **Open the Log Web UI (`vmui`) via Auto-Tunnel:**
  ```powershell
  # Windows PowerShell (auto-reads SSH_HOST/HOSTNAME, SSH_USER/USER, SSH_PORT/PORT from .\.env or TECHSTACK\.env)
  .\observability\open-logs.ps1
  # Or pass a host / custom .env explicitly:
  .\observability\open-logs.ps1 <user@server-ip>
  .\observability\open-logs.ps1 -EnvFile path\to\.env
  ```
  ```bash
  # Linux / macOS
  bash ./observability/open-logs.sh [<user@server-ip>]
  ```
* **Optional Environment Overrides:**
  ```bash
  curl -fsSL https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/observability/install.sh | sudo RETENTION_PERIOD=60d bash
  ```
* **If the repository is private:**
  ```bash
  curl -fsSL -H "Authorization: Bearer <GITHUB_TOKEN>" \
    https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/observability/install.sh | sudo bash
  ```

### Windows Local Setup (No Admin / UAC Required)

Windows does not have `systemd-journald`, so `start.ps1` starts standalone `victoria-logs-prod.exe` + [`observability/ship-logs.ps1`](observability/ship-logs.ps1) **first** before any app starts, and `stop.ps1` confirms all app processes & ports are dead and flushed **before** stopping VictoriaLogs **last**:

```powershell
irm https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/observability/install.ps1 | iex
```

* Once installed into `%LOCALAPPDATA%\VictoriaLogs`, your app's `start.ps1` / `stop.ps1` manage the full logger lifecycle automatically (`.\stop.ps1 -KeepLogger` keeps `http://127.0.0.1:9428/select/vmui/` open after stopping apps).

---

## Repository Index

| Document / Folder | Purpose |
| :--- | :--- |
| **[BACKEND_TECHSTACK.md](BACKEND_TECHSTACK.md)** | High-performance Rust (`Axum`, `Tokio`, `SQLx`, `tracing`, FSM architecture, decoupled observability) |
| **[FRONTEND_TECHSTACK.md](FRONTEND_TECHSTACK.md)** | Low-overhead SolidJS + Tailwind CSS + client FSM reactive architecture |
| **[MOBILE_TECHSTACK.md](MOBILE_TECHSTACK.md)** | High-FPS Flutter (`Impeller` + `signals_flutter` + `Drift`) architecture |
| **[OBSERVABILITY_MIGRATION.md](OBSERVABILITY_MIGRATION.md)** | Step-by-step host install & migration guide (`journald` on Linux, `ship-logs.ps1` + ordered lifecycle on Windows) |
| **[VIBE_CODING_RULES.md](VIBE_CODING_RULES.md)** | Cross-project coding & operational discipline rules |
| **[observability/install.sh](observability/install.sh)** | Self-contained, verified Linux host installer for `VictoriaLogs` + `systemd-journal-upload` |
| **[observability/install.ps1](observability/install.ps1)** | Zero-admin Windows installer for standalone `victoria-logs-prod.exe` (`%LOCALAPPDATA%\VictoriaLogs`) |
| **[observability/ship-logs.ps1](observability/ship-logs.ps1)** | Windows NDJSON/stderr log shipper with atomic `.stop-shipper` -> `.shipper-flushed` shutdown handshake |
| **`build-start-separation/`** | Target-platform 3-script (`build` / `start` / `stop` for `.ps1` and/or `.sh`) lifecycle standard & templates |
| **`solid-architecture/`** | Zero-cost SOLID architecture skill & cross-stack reference |
| **`responsive-ui-audit/`** | Responsive layout & mobile overflow audit skill |
