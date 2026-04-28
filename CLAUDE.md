# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Midnight Munch** — a first-person food truck taco assembly game.
**Engine:** Godot 4.6 | **Language:** GDScript only | **Target:** HTML5/WebGL2 | **Budget:** 60 FPS @ 16.6 ms/frame | **Physics:** Jolt | **Renderer:** GL Compatibility

## Environment

**Godot Executables:**
- **Godot 4.6 (Primary):**
  - GUI: `C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe`
  - Console: `C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- **Godot 4.5.1 (Legacy/Console):**
  - GUI: `C:\00_Godot\z_installer\Godot_v4.5.1-stable_win64.exe`
  - Console: `C:\00_Godot\z_installer\Godot_v4.5.1-stable_win64_console.exe`

## Running & Testing

Godot has no CLI build command for scripting — use the Godot editor directly.

**Run in browser (required for each module gate):**
```
python -m http.server 8080   # serve the export folder after Web export
```
Web export: `Project → Export → Web` in the editor. Never assume native behavior equals WASM behavior.

**Profiler gate:** Every module must show `< 2 ms` on the Godot Profiler "Script" row when run in the browser before the next module begins.

**GUT tests:** The `addons/gut/` plugin is present. Run via the GUT panel in the Godot editor (bottom panel) or headlessly:
```
godot --headless -s addons/gut/gut_cmdln.gd
```

## Architecture

### Autoload Singletons (order matters)
1. `EventBus` — 12 cross-system signals (must load first)
2. `NodePool` — object pooling, eliminates runtime `queue_free()`
3. `GameManager` — day-phase state machine (`DayPhase` enum), active recipe + taco refs
4. `EconomyManager` — balance ledger, save/load

### Hard Invariants

- **`queue_free()` is banned during gameplay.** All runtime objects use `NodePool.checkout()` / `NodePool.return_to_pool()`. Pooled nodes implement `reset()` to clear per-use state.
- **All timing-sensitive logic in `_physics_process`.** Mouse delta is accumulated in `_unhandled_input` and applied + reset each tick. This is mandatory for WASM input determinism.
- **Signal Up, Call Down.** No sibling connections. `EventBus` routes all cross-system communication. Children are called directly; parents are reached via signals only.
- **Every non-autoload script has `class_name`.** Autoload singletons must NOT use `class_name` — their registered autoload name is already the global identifier and adding `class_name` causes a "hides an autoload singleton" error. Every tunable value uses `@export`.
- **No `Tween` for gameplay-consequential animations.** Use `AnimationPlayer` wired in the Inspector.

### Scene Structure

Main level: `_src/levels/TruckInterior.tscn`

Player scene tree paths:
- Camera: `Player/Body/Neck/Head/Eyes/Camera`
- Pitch rotation: `Player/Body/Neck`
- Interaction raycast: `Player/Body/Neck/Head/Eyes/Camera/InteractionRaycast` (3 m reach, `collide_with_areas = true`)
- Hand anchor: `%CarryablePosition` (Marker3D, unique name) — TacoBase reparents here on checkout
- Wieldables parent: `%Wieldables` (Node3D, unique name) — parent node for held items
- ISM: `Player/InteractionStateMachine` (children: see ISM State Inventory below)

### Interaction System (Phase B — complete)

The interaction layer is **composition-based**, not inheritance-based.

| Script | Role |
|---|---|
| `InteractableComponent` (Area3D) | Identity + gate of a station. Never subclassed. |
| `PromptComponent` (Node3D) | World-space billboard display only. Never driven by station scripts. |
| `InteractionStateMachine` | State traversal only. Does not know what stations exist. |
| `StateIdle` | Polls input in `physics_update()`, calls `ic.interact()`. Station owns the transition. |
| `StateBusy` | **Vestigial — nothing transitions here.** Warns on `enter()` if accidentally reached. |
| Station scripts (Module 4+) | Gameplay logic. Subscribe to `InteractableComponent.interacted` signal. |

**ISM properties (set at runtime — do not hardcode in station scripts):**
- `focused_interactable: InteractableComponent` — set by Player each physics tick
- `held_item: StringName` — set by holding states in `enter()`/`exit()`. Use this in `prerequisite_check` instead of comparing state name strings.
- `active_station: Node` — set by the station **before** calling `transition_to()`; read by reusable states (`StateTiming`, `StateSauce`, `StateTrompo`) in `enter()`

**InteractableComponent properties:**
- `ism: InteractionStateMachine` — injected by Player on first raycast hit. Read by stations in `prerequisite_check` to access `ism.held_item`.

**ISM State Inventory (Phase C):**

| State | `held_item` | Purpose |
|---|---|---|
| `StateIdle` | `&""` | No item held; dispatches to station via `ic.interact()` |
| `StateHoldingTortilla` | `&"tortilla"` | Tortilla grabbed; only Trompo unlocked |
| `StateTrompo` | `&"tortilla"` | Mid-trompo; owns press counter 1–3; cancels on focus loss |
| `StateHoldingMeat` | `&"meat"` | Covers entire toppings + sauces phase; data-driven gating handles unlocks |
| `StateTiming` | `&"meat"` | Reusable shrinking-circle state; reads config from `active_station`; returns to `StateHoldingMeat` |
| `StateSauce` | `&"meat"` | Reusable tap-accumulate state; reads config from `active_station`; returns to `StateHoldingMeat` |
| `StateBellModal` | `&"meat"` | Modal open; sets `Input.MOUSE_MODE_VISIBLE`; all input frozen; restored on exit |

**Assembly sequence (authoritative — GDD §2.1):**
Tortilla → Meat (3 presses) → Toppings (any order) → Sauces (any order) → Bell

`SauceStation.prerequisite_check` is **data-driven**: reads `GameManager.active_taco.ingredients` vs `GameManager.active_recipe.required_ingredients` — no ISM state name strings.

**Signal flow:**
```
Player._update_raycast()
    old_ic.unfocused.emit()          → PromptComponent.hide_prompt()
    new_ic.focused.emit(new_ic)      → PromptComponent.show_prompt(is_locked)
    new_ic.ism = _ism                ← Player injects ISM reference on first hit
    _ism.focused_interactable = new_ic

ISM._physics_process → CurrentState.physics_update()
    [StateIdle]: Input.is_action_just_pressed(ic.required_action)
        if locked → EventBus.station_locked_attempt.emit(station_id, lock_reason)
        if unlocked → ic.interact() → ic.interacted.emit(self)
                      [station handler]: _ism.active_station = self
                                         _ism.transition_to(&"StateXxx")
```

**Adding a new state (Module 4+):**
1. Create `_src/player/states/StateXxx.gd extends Node`.
2. Implement `_init_ism`, `enter`, `exit`, `physics_update(delta)`, `handle_input(event)` — all five must exist even as no-ops.
3. Set `_ism.held_item` in `enter()` and clear it in `exit()`.
4. Add the node as a child of `InteractionStateMachine` in the scene.
5. Call `_ism.transition_to(&"StateXxx")` from the station; never call `enter()`/`exit()` directly.

**Adding a new station (Module 4+):**
1. Create `_src/interactables/XxxStation.gd extends Node3D`.
2. In `_ready()`: get sibling `InteractableComponent` via `$InteractableComponent`, inject `prerequisite_check` and `lock_reason`.
3. Connect `interactable.interacted` to handler. In handler: set `interactable.ism.active_station = self`, call `interactable.ism.transition_to(&"StateXxx")`.
4. `InteractableComponent` (Area3D) must be on **collision_layer = 2** (within raycast mask 7). Set in Inspector.
5. Add `PromptComponent` as sibling — set `key_hint`, `locked_hint` in Inspector only.

**Editor prerequisites before any Phase C script can be attached:**
- `InteractableComponent` added to all 8 station scenes (collision_layer = 2)
- `BasicInteraction` placeholder nodes deleted from all station scenes
- `PromptComponent` added to all 8 station scenes
- All IC exports wired in Inspector (interaction_type, required_action, station_id)
- ISM script attached + `StateIdle`, `StateBusy` children added in scene

### Data Layer

- `_src/data/Recipe.gd` — `Resource` with `required_ingredients`, `optional_ingredients`, `base_sale_price`, `food_cost`
- `_src/data/IngredientDef.gd` — `Resource` with `ingredient_id`, `cost`, `InteractionType` enum
- `_src/entities/food/TacoBase.gd` — poolable node; tracks `ingredients` array and `sloppy_flags`
- `_src/entities/food/ToppingItem.gd` — minimal poolable node with `reset()`

**GameManager runtime refs (set during gameplay):**
- `active_recipe: Recipe` — defaults to `@export var default_recipe` (wire `TacoAlPastor.tres` in Inspector); overridden by `EventBus.order_accepted` in Module 7
- `active_taco: TacoBase` — set by TortillaStation on checkout, cleared by BellStation on order complete

**Pool-specific reset patterns:**
- `TacoBase.reset()` — clears `ingredients`, zeros `sloppy_flags`, zeros transform
- `MeatFragment` — use `MeshInstance3D` + `AnimationPlayer` (not GPUParticles3D). `reset()` stops animation, zeros transform.
- `DroppedTopping` (`RigidBody3D`) — `reset()` must: `freeze = true` → zero position/rotation/velocity → pool returns it. On checkout: position at station, `freeze = false`, apply `apply_central_impulse()`.
- `NodePool.return_to_pool()` calls `node.reparent(self)` before `reset()` — restores pool ownership for nodes that were reparented (e.g. TacoBase under `%Wieldables`).

### Input Actions (defined in project.godot)

`move_forward`, `move_back`, `move_left`, `move_right`, `interact_lmb`, `interact_e`, `interact_f`, `toggle_debug`

### Debug Overlay

`_src/ui/DebugOverlay.gd` — F3-toggled, gated behind `OS.is_debug_build()`. Displays current ISM state, held item, last quality flag, FPS, pool stats. Poll ISM via `get_parent()` in `_refresh_ism_state()`.

## Implementation Phases

| Phase | Status | Scope |
|---|---|---|
| A — Foundation (Modules 1–2) | Complete | Autoloads, NodePool, Player, DebugOverlay |
| B — Interaction Layer (Module 3) | Complete | InteractableComponent, PromptComponent, ISM |
| C — Assembly Line (Modules 4–5) | **Next** | Station scripts (Tortilla → Trompo → Sauces → Toppings) |
| D — Pipeline & Economy (Module 6) | Pending | Bell validator, HUD pills, EconomyManager wiring |
| E — NPCs & Queue (Module 7) | Pending | Navigation, patience, pool-based spawn/despawn |

The detailed task list and per-module verification gates are in `Docs/Midnight_Munch_Implementation_Plan.md`. Interaction layer contracts (strict rules on component boundaries) are in `Docs/Phase_B_Interaction_Contracts.md`.

## NodePool Contract

Every pooled scene must:
- Implement `func reset() -> void` (called automatically by `return_to_pool`)
- Be prewarmed in `NodePool._ready()` via `prewarm(scene, count)`
- Never be `queue_free()`d — always `NodePool.return_to_pool(node)`

`NodePool` tags each checked-out node with `_pool_scene` metadata for O(1) reverse-lookup. A `push_warning` fires on runtime instantiation (prewarm count too low) and on returning non-pooled nodes.

`return_to_pool()` calls `node.reparent(self)` before `reset()` — safe to call on nodes that were reparented during gameplay (e.g. TacoBase moved under `%Wieldables`).
