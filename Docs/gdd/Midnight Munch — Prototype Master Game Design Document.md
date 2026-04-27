
## 1. Prototype Specifications

|**Specification**|**Value**|**Technical Rationale**|
|---|---|---|
|**Engine**|Godot 4.6|Standard runtime environment.|
|**Language**|GDScript only|C# is strictly prohibited due to Web/WASM build size and compatibility targets.|
|**Target Platform**|HTML5 / WebGL2|Browser-first deployment. Focus on Web-safe execution.|
|**Resolution**|1280 × 720|16:9 fixed web canvas.|
|**Performance Target**|60 FPS (16.6 ms/frame)|Requires aggressive object pooling to prevent Garbage Collection (GC) stutter on web.|
|**Save Data Budget**|< 4 KB|`user://save.json` (IndexedDB-backed). Tab-crash resilient.|
|**Core Scope**|1 Truck (Taco), Day 0 (Tutorial) + Day Loop|Single environment, strict order sequencing, fixed customer archetype.|

---

## 2. Core Loop & Mechanics

The core loop requires the player to manage a queue of up to 3 customers, accepting one order at a time, and fulfilling it via a strict positional and mechanical sequence.

### 2.1 The Assembly Sequence (Authoritative)

Recipes enforce a fixed assembly sequence. Stations downstream are mechanically locked until their prerequisites are met.

1. **Tortilla** (Always available; right hand occupied).

2. **Meat** (Requires Tortilla; 3 discrete slices required).

3. **Toppings** (Requires Meat; any internal order; optional per recipe).

4. **Sauces** (Requires all requested Toppings; any internal order; optional per recipe).

5. **Bell** (Always interactive, but validates the held state on press).

### 2.2 Interaction Primitives

Timing-sensitive logic **must** run in `_physics_process` to guarantee consistent execution against WASM input latency. All timing windows must be calibrated 30% wider than native equivalents.

- **Instant (Click):** Single key press (Tortilla grab, Bell ring).

- **Discrete Counter (Meat/Trompo):** `E` requires 3 distinct presses. Each press visually transfers one meat fragment to the tortilla. The meat spin 1 times the first slice, spins 2 slices the second, spins 3 times the third slice.

- **Tap-Accumulate (Sauces):** Repeated `F` presses fill a vertical gauge. 0.4s of input idle auto-commits the value.

  - _Green Zone:_ Perfect hit.

  - _Red Zone/Overfill:_ Sloppy flag assigned (tip lost). Overfill triggers GPU over-spray particles.

- **Shrinking Circle (Toppings):** `LMB` click when the shrinking circle enters the target band. Misses drop the topping on the floor (pooled `RigidBody3D`) and apply a permanent "sloppy" flag to that ingredient for the current order.

### 2.3 Queue & Triage Rules

- **Queue Capacity:** Maximum 3 simultaneous customers at the front counter. Additional spawn attempts are suppressed until a slot frees up.
- **Spawn Logic:** Customers spawn dynamically based on time-of-day traffic curves. Spawns use an Object Pool (`NodePool` or `Array`) to prevent instantiation stutter.
- **Patience Mechanics:**
  - **Initial Drain:** Patience arcs (driven by a `Timer` and visualised via a radial `TextureProgressBar` in screen space) drain immediately from the moment of spawn, _even before the order is accepted_.
  - **Active Order State:** Only **one** order can be accepted and cooked at a time. Accepting an order pauses the patience drain for that specific customer, shifting the challenge from triage to execution speed.
  - **Dynamic Scaling:** Patience duration scales inversely with game progression/day level.
- **Resolution States:**
  - **Patience Expiry:** Triggers a "Walkout" state. Emits a `customer_failed` signal, deducts a $1.50 penalty via the EconomyManager, and returns the customer to the pool.
  - **Successful Service:** Emits a `customer_served` signal. Tip multipliers are calculated based on the remaining percentage of the patience arc at the time of acceptance and the accuracy of the order.
  - **Sloppy Service:** Completes the order but negates the tip multiplier and applies a "sloppy" visual/audio feedback state.

### 2.4 Component System Architecture

- **Composition Over Inheritance:** Build features as self-contained, modular Node-based components (e.g., `InteractionComponent`, `HighlightComponent`) that can be easily dropped into any scene or attached to any entity.
- **Plug-and-Play Scripts:** Scripts must be entirely self-contained and reusable. Expose necessary parameters via `@export` variables so designers can adjust values in the Inspector without editing code.
- **Decoupled Dependencies:** Components should not hardcode references to external nodes or siblings. Use Godot's signal system ("Signal Up, Call Down") or export node paths for explicit dependency injection to prevent brittle code.
- **Modular State Machines:** `InteractionStateMachine` cannot be a giant monolithic script. It must delegate logic to individual state nodes (e.g., `StateIdle`, `StateTiming`) acting as components. Each state handles its own discrete logic, making the system extensible.
- **Strong Typing and Discoverability:** Assign a `class_name` to every component. This strictly types the components and adds them to Godot's "Create New Node" menu, making them easily discoverable and placeable across the project.

### 2.5 Designer Driven

- **Use animation player node for animations:** Use the animation player node to animate the stations.
- **Create @export variables for designers on components:** Allow designers to easily changes variable without diving into code

## 3. Input Map & UX

### 3.1 Keybindings

|**Action**|**Input Event (StringName)**|**Context / Hand**|
|---|---|---|
|**Move**|`move_forward`, `move_back`, `move_left`, `move_right` (WASD)|Global character movement.|
|**Look**|Mouse Motion|Yaw 360° free, Pitch ±89° clamped.|
|**Accept / Timing**|`interact_lmb` (Left Mouse Button)|Target customer / Shrinking circle timing.|
|**Take / Grab**|`interact_e` (Key `E`)|Back Counter (Tortilla, Meat slicing).|
|**Apply / Serve**|`interact_f` (Key `F`)|Front Counter (Sauce squish, Service Bell).|
|**Debug Overlay**|`toggle_debug` (Key `F3`)|Developer state inspector (Debug builds only).|

### 3.2 Dynamic UI & HUD

- **HUD Pills:** Displayed top-right when an order is accepted. States: Grey (Pending) -> Pulsing (Active) -> Green (Perfect) -> Orange (Sloppy).

- **World-Space Prompts:** Emitted by stations when aimed at via a 3.0m `RayCast3D`. Displays inputs (e.g., `[E] Grab Tortilla`) or locked reasons (e.g., `Trompo locked — grab a tortilla first`).

- **Bell Confirmation Modal:** If the Bell is rung while ingredients are missing, a `CanvasLayer` modal halts interaction: _"Missing [Item]. Serve anyway? [YES/NO]"_.

---

## 4. Technical Architecture

### 4.1 Autoload Singletons

|**Singleton**|**Responsibility**|
|---|---|
|`EventBus`|Centralized signal routing. Strictly "Signal Up, Call Down." No sibling connections.|
|`GameManager`|State machine for day phases (`TUTORIAL`, `PLAYING`, `END_OF_DAY`), 5-min timer.|
|`EconomyManager`|Ledger for bank balance, credits/debits, end-of-day tally, and the $0 floor.|
|`NodePool`|Pre-instantiation and checkout/return for Tortillas, Meat particles, Sauce streams, Topping meshes, and NPC nodes. **Never use `queue_free()` during gameplay.**|

### 4.2 Required EventBus Signals

GDScript

```
signal order_accepted(customer_id: int, recipe: Resource)
signal order_step_completed(ingredient: StringName, quality: int) # 0=perfect, 1=sloppy
signal order_completed(payment: float, tip: float)
signal order_rejected(food_cost: float)
signal customer_left_angry(penalty: float)
signal balance_changed(new_balance: float, delta: float)
signal upgrade_purchased(upgrade_id: StringName)
signal day_started(day_number: int)
signal day_ended(summary: Dictionary)
signal station_locked_attempt(station_id: StringName, reason: String)
```

### 4.3 Target Scene Tree (`TruckInterior.tscn`)

Plaintext

```
TruckInterior (Node3D)
├── Player (CharacterBody3D)
│   ├── StandingCollisionShape (CollisionShape3D)
│   ├── Body (Node3D — visual + Camera3D + interaction RayCast3D)
│   ├── MidnightMunchHUD (CanvasLayer)
│   ├── GUI (Control)
│   ├── InteractionStateMachine (Node)
│   ├── DebugOverlay (CanvasLayer)
│   └── NavigationAgent3D (NavigationAgent3D)
├── CSGGeo (Node3D)
├── Stations (Node3D)
│   ├── TortillaStation     (Area3D, type: INSTANT, key: interact_e)
│   ├── TrompoStation       (Area3D, type: DISCRETE_COUNTER, key: interact_e)
│   ├── BellStation         (Area3D + SnapZone, type: INSTANT, key: interact_f)
│   ├── WhiteSauceStation   (Area3D, type: TAP_ACCUMULATE, key: interact_f)
│   ├── RedSauceStation     (Area3D, type: TAP_ACCUMULATE, key: interact_f)
│   ├── CilantroStation     (Area3D, type: TIMING, key: interact_lmb)
│   ├── TomatoStation       (Area3D, type: TIMING, key: interact_lmb)
│   └── OnionStation        (Area3D, type: TIMING, key: interact_lmb)
├── QueueSlots (Node3D)
│   ├── Slot1, Slot2, Slot3 (Marker3D)
└── Lighting (NodeEnvironment)
```

---

## 5. Data & Economy

All configuration must be data-driven using Godot Resources (`.tres`).

### 5.1 Base Economy Protocol

- **Starting Balance:** $5.00

- **Absolute Floor:** $0.00 (Penalties cap at $0; Soft bail-out adds $2.00 next day if hit).

- **Base Taco Sale:** +$3.50

- **Per-Order Tips:**

  - 0 sloppy flags = +$1.00

  - 1 sloppy flag = +$0.50

  - 2+ sloppy flags = +$0.00

- **Deductions:** Drop topping (-$0.05), Patience Expiry (-$1.50), Wrong order (Deducts combined food cost).

### 5.2 Ingredient Food Costs

|**Item**|**Cost**|**Requirement**|
|---|---|---|
|Tortilla|$0.25|Always Required|
|Meat|$0.75|Always Required (3 slices = 1 portion)|
|Sauces (Red/White)|$0.15|Optional (Recipe dependent)|
|Toppings (Cilantro/Tomato/Onion)|$0.10|Optional (Recipe dependent)|

---

## 6. Implementation Checklist

Execute these tasks strictly in order. Do not proceed to the next module until the prior is functioning within the target FPS and WASM constraints.

### Module 1: Core Architecture & Pooling (Verification Phase)
*Goal: Ensure the foundation can handle 60FPS on Web without GC stutter.*
- **Singleton Audit:** Verify `EventBus.gd` contains all signals from GDD Section 4.2.
- **NodePool Setup:** Implement `NodePool.gd` with generic `checkout(scene: PackedScene)` and `return_to_pool(node: Node)` methods.
- **Resource Definitions:** Create `Recipe.gd` (Resource) with `@export` arrays for `required_ingredients` and `optional_ingredients`.
- **Verification:** Create a test script that checks out/returns 100 `ToppingItem.tscn` nodes; verify 0.0ms frame spikes in Profiler.

### Module 2: The "WASM-Ready" Player & Debug Overlay
*Goal: Frame-perfect movement and visibility into the state machine.*
- **Physics-Bound Look:** Process mouse input in `_unhandled_input` but apply all rotations/movement in `_physics_process` to match WASM latency calibration.
- **F3 Debug Overlay:** Create a `CanvasLayer` subscribing to `EventBus`. Display: `Current State`, `Held Item`, `Last Quality Flag`, and `FPS`.
- **Verification:** Use the `F3` overlay to confirm movement speed remains consistent across browser resize events.

### Module 3: Component-Based Interaction System
*Goal: Decouple "What I am" (Station) from "How I'm used" (Interaction Logic).*
- **Base Components:** 
    - Create `InteractableComponent.gd` (Area3D) emitting `focused` signals on RayCast hit.
    - Create `PromptComponent.gd` (Sprite3D/Control) to toggle visibility of bound keys (e.g., "[E] Grab").
- **Interaction State Machine (ISM):** Implement on the Player using child nodes for states (`StateIdle.gd`, `StateBusy.gd`).
- **Verification:** Verify the interaction prompt appears/disappears accurately based on RayCast focus.

### Module 4: The Assembly Line (Back Counter)
*Goal: Strict sequencing of the core taco loop.*
- **Tortilla Station:** Implement as `INSTANT` type. On `interact_e`, checkout `TacoBase` from `NodePool` and parent to Player hand.
- **Trompo (Meat) Station:** Implement `DISCRETE_COUNTER`. Requires `HoldingTortilla` state. Use `AnimationPlayer` for 1x, 2x, 3x spin sequence.
- **Verification:** Attempt Trompo usage without a tortilla; verify `EventBus` emits `station_locked_attempt` and Debug Overlay shows the reason.

### Module 5: Dynamic Interaction (Front Counter)
*Goal: Timing and gauge mechanics calibrated for Web.*
- **Sauce Station (Tap-Accumulate):** Implement 0.4s idle-commit timer. Assign `quality: 1` (Sloppy) if gauge hits the "Red Zone."
- **Topping Station (Shrinking Circle):** Implement UI logic in `_physics_process`. On "Miss," spawn a pooled `RigidBody3D` at the station to simulate a spill.
- **Verification:** Successfully complete a "Perfect" fill and a "Sloppy" drop; verify `EventBus` signals reflect the correct quality.

### Module 6: Order Pipeline & Economy
*Goal: Validation and financial consequences.*
- **HUD Pills:** Map `order_step_completed` quality flags to Grey/Green/Orange UI states.
- **Bell Station (The Validator):** On `interact_f`, compare `TacoBase` ingredients against active `Recipe`. Trigger "Missing Item" popup if incomplete.
- **Economy Wiring:** Connect `order_completed` to `EconomyManager`. Calculate base sale ($3.50) + tips; update HUD balance.
- **Verification:** Serve a perfect taco vs. an incomplete taco; verify balance increases correctly or the warning popup blocks the sale.

### Module 7: The Midnight Crowd (Queue Logic)
*Goal: Triage management and NPCs.*
- **Navigation NPCs:** Setup `Customer.tscn` with `NavigationAgent3D`. Use `NodePool` to spawn/despawn at Marker3D queue slots.
- **Patience Arcs:** Implement world-space `TextureProgressBar`. On timeout, trigger `customer_left_angry` and $1.50 penalty.
- **Verification:** Wait for customer patience to expire; verify penalty deduction and NPC return to pool.
