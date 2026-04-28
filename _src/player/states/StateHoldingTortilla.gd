class_name StateHoldingTortilla
extends Node

var _ism: InteractionStateMachine


func _init_ism(ism: InteractionStateMachine) -> void:
	_ism = ism


func enter() -> void:
	_ism.held_item = &"tortilla"


func exit() -> void:
	_ism.held_item = &""


## Same dispatch loop as StateIdle. held_item = "tortilla" gates which stations
## are unlocked (only TrompoStation's prerequisite_check passes at this point).
func physics_update(_delta: float) -> void:
	var ic: InteractableComponent = _ism.focused_interactable
	if ic == null:
		return
	if not Input.is_action_just_pressed(ic.required_action):
		return
	if ic.is_locked():
		EventBus.station_locked_attempt.emit(ic.station_id, ic.lock_reason)
		return
	ic.interact()


func handle_input(_event: InputEvent) -> void:
	pass
