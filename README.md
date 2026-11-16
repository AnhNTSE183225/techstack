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

---

## Repository Index

| Document / Folder | Purpose |
| :--- | :--- |
| **[BACKEND_TECHSTACK.md](BACKEND_TECHSTACK.md)** | High-performance Rust (`Axum`, `Tokio`, `SQLx`, `tracing`, FSM architecture, decoupled observability) |
| **[FRONTEND_TECHSTACK.md](FRONTEND_TECHSTACK.md)** | Low-overhead SolidJS + Tailwind CSS + client FSM reactive architecture |
| **[MOBILE_TECHSTACK.md](MOBILE_TECHSTACK.md)** | High-FPS Flutter (`Impeller` + `signals_flutter` + `Drift`) architecture |
| **[OBSERVABILITY_MIGRATION.md](OBSERVABILITY_MIGRATION.md)** | Step-by-step host install & migration guide from flat logs / `/api/logs` to `journald` + `VictoriaLogs` |
| **[VIBE_CODING_RULES.md](VIBE_CODING_RULES.md)** | Cross-project coding & operational discipline rules |
| **[observability/install.sh](observability/install.sh)** | Self-contained, verified Linux host installer for `VictoriaLogs` + `systemd-journal-upload` |
| **`build-start-separation/`** | 6-script (`build` / `start` / `stop` for `.ps1` & `.sh`) lifecycle standard & templates |
| **`solid-architecture/`** | Zero-cost SOLID architecture skill & cross-stack reference |
| **`responsive-ui-audit/`** | Responsive layout & mobile overflow audit skill |
