# Agentic Repository Rule Pattern for Build / Start / Stop Lifecycle

When pairing with AI coding agents (Antigravity, Gemini, Claude, Cursor), establishing a strict **Repository Rule** prevents artifact drift, orphaned background servers, and missing toolchain errors.

---

## 1. Setting Up `GEMINI.md` / `AGENTS.md`

Every project created with this tech stack MUST include the following lifecycle rules in its root `GEMINI.md` / `AGENTS.md`:

```markdown
# Repository Rules: Build, Start & Stop Lifecycle

## 1. Root Lifecycle Scripts (Per Target Platform)
This repository maintains three core lifecycle scripts for each target OS it supports (omit unsupported OS scripts for single-platform projects):
- **Windows targets (PowerShell):** `build.ps1`, `start.ps1`, `stop.ps1`
- **Linux / macOS targets (Bash):** `build.sh`, `start.sh`, `stop.sh`

## 2. Zero-Assumption Build Script (`build.ps1` / `build.sh`)
- `build.ps1` and `build.sh` MUST assume the host machine has zero pre-installed compilers, runtimes, or project dependencies.
- Phase 0 of `build` checks and verifies all required compilers and tools (Git, MSVC/GCC linker, Rust `cargo`/`rustc`, Node.js, `pnpm`, and Java JDK 17/Flutter if mobile is present).
- If a missing tool can be installed automatically, the script installs it; otherwise, it aborts with an explicit error message containing the missing dependency name, purpose, download URL, and manual install command.

## 3. Deterministic PID Tracking (`start` & `stop`)
- `start.ps1` / `start.sh` MUST run 100% optimized production artifacts (`target/release/` binary + `dist/` static bundle) and write the spawned process IDs to `.pids`.
- `stop.ps1` / `stop.sh` MUST read `.pids`, terminate the exact process trees by PID, sweep fallback ports, and remove `.pids`.
- If an agent starts the server for verification or Playwright responsive auditing, the agent MUST run `.\stop.ps1` (or `./stop.sh`) before finishing its turn unless the server was already running prior to the turn.

## 4. Mandatory Post-Implementation Build Step
Whenever any code modifications, bug fixes, refactoring, or feature implementations are completed:
- **Always run `powershell.exe -ExecutionPolicy Bypass -File .\build.ps1`** (or `./build.sh` on Linux) before finishing the turn.
- Verify that the build exits with code `0` so the user can run `.\start.ps1` / `./start.sh` immediately.
```

---

## 2. Preventing Git Conflicts with `.gitignore`

Ensure build outputs and the runtime `.pids` state file are ignored in `.gitignore`:

```gitignore
# Runtime PID tracking and logs
.pids
.backend.log
.frontend.log

# Frontend build outputs
frontend/dist/
frontend/node_modules/

# Backend build outputs
backend/target/
*.exe

# Mobile build outputs
mobile/build/
mobile/.dart_tool/

# SQLite WAL runtime files
*.db-shm
*.db-wal
```
