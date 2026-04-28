class_name StateTiming
extends Node

var _ism: InteractionStateMachine
var _station: ToppingStation = null
var _circle_radius: float = 1.0


func _init_ism(ism: InteractionStateMachine) -> void:
	_ism = ism


func enter() -> void:
	_station = _ism.active_station as ToppingStation
	if _station == null:
		printerr("StateTiming.enter: active_station is not a ToppingStation.")
		_ism.transition_to(&"StateHoldingMeat")
		return
	_circle_radius = 1.0
	EventBus.circle_radius_changed.emit(_station.station_id, 1.0)


func exit() -> void:
	# Sentinel -1.0 tells HUD to hide the circle.
	EventBus.circle_radius_changed.emit(&"", -1.0)
	_ism.active_station = null
	_station = null


func physics_update(delta: float) -> void:
	if _ism.focused_interactable == null or _station == null:
		_ism.transition_to(&"StateHoldingMeat")
		return
	_circle_radius -= delta / _station.shrink_duration
	_circle_radius = clampf(_circle_radius, 0.0, 1.0)
	EventBus.circle_radius_changed.emit(_station.station_id, _circle_radius)
	if Input.is_action_just_pressed(&"interact_lmb"):
		_station._evaluate(_circle_radius)
		_ism.transition_to(&"StateHoldingMeat")


func handle_input(_event: InputEvent) -> void:
	pass
