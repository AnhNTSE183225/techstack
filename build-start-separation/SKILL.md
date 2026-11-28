---
name: build-start-separation
description: >-
  Enforces the 3-script lifecycle architecture (`build`, `start`, `stop`) across both Windows
  (`build.ps1`, `start.ps1`, `stop.ps1`) and Linux (`build.sh`, `start.sh`, `stop.sh`). Guarantees
  a Zero-Assumption pre-flight dependency/toolchain checklist in `build`, 100% optimized production
  execution in `start` with `.pids` tracking, and deterministic PID-based process tree termination in `stop`.
---

# Build / Start / Stop Script Separation Architecture

This specification defines the mandatory lifecycle script architecture for full-stack, multi-service, and compiled projects across Backend ([BACKEND_TECHSTACK.md](../BACKEND_TECHSTACK.md)), Frontend ([FRONTEND_TECHSTACK.md](../FRONTEND_TECHSTACK.md)), and Mobile ([MOBILE_TECHSTACK.md](../MOBILE_TECHSTACK.md)).

---

## ⚡ The Three Cardinal Rules

> [!IMPORTANT]
> 1. **Target-Platform 3-Script Mandate (`build`, `start`, `stop`):**
>    Every repository MUST provide `build`, `start`, and `stop` scripts at the root for **each supported target OS** (single-platform projects only need scripts for that OS):
>    * **Windows targets:** `build.ps1`, `start.ps1`, `stop.ps1`
>    * **Linux / macOS targets:** `build.sh`, `start.sh`, `stop.sh`
>    * *(Cross-platform projects include all 6.)*
>
> 2. **Zero-Assumption Build Script (`build.ps1` / `build.sh`):**
>    The build script MUST assume the target machine is a **completely bare system with zero pre-installed compilers, runtimes, or dependencies** (no Rust, no MSVC/GCC linker, no Node.js, no pnpm, no Java/JDK, no Flutter).
>    * It must run an **extensive pre-flight verification checklist** at Phase 0.
>    * If a missing dependency/compiler can be installed automatically by the script (`winget`, `rustup-init`, `corepack`, `apt`/`dnf`/`pacman`), it installs it and refreshes `PATH`.
>    * If a dependency cannot be auto-installed (or auto-install fails), it MUST immediately throw a formatted, actionable fatal error stating **what is missing, why it is needed, the official download URL, and the exact manual install command**.
>
> 3. **100% Optimized, Detached-by-Default Production Start (`start`) & Deterministic PID Stop (`stop`):**
>    * `start.ps1` / `start.sh` MUST NEVER run development servers (`npm run dev`, `vite`, `cargo run`). It executes ONLY pre-compiled Release binaries (`target/release/`) and minified production bundles (`dist/`).
>    * **Detached Default (No Hung Terminals):** Running `.\start.ps1` / `./start.sh` MUST default to **detached background execution** and return exit code `0` as soon as health probes pass (requiring explicit `-Foreground` / `--foreground` to attach live logs).
>    * **Zero Stdio Handle Leaks on Windows (`Start-Process`):** Redirect `stdin` (`-RedirectStandardInput`) to an empty `.stdin` file in `.logs\` for **every** hidden child process (`VictoriaLogs`, `ship-logs.ps1` with `-NonInteractive`, backend, frontend), invoke `node.exe` directly on `node_modules\vite\bin\vite.js` instead of `pnpm.cmd`/`cmd.exe` wrappers, and pass `-DisableKeepAlive` on readiness HTTP probes so parent shells/agent runners never block waiting on inherited pipes.
>    * `start` MUST immediately persist the launched process IDs (`backend_pid`, `frontend_pid`, ports, timestamp) to a root `.pids` state file.
>    * `stop.ps1` / `stop.sh` MUST read `.pids` and deterministically kill the stored PIDs and their child process trees (`taskkill /PID <id> /T /F` on Windows; `pkill -P <id>` + `kill` on Linux), then delete `.pids`.

---

## The Three-Script Separation Model (Per Target OS)

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                   REPOSITORY ROOT (3 SCRIPTS PER TARGET PLATFORM)                      │
├───────────────────────────┬─────────────────────────────┬──────────────────────────────┤
│   build.ps1 / build.sh    │    start.ps1 / start.sh     │     stop.ps1 / stop.sh       │
│  (Zero-Assumption Build)  │     (Production Runner)     │   (Deterministic PID Stop)   │
├───────────────────────────┼─────────────────────────────┼──────────────────────────────┤
│ • Assumes bare OS         │ • Calls stop first          │ • Reads stored .pids file    │
│ • Runs extensive pre-     │ • Auto-runs build ONLY if   │ • Kills exact Backend &      │
│   flight toolchain check  │   artifacts are missing     │   Frontend PIDs + child tree │
│ • Auto-installs or throws │ • Runs Release binary &     │ • Sweeps fallback ports for  │
│   explicit download error │   static preview (dist/)    │   any orphaned subprocesses  │
│ • Calls stop to unlock    │ • Persists active PIDs to   │ • Deletes .pids cleanly      │
│   Windows binaries        │   root .pids file           │ • Called by build, start,    │
│ • Builds dist/ & --release│ • < 500ms cold start        │   Ctrl+C trap, or user CLI   │
└───────────────────────────┴─────────────────────────────┴──────────────────────────────┘
```

---

## Zero-Assumption Toolchain Checklist Matrix (`build.ps1` / `build.sh`)

Every `build.ps1` and `build.sh` MUST verify the following checklist in order before compiling project code:

| # | Toolchain / Dependency | Windows Verification & Auto-Install (`build.ps1`) | Linux Verification & Auto-Install (`build.sh`) | Action if Auto-Install Unavailable / Fails |
| :- | :--- | :--- | :--- | :--- |
| **1** | **Git SCM (`git`)** | `Get-Command git` → `winget install Git.Git` | `command -v git` → `apt/dnf/pacman install git curl` | Throw fatal error with `https://git-scm.com/downloads` |
| **2** | **Native C/C++ Compiler & Linker** | `cl.exe` or `vswhere` (`VC.Tools.x86.x64`) → `winget install Microsoft.VisualStudio.2022.BuildTools` | `cc` & `pkg-config` & `libssl-dev` → `apt install build-essential pkg-config libssl-dev` | Throw fatal error with Visual Studio C++ Build Tools / distro package instructions |
| **3** | **Rust Toolchain (`rustup`, `rustc`, `cargo`)** | `Get-Command cargo` → `winget install Rustlang.Rustup` + `rustup default stable` | `command -v cargo` → `curl https://sh.rustup.rs \| sh -s -- -y` | Throw fatal error with `https://rustup.rs/` |
| **4** | **Node.js LTS (`node`)** | `Get-Command node` → `winget install OpenJS.NodeJS.LTS` | `command -v node` → `apt/dnf/pacman install nodejs npm` | Throw fatal error with `https://nodejs.org/` |
| **5** | **pnpm Package Manager (`pnpm`)** | `Get-Command pnpm` → `corepack enable && corepack prepare pnpm@latest --activate` or `winget install pnpm.pnpm` | `command -v pnpm` → `corepack enable` or `npm install -g pnpm` | Throw fatal error with `https://pnpm.io/installation` |
| **6** | **Java JDK 17 (`java` / `javac`)** *(if Mobile present)* | `Get-Command java` → `winget install Microsoft.OpenJDK.17` | `command -v java` → `apt install openjdk-17-jdk` | Throw fatal error with `https://adoptium.net/` |
| **7** | **Flutter & Dart AOT SDK (`flutter`)** *(if Mobile present)* | `Get-Command flutter` → `winget install Google.Flutter` | `command -v flutter` → Check `$HOME/flutter/bin` | Throw fatal error with `https://docs.flutter.dev/get-started/install` |

---

## Why Dev Mode Fails for Startup Speed

| Metric | Development Mode (`npm run dev` + `cargo run`) | Optimized Production (`start.ps1` / `start.sh`) |
| :--- | :--- | :--- |
| **Startup Speed** | 5 – 20+ seconds (cold start, module graph analysis) | **< 500 milliseconds** (instant binary execution) |
| **Browser Experience** | 5 – 10s blank white screen while transpiling thousands of modules | **Instant visual render** with zero layout shift |
| **Backend Performance**| Debug build (`opt-level = 0`, 20x–100x slower compute) | **Release build** (`opt-level = 3`, fat LTO, stripped symbols) |
| **Process Control** | Orphaned node/cargo watchers left behind in background | **Deterministic `.pids` file** stopped cleanly via `stop.ps1` / `stop.sh` |
| **Windows File Locks** | Recompiling while running crashes with `OS Error 5` | `build.ps1` invokes `stop.ps1` first to unlock all `.exe` files |

---

## Architecture Implementation Steps

### Step 1: Structure the Build Script (`build.ps1` & `build.sh`)
1. **Phase 0 — Zero-Assumption Pre-Flight Checklist:** Verify Git, C/C++ linker, Rust (`rustc`/`cargo`), Node.js, `pnpm`, and (if mobile is included) OpenJDK 17 and Flutter. Attempt automated installation where supported; otherwise throw a detailed error with the download URL and manual install command.
2. **Phase 1 — Stop Running Services:** Invoke `.\stop.ps1 -Quiet` / `./stop.sh --quiet` to kill active PIDs and unlock running binaries on Windows (`OS Error 5` prevention).
3. **Phase 2 — Frontend Production Bundling:** Run `pnpm install` and `pnpm run build` (`tsc && vite build` -> `dist/`). Verify `dist/index.html` exists.
4. **Phase 3 — Backend Release Compilation:** Compile with `cargo build --release` using a shared Cargo target cache (`CARGO_TARGET_DIR` / `[build] target-dir` so multi-repo dependency crates are stored once instead of per-repo) and stage only the compiled release binary to `target/release/`. Verify the release binary exists in `target/release/`.
5. **Phase 4 — Mobile Release Compilation (Optional):** Run `flutter pub get`, `build_runner`, and `flutter build apk --release --split-per-abi`.

👉 See [examples/build.ps1.template](./examples/build.ps1.template) and [examples/build.sh.template](./examples/build.sh.template).

---

### Step 2: Structure the Runtime Launcher (`start.ps1` & `start.sh`)
1. **Clean Slate via `stop`:** Invoke `.\stop.ps1 -Quiet` / `./stop.sh --quiet` first if an instance is already running.
2. **Artifact Verification (`Ensure-BuildArtifacts`):** Check if `frontend/dist/index.html` and `backend/target/release/<binary>` exist. Run `build` automatically **only** if missing.
3. **Start Observability Stack FIRST (Windows `start.ps1`):** Boot `victoria-logs-prod.exe` on `127.0.0.1:9428`, wait for `/health` `200 OK`, and start `observability/ship-logs.ps1` before any app starts so startup errors and panics are never lost.
4. **Launch Pre-Compiled Production Artifacts (Detached & Pipe-Safe):** Spawn the release binary (`RUST_LOG=info`, `LOG_FORMAT=json`) and static preview server (`node.exe` -> `vite/bin/vite.js preview`, avoiding `pnpm.cmd` wrapper handles), redirecting Windows `stdin` (`-RedirectStandardInput` empty files in `.logs\`), `stdout`, and `stderr` cleanly (or `< /dev/null` on Linux / `systemd-journald`). Always set `$env:APP__SERVER__PORT = "$BackendPort"` unconditionally and restore any caller `$env:*` overrides in `try / finally` so launching one app never leaks ports/profiles into another app started from the same PowerShell session (see [PORTS.md](../../PORTS.md)).
5. **Persist `.pids` State File:** Immediately write `logger_pid`, `logger_owned`, `logger_port`, `shipper_pid`, `backend_pid`, `frontend_pid`, `backend_port`, `frontend_port`, `tailscale_serve`, and `started_at` to `<repo-root>/.pids`.
6. **Optional Tailscale Serve HTTPS Proxy (Mobile & PWA Access):** When Tailscale is installed on Windows (and `-SkipTailscale` is not passed), discover the machine's MagicDNS hostname via `tailscale status --json` (`Self.DNSName`), expose the frontend over valid TLS with `tailscale serve --bg --yes --https=443 "http://127.0.0.1:$FrontendPort"`, set `APP__SERVER__FRONTEND_URL="https://<dns-host>"` so CORS and Web Push URLs match, and allow `.ts.net` in Vite's `allowedHosts: [".ts.net", "localhost", "127.0.0.1"]`. This provides a trusted HTTPS origin for iOS/Android PWA installation and Web Push testing on phones.
7. **Fast Readiness Probing, Detached Exit & Optional `-Foreground` Trap:** Poll endpoints at 100ms intervals (`-DisableKeepAlive`) until `200 OK`, print clickable URLs (including `https://<dns-host>`) and PIDs, and **exit `0` immediately in detached mode by default**. Only when `-Foreground` (Windows) or `--foreground` (Linux) is passed does `start` stream live prefixed logs and trap Ctrl+C (`SIGINT`/`SIGTERM`/`PipelineStoppedException`) to invoke `stop.ps1` / `stop.sh`.

👉 See [examples/start.ps1.template](./examples/start.ps1.template) and [examples/start.sh.template](./examples/start.sh.template).

---

### Step 3: Structure the Deterministic Stop Script (`stop.ps1` & `stop.sh`)
1. **Read `.pids` File:** Parse `backend_pid`, `frontend_pid`, `tailscale_serve`, `logger_pid`, `logger_owned`, `logger_port`, and `shipper_pid` from `<repo-root>/.pids`.
2. **Reset Tailscale Serve (If Owned) & Kill Application Process Trees FIRST:**
   * If `tailscale_serve` is `true` in `.pids`, run `tailscale serve reset` so the host proxy is cleaned up without disturbing unrelated configs when disabled.
   * **Windows (`stop.ps1`):** Execute `taskkill.exe /PID <pid> /T /F` and `Stop-Process -Id <pid> -Force` on Frontend and Backend PIDs.
   * **Linux (`stop.sh`):** Execute `pkill -TERM -P <pid>` and `kill -TERM <pid>`, escalating to `kill -KILL` after 200ms if still alive.
3. **Fallback App Port Sweep & Confirmed Shutdown (Windows):** Check application ports (`8080`, `5173`, etc. — **excluding** `logger_port` `9428`), terminate survivors, and **poll to confirm every application PID & port is completely dead**. If any app lingers, abort logger teardown so shutdown diagnostics remain captured.
4. **Flush Shipper & Stop Logger LAST (Windows):** Create `.logs\.stop-shipper`, wait for `.logs\.shipper-flushed` (trailing `stdout`/`stderr` shipped to `VictoriaLogs`), terminate `VictoriaLogs` **last** (unless `-KeepLogger` is set), and delete `.pids`.

👉 See [examples/stop.ps1.template](./examples/stop.ps1.template) and [examples/stop.sh.template](./examples/stop.sh.template).

---

## Detailed References & Templates

- [Architecture Deep Dive & Lifecycle Flow](./references/architecture.md)
- [Agent Repo Rule Pattern](./references/repo-rule-pattern.md)
- **Windows (PowerShell Templates):**
  - [build.ps1.template](./examples/build.ps1.template)
  - [start.ps1.template](./examples/start.ps1.template)
  - [stop.ps1.template](./examples/stop.ps1.template)
- **Linux / macOS (Bash Templates):**
  - [build.sh.template](./examples/build.sh.template)
  - [start.sh.template](./examples/start.sh.template)
  - [stop.sh.template](./examples/stop.sh.template)
