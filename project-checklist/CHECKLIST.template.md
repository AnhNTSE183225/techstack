# Project Compliance Checklist (`TECHSTACK`)

> **Local Tracker Only:** Ensure `CHECKLIST.md` is listed in `.gitignore`.
> **Mode:** `[ ] Greenfield (From 0)` | `[ ] Re-Evaluation`
> **Last Evaluated:** `YYYY-MM-DD`
> **Source Constitution:** `C:\GIT\TECHSTACK\VIBE_CODING_RULES.md`

---

## 0. Workspace Hygiene & Bootstrap
- [ ] `CHECKLIST.md` added to `.gitignore`
- [ ] Project engineering constitution present (`GEMINI.md` and/or `.cursor/rules/`) without conflicting with harness-managed state files
- [ ] `.gitignore` excludes build artifacts, secrets (`.env`, `config/local.yaml`), databases, `.pids`, `.logs/`

## 1. Target-Platform Lifecycle (`build-start-separation`)
- [ ] Windows scripts present (if Windows target): `build.ps1`, `start.ps1`, `stop.ps1`
- [ ] Linux/macOS scripts present (if Linux target): `build.sh`, `start.sh`, `stop.sh`
- [ ] `build` runs Phase 0 Zero-Assumption toolchain checklist (auto-install or actionable fatal error)
- [ ] `build` invokes `stop` first to unlock binaries before compiling
- [ ] `start` executes **only** pre-compiled release binaries (`target/release/`) & production bundles (`dist/`) — never dev mode
- [ ] `start` persists PIDs to root `.pids`; `stop` deterministically terminates stored PID trees + fallback port sweep + removes `.pids`

## 2. Backend Architecture (`BACKEND_TECHSTACK.md`)
- [ ] Rust (`Axum` + `Tokio` + `SQLx` SQLite WAL + `Mimalloc`)
- [ ] Cascading YAML config (`config/default.yaml` + `config/prod.yaml` + optional `config/local.yaml` / `APP__*` env overrides)
- [ ] Release profile configured (`opt-level = 3`, `lto = "fat"`, `codegen-units = 1`, `panic = "abort"`, `strip = "debuginfo"`)
- [ ] Passwords hashed with `argon2` (Argon2id + random salt) where auth is present; zero plaintext secrets in DB
- [ ] Input validation (`validator` / typed DTOs) and unified `AppError` (`thiserror`) responses

## 3. Frontend & Mobile Architecture (`FRONTEND_TECHSTACK.md` / `MOBILE_TECHSTACK.md`)
- [ ] Web SPA built with SolidJS + Vite + Tailwind CSS + WAAPI transitions (zero prop destructuring; `<Show>` / `<For>` control flow)
- [ ] Vite production preview proxy uses unbounded `keepAliveAgent` (`maxSockets: Infinity`)
- [ ] PWA manifest (`display: standalone`) + Service Worker configured (if Web Push / installable PWA)
- [ ] Mobile (`Flutter Impeller` + `signals_flutter` + `Drift`) verified *(or mark N/A if no mobile target)*

## 4. SOLID Architecture & Deterministic FSM (`solid-architecture` & Rule 2)
- [ ] Strict 4-layer separation (Transport/View → Services/Stores → Models → Repositories/API); zero God files
- [ ] Traits / narrow interfaces / compile-time generics used (zero unnecessary runtime reflection)
- [ ] End-to-End Deterministic FSM: singular `status` discriminant (`disconnected | idle | loading | active | paused | error`), zero scattered boolean flags
- [ ] Transitions logged via `[FSM] Entity <id>: <old> -> <new> (Reason: <reason>)`
- [ ] Atomic teardown of intervals/SSE/timers on resting states

## 5. Responsive UI Audit (`responsive-ui-audit`)
- [ ] 5px translucent custom scrollbar (`rgba(148, 163, 184, 0.25)`) + `.no-scrollbar` utility in root CSS
- [ ] Sliding active tab pill indicator (`cubic-bezier(0.16, 1, 0.3, 1)`)
- [ ] Dynamic flex-stretch grids for odd-count card collections *(or N/A)*
- [ ] Automated Playwright 8-viewport check (`375x667` to `2560x1080`): `total_overflows == 0` and zero console/page errors

## 6. Decoupled Observability & Instrumentation (`OBSERVABILITY_MIGRATION.md`)
- [ ] Structured JSON tracing in production (`LOG_FORMAT=json` / `PROFILE=PROD`) + panic hook + `RUST_BACKTRACE=1`
- [ ] Meaningful spans/logs for latency, state transitions, fallbacks, and errors (never silently swallowed)
- [ ] Windows: `start.ps1` starts VictoriaLogs (`127.0.0.1:9428`) + `ship-logs.ps1` **first**; `stop.ps1` stops apps -> confirms dead -> flushes shipper -> stops VictoriaLogs **last**
- [ ] Linux: `systemd-journald` → `VictoriaLogs` ready (no flat `nohup` logs or unauthenticated `/api/logs`)

## 7. Security Audit Pipeline (`security-audit`) — Strict Order
- [ ] **Tier 1 — Gitleaks:** Secret scan executed (`gitleaks detect --no-git` & `gitleaks git`); zero leaked credentials/keys
- [ ] **Tier 2 — Vibe Security Skill (9 Areas):**
  - [ ] 1. Secrets Exposure
  - [ ] 2. Database Access Control
  - [ ] 3. Authentication & Sessions
  - [ ] 4. Rate Limiting & Abuse Protection
  - [ ] 5. Payments & Webhooks *(or N/A)*
  - [ ] 6. Mobile Security *(or N/A)*
  - [ ] 7. AI / LLM Integration *(or N/A)*
  - [ ] 8. Deployment Config (CORS, headers, debug flags)
  - [ ] 9. Input Validation & Injection Defense
- [ ] **Tier 3 — Cloudflare Security Audit Skill (Heavy Final Audit):**
  - [ ] Reconnaissance & trust-boundary coverage map completed
  - [ ] Coverage-led vulnerability hunting completed
  - [ ] Adversarial independent validation completed on all candidate findings
  - [ ] Confirmed High/Critical/Medium findings fixed and re-verified

## 8. Final Release Gate
- [ ] Unit/integration tests pass (`cargo test`, `tsc --noEmit`)
- [ ] Full production build passes (`.\build.ps1` / `./build.sh`, exit code `0`)
- [ ] Verification servers stopped cleanly (`.\stop.ps1` / `./stop.sh`)

---

## Audit Notes & Findings Log
- _Record evaluation date, command results, findings remediated, and remaining N/A notes here._
