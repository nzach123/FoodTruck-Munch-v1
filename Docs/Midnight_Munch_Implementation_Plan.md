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

**EDITOR PREREQUISITES (must be done before scripting):**
- [ ] Add `InteractableComponent` (Area3D, collision_layer=2, collision_mask=0) to all 8 station scenes
- [ ] Delete `BasicInteraction` placeholder Node from all station scenes
- [ ] Add `PromptComponent` (Node3D) as sibling to each IC; wire `key_hint` + `locked_hint` in Inspector
- [ ] Wire all IC exports per station (see table in CLAUDE.md)
- [ ] Attach `InteractionStateMachine.gd` to ISM node in scene; add `StateIdle` + `StateBusy` as children

**TacoBase Pool**
- [ ] Verify `TacoBase.tscn` exists with `MeshInstance3D` (placeholder tortilla) and `TacoBase.gd`
- [ ] In `NodePool._ready()`, call `prewarm(TacoBase_scene, 3)` — max 3 concurrent tacos
- [ ] Wire `GameManager.default_recipe` to `TacoAlPastor.tres` in Inspector

**State: StateHoldingTortilla**
- [ ] Create `res://_src/player/states/StateHoldingTortilla.gd` as `class_name StateHoldingTortilla extends Node`
- [ ] `enter()`: `_ism.held_item = &"tortilla"`
- [ ] `exit()`: `_ism.held_item = &""`
- [ ] `physics_update` / `handle_input`: no-ops

**Tortilla Station — INSTANT**
- [ ] Create `res://_src/interactables/TortillaStation.gd` as `class_name TortillaStation extends Node3D`
- [ ] `@export var hand_marker: NodePath` — wire to `%CarryablePosition` in Inspector
- [ ] In `_ready()`: cache `_ic := $InteractableComponent`; cache `_hand := get_node(hand_marker) as Marker3D`; inject `prerequisite_check = func() -> bool: return GameManager.active_taco != null`; connect `_ic.interacted` to `_on_interacted`
- [ ] `_on_interacted()`: checkout `TacoBase` from pool; `reparent(%Wieldables)`; snap to `%CarryablePosition.global_position`; set `GameManager.active_taco`; emit `EventBus.order_step_completed(&"tortilla", 0, 0.25)`; set `_ic.ism.active_station = null`; call `_ic.ism.transition_to(&"StateHoldingTortilla")`

**State: StateTrompo**
- [ ] Create `res://_src/player/states/StateTrompo.gd` as `class_name StateTrompo extends Node`
- [ ] `enter()`: `_ism.held_item = &"tortilla"`; cast `_ism.active_station` to `TrompoStation`
- [ ] `exit()`: `_ism.active_station = null`
- [ ] `physics_update(delta)`: if `_ism.focused_interactable == null` → reset station press count → `_ism.transition_to(&"StateHoldingTortilla")`; else poll `Input.is_action_just_pressed(&"interact_e")` → call `active_station._on_press()`

**Trompo (Meat) Station — DISCRETE\_COUNTER**
- [ ] Create `res://_src/interactables/TrompoStation.gd` as `class_name TrompoStation extends Node3D`
- [ ] `@export var required_presses: int = 3`; `@export var animation_player: AnimationPlayer`
- [ ] `prerequisite_check`: `func() -> bool: return _ic.ism.held_item != &"tortilla"`
- [ ] `_on_interacted()`: set `_ic.ism.active_station = self`; call `_ic.ism.transition_to(&"StateTrompo")`
- [ ] `func _on_press()`: increment `_press_count`; play `"meat_spin_%dx" % _press_count`; spawn pooled `MeatFragment` (×press_count); on third press: `GameManager.active_taco.add_ingredient(&"meat")`; emit `EventBus.order_step_completed(&"meat", 0, 0.75)`; `_ic.ism.transition_to(&"StateHoldingMeat")`
- [ ] `func reset_count()`: `_press_count = 0` — called by `StateTrompo` on focus loss cancel
- [ ] Create `res://_src/entities/MeatFragment.tscn` — `MeshInstance3D` + `AnimationPlayer`; `reset()` stops animation, zeros transform
- [ ] Create `"meat_spin_1x"`, `"meat_spin_2x"`, `"meat_spin_3x"` animations in Trompo's `AnimationPlayer`
- [ ] **Verification:** Attempt Trompo without tortilla; confirm `station_locked_attempt` in Debug Overlay. Walk away mid-sequence; confirm press count resets. Complete 3 presses; confirm `StateHoldingMeat` active.

---

### Module 5 — Dynamic Interaction (Front Counter)

**State: StateHoldingMeat**
- [ ] Create `res://_src/player/states/StateHoldingMeat.gd` as `class_name StateHoldingMeat extends Node`
- [ ] `enter()`: `_ism.held_item = &"meat"`
- [ ] `exit()`: `_ism.held_item = &""`
- [ ] `physics_update` / `handle_input`: no-ops (stations drive their own transitions)

**State: StateTiming (reusable — all 3 topping stations)**
- [ ] Create `res://_src/player/states/StateTiming.gd` as `class_name StateTiming extends Node`
- [ ] `enter()`: cast `_ism.active_station` to `ToppingStation`; `_circle_radius = 1.0`; emit `EventBus.circle_radius_changed(station.station_id, 1.0)`
- [ ] `exit()`: emit `EventBus.circle_radius_changed(&"", -1.0)` (sentinel — HUD hides circle); `_ism.active_station = null`
- [ ] `physics_update(delta)`: if `_ism.focused_interactable == null` → `_ism.transition_to(&"StateHoldingMeat")`; else shrink: `_circle_radius -= delta / station.shrink_duration`; clamp to 0; emit `EventBus.circle_radius_changed(station.station_id, _circle_radius)`; poll `Input.is_action_just_pressed(&"interact_lmb")` → call `station._evaluate(_circle_radius)` → `_ism.transition_to(&"StateHoldingMeat")`

**State: StateSauce (reusable — both sauce stations)**
- [ ] Create `res://_src/player/states/StateSauce.gd` as `class_name StateSauce extends Node`
- [ ] `enter()`: cast `_ism.active_station` to `SauceStation`; `_gauge = 0.0`; `_idle_timer = 0.0`
- [ ] `exit()`: emit `EventBus.sauce_gauge_changed(&"", 0.0)` (reset); `_ism.active_station = null`
- [ ] `physics_update(delta)`: poll `Input.is_action_just_pressed(&"interact_f")` → increment gauge → emit `EventBus.sauce_gauge_changed`; accumulate idle timer; on `idle_timer >= station.idle_commit_time` → call `station._commit(_gauge)` → `_ism.transition_to(&"StateHoldingMeat")`

**Sauce Stations — TAP\_ACCUMULATE**
- [ ] Create `res://_src/interactables/SauceStation.gd` as `class_name SauceStation extends Node3D` (reused by WhiteSauce + RedSauce)
- [ ] `@export var green_zone_min: float = 0.6`, `@export var green_zone_max: float = 0.85`, `@export var idle_commit_time: float = 0.4`
- [ ] `@export var overfill_particles: GPUParticles3D`
- [ ] `prerequisite_check` (data-driven): checks `GameManager.active_taco != null` AND all required toppings from `GameManager.active_recipe.required_ingredients` are in `active_taco.ingredients`
- [ ] `_on_interacted()`: set `_ic.ism.active_station = self`; `_ic.ism.transition_to(&"StateSauce")`
- [ ] `func _commit(gauge: float)`: evaluate quality; on overfill enable particles for 1.0s (AnimationPlayer, not Tween); emit `EventBus.order_step_completed(station_id, quality, 0.0)` (0.0 food_cost — tip loss only); if perfect: `GameManager.active_taco.add_ingredient(station_id)`

**Topping Stations — TIMING (Shrinking Circle)**
- [ ] Create `res://_src/interactables/ToppingStation.gd` as `class_name ToppingStation extends Node3D` (reused by Cilantro, Tomato, Onion)
- [ ] `@export var shrink_duration: float = 1.8`, `@export var target_band_min: float = 0.3`, `@export var target_band_max: float = 0.55`
- [ ] `@export var ingredient_id: StringName`, `@export var ingredient_cost: float = 0.10`
- [ ] `prerequisite_check`: `GameManager.active_taco != null` AND `active_taco.ingredients.has(&"meat")`
- [ ] `_on_interacted()`: set `_ic.ism.active_station = self`; `_ic.ism.transition_to(&"StateTiming")`
- [ ] `func _evaluate(radius: float)`: if within band → quality 0, `active_taco.add_ingredient(ingredient_id)`, emit `order_step_completed(ingredient_id, 0, 0.0)`; else → quality 1, `active_taco.sloppy_flags += 1`, spawn `DroppedTopping` from pool with `apply_central_impulse()`, emit `order_step_completed(ingredient_id, 1, ingredient_cost)`
- [ ] Create `res://_src/entities/DroppedTopping.tscn` — pooled `RigidBody3D` + `MeshInstance3D`; `reset()`: `freeze = true` → zero position/rotation/linear_velocity/angular_velocity (freeze must precede zeroing in Jolt)
- [ ] **Verification:** Perfect hit → `quality=0`, ingredient in taco. Miss → `RigidBody3D` on floor, `quality=1`, `food_cost=0.10` in signal. Step away mid-circle → circle hides (sentinel -1.0 emitted), returns to `StateHoldingMeat`.

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
