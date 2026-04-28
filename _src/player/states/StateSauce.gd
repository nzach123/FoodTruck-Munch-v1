class_name StateSauce
extends Node

var _ism: InteractionStateMachine
var _station: SauceStation = null
var _gauge: float = 0.0
var _idle_timer: float = 0.0


func _init_ism(ism: InteractionStateMachine) -> void:
	_ism = ism


func enter() -> void:
	_station = _ism.active_station as SauceStation
	if _station == null:
		push_error("StateSauce.enter: active_station is not a SauceStation.")
		_ism.transition_to(&"StateHoldingMeat")
		return
	_gauge = 0.0
	_idle_timer = 0.0


func exit() -> void:
	# 0.0 tells HUD to reset/hide the gauge.
	EventBus.sauce_gauge_changed.emit(&"", 0.0)
	_ism.active_station = null
	_station = null


func physics_update(delta: float) -> void:
	if _station == null:
		_ism.transition_to(&"StateHoldingMeat")
		return
	_idle_timer += delta
	if Input.is_action_just_pressed(&"interact_f"):
		_gauge = clampf(_gauge + _station.tap_increment, 0.0, 1.0)
		_idle_timer = 0.0
		EventBus.sauce_gauge_changed.emit(_station.station_id, _gauge)
	if _idle_timer >= _station.idle_commit_time:
		_station._commit(_gauge)
		_ism.transition_to(&"StateHoldingMeat")


func handle_input(_event: InputEvent) -> void:
	pass
