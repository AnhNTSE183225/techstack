# SOLID Implementation Blueprints Across Backend, Frontend & Mobile

This reference provides concrete **Anti-Pattern (❌)** vs. **SOLID Standard (✔)** code examples tailored specifically to our three high-performance tech stacks:
1. **Backend:** Rust + Axum + SQLx ([BACKEND_TECHSTACK.md](../../BACKEND_TECHSTACK.md))
2. **Frontend:** SolidJS + TypeScript + Vite ([FRONTEND_TECHSTACK.md](../../FRONTEND_TECHSTACK.md))
3. **Mobile:** Flutter (Impeller) + Dart AOT + Signals + Drift ([MOBILE_TECHSTACK.md](../../MOBILE_TECHSTACK.md))

---

## 1. Single Responsibility Principle (SRP)

> **Rule:** Separate HTTP/UI transport, business/FSM orchestration, and raw SQL/network I/O into distinct modules.

### ❌ Anti-Pattern (God Handler Mixing HTTP, Business Logic, and Raw SQL)
```rust
// ❌ BAD: Handler validates input, runs raw SQL, computes business metrics, and formats HTTP responses
pub async fn create_order(
    State(pool): State<SqlitePool>,
    Json(payload): Json< serde_json::Value >,
) -> impl IntoResponse {
    let price = payload["price"].as_f64().unwrap_or(0.0);
    if price <= 0.0 {
        return (StatusCode::BAD_REQUEST, "Invalid price").into_response();
    }
    let tax = price * 0.08;
    let _ = sqlx::query("INSERT INTO orders (price, tax) VALUES (?, ?)")
        .bind(price)
        .bind(tax)
        .execute(&pool)
        .await;
    (StatusCode::CREATED, "Created").into_response()
}
```

### ✔ SOLID Standard (Separated Validator DTO, Service, Repository & Handler)
```rust
// 1. DTO & Validation Responsibility (models/order.rs)
#[derive(Deserialize, Validate)]
pub struct CreateOrderRequest {
    #[validate(range(min = 0.01))]
    pub price: f64,
}

// 2. Persistence Responsibility (repositories/order_repo.rs)
pub struct SqliteOrderRepo {
    pool: SqlitePool,
}
impl SqliteOrderRepo {
    pub async fn insert(&self, price: f64, tax: f64) -> Result<i64, AppError> {
        let res = sqlx::query!("INSERT INTO orders (price, tax) VALUES (?, ?)", price, tax)
            .execute(&self.pool)
            .await?;
        Ok(res.last_insert_rowid())
    }
}

// 3. Domain Calculation Responsibility (services/order_service.rs)
pub struct OrderService<R: OrderRepository> {
    repo: R,
}
impl<R: OrderRepository> OrderService<R> {
    pub async fn create(&self, req: CreateOrderRequest) -> Result<OrderDto, AppError> {
        req.validate()?;
        let tax = req.price * 0.08;
        let id = self.repo.insert(req.price, tax).await?;
        Ok(OrderDto { id, total: req.price + tax })
    }
}

// 4. Thin Transport Handler Responsibility (handlers/order_handler.rs)
pub async fn create_order(
    State(state): State<AppState>,
    Json(req): Json<CreateOrderRequest>,
) -> Result<(StatusCode, Json<OrderDto>), AppError> {
    let order = state.order_service.create(req).await?;
    Ok((StatusCode::CREATED, Json(order)))
}
```

---

## 2. Open/Closed Principle (OCP)

> **Rule:** Design modules so new behaviors, providers, or UI views can be added by registering a new implementation—without modifying existing tested code.

### ❌ Anti-Pattern (Modifying Core Functions with Growing `match` / `if-else` Chains)
```typescript
// ❌ BAD: Every time a new notification channel is added, this core function must be edited
export async function sendAlert(type: string, msg: string) {
  if (type === "email") {
    // hardcoded email logic
  } else if (type === "sms") {
    // hardcoded sms logic
  } else if (type === "webhook") {
    // hardcoded webhook logic
  }
}
```

### ✔ SOLID Standard (Open for Extension via Strategy / Trait Contract)
```typescript
// ✔ GOOD: Closed for modification, open for extension via AlertTransport contract
export interface AlertTransport {
  readonly channel: string;
  send(message: string): Promise<void>;
}

export class AlertDispatcher {
  private readonly transports = new Map<string, AlertTransport>();

  register(transport: AlertTransport): void {
    this.transports.set(transport.channel, transport);
  }

  async dispatch(channel: string, message: string): Promise<void> {
    const transport = this.transports.get(channel);
    if (!transport) throw new Error(`Unsupported alert channel: ${channel}`);
    await transport.send(message);
  }
}
```

---

## 3. Liskov Substitution Principle (LSP)

> **Rule:** Every subtype or implementation of an interface/trait must uphold the exact same input/output invariants and state machine transitions.

### ✔ SOLID Standard Across Rust, SolidJS & Flutter (`StateMachineDTO<T>` Contract)
Whether a frontend or mobile store connects to:
- `LiveSseTelemetrySource` (production Rust Axum backend stream),
- `CachedSqliteTelemetrySource` (offline local SQLite WAL replay), or
- `MockTelemetrySource` (automated Playwright / Flutter widget test),

Every implementation MUST emit valid `EntityStatus` transitions (`disconnected` -> `loading` -> `active` / `idle`) and never violate the teardown contract:

```dart
abstract interface class TelemetryGateway<T> {
  Stream<StateMachineDTO<T>> watchStatus(String entityId);
  Future<void> triggerTransition(String entityId, String action);
}

// Both LiveDioTelemetryGateway and OfflineDriftTelemetryGateway can be substituted
// into StatefulEntityController<T> without changing a single line of UI or FSM code.
```

---

## 4. Interface Segregation Principle (ISP)

> **Rule:** Never force a component, handler, or service to depend on methods, signals, or props it does not use.

### ❌ Anti-Pattern (Passing Bloated Store Objects to Leaf UI Components)
```tsx
// ❌ BAD: StatusBadge only needs 'status', but is forced to depend on the entire 25-field UserSessionStore
export function StatusBadge(props: { store: FullUserSessionStore }) {
  return <span class="badge">{props.store.state.status}</span>;
}
```

### ✔ SOLID Standard (Segregated Minimal Props / Narrow Traits)
```tsx
// ✔ GOOD: Depends strictly on the minimal read-only status accessor it renders
import type { Accessor } from "solid-js";
import type { EntityStatus } from "../models/state";

export interface StatusBadgeProps {
  status: Accessor<EntityStatus>;
}

export function StatusBadge(props: StatusBadgeProps) {
  return <span class="px-2 py-1 rounded text-xs">{props.status()}</span>;
}
```

In Rust (`BACKEND_TECHSTACK.md`), segregate traits by role rather than creating one monolithic trait:
```rust
// ✔ GOOD: Read-only health/metrics consumers only depend on TelemetryReader
pub trait TelemetryReader: Send + Sync {
    fn current_status(&self) -> LifecycleState;
}

pub trait TelemetryController: TelemetryReader {
    fn transition_to(&mut self, next: LifecycleState, reason: &str);
}
```

---

## 5. Dependency Inversion Principle (DIP)

> **Rule:** High-level domain logic and UI state stores must depend on abstractions and injected configuration—never on hardcoded low-level infrastructure.

### ❌ Anti-Pattern (Hardcoded Low-Level Dependencies Inside UI / Domain Logic)
```dart
// ❌ BAD: Controller instantiates Dio with a hardcoded URL and queries SQLite directly
class DashboardController {
  final dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.50:8080'));
  Future<void> refresh() async {
    final res = await dio.get('/api/items');
    // ...
  }
}
```

### ✔ SOLID Standard (Constructor-Injected Abstractions + `AppConfig`)
```dart
// ✔ GOOD: Depends on abstract ItemRepository; concrete Dio/Drift implementation is injected at root
abstract interface class ItemRepository {
  Future<List<ItemDto>> fetchAll();
}

class DashboardController {
  final ItemRepository _repository;
  final Signal<EntityStatus> status = signal(EntityStatus.idle);
  final Signal<List<ItemDto>> items = signal(const []);

  DashboardController(this._repository);

  Future<void> refresh() async {
    status.value = EntityStatus.loading;
    try {
      final data = await _repository.fetchAll();
      batch(() {
        items.value = data;
        status.value = EntityStatus.active;
      });
    } catch (_) {
      status.value = EntityStatus.error;
    }
  }
}
```
