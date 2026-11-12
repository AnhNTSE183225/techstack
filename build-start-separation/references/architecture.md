# Build, Start & Stop Script Separation Architecture

This document details the architectural mechanics, lifecycle phases, PID tracking protocol, and zero-assumption environment verification for Windows (`.ps1`) and Linux (`.sh`).

---

## 1. Why Start Must Run in Optimized Production Mode (Never Dev Mode)

In many full-stack setups, developers default to running development servers (`npm run dev`, `cargo run`, `flutter run`). In real-world applications, this severely degrades startup speed and runtime performance:

### The Flaws of Development Mode:
1. **Dynamic Transpilation Lag (The "Blank Screen" Problem)**:
   - Dev bundlers compile modules on demand as the browser requests them, causing a 5 to 15 second blank white screen on initial load.
2. **Unoptimized Execution (Debug Profile)**:
   - `cargo run` defaults to `opt-level = 0` with zero SIMD vectorization or inlining (running 20x–100x slower on compute workloads).
   - `flutter run` (debug) runs inside a JIT VM with checked assertions, causing frame drops on 120Hz displays.
3. **Orphaned Background Processes & File Locks**:
   - Without deterministic PID tracking (`.pids`) and a dedicated `stop` script, background processes linger on ports and lock `.exe` files on Windows (`OS Error 5: Access is denied`).

---

## 2. Three-Script Lifecycle Flow (`build` / `start` / `stop`)

```mermaid
flowchart TD
    subgraph BuildPhase ["1. Zero-Assumption Build (build.ps1 / build.sh)"]
        direction TB
        B0["Phase 0: Extensive Toolchain Checklist (Git, C/C++ Linker, Rust, Node, pnpm, JDK/Flutter)"]
        B0_Install{"Missing Tool Auto-Installable?"}
        B0_Auto["Auto-Install via winget / rustup / corepack / apt"]
        B0_Fail["Throw Actionable Error with Download URL & Command"]
        B1["Phase 1: Invoke stop.ps1 / stop.sh (Unlock Running Binaries)"]
        B2["Phase 2: Install Dependencies & Bundle Frontend (pnpm build -> dist/)"]
        B3["Phase 3: Compile Release Backend (cargo build --release)"]
        B4["Phase 4: Verify Production Artifacts Ready (Exit 0)"]

        B0 --> B0_Install
        B0_Install -- "Yes" --> B0_Auto --> B1
        B0_Install -- "No / Failed" --> B0_Fail
        B0_Install -- "All Present" --> B1
        B1 --> B2 --> B3 --> B4
    end

    subgraph StartPhase ["2. Production Runner (start.ps1 / start.sh)"]
        direction TB
        S0["1. Invoke stop.ps1 / stop.sh --quiet (Clean Slate)"]
        S1{"2. Artifacts Exist?"}
        S1_Build["Fallback: Run build.ps1 / build.sh"]
        S2["3. Spawn Release Binary & Static Preview Server"]
        S3["4. Write Backend & Frontend PIDs to .pids File"]
        S4["5. 100ms Health Polling -> Print URLs & PIDs (< 500ms)"]

        S0 --> S1
        S1 -- "No" --> S1_Build --> S2
        S1 -- "Yes" --> S2
        S2 --> S3 --> S4
    end

    subgraph StopPhase ["3. Deterministic PID Stopper (stop.ps1 / stop.sh)"]
        direction TB
        K0["1. Read backend_pid & frontend_pid from .pids"]
        K1["2. Terminate Process Trees (taskkill /T /F or pkill -P)"]
        K2["3. Sweep Fallback Ports for Any Orphaned Children"]
        K3["4. Delete .pids State File"]

        K0 --> K1 --> K2 --> K3
    end

    BuildPhase -.->|"Produces artifacts"| StartPhase
    StartPhase -.->|"Writes .pids"| StopPhase
```

---

## 3. Deterministic PID Tracking Protocol (`.pids`)

When `start.ps1` or `start.sh` launches the application:
1. It immediately captures the OS process ID (`PID`) of both the compiled backend binary and the frontend preview server.
2. It writes those PIDs to `<repo-root>/.pids`:
   - On Windows (`start.ps1`): JSON structure containing `backend_pid`, `frontend_pid`, `backend_port`, `frontend_port`, `started_at`.
   - On Linux (`start.sh`): Key-value shell env structure containing `BACKEND_PID`, `FRONTEND_PID`, `BACKEND_PORT`, `FRONTEND_PORT`, `STARTED_AT`.
3. When `stop.ps1` or `stop.sh` is executed (either manually by the user, by an AI agent after testing, by `build` before recompiling, or by the `Ctrl+C` trap in `start`):
   - It reads `.pids` first and kills the exact process trees for those PIDs.
   - It then performs a secondary port check and deletes `.pids`.

---

## 4. Reverse Proxy Connection Pooling (`vite.config.ts`)

In preview mode, Vite reverse-proxies API calls from `5173` to `8080`. Always configure an unbounded keep-alive agent in `frontend/vite.config.ts` to prevent socket exhaustion:

```typescript
import http from "node:http";
import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid";

const keepAliveAgent = new http.Agent({
  keepAlive: true,
  maxSockets: Infinity,
  maxFreeSockets: 64,
  timeout: 30000,
});

export default defineConfig({
  plugins: [solidPlugin()],
  preview: {
    host: true,
    port: 5173,
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8080",
        changeOrigin: true,
        agent: keepAliveAgent,
      },
    },
  },
});
```
