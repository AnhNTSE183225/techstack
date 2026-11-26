# FRONTEND_TECHSTACK.md: Ultra-Low Overhead SolidJS Architecture

A reference specification for building an ultra-fast, low-footprint single-page frontend application designed for near-instant interaction, sub-millisecond reactive updates, and fluid hardware-accelerated animations while maintaining minimal client-side bundle size (< 25 KB gzipped).

---

## 1. Core Toolchains & Environment

| Component | Role | Documentation & Reference |
| :--- | :--- | :--- |
| **Node.js (LTS) & pnpm** | High-performance, hard-linked package management with deterministic lockfiles | • [pnpm Docs](https://pnpm.io/)<br>• [Node.js](https://nodejs.org/) |
| **TypeScript** | Static type safety and contract synchronization with backend DTOs | • [TypeScript Handbook](https://www.typescriptlang.org/docs/) |
| **Vite** | Native ES Module (ESM) build engine and lightning-fast HMR bundler | • [Vite Docs](https://vite.dev/) |

---

## 2. Environment Setup Guide (Windows & Linux)

### Windows 10 / 11 Setup

Run the following commands in PowerShell (as Administrator):

```powershell
# 1. Install Node.js LTS via Windows Package Manager (winget)
winget install OpenJS.NodeJS.LTS --exact

# 2. Restart PowerShell, then enable pnpm (bundled with Node via Corepack)
corepack enable
corepack prepare pnpm@latest --activate

# Alternative: Install pnpm directly via winget
# winget install pnpm.pnpm

# 3. Verify installations
node --version   # Should output v20.x or v22.x+
pnpm --version   # Should output v9.x or v10.x+
```

### Linux Setup (Ubuntu / Debian / Raspberry Pi OS / Fedora)

Run the following commands in your terminal:

```bash
# 1. Install Node.js LTS via official NodeSource repository
# (Debian/Ubuntu/Raspberry Pi OS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt update && sudo apt install -y nodejs

# (Fedora)
# sudo dnf install -y nodejs npm

# (Arch Linux)
# sudo pacman -S nodejs npm

# 2. Enable pnpm via Corepack
sudo corepack enable
corepack prepare pnpm@latest --activate

# 3. Verify installations
node --version
pnpm --version
```

---

## 3. UI Paradigm & Reactivity (The Zero-Virtual-DOM Engine)

SolidJS provides a familiar JSX component syntax similar to React, but avoids the Virtual DOM diffing overhead entirely. Components execute **only once on initialization**, setting up fine-grained reactive subscriber graphs.

```text
┌────────────────────────────────────────────────────────┐
│  SolidJS JSX: Compiles to Native Direct DOM Calls       │
├────────────────────────────────────────────────────────┤
│  Fine-Grained Signals: createSignal, createMemo        │
├────────────────────────────────────────────────────────┤
│  Browser Compositor Thread: WAAPI Hardware Animations  │
├────────────────────────────────────────────────────────┤
│  Tailwind CSS: Pre-compiled Atomic Utility Classes     │
└────────────────────────────────────────────────────────┘
```

### SolidJS (Fine-Grained Reactive Framework)
* **Reactivity via Signals:** Employs `createSignal`, `createMemo`, and `createEffect` for direct micro-subscriber updates. When state updates, only the specific text node or DOM attribute is mutated—no component re-rendering and no diffing trees.
* **Size:** ~7 KB gzipped baseline runtime.
* **Performance:** Dominates the JS Web Framework Benchmark in memory efficiency and execution speed.
* **Documentation:**
  * Official Guide: [solidjs.com](https://www.solidjs.com/)
  * Tutorial: [solidjs.com/tutorial](https://www.solidjs.com/tutorial/introduction_basics)
  * GitHub: [solidjs/solid](https://github.com/solidjs/solid)

### Crucial Architectural Rules & Gotchas

> [!CAUTION] Never Destructure Component Props
> In React, `const { title, count } = props;` is standard. **In SolidJS, destructuring props breaks reactivity.**
> Props in SolidJS are reactive proxies with getters. Destructuring evaluates the getter immediately at initial mount, losing the reactive subscriber link.
> * **Correct:** Use `props.title` directly in your JSX.
> * **For Prop Splitting:** Use Solid's built-in `splitProps(props, ["title"], ["other"])`.

> [!TIP] Reactive Control Flow (`<Show>` and `<For>`)
> Prefer Solid's built-in control flow components over native JS expressions:
> * Use `<Show when={isOpen()}>` instead of `{isOpen() && <Modal />}`.
> * Use `<For each={items()}>` instead of `{items().map(...)}`. Solid's `<For>` uses keyed, fine-grained DOM recycling with zero re-creation costs.

---

## 4. Hardware-Accelerated Animations & Styling

### Animation Strategy: When to Use What

```text
Simple Hover / Focus / Transitions ───► Pure Tailwind CSS (0 KB JS, 100% GPU)
Exit Transitions / Dynamic Mounts   ───► @motionone/solid or solid-transition-group (WAAPI)
Complex Multi-Stage Sequences       ───► Web Animations API (WAAPI)
```

1. **Tier 1 (Default): Pure Tailwind CSS Transitions**
   * For 90% of UI needs (buttons, hover effects, color fades, basic transforms), use standard Tailwind utility classes (`transition-all duration-200 ease-out active:scale-95`).
   * **Cost:** **0 KB extra JavaScript bundle.** Executed natively by the browser.

2. **Tier 2: Motion One for Solid (`@motionone/solid`)**
   * Use when elements need declarative enter/exit state transitions (`<Presence>`, `<Motion.div>`).
   * **Key Advantage:** Built on top of the browser's native **Web Animations API (WAAPI)**. Animations run directly on the browser's compositor thread, maintaining 60–120 FPS without choking the main JavaScript execution thread.
   * **Documentation:** [motion.dev](https://motion.dev/) | [GitHub: solid-motionone](https://github.com/solidjs-community/solid-motionone)

3. **Tier 3: Solid Transition Group (`solid-transition-group`)**
   * Lightweight manager for CSS transition classes during DOM insertion/removal.
   * **Documentation:** [GitHub: solid-transition-group](https://github.com/solidjs-community/solid-transition-group)

---

## 5. Architecture & Directory Blueprint

```text
frontend/
├── package.json
├── pnpm-lock.yaml
├── tsconfig.json
├── vite.config.ts             # Bundler configuration & local API proxy
├── tailwind.config.js
├── postcss.config.js
│
├── public/                    # Unprocessed static assets (favicon, robots.txt)
│   └── favicon.ico
│
└── src/
    ├── index.tsx              # Application mount point
    ├── App.tsx                # Root layout & route container
    ├── index.css              # Tailwind base, components, and utilities
    │
    ├── api/                   # Backend API communication clients
    │   ├── client.ts          # Fetch wrapper with typed responses
    │   └── health.ts          # Endpoints mapped to Rust backend
    │
    ├── components/            # Reusable UI elements (buttons, modals, cards)
    │   ├── Button.tsx
    │   └── AnimatedPanel.tsx
    │
    ├── pages/                 # Route-level view components
    │   ├── Home.tsx
    │   └── Dashboard.tsx
    │
    └── stores/                # Global reactive state (signals & stores)
        └── authStore.ts
```

---

## 6. Production `package.json` Reference

```json
{
  "name": "ultra-frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "solid-js": "^1.9.0",
    "solid-transition-group": "^0.2.3",
    "@motionone/solid": "^10.16.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "vite": "^5.2.0",
    "vite-plugin-solid": "^2.10.0",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0"
  }
}
```

---

## 7. Build & Production Preview Proxy Configuration (`vite.config.ts`)

Configured for **100% production preview execution** (`pnpm run preview` via `start.ps1` / `start.sh`) with an unbounded `keepAliveAgent` (`maxSockets: Infinity`) to prevent reverse-proxy socket queueing on concurrent API/streaming requests:

```typescript
import http from "node:http";
import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid";

// Optimize connection pool for production preview mode
const keepAliveAgent = new http.Agent({
  keepAlive: true,
  maxSockets: Infinity, // Prevent proxy queuing deadlocks on rich media/streaming
  maxFreeSockets: 64,
  timeout: 30000,
});

export default defineConfig({
  plugins: [solidPlugin()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8080",
        changeOrigin: true,
      },
    },
  },
  preview: {
    host: true,
    port: 5173,
    // Proxy API calls directly to the local Rust Axum release binary
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8080",
        changeOrigin: true,
        agent: keepAliveAgent,
      },
    },
  },
  build: {
    target: "esnext",
    outDir: "dist",
    emptyOutDir: true,
    cssCodeSplit: true,
    minify: "esbuild", // Ultra-fast native minifier
  },
});
```

---

## 8. Real-World Component Blueprint (Signals & WAAPI Animations)

```tsx
import { createSignal, Show } from "solid-js";
import { Motion, Presence } from "@motionone/solid";

export default function AnimatedPanelDemo() {
  const [isOpen, setIsOpen] = createSignal(false);

  return (
    <div class="flex flex-col items-center justify-center min-h-screen bg-slate-900 text-white p-4">
      {/* Native Tailwind hardware-accelerated transform */}
      <button
        onClick={() => setIsOpen(!isOpen())}
        class="px-5 py-2.5 bg-blue-600 hover:bg-blue-500 rounded-lg font-medium transition-colors active:scale-95 duration-100 shadow-md"
      >
        Toggle Dynamic Panel
      </button>

      {/* Handles smooth mounting and unmounting exit animations via WAAPI */}
      <Presence>
        <Show when={isOpen()}>
          <Motion.div
            initial={{ opacity: 0, scale: 0.9, y: -10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.9, y: -10 }}
            transition={{ duration: 0.2, easing: "ease-out" }}
            class="mt-4 p-6 bg-slate-800 border border-slate-700 rounded-xl shadow-2xl w-80"
          >
            <h3 class="text-lg font-semibold text-slate-100">Fine-Grained Panel</h3>
            <p class="text-sm text-slate-400 mt-2">
              This panel mounts and animates smoothly on the browser's compositor thread using the Web Animations API (WAAPI).
            </p>
          </Motion.div>
        </Show>
      </Presence>
    </div>
  );
}
```

---

## 9. Build / Start / Stop Separation Lifecycle

In accordance with [build-start-separation/SKILL.md](file:///C:/GIT/TECHSTACK/build-start-separation/SKILL.md), the application MUST NEVER be launched via `pnpm dev` / `vite` dev mode for standard operation or testing, as on-demand module transpilation causes a 5–15s blank white screen. Instead, every project uses the **3 root lifecycle scripts for each supported target OS** (`build.ps1`, `start.ps1`, `stop.ps1` for Windows targets; `build.sh`, `start.sh`, `stop.sh` for Linux/macOS targets; all 6 if cross-platform):

1. **Zero-Assumption Build (`.\build.ps1` / `./build.sh`):**
   * Runs a pre-flight checklist assuming a bare system: checks for Node.js LTS and `pnpm`, auto-installing them via `winget` / `corepack` / `apt` if possible, or throwing an explicit fatal error with download instructions if missing.
   * Calls `stop.ps1` / `stop.sh` first, installs `node_modules` if needed, compiles TypeScript (`tsc`), and bundles static assets (`vite build` -> `dist/` < 25 KB gzipped).
2. **100% Optimized Production Start (`.\start.ps1` / `./start.sh`):**
   * Verifies `dist/index.html` exists (auto-running `build` only if missing), launches `pnpm run preview` serving the pre-minified `dist/` bundle alongside the Rust release binary, and stores `frontend_pid` & `backend_pid` in `<repo-root>/.pids`.
   * Renders in the browser in **< 500 milliseconds** with zero transpilation lag.
3. **Deterministic PID Stop (`.\stop.ps1` / `./stop.sh`):**
   * Reads `<repo-root>/.pids`, terminates the stored `frontend_pid` and `backend_pid` process trees cleanly, sweeps fallback ports, and deletes `.pids`.

---

## 10. Client-Side Finite State Machine & Reactive Contract

Frontend single-page applications consuming real-time asynchronous telemetry MUST NOT rely on scattered, independent boolean flags (`isLoading`, `isPaused`, `hasError`, `isReady`, `stopped`) to derive component render states. Independent flags cause UI tearing, flickering, race conditions, and phantom background tickers (such as counters looping at `00:00`).

Client-side architecture strictly mandates that stateful modules consume and mirror an **explicit, singular State Machine contract**.

### 10.1 TypeScript Contract & State Discriminated Union

State is defined as a strongly typed string union representing mutually exclusive lifecycle phases:

```typescript
export type EntityStatus = 
  | 'disconnected' 
  | 'idle' 
  | 'loading' 
  | 'active' 
  | 'paused' 
  | 'error';

export interface StateMachineDTO<TData> {
  status: EntityStatus;
  data: TData | null;
  timestamp: number;
  // Legacy compatibility flags maintained strictly for backwards-compatible ingestion
  is_active?: boolean;
  is_loading?: boolean;
  has_error?: boolean;
}
```

### 10.2 Client-Side State Transition & Rendering Rules

1. **Single Source of Truth (`status`):**
   Components derive view visibility, progress bars, active spinners, and control buttons directly from the singular `status` discriminant:
   - `'active'`: Module is actively running; progress tickers/intervals run with server timestamp offset reconciliation.
   - `'paused'`: Execution suspended; timers freeze at their last known offset; controls switch to 'Resume'.
   - `'loading'`: Asynchronous handshake or buffer initialization in progress; spinners active; tickers halted.
   - `'idle'`: Standby state; active resource pointers reset to `null`; UI displays resting/standby empty state.
   - `'disconnected'`: Network or subsystem offline; reconnect prompts displayed.
   - `'error'`: Fault condition; error recovery/retry actions exposed.
2. **Deterministic Teardown (Elimination of Phantom Loops):**
   When transitioning out of `'active'` or `'paused'` into resting states (`'idle'`, `'disconnected'`, `'error'`), client components MUST immediately:
   - Clear and cancel active animation frames and `setInterval` handles.
   - Nullify active entity data pointers to prevent rendering stale payloads.
3. **Resilient Backwards Compatibility & Fallback Resolvers:**
   When ingesting telemetry from legacy backends or test mocks where `status` may be omitted, the client MUST compute an unambiguous fallback status deterministically rather than spreading unvalidated booleans:
   ```typescript
   export function resolveEntityStatus(dto: Partial<StateMachineDTO<unknown>>): EntityStatus {
     if (dto.status) return dto.status;
     if (dto.is_active === false && !dto.data) return 'idle';
     if (dto.is_loading) return 'loading';
     if (dto.is_active) return 'active';
     return 'idle';
   }
   ```

---

## 11. Responsive UI Audit & Visual Design Standards (`MusicBotUI` Pattern)

All frontend applications built with this stack MUST adhere to the automated **Responsive UI Audit & Visual Design Standards** defined in [responsive-ui-audit/SKILL.md](file:///C:/GIT/TECHSTACK/responsive-ui-audit/SKILL.md) and [workflow-guide.md](file:///C:/GIT/TECHSTACK/responsive-ui-audit/references/workflow-guide.md).

### 11.1 Mandatory Visual Design Patterns

1. **Sliding Active Tab Indicator (The Magic Pill Pattern):**
   * Never use abrupt background color toggles on click or un-transitioned hover flashes (see [hover-animation-issue.png](file:///C:/GIT/TECHSTACK/responsive-ui-audit/resources/hover-animation-issue.png)).
   * Position an absolute pill indicator beneath tab labels that dynamically transitions via `transform: translateX(...)` and `width` using Apple/iOS-style spring easing (`cubic-bezier(0.16, 1, 0.3, 1)`, `300ms`), paired with `transition-colors duration-200 ease-out` and `hover:bg-white/[0.04]` on buttons (see [sliding-tab-fixed.png](file:///C:/GIT/TECHSTACK/responsive-ui-audit/resources/sliding-tab-fixed.png)).
2. **Odd-Numbered Grid Balancing (Dynamic Flex Stretch):**
   * Never use rigid 2-column grids (`sm:grid-cols-2`) for odd-numbered card collections (e.g., 5 items), which leaves an empty void in the bottom-right (see [uneven-items-issue.png](file:///C:/GIT/TECHSTACK/responsive-ui-audit/resources/uneven-items-issue.png)).
   * Use `flex flex-wrap items-stretch gap-2.5` on the container and `flex-1 min-w-[210px]` on each card so items automatically expand to fill 100% of every row (e.g., 3 + 2 on tablet, 5 across on desktop; see [balanced-providers-fixed.png](file:///C:/GIT/TECHSTACK/responsive-ui-audit/resources/balanced-providers-fixed.png)).
3. **Mandatory Custom Scroller (`src/index.css`):**
   * Never allow default white/gray Chromium scrollbars on dark-themed scroll containers (see [bad-default-scrollbar.png](file:///C:/GIT/TECHSTACK/responsive-ui-audit/resources/bad-default-scrollbar.png)). Always include the 5px translucent rounded scrollbar and `.no-scrollbar` utility in `src/index.css`:

```css
/* Custom sleek scrollbar matching MusicBotUI pattern */
* {
  scrollbar-width: thin;
  scrollbar-color: rgba(148, 163, 184, 0.25) transparent;
}

*::-webkit-scrollbar {
  width: 5px;
  height: 5px;
}

*::-webkit-scrollbar-track {
  background: transparent;
}

*::-webkit-scrollbar-thumb {
  background: rgba(148, 163, 184, 0.25);
  border-radius: 9999px;
  transition: background 0.2s ease;
}

*::-webkit-scrollbar-thumb:hover {
  background: rgba(148, 163, 184, 0.45);
}

*::-webkit-scrollbar-button {
  display: none;
  width: 0;
  height: 0;
}

.no-scrollbar {
  scrollbar-width: none !important;
  -ms-overflow-style: none !important;
}

.no-scrollbar::-webkit-scrollbar {
  display: none !important;
}
```

### 11.2 Automated 8-Viewport Zero-Overflow Audit Workflow

Before concluding any UI feature or layout change, verify zero horizontal overflow (`scrollWidth <= clientWidth`) across all 8 standard viewports (`375x667`, `390x844`, `844x390`, `768x1024`, `1024x768`, `1366x768`, `1920x1080`, `2560x1080`):

1. **Capture Multi-Viewport Screenshots:**
   ```powershell
   python responsive-ui-audit/scripts/capture_responsive.py --url http://localhost:5173 --output screenshots/responsive
   ```
2. **Pinpoint Overflowing DOM Nodes (`scrollWidth > clientWidth`):**
   ```powershell
   python responsive-ui-audit/scripts/detect_overflows.py --url http://localhost:5173
   ```
   *(Script exits with code `0` only when `total_overflows == 0` across every viewport and navigation tab.)*

---

## 12. SOLID Architecture Principles in SolidJS & TypeScript

In accordance with [solid-architecture/SKILL.md](file:///C:/GIT/TECHSTACK/solid-architecture/SKILL.md) and [solid-across-stacks.md](file:///C:/GIT/TECHSTACK/solid-architecture/references/solid-across-stacks.md), all frontend code MUST enforce the five SOLID principles with **0 KB runtime overhead**:

1. **Single Responsibility Principle (SRP):**
   * Separate **Presentational Components** (`src/components/`), **Route Containers** (`src/pages/`), **Reactive Signal Stores & FSMs** (`src/stores/`), and **Typed HTTP/SSE Clients** (`src/api/`).
   * UI components MUST NEVER execute raw `fetch()` calls or mutate global state directly inside JSX event handlers.
2. **Open/Closed Principle (OCP):**
   * Design reusable UI primitives (`Button`, `AnimatedPanel`, `Card`) to be open for extension via composition (`props.children`, slot props, and variant maps) without modifying base component internals.
3. **Liskov Substitution Principle (LSP):**
   * Any data source or store consuming `StateMachineDTO<T>` (live SSE stream, REST poller, or mock fixture) MUST honor the exact same `EntityStatus` transition contract and deterministic teardown rules.
4. **Interface Segregation Principle (ISP):**
   * Never pass an entire global store object into a leaf component. Define narrow TypeScript prop interfaces containing **only** the specific signal accessors (`Accessor<T>`) or primitive values that the component renders.
5. **Dependency Inversion Principle (DIP):**
   * Reactive stores in `src/stores/` depend on typed API client interfaces (`src/api/`) and environment configs—never on hardcoded URLs or raw `window.fetch` implementation details.

---

## 13. Human-Readable Error Messages (Never Surface Raw HTTP Codes)

* **Rule:** UI components and API clients (`src/api/client.ts`) MUST NEVER surface raw status strings such as `"HTTP 404"`, `"HTTP 502"`, or `"Failed to fetch"` to users.
* **Centralized Status Mapping:** Always check structured backend messages (`detail` / `message` / `error`) first, and fall back to a human-readable status lookup table:
  * `400` → *"Please check your input and try again."*
  * `401` → *"Your session has expired. Please sign in again."*
  * `403` → *"You don't have permission to perform this action."*
  * `404` → *"The requested item or endpoint could not be found."*
  * `408` → *"The request timed out. Please try again."*
  * `409` → *"This conflicts with existing data. Please refresh and try again."*
  * `429` → *"Too many requests right now. Please wait a moment and try again."*
  * `500` → *"Something went wrong on the server. Please try again."*
  * `502` / `503` / `504` → *"The server is temporarily unreachable. Please try again in a moment."*
* **Network / Offline Errors:** Catch `fetch` network exceptions (`TypeError`) and surface *"Unable to reach the server. Please check your connection and try again."*

---

## 14. Mobile & PWA Power Efficiency (Zero Background Battery Leaks)

On Android, installed PWAs (Chrome WebAPKs) run their entire JS runtime, SSE/WebSocket sockets, and Service Worker inside `com.android.chrome`. Any background reconnect loop or unpaused timer drains battery under the **Chrome** app entry.

### 14.1 Visibility-Gated SSE / WebSocket Lifecycle (Mandatory)
* **Pause in Background:** When `document.hidden` becomes `true`, close all `EventSource` / `WebSocket` connections (`teardownStreams()`). Background notifications belong to Web Push (`sw.js`), not open TCP sockets.
* **Resume on Foreground:** When `document.hidden` becomes `false`, reconnect streams and run a single REST sync.
* **Bounded Backoff:** On `onerror`, NEVER use a fixed tight retry (e.g., `setTimeout(..., 5000)`). Guard against `document.hidden` and use capped exponential backoff (`5s` → `10s` → `20s` → `60s` max).

```ts
// Reference pattern for stores managing EventSource / WebSocket
if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      teardownStreams();
    } else if (getStoredToken()) {
      void scheduleStore.loadAll(untrack(loadedCalendars));
    }
  });
}
```

### 14.2 Timers, Service Worker & Media Rules
1. **Pause Intervals:** `setInterval` / `requestAnimationFrame` loops must skip or clear while `document.hidden === true`.
2. **Zero-Fetch `sw.js`:** Service Worker `push` handlers must render directly from `event.data.json()` via `self.registration.showNotification(...)` inside `event.waitUntil(...)`—avoid `fetch()` inside `push` events so background wakeups stay sub-100ms.
3. **Media / `AudioMix` Hygiene:** Pause and clear `srcObject` / `src` on `<video>` and `<audio>` elements on unmount or `pagehide` so Android does not retain an idle `AudioTrack` (`AudioMix` wakelock).
4. **How to Audit Power Leaks:**
   * **Code:** Grep `frontend/src` and `public/sw.js` for `EventSource`, `WebSocket`, `setInterval`, `wakeLock`, and `fetch` inside `sw.js`, and verify each is gated by `visibilitychange` / `onCleanup`.
   * **Android ADB (Read-Only):** Check `dumpsys batterystats --charged` (screen-off CPU/Wi-Fi & partial wakelocks), `dumpsys netpolicy` (frequent `RCVR` wakeups), and `dumpsys audio` (orphaned `AudioTrack` instances).

---

## 15. Mobile-First PWA Layout & Navigation Rules (Lessons Learned)

When building mobile views for web/PWA apps (`< 768px`), NEVER port desktop multi-row headers, 7-column grids, or centered floating modals onto a ~390px viewport:

1. **Zero Header Sprawl — Floating Bottom Capsule Navigation + FAB:**
   * Move top-level sections (*Schedule, Split Bills, Groups, Profile*) into a bottom navigation capsule (`sticky bottom-0`, `pb-[max(20px,env(safe-area-inset-bottom))]`), and dock the primary create action (`+`) as a FAB right above the tab bar so events/content start immediately at the top.
2. **Sheets & Full-Screen Pages Instead of Centered Modals:**
   * **Quick views / details / pickers** (Event Details, Payment QR, Filter lists): Use bottom-anchored sheets (`rounded-t-[23.5px]`, drag handle, `env(safe-area-inset-bottom)` sticky footer).
   * **Long multi-field forms** (Event Editor, New Split Bill): Use a full-screen page with a sticky top bar (`←` Back, Title, Primary Save) so virtual keyboards never crush or trap scroll gestures.
   * **Single Dismiss Control:** Never render both a back arrow (`←`) and a close button (`✕`) in the same mobile header.
3. **Mobile Calendar Views (No Squished 7-Day Grids):**
   * **Month View:** Render colored event dots under day numbers instead of truncated 2-letter text chips, and show the selected day's agenda list directly underneath.
   * **Week View:** Render a **rolling 3-day** column grid (`3-Day`) instead of 7 cramped columns so event titles and touch targets remain legible without horizontal cutoff.
4. **Flatten Payment & Action Flows:**
   * Avoid nested bordered boxes around QR codes; surface the owed amount and primary **Open Banking App** / **Pay with VietQR** CTA at the top level with safe-area bottom padding.






