# MOBILE_TECHSTACK.md: Ultra-Low Overhead Flutter (Impeller + AOT) Architecture

A reference specification for building an ultra-fast, low-footprint cross-platform mobile application in Flutter & Dart (AOT) designed for locked 60–120Hz (ProMotion / LTPO) frame rates, sub-millisecond fine-grained reactive updates, zero runtime reflection, and deterministic execution across **local Windows/Linux development** and **resource-constrained Android & iOS devices**.

---

## 1. Toolchain & Core Prerequisites

| Component | Role | Documentation & Reference |
| :--- | :--- | :--- |
| **Flutter SDK & Dart AOT Toolchain** | Ahead-of-Time (AOT) native ARM64 (`aarch64`) machine-code compiler and UI toolkit | • [Flutter Docs](https://docs.flutter.dev/)<br>• [Dart Language Tour](https://dart.dev/language)<br>• [Dart AOT vs JIT Architecture](https://docs.flutter.dev/resources/architectural-overview) |
| **Impeller Rendering Engine** | Next-gen GPU rendering runtime with offline AOT-compiled shaders (Vulkan on Android, Metal on iOS) | • [Impeller Rendering Engine](https://docs.flutter.dev/perf/impeller) |
| **Android SDK / NDK & Platform Tools** | Native Android compilation, C FFI linker (`clang`), and `adb` hardware debugging bridge | • [Android Command-Line Tools](https://developer.android.com/tools)<br>• [ADB Reference](https://developer.android.com/tools/adb) |
| **`just` (Command Runner)** | Unified, cross-platform task runner replacing fragmented `.bat`, `.ps1`, and `.sh` scripts | • [just Manual](https://just.systems/man/en/) |
| **`build_runner` & Codegen CLI** | Compile-time static code generation for SQL queries (`drift`) and JSON DTOs (`json_serializable`) | • [build_runner Package](https://pub.dev/packages/build_runner)<br>• [Drift SQL Compiler](https://drift.simonbinder.eu/) |

---

## 2. Environment Setup Guide (Windows & Linux)

### Windows 10 / 11 Setup

Run the following commands in PowerShell (as Administrator):

```powershell
# 1. Install Git, OpenJDK 17 (required by Gradle/Android SDK), and Flutter SDK via winget
winget install Git.Git
winget install Microsoft.OpenJDK.17
winget install Google.Flutter

# 2. Install Android Studio (includes Android SDK, NDK, and Platform-Tools / ADB)
winget install Google.AndroidStudio

# 3. Optional: Install Visual Studio C++ Build Tools (for local Windows desktop target testing)
winget install Microsoft.VisualStudio.2022.BuildTools --override "--passive --add Microsoft.VisualStudio.Workload.VCTools"

# 4. Install 'just' command runner
winget install Casey.Just

# 5. Restart PowerShell, accept Android licenses, and verify toolchain health
flutter doctor --android-licenses
flutter doctor -v
```

### Linux Setup (Ubuntu / Debian / Fedora / Arch)

Run the following commands in your Linux terminal:

```bash
# 1. Install system dependencies, KVM virtualization dependencies, and OpenJDK 17
# (Debian / Ubuntu)
sudo apt update && sudo apt install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk clang cmake ninja-build pkg-config libgtk-3-dev

# (Fedora)
# sudo dnf install -y curl git unzip xz zip mesa-libGLU java-17-openjdk-devel clang cmake ninja-build gtk3-devel

# (Arch Linux)
# sudo pacman -S curl git unzip xz zip glu jdk17-openjdk clang cmake ninja gtk3

# 2. Install Flutter SDK (via official tarball or snap/git)
git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

# 3. Verify installation and accept Android SDK licenses
flutter doctor --android-licenses
flutter doctor -v
```

---

## 3. Rendering Engine & Runtime Architecture

Unlike React Native or Cordova—which serialize events across an asynchronous JavaScript bridge or rely on heavy DOM layouts—Flutter compiles Dart directly into **native ARM64 (`aarch64`) machine instructions** and drives the GPU directly via **Impeller**.

```text
┌────────────────────────────────────────────────────────────────┐
│  Flutter Widgets & Fine-Grained Signals (signals_flutter)      │
├────────────────────────────────────────────────────────────────┤
│  Element & RenderObject Tree: Sub-millisecond Dirty Layout     │
├────────────────────────────────────────────────────────────────┤
│  Impeller Engine: Pre-compiled AOT Shaders (Zero Shader Jank)  │
├────────────────────────────────────────────────────────────────┤
│  Native GPU Hardware API: Android Vulkan  /  iOS Metal         │
├────────────────────────────────────────────────────────────────┤
│  Background Worker Isolates: SQLite WAL (C FFI) & JSON Parsing │
└────────────────────────────────────────────────────────────────┘
```

### Impeller (Hardware-Accelerated GPU Runtime)
* **Role:** Deterministic 2D/3D hardware rasterizer built specifically to guarantee locked 60Hz–120Hz frame pacing (< 8.3ms frame budget at 120Hz).
* **Performance Profile:**
  * **Zero Runtime Shader Compilation:** All GLSL/MSL shaders are compiled ahead-of-time during `flutter build`. Eliminates the notorious first-run animation stutter ("shader compilation jank") seen in legacy Skia pipelines.
  * **Direct Metal & Vulkan Backends:** Bypasses legacy OpenGL drivers to minimize CPU-to-GPU command buffer submission overhead and leverage explicit memory management.
* **Documentation:**
  * Official Architecture: [docs.flutter.dev/perf/impeller](https://docs.flutter.dev/perf/impeller)

### Dart AOT Runtime & Isolate Concurrency Model
* **Role:** Shared-nothing actor concurrency model (`Isolate`) paired with Ahead-of-Time native machine code compilation.
* **Performance Profile:**
  * **Generational Low-Latency Allocation:** The UI Isolate features a thread-local bump-pointer nursery allocator designed to collect short-lived frame objects during vsync idle gaps without pausing animations.
  * **Zero UI-Thread Blocking (`Isolate.run`):** All compute-heavy workloads (JSON payload decoding > 10 KB, cryptographic hashing, image transcoding, and SQLite disk I/O) execute on background worker isolates with zero lock contention on the UI thread.
* **Documentation:**
  * Concurrency & Isolates: [dart.dev/language/concurrency](https://dart.dev/language/concurrency)

---

## 4. UI Paradigm, Fine-Grained Reactivity & 120Hz Animations

To match the zero-overhead reactivity of [FRONTEND_TECHSTACK.md](file:///C:/GIT/TECHSTACK/FRONTEND_TECHSTACK.md) (SolidJS), this architecture replaces heavyweight stream/bloc ceremony and full-screen `setState()` rebuilds with **fine-grained reactive Signals**.

### `signals_flutter` (Fine-Grained Reactive Engine)
* **Reactivity via Signals:** Uses `signal()`, `computed()`, and `effect()` backed by a lazy, glitch-free dependency graph identical in semantics to SolidJS.
* **Surgical Leaf-Node Rebuilds:** Wrapping a leaf widget in `Watch((context) => ...)` subscribes **only that specific widget** to the read signals. Updating a counter, progress bar, or telemetry value mutates only the exact leaf `RenderObject` without rebuilding parent screens or layouts.
* **Documentation:**
  * Package & API Reference: [pub.dev/packages/signals_flutter](https://pub.dev/packages/signals_flutter)
  * Official Guide: [dartsignals.dev](https://dartsignals.dev/)

### Crucial Architectural Rules & Gotchas

> [!CAUTION] Never Call `setState()` at the Page Root or Read Signals Outside `Watch`
> Calling `setState()` on a top-level `StatefulWidget` marks the entire component subtree dirty, forcing O(N) widget allocation on every tick.
> * **Incorrect:** Reading `mySignal.value` directly inside a parent screen's `build()` method without a `Watch` boundary (rebuilds the entire screen on every change).
> * **Correct:** Keep page-level widgets `StatelessWidget` with `const` constructors, and wrap **only the dynamic leaf node** in `Watch((_) => Text('${counter.value}'))`.

> [!TIP] Aggressive `const` Widget Canonicalization & `RepaintBoundary`
> * **Always mark static widget subtrees `const`:** The Dart AOT compiler canonicalizes `const` widgets into compile-time singletons in read-only memory. During layout/rebuild passes, Flutter short-circuits `const` subtrees in $O(1)$ pointer comparison time.
> * **Isolate High-Frequency Repaints:** Wrap continuously animating elements (tickers, waveform visualizers, spinners, progress bars) in a `<RepaintBoundary>` so Impeller caches surrounding static layers as a GPU texture without re-rasterizing them.

### Hardware-Accelerated Animation Strategy: When to Use What

```text
Simple State / Layout Transitions ───► ImplicitlyAnimatedWidgets (TweenAnimationBuilder / AnimatedOpacity)
High-Frequency 120Hz Transitions  ───► Explicit AnimationController + CustomPainter + RepaintBoundary
Page / Shared-Element Routing     ───► GoRouter + Hero GPU Layer Transitions
```

1. **Tier 1 (Default): Implicit GPU-Backed Transitions (`AnimatedContainer`, `AnimatedScale`, `AnimatedOpacity`)**
   * Use for 85% of micro-interactions (button press scaling, color shifts, panel expansion).
   * **`AnimatedOpacity` / `AnimatedSlide` Optimization:** Automatically updates the underlying `RenderObject` layer properties (`OpacityLayer`, `TransformLayer`) directly on the Impeller raster thread without rebuilding the child widget tree.
2. **Tier 2: Explicit `AnimationController` + `flutter_animate`**
   * Use for declarative, composable multi-stage enter/exit sequences matching `@motionone/solid` ergonomics.
   * Driven by `Ticker` synced directly to the display hardware VSync signal (60Hz / 90Hz / 120Hz).
   * **Documentation:** [pub.dev/packages/flutter_animate](https://pub.dev/packages/flutter_animate)
3. **Tier 3: Direct Canvas (`CustomPainter` + Fragment Shaders)**
   * For real-time telemetry charts, audio visualizers, or particle effects, bypass the widget tree completely and draw directly onto the Impeller `Canvas` inside a `RepaintBoundary`.

---

## 5. Data Persistence, Isolate Offloading & Serialization

### Drift + `sqlite3` FFI (Compile-Time Verified SQLite in WAL Mode)
* **Role:** Pure C SQLite bound directly via Dart FFI (`dart:ffi`), paired with `drift` for compile-time SQL verification—the exact mobile counterpart to Rust's `sqlx` in [BACKEND_TECHSTACK.md](file:///C:/GIT/TECHSTACK/BACKEND_TECHSTACK.md).
* **Database Strategy:**
  * **Direct C FFI (`sqlite3_flutter_libs`):** Bypasses slow platform-channel Java/Obj-C SQLite wrappers (`sqflite`), executing C SQLite calls with zero serialization overhead.
  * **Background Isolate Execution (`NativeDatabase.createInBackground`):** Runs the entire SQLite connection pool on a dedicated background Isolate so queries and writes never block a single UI frame.
  * **Mandatory WAL Pragmas:** Configured at initialization with `PRAGMA journal_mode = WAL;`, `PRAGMA synchronous = NORMAL;`, and `PRAGMA temp_store = MEMORY;` for concurrent read/write throughput and minimal flash wear.
* **Compile-Time Safety:**
  * Validates SQL syntax, schema types, and indices at build time, generating zero-reflection typed Data Classes.
* **Documentation:**
  * Official Manual: [drift.simonbinder.eu](https://drift.simonbinder.eu/)
  * Package Reference: [pub.dev/packages/drift](https://pub.dev/packages/drift) | [pub.dev/packages/sqlite3](https://pub.dev/packages/sqlite3)

### `json_serializable` & `freezed` (Zero-Reflection Serialization)
* **Role:** Compile-time AST code generation for JSON encoding/decoding and immutable value types.
* **Performance Profile:** Dart AOT strips `dart:mirrors` (runtime reflection) completely to keep binaries small and fast. `json_serializable` generates static, inlineable `fromJson` / `toJson` methods that can be passed directly into `Isolate.run()` for background parsing.
* **Documentation:**
  * Package Reference: [pub.dev/packages/json_serializable](https://pub.dev/packages/json_serializable) | [pub.dev/packages/freezed](https://pub.dev/packages/freezed)

### Dio & Native HTTP/2 + SSE Client
* **Role:** High-performance HTTP client with connection pooling, binary interceptors, and real-time Server-Sent Events (SSE) / WebSocket streaming to the Rust Axum backend.
* **Documentation:**
  * Package Reference: [pub.dev/packages/dio](https://pub.dev/packages/dio)

### Hardware-Backed Security (`flutter_secure_storage`)
* **Role:** Stores JWT tokens and cryptographic keys inside hardware-backed secure enclaves (**Android Keystore** / **iOS Keychain** with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
* **Documentation:**
  * Package Reference: [pub.dev/packages/flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)

---

## 6. Configuration & Environment Layer

### Compile-Time Configuration Injection (`--dart-define-from-file`)
* **Role:** Mirrors the `config/default.yaml` and `config/prod.yaml` pattern from [BACKEND_TECHSTACK.md](file:///C:/GIT/TECHSTACK/BACKEND_TECHSTACK.md) with **zero runtime file-parsing overhead**.
* **Design Pattern:**
  * `config/default.json`: Baseline configuration targeting local development (e.g., local Rust Axum backend at `http://10.0.2.2:8080` for Android Emulator or LAN IP for physical device).
  * `config/prod.json`: Production API endpoints and telemetry toggles baked directly into AOT compile-time constants (`String.fromEnvironment`).
  * Because `String.fromEnvironment` evaluates as a `const` at compile time, the Dart AOT compiler dead-code eliminates (`tree-shakes`) any debug-only branches from the production binary.

---

## 7. Complete Mobile `pubspec.yaml` Reference

```yaml
name: ultra_mobile
description: Ultra-low overhead 120Hz mobile client architecture.
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

  # 1. Fine-Grained Reactivity (SolidJS-style Signals)
  signals_flutter: ^5.5.0

  # 2. Routing & Hardware-Accelerated Animations
  go_router: ^14.2.0
  flutter_animate: ^4.5.0

  # 3. Local Persistence (C FFI SQLite in WAL Mode on Background Isolate)
  drift: ^2.20.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0

  # 4. Networking, Serialization & Hardware Keystore
  dio: ^5.7.0
  json_annotation: ^4.9.0
  flutter_secure_storage: ^9.2.2

  # 5. Structured Telemetry
  logging: ^1.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

  # Compile-Time Code Generators (Zero Runtime Reflection)
  build_runner: ^2.4.12
  drift_dev: ^2.20.0
  json_serializable: ^6.8.0

flutter:
  uses-material-design: true
```

> [!IMPORTANT]
> **CRITICAL PERFORMANCE RULE: Always Benchmark & Deploy in Release Mode (`--release`)**
> * **Debug Mode (`flutter run`):** Compiles Dart in **JIT (Just-In-Time) VM mode** with debugging service extensions (` observatory` / `dds`), checked assertions, and unstripped symbol tables enabled. Frame times are unpredictable, memory usage is inflated by 60–100 MB, and animations frequently drop frames. **Never evaluate UI smoothness or CPU/memory metrics in Debug mode.**
> * **Profile Mode (`flutter run --profile`):** Compiles to native ARM64 AOT instructions while keeping only lightweight DevTools tracing enabled for 120Hz frame-timing inspection.
> * **Release Mode (`flutter run --release` / `flutter build apk --release --split-per-abi`):** Strips the Dart VM completely, compiles 100% AOT native `aarch64` assembly, tree-shakes unused code and icons, obfuscates symbols, and locks in sub-millisecond reactive updates.

---

## 8. Architecture & Directory Blueprint

```text
mobile/
├── build.ps1                          # [Windows] Zero-Assumption checklist + AOT Release Build
├── start.ps1                          # [Windows] Release runner on device/emulator (writes .pids)
├── stop.ps1                           # [Windows] Deterministic PID tree stopper (reads .pids)
├── build.sh                           # [Linux] Zero-Assumption checklist + AOT Release Build
├── start.sh                           # [Linux] Release runner on device/emulator (writes .pids)
├── stop.sh                            # [Linux] Deterministic PID tree stopper (reads .pids)
├── .pids                              # [Runtime] Active process IDs persisted by start script
├── pubspec.yaml
├── Justfile                           # Optional task shortcuts
├── analysis_options.yaml              # Strict static analyzer & linter rules
│
├── config/                            # [Configurations] Compile-time environment definitions
│   ├── default.json                   # Local dev config (10.0.2.2:8080 / LAN Rust backend)
│   └── prod.json                      # Production host & telemetry overrides
│
├── android/                           # Native Android host (Vulkan Impeller enabled)
├── ios/                               # Native iOS host (Metal Impeller enabled)
│
└── lib/                               # [Pure Code] Application logic only
    ├── main.dart                      # Entrypoint, AppLifecycle listener & root mount
    ├── app_config.dart                # Compile-time const configuration accessor
    ├── router.dart                    # Declarative GoRouter configuration
    │
    ├── core/
    │   ├── database/                  # Drift compile-time SQLite WAL engine
    │   │   ├── app_database.dart
    │   │   └── tables.drift           # Raw compile-time verified SQL schema & queries
    │   ├── network/                   # Dio HTTP/SSE client & isolate JSON decoders
    │   │   └── api_client.dart
    │   └── telemetry/                 # Structured FSM & lifecycle logger
    │       └── logger.dart
    │
    ├── stores/                        # Global reactive state (Signals & FSM controllers)
    │   ├── auth_store.dart
    │   └── entity_fsm_store.dart
    │
    ├── models/                        # Compile-time DTOs (json_serializable)
    │   └── state_machine_dto.dart
    │
    ├── components/                    # Reusable leaf-reactive UI widgets
    │   ├── animated_panel.dart
    │   └── status_badge.dart
    │
    └── pages/                         # Screen-level const views
        ├── home_page.dart
        └── dashboard_page.dart
```

---

## 9. Implementation Blueprints & Unified Task Automation

### 9.1 Compile-Time Configuration (`config/default.json` & `lib/app_config.dart`)

**`config/default.json`:**
```json
{
  "ENV": "dev",
  "API_BASE_URL": "http://10.0.2.2:8080/api",
  "WS_BASE_URL": "ws://10.0.2.2:8080/ws",
  "SQLITE_DB_NAME": "ultra_local.db"
}
```

**`config/prod.json`:**
```json
{
  "ENV": "prod",
  "API_BASE_URL": "https://api.example.com/api",
  "WS_BASE_URL": "wss://api.example.com/ws",
  "SQLITE_DB_NAME": "ultra_prod.db"
}
```

**`lib/app_config.dart`:**
```dart
abstract final class AppConfig {
  static const String env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080/api',
  );
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://127.0.0.1:8080/ws',
  );
  static const String sqliteDbName = String.fromEnvironment(
    'SQLITE_DB_NAME',
    defaultValue: 'ultra_local.db',
  );

  static const bool isProd = env == 'prod';
}
```

### 9.2 Background Isolate SQLite in WAL Mode (`lib/core/database/app_database.dart`)

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../app_config.dart';

part 'app_database.g.dart';

LazyDatabase _openWalConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConfig.sqliteDbName));

    // Executes all SQLite C FFI calls on a dedicated background Isolate
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // Match BACKEND_TECHSTACK.md SQLite WAL performance pragmas
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA synchronous = NORMAL;');
        rawDb.execute('PRAGMA temp_store = MEMORY;');
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}

@DriftDatabase(include: {'tables.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openWalConnection());

  @override
  int get schemaVersion => 1;
}
```

### 9.3 Fine-Grained Signal + 120Hz Impeller Component (`lib/components/animated_panel.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:signals_flutter/signals_flutter.dart';

class AnimatedPanelDemo extends StatefulWidget {
  const AnimatedPanelDemo({super.key});

  @override
  State<AnimatedPanelDemo> createState() => _AnimatedPanelDemoState();
}

class _AnimatedPanelDemoState extends State<AnimatedPanelDemo> {
  // Fine-grained reactive signal (does NOT trigger parent StatefulWidget rebuilds)
  final isOpen = signal<bool>(false);

  @override
  void dispose() {
    isOpen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Notice: build() executes ONLY ONCE on mount.
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => isOpen.value = !isOpen.value,
              child: const Text('Toggle 120Hz Impeller Panel'),
            ),
            const SizedBox(height: 16),
            // Surgical leaf subscription: only this Watch block updates when isOpen changes
            Watch((context) {
              if (!isOpen.value) return const SizedBox.shrink();
              return RepaintBoundary(
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fine-Grained Impeller Panel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF1F5F9),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Rasterized directly via Vulkan/Metal with pre-compiled shaders and surgical Signal reactivity.',
                        style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 200.ms, curve: Curves.easeOut)
                    .scaleXY(begin: 0.9, end: 1.0, duration: 200.ms, curve: Curves.easeOut)
                    .moveY(begin: -10, end: 0, duration: 200.ms, curve: Curves.easeOut),
              );
            }),
          ],
        ),
      ),
    );
  }
}
```

### 9.4 Mandatory 6-Script Lifecycle (`build`, `start`, `stop` for `.ps1` & `.sh`) & `Justfile`

In accordance with [build-start-separation/SKILL.md](file:///C:/GIT/TECHSTACK/build-start-separation/SKILL.md), the mobile workspace integrates into the repository's 6 mandatory root scripts (`build.ps1`, `start.ps1`, `stop.ps1` for Windows; `build.sh`, `start.sh`, `stop.sh` for Linux):

1. **Zero-Assumption Build (`build.ps1 -IncludeMobile` / `./build.sh --include-mobile`):**
   * Assumes a bare OS with zero pre-installed compilers or SDKs.
   * Verifies **Git**, **OpenJDK 17 (`java`/`javac`)**, and **Flutter & Dart AOT SDK (`flutter`)**—auto-installing via `winget` / `apt` / `dnf` / `pacman` where possible, or throwing a formatted fatal error with the official download URL and manual install command.
   * Executes `flutter pub get`, compile-time codegen (`dart run build_runner build --delete-conflicting-outputs`), and AOT native ARM64 release compilation (`flutter build apk --release --split-per-abi`).
2. **Release Runner (`start.ps1` / `start.sh`):**
   * Launches the pre-compiled release binary (`flutter run --release` or installs the built release APK via `adb`) and records active host process IDs in `.pids`.
3. **Deterministic Stopper (`stop.ps1` / `stop.sh`):**
   * Reads `.pids`, terminates active host runner/daemon PIDs and their child trees, and deletes `.pids`.

```makefile
# Full Zero-Assumption build (includes mobile AOT release APK)
build:
    powershell -ExecutionPolicy Bypass -File ../build.ps1 -IncludeMobile

# Run in Profile mode (AOT native performance + 120Hz DevTools frame tracing)
profile:
    flutter run --profile --dart-define-from-file=config/default.json

# Run in full Release mode on connected device (true production performance)
run-release:
    flutter run --release --dart-define-from-file=config/default.json

# Compile-time code generation (Drift SQLite + JSON DTOs)
codegen:
    dart run build_runner build --delete-conflicting-outputs

# Build ultra-compact, ABI-split, symbol-stripped ARM64 production APK
build-apk: codegen
    flutter build apk --release \
      --split-per-abi \
      --obfuscate \
      --split-debug-info=build/symbols \
      --dart-define-from-file=config/prod.json

# Build production Android App Bundle (AAB) for Play Store
build-aab: codegen
    flutter build appbundle --release \
      --obfuscate \
      --split-debug-info=build/symbols \
      --dart-define-from-file=config/prod.json
```

---

## 10. Deterministic Finite State Machine (FSM) & OS Lifecycle Architecture

Mobile applications face an even harsher concurrency environment than desktop browsers: in addition to network streams and user input, the mobile OS (`Android ActivityManager` / `iOS SpringBoard`) can preempt, background, throttle, or reclaim hardware handles at any moment.

Relying on scattered boolean flags (`isLoading`, `isPaused`, `isConnected`, `isInBackground`, `hasError`) causes battery-draining phantom `Timer.periodic` loops in the background, orphaned audio/camera/socket handles, and UI tearing upon app resumption.

Mobile architecture strictly mandates that all stateful modules be governed by an **explicit, deterministic Finite State Machine (FSM)** that synchronizes both **backend network contracts** and **OS `AppLifecycleState` events**.

### 10.1 The Anti-Pattern: Distributed Boolean Flags

```text
❌ ANTI-PATTERN: Scattered Boolean Flags
   isConnected: true | isLoading: false | isPlaying: true | isBackgrounded: true  <-- Invalid!
   Result: Phantom 60Hz tickers draining battery while screen is off, crashes on dead surface handles.

✔ ARCHITECTURAL STANDARD: Explicit Finite State Machine
   Status:EntityStatus.paused (or suspended)
   Result: Single source of truth, deterministic teardown of tickers/streams on OS backgrounding.
```

### 10.2 Dart FSM Pattern: Strongly-Typed Enum, Signal Store & Explicit Transitions

The mobile client consumes the exact same lowercase `status` wire contract defined in [BACKEND_TECHSTACK.md](file:///C:/GIT/TECHSTACK/BACKEND_TECHSTACK.md) and [FRONTEND_TECHSTACK.md](file:///C:/GIT/TECHSTACK/FRONTEND_TECHSTACK.md):

```dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

enum EntityStatus {
  disconnected,
  idle,
  loading,
  active,
  paused,
  error;

  static EntityStatus fromWire(String? raw) {
    return EntityStatus.values.firstWhere(
      (e) => e.name == raw?.toLowerCase(),
      orElse: () => EntityStatus.idle,
    );
  }
}

class StateMachineDTO<T> {
  final EntityStatus status;
  final T? data;
  final int timestamp;

  const StateMachineDTO({
    required this.status,
    required this.data,
    required this.timestamp,
  });

  /// Resilient backwards-compatible resolver matching FRONTEND_TECHSTACK.md
  static EntityStatus resolveEntityStatus(Map<String, dynamic> json) {
    if (json['status'] is String) {
      return EntityStatus.fromWire(json['status'] as String);
    }
    if (json['is_active'] == false && json['data'] == null) return EntityStatus.idle;
    if (json['is_loading'] == true) return EntityStatus.loading;
    if (json['is_active'] == true) return EntityStatus.active;
    return EntityStatus.idle;
  }
}
```

State transitions MUST be encapsulated inside a dedicated controller that enforces resource invariants, logs every transition, and reconciles OS lifecycle changes (`WidgetsBindingObserver`):

```dart
class StatefulEntityController<T> with WidgetsBindingObserver {
  final String id;
  final Signal<EntityStatus> status = signal(EntityStatus.disconnected);
  final Signal<T?> activeData = signal(null);

  Timer? _progressTicker;
  EntityStatus? _preBackgroundStatus;

  StatefulEntityController({required this.id}) {
    WidgetsBinding.instance.addObserver(this);
  }

  void transitionTo(EntityStatus next, {required String reason, T? data}) {
    final current = status.value;
    if (current == next && data == null) return;

    batch(() {
      status.value = next;
      if (data != null) {
        activeData.value = data;
      }

      // Invariant enforcement: Atomic teardown on resting or fault states
      if (next == EntityStatus.idle ||
          next == EntityStatus.disconnected ||
          next == EntityStatus.error) {
        _cancelTickers();
        activeData.value = null;
      } else if (next == EntityStatus.paused || next == EntityStatus.loading) {
        _cancelTickers();
      }
    });

    dev.log(
      '[FSM] Entity $id: ${current.name} -> ${next.name} (Reason: $reason)',
      name: 'state_machine',
    );
  }

  /// Reconciles mobile OS foreground/background transitions deterministically
  @override
  void didChangeAppLifecycleState(AppLifecycleState osState) {
    switch (osState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (status.value == EntityStatus.active) {
          _preBackgroundStatus = EntityStatus.active;
          _cancelTickers();
          dev.log(
            '[FSM] Entity $id: Suspended UI tickers due to OS ${osState.name}',
            name: 'state_machine',
          );
        }
        break;
      case AppLifecycleState.resumed:
        if (_preBackgroundStatus == EntityStatus.active) {
          _preBackgroundStatus = null;
          // Trigger immediate state resync with backend upon returning to foreground
          transitionTo(EntityStatus.loading, reason: 'OS foreground resume resync');
        }
        break;
      case AppLifecycleState.detached:
        transitionTo(EntityStatus.disconnected, reason: 'OS detached engine');
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _cancelTickers() {
    _progressTicker?.cancel();
    _progressTicker = null;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTickers();
    status.dispose();
    activeData.dispose();
  }
}
```

### 10.3 State Transition Matrix & OS Lifecycle Reconciliation

```text
  ┌──────────────┐      connect()      ┌──────────────┐
  │ disconnected │ ──────────────────> │     idle     │ <──────────────────┐
  └──────────────┘                     └──────────────┘                    │
         ▲                                     │         ▲                 │
         │ disconnect() / OS detached          │ start   │ stop / finish   │
         │                                     ▼         │                 │
         │                             ┌──────────────┐  │                 │
         │                             │   loading    │ ─┘ (on error/idle) │
         │                             └──────────────┘                    │
         │                                     │                           │
         │                                     │ ready (SSE/REST sync)     │
         │                                     ▼                           │
         │      terminate() / error    ┌──────────────┐                    │
         │ <────────────────────────── │    active    │ ───────────────────┤
         │                             └──────────────┘                    │
         │                                     │      ▲                    │
         │             pause() / OS background │      │ resume()           │
         │                                     ▼      │                    │
         │                                 ┌──────────────┐                │
         └──────────────────────────────── │    paused    │ ───────────────┘
                                           └──────────────┘
```

### 10.4 Core Architectural Invariants

1. **Single Source of Truth (`status` Signal):**
   All UI views bind via `Watch` to the singular `status` signal (`EntityStatus`). Independent boolean flags (`isLoading`, `isPaused`, `isPlaying`) are strictly prohibited in view stores.
2. **Mandatory Structured Transition Logging:**
   Every transition MUST emit a structured log entry (`name: 'state_machine'`) recording the entity ID, previous state, next state, and explicit trigger reason.
3. **Zero Background Battery Drain (OS Lifecycle Reconciliation):**
   When the mobile OS transitions to `AppLifecycleState.paused` or `AppLifecycleState.hidden`, all UI `Ticker`s, animation controllers, and periodic polling timers MUST be suspended immediately. Upon `AppLifecycleState.resumed`, the FSM reconciles its offset against the authoritative server timestamp rather than relying on drifted client timers.
4. **Atomic Teardown on Resting States:**
   Transitioning to `idle`, `disconnected`, or `error` MUST atomically cancel active timers/streams and set `activeData` to `null` inside a single synchronous `batch()` update to prevent stale frame renders or phantom `00:00` counter loops.

---

## 11. Responsive Layout & Visual Cohesion Standards (`MusicBotUI` Mobile Counterpart)

To maintain visual and geometric parity with [FRONTEND_TECHSTACK.md](file:///C:/GIT/TECHSTACK/FRONTEND_TECHSTACK.md) and [responsive-ui-audit/SKILL.md](file:///C:/GIT/TECHSTACK/responsive-ui-audit/SKILL.md) across compact phones (`375x667`), modern tall phones (`390x844`), foldables, and tablets (`768x1024` / `1024x768`):

1. **Zero RenderFlex Overflow Guarantee:**
   * Never use rigid fixed pixel widths on row children. Wrap multi-badge toolbars in `Wrap(spacing: 8, runSpacing: 8)` or `Flexible`/`Expanded` with `TextOverflow.ellipsis` so no screen size ever triggers a yellow/black `RenderFlex overflowed` banner.
2. **Sliding Active Tab Pill (`Cubic(0.16, 1.0, 0.3, 1.0)`):**
   * Use `AnimatedAlign` or `AnimatedPositioned` with `const Cubic(0.16, 1.0, 0.3, 1.0)` (`300ms`) for segmented controls and tab bars so the active pill glides smoothly between selections on Impeller's raster thread.
3. **Balanced Adaptive Card Grids (`LayoutBuilder`):**
   * When rendering odd-numbered card collections on tablets or landscape phones, calculate item widths dynamically via `LayoutBuilder` + `Wrap` so trailing items stretch to balance the row rather than leaving an empty bottom-right void.
4. **Sleek Translucent Scrollbars (`RawScrollbar`):**
   * Configure global `ScrollbarThemeData` with `thickness: WidgetStatePropertyAll(4.0)`, `radius: const Radius.circular(9999)`, and `thumbColor: WidgetStatePropertyAll(Color(0x4094A3B8))` to match the 5px translucent `MusicBotUI` scroller.

