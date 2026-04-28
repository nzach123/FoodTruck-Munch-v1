class_name InteractableComponent
extends Area3D

## Declares the mechanic type for StateIdle and future station scaffolding.
enum InteractionType { INSTANT, DISCRETE_COUNTER, TAP_ACCUMULATE, TIMING }

## What mechanic category this station uses. Read by StateIdle and station scripts.
@export var interaction_type: InteractionType = InteractionType.INSTANT
## The input action StringName that activates this station (e.g. &"interact_e").
## StateIdle calls Input.is_action_just_pressed(required_action) each physics tick.
@export var required_action: StringName
## Unique station identifier routed through EventBus signals.
@export var station_id: StringName
## Human-readable lock message. Populated by the Station script; read by PromptComponent.
@export var lock_reason: String = ""

## Injected by the Station's _ready() to define prerequisite conditions.
## Signature must be: func() -> bool
## Leave unconfigured (Callable()) for always-unlocked stations (e.g. TortillaStation).
var prerequisite_check: Callable = Callable()

## Emitted by Player._update_raycast() when the interaction raycast enters this Area3D.
## Argument is self so subscribers don't need a stored reference.
signal focused(component: InteractableComponent)
## Emitted by Player._update_raycast() when the raycast leaves this Area3D.
signal unfocused()
## Emitted by interact(). Station scripts connect to this to run their logic.
## StateIdle is the ONLY caller of interact() — stations never call it directly.
signal interacted(component: InteractableComponent)


## Returns true if this station's prerequisites are not currently met.
## Delegates entirely to prerequisite_check; default (no callable) is always false.
func is_locked() -> bool:
	if prerequisite_check.is_valid():
		return prerequisite_check.call()
	return false


## Called exclusively by StateIdle on a valid, unlocked input press.
## Emits interacted — the Station's handler fires from that signal.
func interact() -> void:
	interacted.emit(self)
