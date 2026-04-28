class_name StateIdle
extends Node

var _ism: InteractionStateMachine


## Injected by InteractionStateMachine._ready(). Do not call this manually.
func _init_ism(ism: InteractionStateMachine) -> void:
	_ism = ism


func enter() -> void:
	pass


func exit() -> void:
	pass


## Primary interaction detection. Input is POLLED here (not in handle_input) to guarantee
## determinism: all interaction decisions happen at the same physics-tick cadence as movement.
func physics_update(_delta: float) -> void:
	var ic: InteractableComponent = _ism.focused_interactable
	if ic == null:
		return

	# Only react to the exact action this station declares.
	if not Input.is_action_just_pressed(ic.required_action):
		return

	if ic.is_locked():
		EventBus.station_locked_attempt.emit(ic.station_id, ic.lock_reason)
		return

	# Trigger the station's handler. The station's interacted signal handler
	# owns the transition — StateIdle does not assume a destination state.
	ic.interact()


## Reserved for emergency/cancel inputs that need event-driven (not polled) response.
## Do NOT duplicate primary interaction detection here — use physics_update() for that.
func handle_input(_event: InputEvent) -> void:
	pass
