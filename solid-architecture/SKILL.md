---
name: solid-architecture
description: >-
  Enforces the five SOLID software design principles (Single Responsibility, Open/Closed,
  Liskov Substitution, Interface Segregation, Dependency Inversion) across both AI agent
  code generation (Rust, SolidJS, Flutter) and AI agent task/prompt decomposition—without
  sacrificing sub-millisecond performance (preferring compile-time generics and traits over
  heavy runtime vtable/heap overhead).
---

# SOLID Architecture & Agentic Engineering Standard

AI coding models do **not** naturally write SOLID code by default. Without explicit architectural constraints, "vibe coding" with AI quickly produces **God files** (e.g., 1,500-line `main.rs` or `App.tsx` files mixing HTTP routing, SQL queries, state machines, and UI rendering), tightly coupled hardcodings, and fragile, untestable pipelines.

This skill mandates that every AI agent operating in this repository apply **SOLID Principles at two levels simultaneously**:
1. **Level 1 — Code & System Architecture:** Every Rust module, SolidJS component/store, and Flutter widget/DAO written or refactored MUST strictly adhere to SOLID using **zero-cost compile-time abstractions**.
2. **Level 2 — Agent Task & Prompt Decomposition:** Every complex user request MUST be decomposed by the agent into single-responsibility, contract-driven execution steps (see [resources/solid-prompt-engineering.jpg](./resources/solid-prompt-engineering.jpg)).

---

## ⚡ The Performance-First SOLID Rule (Zero-Cost Abstractions)

> [!IMPORTANT]
> **SOLID Must Never Introduce Runtime Bloat**
> Traditional OOP interpretations of SOLID often abuse deep class inheritance hierarchies, excessive heap boxing (`Box<dyn Trait>`), and runtime dependency-injection reflection containers that hurt latency.
>
> In our high-performance tech stack, SOLID is achieved with **zero runtime cost**:
> * **Rust Backend:** Use **Traits + Monomorphized Generics (`impl Trait` / `<R: ItemRepository>`)** or enum dispatch instead of unnecessary `Box<dyn Trait>` vtable heap allocations.
> * **SolidJS Frontend:** Use **Pure Functions, Composable Signal Stores, and TypeScript Discriminated Interfaces** (`type` / `interface`)—all of which compile away to **0 bytes** of runtime overhead.
> * **Flutter Mobile:** Use **`abstract interface class` + Compile-Time Constructor Injection** (zero `dart:mirrors` reflection).

---

## 1. The Five SOLID Pillars Applied to Code Architecture

| Principle | Core Rule | Anti-Pattern (Forbidden in Vibe Coding) | Architectural Standard Across Our Stacks |
| :--- | :--- | :--- | :--- |
| **S — Single Responsibility (SRP)** | A module, struct, store, or component must have **only one reason to change**. | Placing SQL queries, business validation, and HTTP status formatting inside a single Axum route handler or putting `fetch()` + complex state transforms directly inside a SolidJS/Flutter UI view. | **Strict 4-Layer Separation:**<br>1. **Transport / View** (`routes/`, `components/`, `pages/`)<br>2. **State / Application Logic** (`handlers/`, `stores/`, FSM controllers)<br>3. **Domain Contracts & Models** (`models/`)<br>4. **Data / Infrastructure** (`repositories/`, `api/`, `database/`) |
| **O — Open/Closed (OCP)** | Entities must be **open for extension, closed for modification**. | Modifying a core dispatcher with giant `if/else` chains every time a new provider, export format, or animation variant is added. | **Trait / Slot / Strategy Extension:**<br>• **Rust:** Implement a shared `Trait` or `enum` variant handler.<br>• **SolidJS/Flutter:** Extend UI via composable slots (`props.children`), strategy maps, or theme tokens without altering the core component logic. |
| **L — Liskov Substitution (LSP)** | Subtypes/implementations must be **interchangeable without breaking caller invariants**. | A mock or alternative repository/provider that silently swallows errors, mutates shared state unexpectedly, or returns a different DTO shape. | **Strict Behavioral & Wire Contracts:**<br>All implementations of a repository trait, API client, or `StateMachineDTO<T>` MUST honor the exact same state machine transitions, error semantics (`Result<T, AppError>`), and output schema. |
| **I — Interface Segregation (ISP)** | Clients must **never depend on methods or props they do not use**. | Passing an entire 30-field `UserStore` or `AppState` into a simple `AvatarBadge` component, or creating a monolithic 20-method `DatabaseManager` trait. | **Role-Focused Narrow Contracts:**<br>• **Rust:** Split traits by capability (`ItemReader`, `ItemWriter`, `HealthCheck`).<br>• **SolidJS/Flutter:** Pass only the exact signals/fields a leaf component renders (`Pick<T, K>` or narrow `interface`). |
| **D — Dependency Inversion (DIP)** | High-level business logic must **depend on abstractions (traits/interfaces & structured config)**, never hardcoded low-level details. | Hardcoding SQLite file paths, URLs (`"http://localhost:8080"`), or concrete third-party SDK calls directly inside business/UI logic. | **Invert via Traits, Interfaces & Config:**<br>High-level handlers/stores depend on abstract repository traits/interfaces and strongly-typed configuration (`AppConfig` from `default.yaml` / `default.json`). |

---

## 2. The Five SOLID Pillars Applied to AI Agent Workflow & Prompt Engineering

As illustrated in [resources/solid-prompt-engineering.jpg](./resources/solid-prompt-engineering.jpg), AI agents produce dramatically higher accuracy, lower complexity, and easier debugging when tasks and subagent prompts follow SOLID:

```text
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                 SOLID PRINCIPLES FOR AI AGENT TASK DECOMPOSITION                    │
├──────┬──────────────────────────────┬───────────────────────────────────────────────┤
│  S   │ Single Responsibility        │ One clear objective per step/subagent task.   │
│      │                              │ Separate data/DB changes, backend endpoints,  │
│      │                              │ UI components, and verification into distinct │
│      │                              │ sequential phases.                            │
├──────┼──────────────────────────────┼───────────────────────────────────────────────┤
│  O   │ Open / Closed                │ Keep core system rules & base architectures   │
│      │                              │ immutable; add domain features via modular    │
│      │                              │ extensions (new routes, stores, skills).      │
├──────┼──────────────────────────────┼───────────────────────────────────────────────┤
│  L   │ Liskov Substitution          │ Specialized modules or subagents must return  │
│      │                              │ the exact same output contract (e.g.,         │
│      │                              │ StateMachineDTO<T>) regardless of backend.    │
├──────┼──────────────────────────────┼───────────────────────────────────────────────┤
│  I   │ Interface Segregation        │ Do not overload a single turn or subagent     │
│      │                              │ with unrelated instructions. Feed only the    │
│      │                              │ relevant stack spec and files for that layer. │
├──────┼──────────────────────────────┼───────────────────────────────────────────────┤
│  D   │ Dependency Inversion         │ Drive behavior through structured inputs and  │
│      │                              │ typed schemas (YAML/JSON configs, DTOs),      │
│      │                              │ never hardcoded magic strings or assumptions. │
└──────┴──────────────────────────────┴───────────────────────────────────────────────┘
```

---

## 3. Mandatory Pre-Finish SOLID Self-Audit Checklist for Agents

Before running `.\build.ps1` / `./build.sh` to conclude any coding task, the AI agent MUST verify:

- [ ] **1. File & Function Granularity (SRP):**
  - Are any files becoming "God files" (> 300–400 lines mixing multiple concerns)? If so, split them by responsibility (`routes/`, `handlers/`, `services/`, `repositories/`, `models/`, `components/`, `stores/`).
  - Does every struct, store, and UI component have a single, clearly stated responsibility?
- [ ] **2. Zero-Touch Extension (OCP):**
  - Can a new item type, provider, or view variant be added without rewriting existing working business logic?
- [ ] **3. Contract & FSM Interchangeability (LSP):**
  - Do all implementations of a trait/interface honor the exact same `Result<T, AppError>` and `StateMachineDTO<T>` (`status` enum) invariants?
- [ ] **4. Narrow Props & Trait Boundaries (ISP):**
  - Do UI components accept only the specific props/signals they render? Are Rust traits and TypeScript/Dart interfaces small and role-specific?
- [ ] **5. Zero Hardcoded Infrastructure in Domain Logic (DIP):**
  - Are all URLs, ports, file paths, timeouts, and credentials injected via `AppConfig` (`config/default.yaml` / `config/default.json`) and accessed through typed clients/repositories?

---

## Detailed References & Visual Guide

- **Cross-Stack Code Blueprints (Rust, SolidJS, Flutter):** [references/solid-across-stacks.md](./references/solid-across-stacks.md)
- **SOLID Prompt Engineering Visual Reference:** [resources/solid-prompt-engineering.jpg](./resources/solid-prompt-engineering.jpg)
