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

## 7. Build & Proxy Configuration (`vite.config.ts`)

Configured for local development with automatic API proxying to the Rust backend (`http://127.0.0.1:8080`) to eliminate CORS configuration during development.

```typescript
import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid";

export default defineConfig({
  plugins: [solidPlugin()],
  server: {
    port: 3000,
    // Proxy API calls directly to the local Rust Axum backend
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8080",
        changeOrigin: true,
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

## 9. Development & Production Build Lifecycle

1. **Local Development (Windows & Linux):**
   ```bash
   pnpm install
   pnpm dev
   ```
   * Starts Vite at `http://localhost:3000`.
   * Automatically proxies `/api/*` requests to the Rust backend running on `http://127.0.0.1:8080`.

2. **Production Build:**
   ```bash
   pnpm build
   ```
   * Compiles TypeScript and runs Vite production build.
   * Outputs static, pre-minified assets into `dist/` (< 25 KB total initial load).
   * Ready for static hosting, CDN, or serving directly from a lightweight reverse proxy or embedded binary.

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

