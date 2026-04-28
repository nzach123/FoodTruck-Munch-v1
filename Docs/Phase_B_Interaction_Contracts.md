# Phase B — Interaction Layer Architecture Contracts

**Module 3 | Midnight Munch | Godot 4.6 / GDScript**

These rules are **mandatory** for all future modules. Violations cascade system-wide.

---

## Component Roles (Hard Boundaries)

| Component | Is | Is Not |
|---|---|---|
| `InteractableComponent` | Identity + gate of a station | Does not run gameplay logic |
| `PromptComponent` | World-space display only | Does not make interaction decisions |
| `InteractionStateMachine` | State traversal controller | Does not know what stations exist |
| `StateIdle` | Input poller + transition initiator | Does not know station types |
| `StateBusy` | Placeholder while station runs | Does not drive station tick logic |
| Station scripts (Module 4+) | Gameplay implementation | Does not call `interact()` on itself |

---

## Strict Rules

### InteractableComponent

- **Never subclass `InteractableComponent`.** Stations are composed WITH it as a child node, not derived from it.
- **`interact()` is called exclusively by `StateIdle.physics_update()`.**  Station scripts never call `interact()` directly — they subscribe to the `interacted` signal and respond.
- **`prerequisite_check` must be injected in the Station's `_ready()`**, not hardcoded inside `InteractableComponent`. The component is generic; conditions are station-specific.
- **`lock_reason` must be set before `is_locked()` can return true.** Set it when you set `prerequisite_check`, so the string is always consistent with the condition.
- **Collision layer must be visible to the Player's `InteractionRaycast`.** The raycast has `collision_mask = 7` and `collide_with_areas = true`. InteractableComponent (Area3D) must be on layer 1, 2, or 3.
- **Do not connect `focused` or `unfocused` from outside the Player.** Only Player's `_update_raycast()` emits these signals. PromptComponent connects passively; nothing else should.

### PromptComponent

- **One `PromptComponent` per station, as a sibling of `InteractableComponent`** under the same parent Station node. Auto-discovery depends on this.
- **Never call `show_prompt()` or `hide_prompt()` from Station scripts.** PromptComponent is exclusively driven by `InteractableComponent.focused` / `unfocused` signals.
- **Set `key_hint` and `locked_hint` in the Inspector, not in code.** They are designer-tunable, not programmer constants.
- **`prompt_label` must reference a child `Label3D` node.** Billboard mode is enforced in `_ready()` — do not override it.
- **Do not cache a reference to `PromptComponent` in any other script.** It is a display sink only.

### InteractionStateMachine

- **`transition_to(state_name)` is the only way to change states.** Never set `_current_state` directly.
- **`state_name` must exactly match the `Node.name` of a registered child state.** Node names are the primary key — do not rename state nodes after wiring.
- **All state nodes must be children of the `InteractionStateMachine` node** in the scene tree. ISM auto-discovers children when the `states` array is empty.
- **`focused_interactable` is set by Player only.** ISM exposes it as a readable property; it is never set from within a state or station.
- **Do not add gameplay logic to ISM.** It routes and traverses — nothing more.

### State Nodes (StateIdle, StateBusy, and all future states)

- **Every state must implement the four-method interface:** `enter()`, `exit()`, `physics_update(delta: float)`, `handle_input(event: InputEvent)`. All may be no-ops, but all must exist.
- **`_init_ism(ism: InteractionStateMachine)` is injected by ISM._ready().**  Do not call it manually. Do not store any other ISM reference.
- **Primary interaction detection lives in `physics_update()` only**, using `Input.is_action_just_pressed()`. Never use `_unhandled_input()` or `handle_input()` for primary action detection — this breaks WASM input determinism.
- **States call `_ism.transition_to()` to change states.** They do not call `enter()` or `exit()` directly, ever.
- **States do not reference other states.** StateIdle does not know StateBusy exists; it only calls `_ism.transition_to(&"StateBusy")`.
- **States do not reference Station scripts.** They call `ic.interact()` generically; the Station script subscribes to the signal.

### Player._update_raycast()

- **`focused` and `unfocused` signals on `InteractableComponent` are emitted exclusively here.** No other script emits them.
- **`_ism.focused_interactable` is set here, once per physics tick.** It is never set inside a state or station.
- **The raycast must have `collide_with_areas = true`** in `TruckInterior.tscn`. Without it, Area3D (InteractableComponent) is invisible to the ray.

---

## Signal Flow Diagram

```
[Player.RayCast3D hits Station.InteractableComponent]
    Player._update_raycast()
        old_ic.unfocused.emit()                     → PromptComponent.hide_prompt()
        new_ic.focused.emit(new_ic)                 → PromptComponent.show_prompt(is_locked)
        _ism.focused_interactable = new_ic

[ISM._physics_process → StateIdle.physics_update()]
    ic = _ism.focused_interactable
    Input.is_action_just_pressed(ic.required_action)
        if locked → EventBus.station_locked_attempt.emit(station_id, lock_reason)
        if unlocked → ic.interact()
                      _ism.transition_to(&"StateBusy")

[ic.interact()]
    ic.interacted.emit(self)                        → Station._on_interacted(ic) [Module 4+]
```

---

## Adding a New State (Module 4+)

1. Create `res://_src/player/states/StateHoldingTortilla.gd` extending `Node`.
2. Implement `_init_ism`, `enter`, `exit`, `physics_update`, `handle_input`.
3. Add the script as a child of the `InteractionStateMachine` node in `TruckInterior.tscn`.
4. Call `_ism.transition_to(&"StateHoldingTortilla")` from the appropriate station handler.
5. Never add ISM, Player, or any station-specific logic to the state file itself.

## Adding a New Station (Module 4+)

1. Create `res://_src/interactables/TortillaStation.gd` extending `Node3D`.
2. In `_ready()`: get the sibling `InteractableComponent`, set `prerequisite_check` and `lock_reason`, connect `interactable.interacted` to your handler.
3. Add an `InteractableComponent` (Area3D) as a child of the station in the scene — set `interaction_type`, `required_action`, `station_id` in the Inspector.
4. Add a `PromptComponent` (Node3D) as a sibling of `InteractableComponent` — set `key_hint`, `locked_hint`, assign the `Label3D` child.
5. Set the `InteractableComponent`'s collision layer to match the raycast mask (layer 1, 2, or 3).
