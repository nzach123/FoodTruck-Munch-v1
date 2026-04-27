# Midnight Munch — Implementation Plan & Task List

**Engine:** Godot 4.6 | **Language:** GDScript only | **Target:** HTML5/WebGL2 | **Budget:** 60 FPS @ 16.6 ms/frame

---

## 1. Architecture Overview

The foundation rests on four Autoload singletons wired through a strict **Signal Up, Call Down** discipline: `EventBus` routes all cross-system communication; `GameManager` owns day-phase state; `EconomyManager` owns the ledger; and `NodePool` eliminates all runtime instantiation during gameplay. The screenshot confirms all four `.gd` files exist under `res://_src/autoloads/`.

`TruckInterior.tscn` acts as the single level scene. The `Player` (CharacterBody3D) owns the `InteractionStateMachine` as a child node tree — **not** a monolithic script — delegating per-state logic to `StateIdle`, `StateBusy`, etc. Stations are self-describing `Area3D` nodes composed with `InteractableComponent` and `PromptComponent` — they declare their own interaction *type* (`INSTANT`, `DISCRETE_COUNTER`, `TAP_ACCUMULATE`, `TIMING`) and key binding via `@export`, and the ISM reads those declarations rather than hard-coding per-station behavior.

Every spawned object (toppings, meat particles, sauce streams, NPCs) must be checked out from `NodePool` and returned on completion — **`queue_free()` is banned during gameplay**. All timing-sensitive logic (`DiscreteCounter` press windows, `TapAccumulate` idle timers, `ShrinkingCircle` radius math) must execute in `_physics_process` to remain deterministic against WASM input latency.

**Critical scene tree deltas identified (screenshot vs. GDD spec):**
- Player has `CrouchingCollisionShape`, `StaircheckRayCast3D`, and `CrouchRayCast` — crouching mechanic is live but undocumented in the GDD. These should be wrapped behind an `@export var enable_crouch: bool = false` flag until the feature is formally scoped.
- `DebugOverlay` (CanvasLayer) node is **absent** from the Player subtree — needs adding for Module 2.
- `QueueSlots` (Node3D with 3× Marker3D children) is **absent** from the scene — needed for Module 7.
- `CSGGeo` is present and blocking-out geometry correctly. No `MeshInstance3D` replacements needed for the prototype.

---

## 2. Implementation Plan

Execute modules in strict order. Do not advance until the prior module passes its verification gate at 60 FPS in the browser profiler.

### Phase A — Foundation (Modules 1–2)
Establish the data backbone and the player controller. Nothing gameplay-specific is built until `NodePool` is verified zero-spike and the debug overlay is live.

### Phase B — Interaction Layer (Module 3)
Build the component contracts (`InteractableComponent`, `PromptComponent`, `ISM` state nodes) in isolation. All Stations get the component shell before any station-specific logic is added. This is the riskiest architectural phase — changes here cascade everywhere.

### Phase C — Assembly Line (Modules 4–5)
Implement gameplay mechanics station by station, Back Counter first (Tortilla → Trompo) then Front Counter (Sauces → Toppings). Each station is verified in isolation against `EventBus` signal emission before integration.

### Phase D — Pipeline & Economy (Module 6)
Wire the Bell validator, HUD pill state machine, and economy ledger. Only integrate after Phase C stations are individually verified — do not test end-to-end until each step has a standalone test.

### Phase E — NPCs & Queue (Module 7)
Final phase. Navigation, patience arcs, and pool-based spawn/despawn. The most GC-sensitive phase; profiler must stay clean throughout.

---

## 3. Actionable Task List

### Module 1 — Core Architecture & Pooling

**EventBus Audit**
- [ ] Open `res://_src/autoloads/EventBus.gd` and verify all 10 signals from GDD §4.2 are declared with correct typed parameters
- [ ] Add any missing signals: `order_accepted`, `order_step_completed`, `order_completed`, `order_rejected`, `customer_left_angry`, `balance_changed`, `upgrade_purchased`, `day_started`, `day_ended`, `station_locked_attempt`
- [ ] Confirm `EventBus` is registered in Project Settings → Autoload and loads before all other singletons

**NodePool Implementation**
- [ ] Open `res://_src/autoloads/NodePool.gd` — implement `checkout(scene: PackedScene) -> Node` that returns a free node from an internal `Dictionary[PackedScene, Array]` pool or instantiates if empty
- [ ] Implement `return_to_pool(node: Node) -> void` that calls `node.visible = false`, resets position/rotation, and appends back to the pool array — **no `queue_free()`**
- [ ] Implement `prewarm(scene: PackedScene, count: int) -> void` called at scene load to pre-instantiate objects before gameplay begins
- [ ] Add `class_name NodePool` to the script for strong typing

**Resource Definitions**
- [ ] Create `res://_src/data/Recipe.gd` as `class_name Recipe extends Resource`
- [ ] Add `@export var recipe_name: StringName`
- [ ] Add `@export var required_ingredients: Array[StringName]`
- [ ] Add `@export var optional_ingredients: Array[StringName]`
- [ ] Add `@export var base_sale_price: float = 3.50`
- [ ] Add `@export var food_cost: float` (computed from ingredient costs)
- [ ] Create `res://_src/data/recipes/TacoAlPastor.tres` as a `Recipe` resource instance
- [ ] Create `res://_src/data/IngredientDef.gd` as `class_name IngredientDef extends Resource` with `@export var ingredient_id: StringName`, `@export var cost: float`, `@export var interaction_type: int`

**NodePool Verification**
- [ ] Create `res://_src/data/test/PoolStressTest.gd` — in `_ready()`, checkout and immediately return 100 `ToppingItem.tscn` nodes in a loop
- [ ] Open the Godot Profiler, run the scene in the browser, confirm zero frame spikes above 2 ms during the stress loop
- [ ] Delete the test script after verification passes

---

### Module 2 — WASM-Ready Player & Debug Overlay

**Player Controller**
- [ ] Open the Player script — confirm `_unhandled_input()` accumulates raw mouse delta into a cached `Vector2 _mouse_delta`
- [ ] Confirm all rotation and movement math is applied inside `_physics_process()`, not `_input()` or `_process()`
- [ ] Add `@export var mouse_sensitivity: float = 0.3` for designer tuning
- [ ] Add `@export var move_speed: float = 5.0` and `@export var gravity: float = 9.8`
- [ ] Clamp pitch to ±89° in `_physics_process` to prevent gimbal lock
- [ ] Add a `@export var enable_crouch: bool = false` flag — gate all crouch logic (`CrouchingCollisionShape`, `CrouchRayCast`) behind this flag until formally scoped
- [ ] Verify `StaircheckRayCast3D` and `CrouchRayCast` are disabled in the Inspector if crouching is not in scope for the prototype

**Interaction RayCast**
- [ ] Confirm `Body` child of Player contains a `Camera3D` and a `RayCast3D` with `target_position = Vector3(0, 0, -3.0)` (3-meter reach per GDD §3.2)
- [ ] In `_physics_process`, call `RayCast3D.force_raycast_update()` and cache the collider each frame
- [ ] On collider change (enter/exit), emit `focused`/`unfocused` on the collider's `InteractableComponent` (once component exists in Module 3)

**Debug Overlay**
- [ ] Add a `DebugOverlay` (CanvasLayer) node as a child of Player in `TruckInterior.tscn`
- [ ] Create `res://_src/ui/DebugOverlay.gd` with `class_name DebugOverlay extends CanvasLayer`
- [ ] In `_ready()`, subscribe to `EventBus` signals; store references to `Label` nodes for each field
- [ ] Display fields: `Current ISM State`, `Held Item`, `Last Quality Flag`, `FPS` (updated every 0.5s to avoid label churn)
- [ ] Gate entire CanvasLayer behind `OS.is_debug_build()` — overlay is invisible in release exports
- [ ] Bind `toggle_debug` action (`F3`) in Input Map → Project Settings
- [ ] In `_unhandled_input`, toggle `DebugOverlay.visible` on `toggle_debug` press
- [ ] **Verification:** Resize the browser window mid-play; confirm movement speed does not change and FPS counter stays ≥ 60

---

### Module 3 — Component-Based Interaction System

**InteractableComponent**
- [ ] Create `res://_src/interactables/InteractableComponent.gd` as `class_name InteractableComponent extends Area3D`
- [ ] Add `@export var interaction_type: InteractionType` where `InteractionType` is an `enum { INSTANT, DISCRETE_COUNTER, TAP_ACCUMULATE, TIMING }`
- [ ] Add `@export var required_action: StringName` (e.g., `&"interact_e"`)
- [ ] Add `@export var station_id: StringName`
- [ ] Add `@export var lock_reason: String = ""` — populated by the Station when prerequisites are unmet
- [ ] Declare signals: `signal focused(component: InteractableComponent)` and `signal unfocused()`
- [ ] Expose `func is_locked() -> bool` that checks the current game state via an `@export var prerequisite_check: Callable` (injected by the Station)
- [ ] Add `class_name InteractableComponent` to Godot's node creation menu

**PromptComponent**
- [ ] Create `res://_src/interactables/PromptComponent.gd` as `class_name PromptComponent extends Node3D`
- [ ] Add `@export var prompt_label: Label3D`
- [ ] Add `@export var key_hint: StringName` — formats as `[E] Grab Tortilla`
- [ ] Add `@export var locked_hint: StringName` — displays the `lock_reason` when station is locked
- [ ] In `_ready()`, call `set_visible(false)`
- [ ] Expose `func show_prompt(locked: bool) -> void` and `func hide_prompt() -> void`
- [ ] Bill world-space billboard: set `Label3D.billboard = BaseMaterial3D.BILLBOARD_ENABLED`

**Interaction State Machine**
- [ ] Confirm `InteractionStateMachine` node exists as a child of Player in the scene tree
- [ ] Create `res://_src/player/InteractionStateMachine.gd` as `class_name InteractionStateMachine extends Node`
- [ ] Add `@export var states: Array[Node]` — child state nodes registered here
- [ ] Implement `transition_to(state_name: StringName) -> void` — exits current state, enters new one
- [ ] Create `res://_src/player/states/StateIdle.gd` as `class_name StateIdle extends Node` with `func enter()`, `func exit()`, `func physics_update(delta: float)`, `func handle_input(event: InputEvent)`
- [ ] Create `res://_src/player/states/StateBusy.gd` with the same interface — active during any interaction in progress
- [ ] In `StateIdle.physics_update`, poll the focused `InteractableComponent`; on valid input press, call `ISM.transition_to(&"StateBusy")` and dispatch to the station's interaction handler
- [ ] **Verification:** Aim at a station; confirm prompt appears. Step away; confirm prompt disappears. Confirm `station_locked_attempt` fires via Debug Overlay when prerequisites are unmet.

**Station Scaffolding (all 8 stations)**
- [ ] Add `InteractableComponent` as a child of `TortillaStation` in the Inspector; set `interaction_type = INSTANT`, `required_action = &"interact_e"`, `station_id = &"tortilla"`
- [ ] Repeat for `TrompoStation`: `DISCRETE_COUNTER`, `interact_e`, `&"trompo"`
- [ ] Repeat for `BellStation`: `INSTANT`, `interact_f`, `&"bell"`
- [ ] Repeat for `WhiteSauceStation`: `TAP_ACCUMULATE`, `interact_f`, `&"white_sauce"`
- [ ] Repeat for `RedSauceStation`: `TAP_ACCUMULATE`, `interact_f`, `&"red_sauce"`
- [ ] Repeat for `CilantroStation`: `TIMING`, `interact_lmb`, `&"cilantro"`
- [ ] Repeat for `TomatoStation`: `TIMING`, `interact_lmb`, `&"tomato"`
- [ ] Repeat for `OnionStation`: `TIMING`, `interact_lmb`, `&"onion"`
- [ ] Add `PromptComponent` as a sibling to each `InteractableComponent` and wire `key_hint` and `locked_hint` in the Inspector

---

### Module 4 — Assembly Line (Back Counter)

**TacoBase Resource & Pool**
- [ ] Create `res://_src/entities/TacoBase.tscn` as a `Node3D` with a `MeshInstance3D` child (placeholder tortilla mesh) and a script `TacoBase.gd`
- [ ] `TacoBase.gd`: `class_name TacoBase extends Node3D`; track `var ingredients: Array[StringName] = []`, `var sloppy_flags: int = 0`
- [ ] Add `func add_ingredient(id: StringName) -> void` and `func reset() -> void` (called on pool return)
- [ ] In `NodePool._ready()`, call `prewarm(TacoBase_scene, 3)` — max 3 concurrent tacos

**Tortilla Station — INSTANT**
- [ ] Create `res://_src/interactables/TortillaStation.gd` as `class_name TortillaStation extends Node3D`
- [ ] On `InteractableComponent.focused` received: verify player is NOT already holding a `TacoBase`; set `lock_reason` accordingly
- [ ] On `interact_e` pressed (dispatched by ISM in `StateIdle`): `NodePool.checkout(TacoBase_scene)`; parent to Player's right-hand `Marker3D`; emit `EventBus.order_step_completed(&"tortilla", 0)`
- [ ] Transition Player ISM to `StateHoldingTortilla` (new state)
- [ ] Create `res://_src/player/states/StateHoldingTortilla.gd` — blocks re-grab of Tortilla; unlocks Trompo

**Trompo (Meat) Station — DISCRETE\_COUNTER**
- [ ] Create `res://_src/interactables/TrompoStation.gd` as `class_name TrompoStation extends Node3D`
- [ ] Add `@export var required_presses: int = 3`
- [ ] Add `@export var animation_player: AnimationPlayer` — wire in Inspector
- [ ] Track `var _press_count: int = 0` (reset on new order)
- [ ] Gate: if ISM state is NOT `StateHoldingTortilla`, emit `EventBus.station_locked_attempt(&"trompo", "Grab a tortilla first")` and abort
- [ ] On first `interact_e` press: play `AnimationPlayer` animation `"meat_spin_1x"`, increment `_press_count`; spawn pooled `MeatFragment` particle at Trompo, animate onto TacoBase
- [ ] On second press: play `"meat_spin_2x"`, spawn two `MeatFragment` nodes from pool
- [ ] On third press: play `"meat_spin_3x"`, spawn three `MeatFragment` nodes; call `taco_base.add_ingredient(&"meat")`; emit `EventBus.order_step_completed(&"meat", 0)`; transition ISM to `StateHoldingMeat`
- [ ] Create `res://_src/entities/MeatFragment.tscn` — pooled `GPUParticles3D` or `MeshInstance3D` node; `reset()` disables emitting and returns to origin
- [ ] Create `"meat_spin_1x"`, `"meat_spin_2x"`, `"meat_spin_3x"` animations in the Trompo's `AnimationPlayer` — rotate the Trompo mesh on the Y-axis 1×, 2×, 3× respectively
- [ ] **Verification:** Attempt Trompo without tortilla; confirm Debug Overlay shows `station_locked_attempt` with correct reason. Complete all 3 presses; confirm `order_step_completed` fired 3 times.

---

### Module 5 — Dynamic Interaction (Front Counter)

**Sauce Stations — TAP\_ACCUMULATE**
- [ ] Create `res://_src/interactables/SauceStation.gd` as `class_name SauceStation extends Node3D`
- [ ] Add `@export var green_zone_min: float = 0.6`, `@export var green_zone_max: float = 0.85`, `@export var idle_commit_time: float = 0.4`
- [ ] Add `@export var overfill_particles: GPUParticles3D` — wire in Inspector; disabled by default
- [ ] Track `var _gauge_value: float = 0.0`, `var _idle_timer: float = 0.0`, `var _committed: bool = false` — all logic in `_physics_process`
- [ ] Gate: require ISM state `StateHoldingMeat` or `StateHoldingToppings`; otherwise `station_locked_attempt`
- [ ] Each `interact_f` press: increment `_gauge_value` by `0.15`; reset `_idle_timer = 0.0`
- [ ] In `_physics_process`: accumulate `_idle_timer += delta`; if `_idle_timer >= idle_commit_time` and `_gauge_value > 0.0`, call `_commit()`
- [ ] `_commit()`: if `_gauge_value > green_zone_max`, enable `overfill_particles.emitting = true` for 1.0s (via a pooled timer), set quality = 1 (Sloppy); else if `_gauge_value >= green_zone_min`, quality = 0 (Perfect); else quality = 1 (Sloppy)
- [ ] Emit `EventBus.order_step_completed(station_id, quality)`; call `taco_base.add_ingredient(station_id)` if quality < 2; reset `_gauge_value = 0.0`
- [ ] Wire gauge display to a `TextureProgressBar` on the `MidnightMunchHUD` via `EventBus` signal — do not direct-reference HUD from Station

**Topping Stations — TIMING (Shrinking Circle)**
- [ ] Create `res://_src/interactables/ToppingStation.gd` as `class_name ToppingStation extends Node3D`
- [ ] Add `@export var shrink_duration: float = 1.8` (30% wider than native — per GDD §2.2)
- [ ] Add `@export var target_band_min: float = 0.3`, `@export var target_band_max: float = 0.55` (normalized 0–1 radius)
- [ ] Add `@export var topping_scene: PackedScene` — set per station (Cilantro, Tomato, Onion) in Inspector
- [ ] Track `var _circle_radius: float = 1.0`, `var _active: bool = false` — logic in `_physics_process`
- [ ] On RayCast focus: `_active = true`, `_circle_radius = 1.0` — show the shrinking circle UI element via signal
- [ ] On RayCast exit: `_active = false` — hide circle UI
- [ ] In `_physics_process` while `_active`: `_circle_radius -= delta / shrink_duration`; clamp to 0; emit a signal with current radius for the HUD to display
- [ ] On `interact_lmb` press: if `_circle_radius` within `[target_band_min, target_band_max]`, quality = 0 (Perfect); else quality = 1 (Sloppy) AND spawn pooled `RigidBody3D` topping at station floor position with random impulse
- [ ] If sloppy: call `taco_base.sloppy_flags += 1`; emit `EventBus.order_step_completed(station_id, 1)` with `food_cost` deduction note
- [ ] Create `res://_src/entities/DroppedTopping.tscn` — pooled `RigidBody3D` with `MeshInstance3D`; `reset()` zeros velocity, disables physics, repositions
- [ ] **Verification:** Land a Perfect hit; confirm `quality = 0` in Debug Overlay. Miss; confirm `RigidBody3D` spawns on the floor and `quality = 1` is emitted.

---

### Module 6 — Order Pipeline & Economy

**HUD Pills**
- [ ] In `MidnightMunchHUD`, create a `HBoxContainer` of 6 `Panel` nodes (one per ingredient slot) styled as pills — Grey by default
- [ ] Create `res://_src/ui/HUDPill.gd` as `class_name HUDPill extends Panel`
- [ ] Add states: `PENDING` (grey), `ACTIVE` (pulsing white — `AnimationPlayer` loop), `PERFECT` (green), `SLOPPY` (orange)
- [ ] Subscribe to `EventBus.order_step_completed` — map `ingredient` StringName to the correct pill; set state based on `quality`
- [ ] Pulse animation: use `AnimationPlayer` on the pill to modulate `modulate.a` between 0.5 and 1.0 at 2 Hz while in `ACTIVE` state

**Bell Station — Validator**
- [ ] Create `res://_src/interactables/BellStation.gd` as `class_name BellStation extends Node3D`
- [ ] On `interact_f` press: retrieve the active `Recipe` resource from `GameManager`; call `taco_base.ingredients` and diff against `Recipe.required_ingredients`
- [ ] If missing required ingredients: show a `CanvasLayer` modal (`res://_src/ui/BellConfirmModal.tscn`) — "Missing [Item]. Serve anyway? [YES/NO]"
- [ ] Modal [NO]: dismiss, return control to Player
- [ ] Modal [YES]: proceed to `_complete_order(sloppy: bool = true)`
- [ ] If all required ingredients present: call `_complete_order(sloppy: taco_base.sloppy_flags > 0)`
- [ ] `_complete_order()`: calculate `tip` from sloppy flag count (0 flags = $1.00, 1 = $0.50, 2+ = $0.00); emit `EventBus.order_completed(3.50, tip)`; return `TacoBase` and `MeatFragment` nodes to `NodePool`; transition ISM to `StateIdle`

**EconomyManager**
- [ ] Open `res://_src/autoloads/EconomyManager.gd`; ensure `var balance: float = 5.00`
- [ ] Connect `EventBus.order_completed` → `func _on_order_completed(payment, tip)`: `balance += payment + tip`; emit `EventBus.balance_changed(balance, payment + tip)`
- [ ] Connect `EventBus.customer_left_angry` → `func _on_customer_angry(penalty)`: `balance = max(0.0, balance - penalty)`; emit `EventBus.balance_changed(balance, -penalty)`
- [ ] Connect `EventBus.order_rejected` → deduct `food_cost`: `balance = max(0.0, balance - food_cost)`
- [ ] Add `func save() -> void` — write `{"balance": balance}` to `user://save.json` (< 4 KB budget)
- [ ] Add `func load() -> void` — read and validate on game start
- [ ] HUD balance label: subscribe to `EventBus.balance_changed` — update a `Label` in `MidnightMunchHUD` with `"$%.2f" % new_balance`
- [ ] **Verification:** Serve a perfect taco; confirm balance goes from $5.00 → $9.50. Serve with 2 sloppy flags; confirm $8.50. Trigger an incomplete serve with [YES]; confirm food cost is deducted.

**GameManager Day Phases**
- [ ] Open `res://_src/autoloads/GameManager.gd`; implement `enum DayPhase { TUTORIAL, PLAYING, END_OF_DAY }`
- [ ] Add `@export var day_duration_seconds: float = 300.0` (5 minutes per GDD §4.1)
- [ ] On `PLAYING` start: begin a `Timer` (use a pre-existing scene-tree Timer, not `await`); on timeout, transition to `END_OF_DAY` and emit `EventBus.day_ended({...})`
- [ ] `TUTORIAL` phase: spawn a single static customer, disable patience drain, walk player through the assembly sequence with on-screen text prompts

---

### Module 7 — The Midnight Crowd (Queue Logic)

**QueueSlots Setup**
- [ ] Add `QueueSlots` (Node3D) as a child of `TruckInterior` in the scene tree
- [ ] Add three `Marker3D` children: `Slot1`, `Slot2`, `Slot3` — position in front of the front counter in the 3D viewport
- [ ] In `GameManager` or a dedicated `QueueManager.gd`, track `var _active_customers: Array[Node] = []` (max 3)

**Customer NPC**
- [ ] Create `res://_src/entities/Customer.tscn` with root `CharacterBody3D`, `NavigationAgent3D`, `CollisionShape3D`, `MeshInstance3D` (placeholder mesh), and `PatienceComponent` child
- [ ] Create `res://_src/entities/Customer.gd` as `class_name Customer extends CharacterBody3D`
- [ ] Add `@export var walk_speed: float = 2.5`
- [ ] On checkout from `NodePool`: receive a target `Marker3D`; set `NavigationAgent3D.target_position`; begin movement in `_physics_process` via `NavigationAgent3D.get_next_path_position()`
- [ ] On arrival at slot: stop movement; begin patience drain
- [ ] Add `func reset() -> void` — stops movement, resets patience, hides node

**PatienceComponent**
- [ ] Create `res://_src/entities/PatienceComponent.gd` as `class_name PatienceComponent extends Node`
- [ ] Add `@export var max_patience: float = 30.0`
- [ ] Add `@export var patience_bar: TextureProgressBar` — wire to a world-space `SubViewport` or a screen-space bar positioned via `Camera3D.unproject_position()`
- [ ] Track `var _current_patience: float` — drain in `_physics_process`: `_current_patience -= delta * _drain_rate`
- [ ] `_drain_rate` is paused when the order is accepted (`GameManager` broadcasts `order_accepted`)
- [ ] On `_current_patience <= 0.0`: emit `EventBus.customer_left_angry(1.50)`; trigger Walkout animation via `AnimationPlayer`; call `NodePool.return_to_pool(owner)` after animation completes (use `AnimationPlayer.animation_finished` signal — no `await`)

**Spawn & Despawn**
- [ ] Create `res://_src/entities/QueueManager.gd` as `class_name QueueManager extends Node`
- [ ] Add `@export var customer_scene: PackedScene`
- [ ] In `NodePool._ready()`: `prewarm(customer_scene, 3)`
- [ ] `func try_spawn_customer() -> void`: if `_active_customers.size() < 3`, checkout from pool, assign to the first empty slot, add to `_active_customers`
- [ ] Connect `EventBus.customer_left_angry` and `EventBus.order_completed` → `func _on_customer_resolved()`: remove from `_active_customers`; free slot; call `try_spawn_customer()` after a short delay (use a pooled `Timer`, not `await`)
- [ ] Implement traffic curves: `@export var spawn_interval_curve: Curve` — `GameManager` samples the curve against elapsed time to set `QueueManager`'s spawn interval

**NavigationMesh**
- [ ] Add `NavigationRegion3D` to `TruckInterior` wrapping the `CSGFloor` geometry
- [ ] Bake the `NavigationMesh` in the editor; ensure it covers the path from spawn point to all 3 queue slots
- [ ] Set `NavigationAgent3D.path_desired_distance = 0.5` and `target_desired_distance = 0.3` on the Customer prefab

**Patience Visualization**
- [ ] Create `res://_src/ui/PatienceBar.tscn` — a `SubViewport` containing a `TextureProgressBar` with a radial fill texture
- [ ] Position above each customer's head using a `Node3D` billboard anchor; update `TextureProgressBar.value` from `PatienceComponent._current_patience / max_patience` each `_physics_process`
- [ ] **Verification:** Spawn a customer; wait for patience to expire; confirm `customer_left_angry` fires, $1.50 deducted, NPC returns to pool, slot reopens, new customer spawns.

---

### Cross-Cutting Concerns (Apply Throughout All Modules)

- [ ] Every script gets `class_name` — verify Godot's "Create New Node" menu reflects all components after each module
- [ ] Every tunable value uses `@export` — zero magic numbers in script bodies
- [ ] All animations are driven by `AnimationPlayer` nodes wired in the Inspector — no `Tween` unless for purely UI transitions with no gameplay consequence
- [ ] Run `Project → Export → Web` after each module verification and test in a local HTTP server (`python -m http.server`) — never assume native behavior equals WASM behavior
- [ ] Profiler gate: every module must show < 2 ms frame time in the Godot Profiler's "Script" row before advancing
- [ ] Input Map: add all six actions (`move_forward`, `move_back`, `move_left`, `move_right`, `interact_lmb`, `interact_e`, `interact_f`, `toggle_debug`) in Project Settings → Input Map if not already present
