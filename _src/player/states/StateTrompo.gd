class_name StateTrompo
extends Node

var _ism: InteractionStateMachine
var _station: TrompoStation = null


func _init_ism(ism: InteractionStateMachine) -> void:
	_ism = ism


func enter() -> void:
	_ism.held_item = &"tortilla"
	_station = _ism.active_station as TrompoStation
	if _station == null:
		printerr("StateTrompo.enter: active_station is not a TrompoStation.")


func exit() -> void:
	_ism.active_station = null
	_station = null


func physics_update(_delta: float) -> void:
	if _station == null:
		_ism.transition_to(&"StateHoldingTortilla")
		return
	# Cancel on focus loss or if player is no longer aiming at THIS trompo.
	var ic: InteractableComponent = _ism.focused_interactable
	if ic == null or ic.station_id != &"trompo":
		_station.reset_count()
		_ism.transition_to(&"StateHoldingTortilla")
		return
	if Input.is_action_just_pressed(&"interact_e"):
		_station._on_press()


func handle_input(_event: InputEvent) -> void:
	pass
