# BACKEND_TECHSTACK.md: High-Performance Rust Architecture

A reference specification for building an ultra-low latency, low-footprint pure backend service in Rust designed for sub-millisecond p99 latency, minimal idle memory (10–30 MB), and seamless execution across **local Windows development** and **low-power Raspberry Pi production**.

---

## 1. Toolchain & Core Prerequisites

| Component | Role | Documentation & Reference |
| :--- | :--- | :--- |
| **Rust Toolchain (`rustup` / `cargo` / `rustc`)** | Core systems language toolchain (zero GC, deterministic borrow-checker lifetimes) | • [rustup Installer](https://rustup.rs/)<br>• [The Rust Programming Language Book](https://doc.rust-lang.org/book/)<br>• [Rust Standard Library Reference](https://doc.rust-lang.org/std/) |
| **LLVM Toolchain / MSVC** | Native binary code generation (x86_64 Windows & ARM Linux compilation) | • Windows: Visual Studio C++ Build Tools (MSVC ABI)<br>• Linux target: `aarch64-unknown-linux-musl` |
| **`cross` (`cross-rs`)** | Zero-setup cross-compilation from Windows to ARM Linux via isolated build containers | • [cross-rs GitHub](https://github.com/cross-rs/cross) |
| **`just` (Command Runner)** | Unified, cross-platform task runner replacing fragmented `.bat` and `.sh` scripts | • [just Manual](https://just.systems/man/en/) |
| **Cargo Subcommands** | Development automation & validation | • [cargo-watch](https://crates.io/crates/cargo-watch) (Auto-reload / watch changes)<br>• [sqlx-cli](https://crates.io/crates/sqlx-cli) (`cargo sqlx prepare` for offline query caching)<br>• [cargo-audit](https://crates.io/crates/cargo-audit) (Vulnerability scanner)<br>• [cargo-flamegraph](https://crates.io/crates/cargo-flamegraph) (CPU profiling & flamegraph generation) |

---

## 2. Environment Setup Guide (Windows & Linux)

### Windows 10 / 11 Setup

Run the following commands in PowerShell (as Administrator):

```powershell
# 1. Install Microsoft Visual Studio C++ Build Tools (MSVC Linker)
winget install Microsoft.VisualStudio.2022.BuildTools --override "--passive --add Microsoft.VisualStudio.Workload.VCTools"

# 2. Install Rustup (Installs rustc compiler and cargo package manager)
winget install Rustlang.Rustup

# 3. Restart your PowerShell terminal, then verify the installation
rustc --version
cargo --version

# 4. Optional: Install productivity CLI utilities via Cargo
cargo install cargo-watch                                      # Hot-reloading daemon
cargo install sqlx-cli --no-default-features --features sqlite # Database migrations & query caching
cargo install just                                             # Cross-platform command shortcut runner

# 5. Optional: For cross-compiling to Linux ARM from Windows
winget install Docker.DockerDesktop
cargo install cross --git https://github.com/cross-rs/cross
```

### Linux Setup (Ubuntu / Debian / Raspberry Pi OS / Fedora / Arch)

Run the following commands in your Linux terminal:

```bash
# 1. Install system C compiler, linker, and development headers
# (Debian / Ubuntu / Raspberry Pi OS)
sudo apt update && sudo apt install -y build-essential pkg-config libssl-dev curl

# (Fedora)
# sudo dnf groupinstall "Development Tools" && sudo dnf install -y openssl-devel curl

# (Arch Linux)
# sudo pacman -S base-devel openssl curl

# 2. Install Rustup via official installer
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 3. Source Cargo environment in current shell session
source "$HOME/.cargo/env"

# 4. Verify installation
rustc --version
cargo --version

# 5. Optional: Install productivity utilities
cargo install cargo-watch
cargo install sqlx-cli --no-default-features --features sqlite
cargo install just
```

---

## 3. Server Framework & Runtime Engine

```text
┌────────────────────────────────────────────────────────┐
│  Axum: Routing, Extractors, Typed REST API Handlers    │
├────────────────────────────────────────────────────────┤
│  Tower & Tower-HTTP: CORS, Compression, Tracing        │
├────────────────────────────────────────────────────────┤
│  Tokio: Multi-threaded Work-Stealing Async Runtime     │
├────────────────────────────────────────────────────────┤
│  OS Socket Layer: Windows IOCP  /  Linux epoll         │
└────────────────────────────────────────────────────────┘
```

### Tokio (Async Executor & Event Loop)
* **Role:** Multi-threaded work-stealing task scheduler handling asynchronous network I/O, timers, and cooperative green-thread multitasking.
* **Performance Profile:** Microsecond task-switching with zero OS thread thrashing. Uses Windows I/O Completion Ports (IOCP) natively on Windows and `epoll` on Linux.
* **Documentation:**
  * Official Guide: [tokio.rs](https://tokio.rs/)
  * API Reference: [docs.rs/tokio](https://docs.rs/tokio)
  * GitHub: [tokio-rs/tokio](https://github.com/tokio-rs/tokio)

### Axum (HTTP Web Framework)
* **Role:** Ergonomic, macro-light routing engine backed directly by the Tokio core team.
* **Performance Profile:** Direct compile-time type resolution for handlers and extractors (zero runtime string reflection, no regex routing overhead).
* **Documentation:**
  * API Reference: [docs.rs/axum](https://docs.rs/axum)
  * GitHub: [tokio-rs/axum](https://github.com/tokio-rs/axum)

### Tower & Tower-HTTP (Service & Middleware Layer)
* **Role:** Standardized `Service` trait abstraction providing composable, zero-cost HTTP middleware.
* **Modules:** `CorsLayer` (CORS negotiation), `CompressionLayer` (Brotli/Gzip stream compression), `TraceLayer` (distributed spans), `TimeoutLayer` (per-request latency bounds).
* **Documentation:**
  * API Reference: [docs.rs/tower](https://docs.rs/tower) | [docs.rs/tower-http](https://docs.rs/tower-http)
  * GitHub: [tower-rs/tower](https://github.com/tower-rs/tower) | [tower-rs/tower-http](https://github.com/tower-rs/tower-http)

---

## 4. Data Persistence, Drivers & Serialization

### SQLx (Async SQL Driver & Connection Pool)
* **Role:** Pure-Rust asynchronous database driver supporting SQLite and PostgreSQL.
* **Database Strategy:**
  * **Primary (Raspberry Pi & Rapid Projects): SQLite with WAL Mode (`mode=rwc`, `journal_mode=WAL`).** Runs entirely in-process with **0 MB idle daemon memory overhead**, avoiding the 80–150 MB RAM cost of running an external database server on constrained devices.
  * **Secondary (Distributed/Multi-Node): PostgreSQL.** Can be switched via cargo feature flag if multi-instance write concurrency is required.
* **Compile-Time Safety & Cross-Compilation (`cargo sqlx prepare`):**
  * Validates SQL queries, schema, and types at compile time.
  * For cross-compiling on Windows targeting ARM Linux without connecting to a live database, use offline mode (`cargo sqlx prepare`), which generates `sqlx-data.json`.
* **Documentation:**
  * API Reference: [docs.rs/sqlx](https://docs.rs/sqlx)
  * GitHub: [transact-rs/sqlx](https://github.com/transact-rs/sqlx)

### Serde & Serde JSON (Serialization Engine)
* **Role:** Compile-time trait derive system for encoding and decoding Rust data structures to/from JSON.
* **Performance Profile:** Zero-copy deserialization (`serde::Deserialize`) that can borrow directly from raw byte buffers (`&str`, `&[u8]`) without allocating intermediate heap objects.
* **Documentation:**
  * Official Manual: [serde.rs](https://serde.rs/)
  * API Reference: [docs.rs/serde](https://docs.rs/serde) | [docs.rs/serde_json](https://docs.rs/serde_json)
  * GitHub: [serde-rs/serde](https://github.com/serde-rs/serde)

### Validator (Data Validation)
* **Role:** Declarative struct validation via derive macros.
* **Performance Profile:** Executes range checks, string lengths, regex matches, and format rules without allocations, executed immediately inside Axum extractors.
* **Documentation:**
  * API Reference: [docs.rs/validator](https://docs.rs/validator)
  * GitHub: [Keats/validator](https://github.com/Keats/validator)

---

## 5. Systems, Memory, Configuration & Telemetry Layer

### Hierarchical YAML Configuration (`config` Crate)
* **Role:** Unified, single-location configuration using YAML with automatic inheritance and cascading overrides.
* **Design Pattern (Base + Production Delta):**
  * `config/default.yaml`: Complete baseline configuration containing all keys and defaults (optimized for local Windows development).
  * `config/prod.yaml`: **Minimal override file** containing *only the fields that change* for production (e.g. `server.host: "0.0.0.0"`, `server.port: 80`, production database path). Any key omitted in `prod.yaml` automatically inherits the baseline value from `default.yaml`.
  * Optional environment variable overrides (`APP__*`).
* **Documentation:**
  * API Reference: [docs.rs/config](https://docs.rs/config)

### Mimalloc (Global Memory Allocator)
* **Role:** Replaces default memory allocators with Microsoft’s cache-conscious, compact allocator.
* **Performance Profile:** Eliminates lock contention in high-concurrency multi-threaded allocations; drops memory fragmentation by up to 30%.
* **Documentation:**
  * API Reference: [docs.rs/mimalloc](https://docs.rs/mimalloc)
  * GitHub: [microsoft/mimalloc](https://github.com/microsoft/mimalloc)

### Tracing & Tracing-Subscriber (Structured Telemetry)
* **Role:** Non-blocking, structured diagnostics built explicitly for asynchronous execution flows.
* **Key Advantage:** Unlike traditional line loggers, `tracing` attaches contextual spans that follow asynchronous tasks across threads and `.await` yield points.
* **Documentation:**
  * API Reference: [docs.rs/tracing](https://docs.rs/tracing) | [docs.rs/tracing-subscriber](https://docs.rs/tracing-subscriber)
  * GitHub: [tokio-rs/tracing](https://github.com/tokio-rs/tracing)

### Thiserror & Anyhow (Error Architecture)
* **Role:**
  * `thiserror`: Generates lightweight, zero-cost domain error enums for library/internal backend code without dynamic heap allocations.
  * `anyhow`: Ergonomic context wrapper for edge/main application initialization errors.
* **Documentation:**
  * API Reference: [docs.rs/thiserror](https://docs.rs/thiserror) | [docs.rs/anyhow](https://docs.rs/anyhow)
  * GitHub: [dtolnay/thiserror](https://github.com/dtolnay/thiserror)

### Argon2 & JSON Web Tokens (Security & Cryptography)
* **Role:** Password hashing and stateless authentication.
* **Crates:** `argon2` (memory-hard, side-channel resistant hashing), `jsonwebtoken` (compact, stateless signature validation).
* **Documentation:**
  * [docs.rs/argon2](https://docs.rs/argon2) | [docs.rs/jsonwebtoken](https://docs.rs/jsonwebtoken)

---

## 6. Complete Backend `Cargo.toml` Reference

```toml
[package]
name = "ultra-engine"
version = "0.1.0"
edition = "2024"

[dependencies]
# 1. Asynchronous Core & HTTP Layer
tokio = { version = "1", features = ["full"] }
axum = { version = "0.8", features = ["macros"] }
tower = { version = "0.5" }
tower-http = { version = "0.6", features = ["cors", "trace", "compression-full", "timeout"] }

# 2. Database & Connection Pooling (SQLite WAL mode default; switchable to postgres)
sqlx = { version = "0.8", features = ["runtime-tokio-rustls", "sqlite", "uuid", "chrono"] }

# 3. Serialization, Configuration & Validation
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
config = { version = "0.15", features = ["yaml"] }
validator = { version = "0.19", features = ["derive"] }

# 4. Telemetry, Tracing & Diagnostics
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
thiserror = "2.0"
anyhow = "1.0"

# 5. Security & Cryptography
argon2 = "0.5"
jsonwebtoken = "9.3"

# 6. Low-overhead Allocator
mimalloc = { version = "0.1", default-features = false }

[profile.release]
opt-level = 3        # Maximum optimizations
lto = "fat"          # Link-Time Optimization across all crates
codegen-units = 1    # Sacrifices compile speed for better optimization passes
panic = "abort"      # Strips stack-unwind tables; produces smaller, faster binaries
strip = "debuginfo"  # Strips heavy DWARF debug info while keeping symbol names for crash backtraces
```

> [!IMPORTANT]
> **CRITICAL PERFORMANCE RULE: Always Run & Build in Release Mode (`--release`)**
> * **Debug Mode (`cargo run` / `cargo build`):** Defaults to `opt-level = 0` with zero inlining, no SIMD auto-vectorization, and disabled loop unrolling. While compilation is fast, compute-intensive workloads—such as image decoding/resizing (`image` crate), audio/video metadata parsing, and cryptographic hashing—run **20x to 100x slower** (e.g., downscaling a photo takes 1,500–2,000 ms in debug vs. 15–25 ms in release).
> * **Release Mode (`cargo run --release` / `cargo build --release`):** Activates maximum LLVM optimizations (`opt-level = 3`), LTO, and CPU vector extensions. Always run with `--release` in development scripts and production to prevent artificial bottlenecks.

---

## 7. Architecture & Directory Blueprint

```text
my-project/
├── build.ps1                  # [Windows] Zero-Assumption checklist + Production Build
├── start.ps1                  # [Windows] 100% Production Runner (writes .pids)
├── stop.ps1                   # [Windows] Deterministic PID tree stopper (reads .pids)
├── build.sh                   # [Linux] Zero-Assumption checklist + Production Build
├── start.sh                   # [Linux] 100% Production Runner (writes .pids)
├── stop.sh                    # [Linux] Deterministic PID tree stopper (reads .pids)
├── .pids                      # [Runtime] Active process IDs persisted by start script
├── Cargo.toml
├── Justfile                   # Optional CLI task shortcuts
├── sqlx-data.json             # Cached queries for offline cross-compilation
│
├── config/                    # [Configurations] All YAML files in ONE place
│   ├── default.yaml           # Complete baseline config & local defaults
│   └── prod.yaml              # Minimal overrides for Raspberry Pi production
│
├── migrations/                # [Database] SQL schema files
│   └── 20260101000000_init.sql
│
├── deploy/                    # [Build & Deploy Pipelines] Ops & infrastructure
│   ├── systemd/
│   │   └── myapp.service      # Linux systemd background service descriptor
│   └── scripts/
│       ├── build-linux.ps1    # Cross-compilation script targeting Linux
│       └── deploy-linux.ps1   # SCP binary/configs to remote Linux host and restart service
│
└── src/                       # [Pure Code] Application logic only
    ├── main.rs                # Application entrypoint, routing & graceful shutdown
    ├── config.rs              # Strongly typed YAML cascading loader
    ├── error.rs               # Central AppError enum + Axum IntoResponse
    ├── state.rs               # Shared AppState (SQLite pool, config)
    ├── routes/                # Route sub-routers
    │   ├── mod.rs
    │   ├── auth.rs
    │   └── items.rs
    ├── handlers/              # Endpoint business logic
    │   ├── auth_handler.rs
    │   └── item_handler.rs
    └── models/                # Domain entities & Serde DTOs
        ├── user.rs
        └── item.rs
```

---

## 8. Configuration Implementation Blueprint

### `config/default.yaml` (Complete Baseline / Local Defaults)
```yaml
server:
  host: "127.0.0.1"
  port: 8080

database:
  url: "sqlite://local.db?mode=rwc"
  max_connections: 5

auth:
  jwt_secret: "dev-insecure-secret-key-32-bytes"
  token_ttl_seconds: 86400
```

### `config/prod.yaml` (Minimal Production Delta)
```yaml
# Only specify values that differ from default.yaml
server:
  host: "0.0.0.0"
  port: 80

database:
  url: "sqlite:///var/lib/myapp/data.db?mode=rwc"
  max_connections: 10
```

### Cascading Config Loader (`src/config.rs`)
```rust
use serde::Deserialize;
use std::path::Path;

#[derive(Debug, Deserialize, Clone)]
pub struct AppConfig {
    pub server: ServerConfig,
    pub database: DatabaseConfig,
    pub auth: AuthConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DatabaseConfig {
    pub url: String,
    pub max_connections: u32,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AuthConfig {
    pub jwt_secret: String,
    pub token_ttl_seconds: u64,
}

impl AppConfig {
    pub fn load(override_path: Option<&str>) -> Result<Self, config::ConfigError> {
        let mut builder = config::Config::builder()
            // 1. Always load baseline complete defaults
            .add_source(config::File::with_name("config/default.yaml").required(true));

        // 2. Cascade minimal override if specified (e.g. prod.yaml)
        if let Some(path) = override_path {
            builder = builder.add_source(config::File::with_name(path).required(false));
        }

        // 3. Allow optional ENV variable overrides (e.g. APP__AUTH__JWT_SECRET)
        builder = builder.add_source(config::Environment::with_prefix("APP").separator("__"));

        builder.build()?.try_deserialize()
    }
}
```

---

## 9. Development, Build/Start/Stop Separation & Deployment Lifecycle

### Platform-Specific Lifecycle Architecture (`build`, `start`, `stop` for `.ps1` and/or `.sh`)

Every project MUST implement the **Build / Start / Stop Separation Architecture** (see [build-start-separation/SKILL.md](file:///C:/GIT/TECHSTACK/build-start-separation/SKILL.md)) for **each target OS the project runs on** — **Windows (`build.ps1`, `start.ps1`, `stop.ps1`)** and/or **Linux (`build.sh`, `start.sh`, `stop.sh`)** (single-OS projects omit the other platform's scripts and `systemd` unit files):

1. **Zero-Assumption Build Script (`build.ps1` / `build.sh`):**
   * Assumes the host machine has **zero pre-installed compilers or dependencies**.
   * Executes a pre-flight checklist verifying Git, the native C/C++ linker (`MSVC VC.Tools.x86.x64` on Windows; `build-essential`, `pkg-config`, `libssl-dev` on Linux), and the Rust toolchain (`rustup`, `rustc`, `cargo`).
   * Automatically installs missing dependencies where supported (`winget` / `rustup` / `apt` / `dnf` / `pacman`); if a dependency cannot be auto-installed, throws an explicit fatal error with the download URL and manual install command.
   * Calls `stop.ps1` / `stop.sh` prior to compiling to unlock running `.exe` binaries on Windows (preventing `OS Error 5: Access is denied`), then compiles `cargo build --release`.
2. **100% Production Start Script (`start.ps1` / `start.sh`):**
   * **Never runs `cargo run`** during startup. Executes the pre-compiled `target/release/<binary>` directly (auto-invoking `build` only if the binary is missing).
   * Persists the active process ID (`backend_pid`, `frontend_pid`, ports, timestamp) to `<repo-root>/.pids` for deterministic lifecycle management.
3. **Deterministic PID Stop Script (`stop.ps1` / `stop.sh`):**
   * Reads `<repo-root>/.pids`, kills the exact process tree by PID (`taskkill /PID <id> /T /F` on Windows; `pkill -P <id>` + `kill` on Linux), sweeps fallback ports, and removes `.pids`.

👉 Reference Templates: [build.ps1.template](file:///C:/GIT/TECHSTACK/build-start-separation/examples/build.ps1.template), [start.ps1.template](file:///C:/GIT/TECHSTACK/build-start-separation/examples/start.ps1.template), [stop.ps1.template](file:///C:/GIT/TECHSTACK/build-start-separation/examples/stop.ps1.template), [build.sh.template](file:///C:/GIT/TECHSTACK/build-start-separation/examples/build.sh.template), [start.sh.template](file:///C:/GIT/TECHSTACK/build-start-separation/examples/start.sh.template), [stop.sh.template](file:///C:/GIT/TECHSTACK/build-start-separation/examples/stop.sh.template).

### Why Bare-Metal Static Binary Beats Docker on Raspberry Pi
* **Zero Container Daemon Bloat:** Running `dockerd` and `containerd` consumes **80–120 MB RAM** on a Pi before your application even boots. A native Rust binary runs in **10–25 MB RAM**.
* **Protects SD Cards:** Eliminates continuous Docker logging, layer caches, and overlay2 storage wear on flash storage.
* **Instant Start:** Managed by `systemd` or `start.sh`, the binary starts in **< 20 milliseconds**.

### Unified Cross-Compilation & Task Automation (`Justfile`)

```makefile
# Build full production artifacts via Zero-Assumption build script
build:
    powershell -ExecutionPolicy Bypass -File ./build.ps1

# Start pre-compiled release binary (writes .pids)
start:
    powershell -ExecutionPolicy Bypass -File ./start.ps1

# Stop running services deterministically by .pids
stop:
    powershell -ExecutionPolicy Bypass -File ./stop.ps1

# Prepare offline SQLx cache (required before cross-compilation)
sqlx-prepare:
    cargo sqlx prepare

# Cross-compile for Linux (e.g. 64-bit ARM Linux musl static binary)
build-linux: sqlx-prepare
    cross build --target aarch64-unknown-linux-musl --release

# Deploy single executable and prod override to remote Linux host
deploy-linux REMOTE_HOST:
    scp target/aarch64-unknown-linux-musl/release/ultra-engine {{REMOTE_HOST}}:/opt/myapp/ultra-engine
    scp config/default.yaml {{REMOTE_HOST}}:/opt/myapp/config/default.yaml
    scp config/prod.yaml {{REMOTE_HOST}}:/opt/myapp/config/prod.yaml
    ssh {{REMOTE_HOST}} "sudo systemctl restart myapp"
```

### Production `systemd` Service (`/etc/systemd/system/myapp.service`)

```ini
[Unit]
Description=Ultra Engine Backend Service
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/ultra-engine --config-override config/prod.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=RUST_LOG=info
Environment=RUST_BACKTRACE=1

# Hardening
ProtectSystem=full
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

---

## 10. Deterministic Finite State Machine (FSM) Architecture

Distributed boolean flags (e.g. `is_active`, `is_paused`, `is_loading`, `is_connected`, `stopped`) inevitably lead to combinatorial state explosion ($2^N$ states), unreachable/phantom states, and desynchronization between concurrent tasks, drivers, and external consumers. 

The architecture strictly mandates that all stateful lifecycle engines, session managers, hardware/driver wrappers, and streaming pipelines be governed by an **explicit, deterministic Finite State Machine (FSM)**.

### 10.1 The Anti-Pattern: Distributed Boolean Flags

```text
❌ ANTI-PATTERN: Scattered Boolean Flags
   is_connected: true | is_loading: false | is_playing: true | is_paused: true  <-- Invalid!
   Result: UI tearing, phantom tickers looping at 0s, race conditions between tasks.

✔ ARCHITECTURAL STANDARD: Explicit Finite State Machine
   Status: Paused
   Result: Single source of truth, mutually exclusive states, guaranteed invariants.
```

### 10.2 Rust FSM Pattern: Strongly-Typed Enum & Explicit Transitions

State is modeled as a first-class Rust `enum` with serde serialization:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LifecycleState {
    Disconnected,
    Idle,
    Loading,
    Active,
    Paused,
    Terminated,
}
```

State transitions MUST be encapsulated in a dedicated transition method rather than raw field assignment. This guarantees validation, invariant preservation, and structured observability:

```rust
pub struct StatefulEntity {
    pub id: String,
    pub state: LifecycleState,
    // Auxiliary resources (must correlate strictly with state)
    pub active_handle: Option<ResourceHandle>,
}

impl StatefulEntity {
    pub fn transition_to(&mut self, next: LifecycleState, reason: impl std::fmt::Display) {
        if self.state == next {
            return;
        }

        let old = self.state;
        self.state = next;

        // Invariant enforcement upon entering resting or terminal states
        if matches!(next, LifecycleState::Idle | LifecycleState::Disconnected | LifecycleState::Terminated) {
            self.active_handle = None;
        }

        tracing::info!(
            target: "state_machine",
            "[FSM] Entity {}: {:?} -> {:?} (Reason: {})",
            self.id, old, next, reason
        );
    }
}
```

### 10.3 State Transition Matrix & Edge Enforcement

All valid state transitions must form a directed graph. Unhandled or illegal transitions must be rejected or gracefully diverted:

```text
 ┌──────────────┐      connect()      ┌──────────────┐
 │ Disconnected │ ──────────────────> │     Idle     │ <──────────────────┐
 └──────────────┘                     └──────────────┘                    │
        ▲                                     │         ▲                 │
        │ disconnect()                        │ start   │ stop / finish   │
        │                                     ▼         │                 │
        │                             ┌──────────────┐  │                 │
        │                             │   Loading    │ ─┘ (on failure)    │
        │                             └──────────────┘                    │
        │                                     │                           │
        │                                     │ ready                     │
        │                                     ▼                           │
        │      terminate() / complete ┌──────────────┐                    │
        │ ─────────────────────────── │    Active    │ ───────────────────┤
        │                             └──────────────┘                    │
        │                                     │      ▲                    │
        │                             pause() │      │ resume()           │
        │                                     ▼      │                    │
        │                                 ┌──────────────┐                │
        └──────────────────────────────── │    Paused    │ ───────────────┘
                                          └──────────────┘
```

### 10.4 Core Architectural Invariants

1. **Mandatory Structured Logging:**
   Every transition MUST emit an info-level structured log capturing the entity identifier, previous state, target state, and actionable reason for auditability and observability.
2. **Subsystem & Driver State Reconciliation:**
   When wrapping lower-level OS processes, network gateways, or async drivers (e.g. audio decoders, database pools, socket handles), the FSM must actively reconcile external driver events (driver exit, buffer EOF, socket drop). If the driver reports completion or error, the FSM transitions to `Idle` or `Terminated` immediately.
3. **Atomic Teardown on Resting States:**
   Entering `Idle`, `Disconnected`, or `Terminated` MUST atomically tear down active subprocesses, timers, and handles. Retaining active handles or cached counters in an idle state is an invariant violation.
4. **Network Serialization Contract:**
   All real-time SSE broadcasts, WebSocket frames, and REST DTOs MUST expose the singular `status` field serialized as a lowercase string (e.g. `"status": "idle"`). Distributed booleans are deprecated and maintained only as read-only computed properties during rolling deployments.

---

## 11. Zero-Cost SOLID Architecture Principles in Rust

In accordance with [solid-architecture/SKILL.md](file:///C:/GIT/TECHSTACK/solid-architecture/SKILL.md) and [solid-across-stacks.md](file:///C:/GIT/TECHSTACK/solid-architecture/references/solid-across-stacks.md), AI agents and developers MUST enforce all five SOLID principles in Rust using **zero-cost compile-time abstractions**:

1. **Single Responsibility Principle (SRP):**
   * Strictly separate **Transport Handlers** (`src/handlers/`), **Domain Services & FSM Orchestration** (`src/services/`), **Persistence Repositories** (`src/repositories/`), and **DTOs/Validators** (`src/models/`).
   * Axum route handlers MUST NEVER contain raw `sqlx::query!` calls or multi-step business calculations.
2. **Open/Closed Principle (OCP):**
   * Extend system capabilities (e.g., new notification channels, storage engines, or stream processors) by implementing shared Rust `trait`s or exhaustive `enum` dispatch rather than modifying existing core pipelines with fragile `if/else` chains.
3. **Liskov Substitution Principle (LSP):**
   * Every implementation of a repository or driver trait (e.g., `SqliteItemRepo`, `PostgresItemRepo`, or `InMemoryMockRepo`) MUST uphold identical `Result<T, AppError>` error semantics and FSM state invariants.
4. **Interface Segregation Principle (ISP):**
   * Keep traits narrow and role-specific (e.g., split `TelemetryReader` from `TelemetryWriter`) so read-only handlers or background tasks never depend on mutation methods they do not invoke.
5. **Dependency Inversion Principle (DIP):**
   * Domain services depend on **Rust Traits** (`<R: ItemRepository>`) and strongly-typed `AppConfig` (`config/default.yaml`)—never on hardcoded file paths, connection strings, or concrete third-party driver structs. Prefer monomorphized generics (`<R: Trait>`) over `Box<dyn Trait>` on hot paths to eliminate heap allocation and vtable indirection.

---

## 12. Production Observability, Decoupled Log Aggregation & Crash Diagnostics

Applications MUST NEVER host or serve their own log endpoints. If a service fails to parse config, panics at boot, deadlocks, or is OOM-killed, an in-app logging route dies with it. Furthermore, flat `nohup > app.log` redirection lacks guaranteed OS timestamps on non-logger output (panics, linker/OS faults, child process `stderr`) and provides no structured query interface for diagnosing latency regressions.

The stack mandates a **100% self-hosted, locally stored, decoupled observability pipeline** into `VictoriaLogs` (`127.0.0.1:9428`), using each target OS's native capture mechanism (**Section 12.3** `systemd-journald` on Linux servers, or **Section 12.5** `ship-logs.ps1` ordered lifecycle on Windows):

### 12.1 Pipeline Topology (Zero Third-Party SaaS — Linux & Windows Paths)

```text
┌──────────────────────────────┐     stdout / stderr (OS fds)     ┌──────────────────────────────┐
│  Application Binary (Rust)   │ ───────────────────────────────> │  systemd-journald (Kernel)   │
│  • tracing JSON to stdout    │   • Captures boot/panic/child    │  • Microsecond timestamps    │
│  • RUST_BACKTRACE=1          │   • Captures exit codes & OOM    │  • Native disk/retention cap │
└──────────────────────────────┘                                  └──────────────────────────────┘
                                                                                 │
                                                     systemd-journal-upload      │ (/insert/journald)
                                                                                 ▼
┌──────────────────────────────┐     HTTP / Tailscale Only        ┌──────────────────────────────┐
│  Humans & Diagnostic Agents  │ <──────────────────────────────> │  VictoriaLogs (Standalone)   │
│  • Browser: /select/vmui/    │   • Completely separate service  │  • Single Go binary, low RAM │
│  • API: /select/logsql/query │   • Survives app crashes         │  • Compressed local disk     │
│  • Tail: /select/logsql/tail │                                  │    (/var/lib/victoria-logs)  │
└──────────────────────────────┘                                  └──────────────────────────────┘
```

* **100% Local Data Ownership:** All logs remain stored locally on the production host (`/var/log/journal` + `/var/lib/victoria-logs`). Zero logs are transmitted to third-party SaaS vendors.
* **Docker-Equivalent Completeness on Bare Metal:** Because `systemd` captures `stdout` and `stderr` at the OS file-descriptor level, every line—pre-startup config errors, Rust `panic!` backtraces, external subprocess `stderr` (e.g., `ffmpeg`, `yt-dlp`), and systemd unit lifecycle events (`Main process exited, code=killed...`)—is recorded with guaranteed microsecond wall-clock timestamps (`__REALTIME_TIMESTAMP`).
* **Migration Guide:** For step-by-step host package installation and migrating existing `nohup`/flat-file/`/api/logs` projects, see [OBSERVABILITY_MIGRATION.md](file:///C:/GIT/TECHSTACK/OBSERVABILITY_MIGRATION.md).

### 12.2 Application Telemetry & Latency Instrumentation (`tracing`)

To answer *"why is PROD slow?"* without guessing, applications MUST emit structured JSON logs to `stdout` via `tracing-subscriber` and record explicit execution timings on external calls, database queries, and HTTP handlers:

1. **Structured JSON Output:** Enable `tracing_subscriber::fmt().json()` in production so fields like `level`, `target`, `span`, `request_id`, and `duration_ms` are automatically indexed as queryable columns.
2. **Latency Spans:** Wrap non-trivial async operations (HTTP routes via `tower_http::trace::TraceLayer`, external CLI invocations, AI/API requests, DB queries) with structured `duration_ms` fields.
3. **Readable Release Panics:** Keep `strip = "debuginfo"` (rather than `strip = true`) in `Cargo.toml` and `RUST_BACKTRACE=1` in the `systemd` unit so panic logs retain function symbol names prior to `abort`.

### 12.3 Standalone Observability Service Blueprint (Linux Targets Only)

On Linux servers, VictoriaLogs runs once per host as an independent `systemd` unit completely isolated from all application lifecycles. *(Windows-only projects skip this section and use Section 12.5 instead.)* Multiple applications on the same Linux server share this single log store and are cleanly isolated by `SYSLOG_IDENTIFIER` and `_SYSTEMD_UNIT`.

👉 **One-Command Host Installer:** [observability/install.sh](file:///C:/GIT/TECHSTACK/observability/install.sh) automates package installation, binary download, systemd unit setup, and end-to-end health verification.

1. **VictoriaLogs Service (`/etc/systemd/system/victoria-logs.service`):**
   ```ini
   [Unit]
   Description=VictoriaLogs Standalone Local Log Store & UI
   After=network.target

   [Service]
   Type=simple
   User=victorialogs
   ExecStart=/usr/local/bin/victoria-logs-prod \
     -storageDataPath=/var/lib/victoria-logs \
     -retentionPeriod=30d \
     -httpListenAddr=127.0.0.1:9428 \
     -journald.streamFields=_HOSTNAME,_SYSTEMD_UNIT,SYSLOG_IDENTIFIER
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   ```
   > [!CAUTION] Security Boundary
   > Production logs frequently contain user IDs, stack traces, or operational metadata. **NEVER** bind `-httpListenAddr` publicly on `0.0.0.0:9428` without authentication. Bind strictly to `127.0.0.1` or your private Tailscale interface (or expose behind an authenticated TLS reverse proxy).

2. **Native Journald Shipper (`/etc/systemd/journal-upload.conf`):**
   ```ini
   [Upload]
   URL=http://127.0.0.1:9428/insert/journald
   ```
   Enabled via `sudo systemctl enable --now systemd-journal-upload.service`. VictoriaLogs natively maps `__REALTIME_TIMESTAMP` to `_time`, `PRIORITY` to log level, and groups streams by `(_MACHINE_ID, _HOSTNAME, _SYSTEMD_UNIT)`.

### 12.4 Read-Only Diagnostic Playbook (Human UI & Agent Queries)

* **Human Web UI (`vmui`):** Access `http://<tailscale-host-or-tunnel>:9428/select/vmui/` for visual time-range slicing, live tailing, and LogsQL exploration.
* **Investigating Crashes (*"The system just crashed, what happened?"*):**
  Query both application panics/errors and `systemd` unit exit events across restarts:
  ```bash
  curl -sG "http://127.0.0.1:9428/select/logsql/query" \
    --data-urlencode 'query=_SYSTEMD_UNIT:myapp.service AND (level:error OR panicked OR "Main process exited" OR OOM) _time:30m' \
    --data-urlencode 'limit=50'
  ```
* **Investigating Latency (*"PROD is slow doing X, check why"*):**
  Filter structured spans by duration or aggregate p95 percentiles directly in LogsQL:
  ```bash
  # Find individual slow operations > 500ms in the last hour
  curl -sG "http://127.0.0.1:9428/select/logsql/query" \
    --data-urlencode 'query=_SYSTEMD_UNIT:myapp.service duration_ms:>500 _time:1h' \
    --data-urlencode 'limit=25'

  # Live-tail logs in real time over HTTP
  curl -N "http://127.0.0.1:9428/select/logsql/tail?query=_SYSTEMD_UNIT:myapp.service"
  ```

### 12.5 Windows Local Observability Lifecycle (`victoria-logs-prod.exe` + `ship-logs.ps1`)

On Windows hosts (no `systemd-journald`), the exact same `127.0.0.1:9428` `VictoriaLogs` schema and `vmui`/LogsQL query workflow applies without requiring Administrator privileges:

1. **Zero-Admin Binary Setup (`observability/install.ps1`):** Installs `victoria-logs-prod.exe` into `%LOCALAPPDATA%\VictoriaLogs\bin\victoria-logs-prod.exe` with compressed TSDB storage in `%LOCALAPPDATA%\VictoriaLogs\data\` (`retentionPeriod=30d`, bound exclusively to `127.0.0.1:9428`).
2. **Start Logger First (`start.ps1`):** `start.ps1` boots `VictoriaLogs` first -> waits for `/health` `200 OK` -> spawns `observability/ship-logs.ps1` to tail `.logs\*.log` -> launches Backend (`RUST_LOG=info`, `LOG_FORMAT=json`) and Frontend with `stdout`/`stderr` redirected to `.logs\`.
3. **Graceful Ordered Shutdown (`stop.ps1`):**
   * Stops Frontend & Backend trees and sweeps app ports (`logger_port` excluded).
   * Polls until **all** application PIDs and listening ports are confirmed dead (`Wait-AppsConfirmedStopped`).
   * Writes `.logs\.stop-shipper` and waits for `.logs\.shipper-flushed` so `ship-logs.ps1` finishes batching trailing crash/shutdown lines into `http://127.0.0.1:9428/insert/jsonline`.
   * Terminates `victoria-logs-prod.exe` **very last** (unless `-KeepLogger` is passed or `logger_owned = false`).
4. **Querying Windows Logs Locally (`vmui` / LogsQL):**
   Open `http://127.0.0.1:9428/select/vmui/` directly in a browser (while running or with `stop.ps1 -KeepLogger`), or query `stream:stderr OR level:error _time:30m` via `http://127.0.0.1:9428/select/logsql/query`.




