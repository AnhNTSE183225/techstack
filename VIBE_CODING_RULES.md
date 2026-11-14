# VIBE_CODING_RULES.md: Master Architecture & Agentic Engineering Constitution

This document serves as the **single unified rulebook** for building, running, auditing, and maintaining full-stack and cross-platform projects using this repository's specifications. Drop or reference this constitution in any project (`GEMINI.md` / `AGENTS.md`) to enforce deterministic, ultra-low-overhead engineering standards.

---

## 1. Repository Specification Map

| Specification / Skill | Scope | Core Mandate |
| :--- | :--- | :--- |
| **[BACKEND_TECHSTACK.md](./BACKEND_TECHSTACK.md)** | Rust Backend (`Axum` + `Tokio` + `SQLx` + `Mimalloc`) | Sub-ms p99 latency, 10–30 MB idle RAM, in-process SQLite WAL mode, cascading YAML config, `--release` (`opt-level = 3`, fat LTO) compilation. |
| **[FRONTEND_TECHSTACK.md](./FRONTEND_TECHSTACK.md)** | Web SPA (`SolidJS` + `Vite` + `Tailwind` + `WAAPI`) | Zero Virtual DOM, fine-grained signals (`createSignal`), < 25 KB gzipped bundle, compositor-thread WAAPI animations, never destructure props. |
| **[MOBILE_TECHSTACK.md](./MOBILE_TECHSTACK.md)** | Mobile App (`Flutter Impeller` + `Dart AOT` + `Drift`) | Locked 60–120Hz Vulkan/Metal rendering, offline pre-compiled shaders, `signals_flutter` leaf updates (`Watch`), background-isolate C FFI SQLite WAL. |
| **[build-start-separation](./build-start-separation/SKILL.md)** | 6-Script Lifecycle (`build`, `start`, `stop` in `.ps1` & `.sh`) | Zero-Assumption toolchain checklist in `build`, 100% production execution in `start` (stores `.pids`), deterministic PID tree termination in `stop`. |
| **[responsive-ui-audit](./responsive-ui-audit/SKILL.md)** | Responsive Layout & Visual Polish (`Playwright` + `MusicBotUI`) | Zero horizontal overflow across 8 viewports, 5px translucent custom scroller, `cubic-bezier(0.16, 1, 0.3, 1)` sliding tab pill, dynamic flex-stretch grids. |
| **[solid-architecture](./solid-architecture/SKILL.md)** | SOLID Code Design & Agent Prompt Decomposition | Enforces SRP, OCP, LSP, ISP, and DIP across Rust, SolidJS, and Flutter using zero-cost compile-time abstractions, plus SOLID agent task decomposition. |

---

## 2. Rule 1: The 6-Script Lifecycle Mandate (`build` / `start` / `stop` for Windows & Linux)

Every project MUST include **six root lifecycle scripts** covering **both Windows PowerShell (`.ps1`) and Linux/macOS Bash (`.sh`)**:

```text
<project-root>/
├── build.ps1      # [Windows] Zero-Assumption Toolchain Checklist + Production Build
├── start.ps1      # [Windows] 100% Optimized Production Runner (writes .pids)
├── stop.ps1       # [Windows] Deterministic Process Tree Stopper (reads .pids)
├── build.sh       # [Linux]   Zero-Assumption Toolchain Checklist + Production Build
├── start.sh       # [Linux]   100% Optimized Production Runner (writes .pids)
├── stop.sh        # [Linux]   Deterministic Process Tree Stopper (reads .pids)
└── .pids          # [Runtime] Active process IDs written by start, consumed by stop
```

### 2.1 Zero-Assumption Build Script (`build.ps1` & `build.sh`)
* **Assume the Host System Has Nothing Installed:** The build script MUST NOT assume compilers, linkers, runtimes, or package managers exist on the machine.
* **Mandatory Phase 0 Pre-Flight Checklist:**
  1. **Git SCM (`git`)**
  2. **Native C/C++ Compiler & Linker** (`MSVC Build Tools / cl.exe` on Windows; `build-essential`, `pkg-config`, `libssl-dev` on Linux)
  3. **Rust Toolchain** (`rustup`, `rustc`, `cargo`)
  4. **Node.js LTS (`node`)**
  5. **Fast Package Manager (`pnpm`)**
  6. **Java JDK 17 (`java`) & Flutter SDK (`flutter`)** *(when mobile target is present)*
* **Auto-Install or Explicit Actionable Failure:**
  * For each checklist item, if the tool is missing, the script attempts automated installation (`winget`, `rustup.rs`, `corepack`, `apt`/`dnf`/`pacman`) and refreshes `PATH`.
  * If automated installation is impossible or fails, the script MUST immediately abort with a formatted fatal error displaying the **missing component name, why it is required, the official download URL, and the exact manual install command**.
* **Pre-Build Binary Unlocking:**
  * `build.ps1` / `build.sh` MUST invoke `stop.ps1` / `stop.sh` before compiling so running executables on Windows are unlocked (preventing `OS Error 5: Access is denied`).
* **100% Release Optimization:**
  * Compiles Backend with `cargo build --release` (`opt-level = 3`, `lto = "fat"`), Frontend with `pnpm run build` (`tsc && vite build` -> `dist/`), and Mobile with `flutter build apk --release --split-per-abi`.

### 2.2 100% Optimized Production Start (`start.ps1` & `start.sh`)
* **Never Run Dev Mode in `start`:** `start.ps1` and `start.sh` MUST NEVER invoke `npm run dev`, `vite`, `cargo run`, or JIT debug watchers. They execute ONLY pre-compiled release binaries (`target/release/`) and static production bundles (`dist/`).
* **Auto-Build Fallback:** Checks if `frontend/dist/index.html` and `backend/target/release/<binary>` exist; runs `build` automatically **only** if artifacts are missing.
* **Mandatory `.pids` Persistence:** Immediately upon spawning the backend and frontend processes, `start` MUST write their OS PIDs (`backend_pid`, `frontend_pid`, ports, and timestamp) to `<project-root>/.pids`.

### 2.3 Deterministic PID-Based Stop (`stop.ps1` & `stop.sh`)
* **Stop by Stored PID:** Reads `<project-root>/.pids` and terminates the exact `frontend_pid` and `backend_pid` along with their entire child process trees (`taskkill /PID <id> /T /F` on Windows; `pkill -P <id>` + `kill` on Linux).
* **Fallback Port Sweep & Cleanup:** Sweeps project ports (`8080`, `5173`, etc.) for any surviving child processes and deletes `.pids`.

👉 **Ready-to-Copy Script Templates:**
* Windows: [build.ps1.template](./build-start-separation/examples/build.ps1.template) | [start.ps1.template](./build-start-separation/examples/start.ps1.template) | [stop.ps1.template](./build-start-separation/examples/stop.ps1.template)
* Linux: [build.sh.template](./build-start-separation/examples/build.sh.template) | [start.sh.template](./build-start-separation/examples/start.sh.template) | [stop.sh.template](./build-start-separation/examples/stop.sh.template)

---

## 3. Rule 2: End-to-End Deterministic Finite State Machine (FSM) Contract

Across Backend (Rust), Frontend (SolidJS), and Mobile (Flutter), **scattered boolean flags (`is_active`, `is_loading`, `is_paused`, `has_error`, `stopped`) are strictly forbidden**.

1. **Singular `status` Discriminant:**
   * All REST DTOs, WebSocket frames, and SSE events serialize a single lowercase `status` field:
     `'disconnected' | 'idle' | 'loading' | 'active' | 'paused' | 'error'` (plus `'terminated'` internal backend state).
2. **Encapsulated State Transitions & Structured Logging:**
   * Transitions occur exclusively via dedicated transition methods (`transition_to` / `transitionTo`) that emit a structured log entry (`[FSM] Entity <id>: <old> -> <new> (Reason: <reason>)`).
3. **Atomic Teardown on Resting States:**
   * Entering `idle`, `disconnected`, `error`, or `terminated` MUST atomically cancel active timers, `setInterval` loops, animation frames, and OS/driver handles, and nullify active data pointers to prevent UI tearing or phantom `00:00` counter loops.
4. **Resilient Fallback Resolution:**
   * Clients implement `resolveEntityStatus(dto)` to deterministically map legacy payloads if `status` is ever omitted.

---

## 4. Rule 3: Responsive UI Audit & Visual Design Standards (`MusicBotUI` Pattern)

Every Web and Mobile UI built under this constitution MUST pass the 5-Phase Responsive Audit ([responsive-ui-audit/SKILL.md](./responsive-ui-audit/SKILL.md)):

1. **Custom Sleek Translucent Scroller (No Default White Browser Scrollbars):**
   * Root CSS (`index.css`) MUST define the 5px rounded translucent scrollbar (`rgba(148, 163, 184, 0.25)`) and `.no-scrollbar` utility (compare [bad-default-scrollbar.png](./responsive-ui-audit/resources/bad-default-scrollbar.png)).
2. **Sliding Active Tab Pill Indicator:**
   * Tab bars and segmented controls MUST use an absolute sliding pill indicator transitioning `transform: translateX(...)` and `width` with `cubic-bezier(0.16, 1, 0.3, 1)` (`300ms`) rather than abrupt background color toggles (see [sliding-tab-fixed.png](./responsive-ui-audit/resources/sliding-tab-fixed.png)).
3. **Balanced Odd-Item Card Grids (Dynamic Flex Stretch):**
   * Use `flex flex-wrap items-stretch gap-2.5` with `flex-1 min-w-[210px]` on cards so odd-numbered collections (e.g., 5 items) dynamically stretch to fill 100% of every row without leaving empty bottom-right voids (see [balanced-providers-fixed.png](./responsive-ui-audit/resources/balanced-providers-fixed.png)).
4. **Automated 8-Viewport Zero-Overflow Verification:**
   * Run [detect_overflows.py](./responsive-ui-audit/scripts/detect_overflows.py) and [capture_responsive.py](./responsive-ui-audit/scripts/capture_responsive.py) across all 8 viewports (`375x667` to `2560x1080`) and verify `total_overflows == 0`.

---

## 5. Rule 4: Mandatory SOLID Architecture & Agent Prompt Decomposition

AI models do **not** naturally write SOLID code by default; without explicit guardrails, AI-generated code degrades into monolithic "God files" and tightly coupled scripts. Every AI agent operating under this constitution MUST enforce [solid-architecture/SKILL.md](./solid-architecture/SKILL.md) and [solid-across-stacks.md](./solid-architecture/references/solid-across-stacks.md) at **two levels**:

### 5.1 Level 1 — Zero-Cost SOLID Code Architecture (Rust, SolidJS, Flutter)
1. **Single Responsibility Principle (SRP):**
   * Every file, struct, store, and UI component MUST have **only one reason to change**.
   * Strictly separate **Transport/UI Views** (`routes/`, `components/`, `pages/`), **Application/FSM Logic** (`handlers/`, `services/`, `stores/`), **Domain Contracts/Models** (`models/`), and **Persistence/Network I/O** (`repositories/`, `api/`, `database/`). Never embed raw SQL in an Axum route handler or raw `fetch()`/business logic inside a SolidJS/Flutter view.
2. **Open/Closed Principle (OCP):**
   * Modules must be **open for extension, closed for modification**. Use Rust traits/enums, TypeScript strategy maps/slots (`props.children`), and Flutter composable builders instead of expanding giant `if/else` chains in core logic.
3. **Liskov Substitution Principle (LSP):**
   * All implementations of a repository trait, API gateway, or telemetry stream (whether live SSE, cached SQLite WAL, or test mock) MUST honor the exact same `StateMachineDTO<T>` (`status`) and `Result<T, AppError>` behavioral contracts.
4. **Interface Segregation Principle (ISP):**
   * Never pass bloated "God stores" or monolithic traits to consumers that only need a single field. Split Rust traits by role (`Reader` vs `Writer`) and pass narrow TypeScript/Dart interfaces (`Pick<T, K>` or single-signal `Accessor<T>`) to leaf UI components.
5. **Dependency Inversion Principle (DIP):**
   * High-level domain services and UI stores MUST depend on **abstractions** (traits/interfaces) and **structured configuration** (`AppConfig` loaded from `config/default.yaml` or `config/default.json`)—never on hardcoded URLs, file paths, or low-level driver internals.
   * **Performance Guarantee:** Implement DIP using **compile-time generics (`<R: Repository>`) and static traits/interfaces** rather than heavy runtime reflection or unnecessary heap vtables.

### 5.2 Level 2 — SOLID AI Task & Prompt Decomposition
As illustrated in [solid-prompt-engineering.jpg](./solid-architecture/resources/solid-prompt-engineering.jpg), when decomposing complex user requests or delegating to subagents:
* **S (Single Objective):** Break multi-part user prompts into focused, single-objective steps (1. Schema/Repository → 2. Service/Handler → 3. Reactive UI/FSM → 4. Build & Responsive Audit).
* **O (Extensible Instructions):** Treat core techstack rules as closed baseline contracts and layer feature-specific requirements as modular add-ons.
* **L (Interchangeable Specializations):** Specialized subagents or modules must return consistent, predictable output schemas.
* **I (Focused Context):** Feed only the relevant stack specification and file slice required for the task at hand to avoid context dilution.
* **D (Structured Inputs over Hardcoding):** Parameterize tasks around explicit schemas, DTOs, and YAML/JSON configs rather than ad-hoc hardcoded values.

---

## 6. Rule 5: Agent Operational Discipline

When an AI coding agent works on a project governed by these rules:
1. **Check Before Starting:** Before running `start.ps1` / `start.sh`, check if `.pids` exists or if the application ports are already active. If already running, connect to the existing instance.
2. **SOLID Self-Audit Before Building:** Verify that no new God files, mixed-concern handlers, bloated prop interfaces, or hardcoded infrastructure dependencies were introduced.
3. **Mandatory Post-Implementation Build:** After any code change in `backend/`, `frontend/`, or `mobile/`, **always run `.\build.ps1` (or `./build.sh`)** and verify exit code `0` before finishing the turn so production artifacts are never stale.
4. **Clean Stop After Auditing:** If the agent started the local server solely for verification or Playwright responsive auditing, the agent **MUST run `.\stop.ps1` (or `./stop.sh`)** to terminate the stored PIDs as soon as testing completes.
