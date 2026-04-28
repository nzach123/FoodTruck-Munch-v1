extends GutTest
# Tests TrompoStation press counting and reset logic.
# _on_press() at completion requires an ISM with StateHoldingMeat registered;
# tests that reach completion wire up a minimal ISM to satisfy that dependency.

class _MockState extends Node:
	var _ism: InteractionStateMachine
	func _init_ism(ism: InteractionStateMachine) -> void: _ism = ism
	func enter() -> void: pass
	func exit() -> void: pass
	func physics_update(_d: float) -> void: pass
	func handle_input(_e: InputEvent) -> void: pass


var _station: TrompoStation
var _ic: InteractableComponent
var _ism: InteractionStateMachine
var _taco: TacoBase

const _TACO_SCENE := preload("res://_src/entities/food/TacoBase.tscn")


func before_each() -> void:
	_taco = NodePool.checkout(_TACO_SCENE) as TacoBase
	GameManager.active_taco = _taco

	_ic = InteractableComponent.new()
	_ic.name = "InteractableComponent"
	_ic.station_id = &"trompo"

	_ism = InteractionStateMachine.new()
	var state_holding_meat := _MockState.new()
	state_holding_meat.name = "StateHoldingMeat"
	_ism.add_child(state_holding_meat)
	add_child_autofree(_ism)

	_ic.ism = _ism

	_station = TrompoStation.new()
	_station.add_child(_ic)
	add_child_autofree(_station)


func after_each() -> void:
	if GameManager.active_taco != null:
		NodePool.return_to_pool(GameManager.active_taco)
		GameManager.active_taco = null


func test_required_presses_default() -> void:
	assert_eq(_station.required_presses, 3)


func test_reset_count_zeroes_press_count() -> void:
	# Press once to increment, then reset.
	_station._on_press()
	_station.reset_count()
	# Access _press_count via property — it's a var, GDScript allows external read.
	assert_eq(_station._press_count, 0)


func test_initial_press_count_is_zero() -> void:
	assert_eq(_station._press_count, 0)


func test_first_press_increments_to_one() -> void:
	_station._on_press()
	assert_eq(_station._press_count, 1)


func test_two_presses_increments_to_two() -> void:
	_station._on_press()
	_station._on_press()
	assert_eq(_station._press_count, 2)


func test_third_press_resets_count() -> void:
	_station._on_press()
	_station._on_press()
	_station._on_press()  # Completion press.
	# After required_presses reached, _press_count resets to 0.
	assert_eq(_station._press_count, 0)


func test_third_press_adds_meat_to_taco() -> void:
	_station._on_press()
	_station._on_press()
	_station._on_press()
	assert_true(_taco.ingredients.has(&"meat"))


func test_third_press_emits_order_step_completed() -> void:
	watch_signals(EventBus)
	_station._on_press()
	_station._on_press()
	_station._on_press()
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"meat", 0, 0.75])


func test_partial_press_does_not_add_meat() -> void:
	_station._on_press()
	_station._on_press()
	assert_false(_taco.ingredients.has(&"meat"))


func test_partial_press_does_not_emit_completed() -> void:
	watch_signals(EventBus)
	_station._on_press()
	_station._on_press()
	assert_signal_not_emitted(EventBus, "order_step_completed")


func test_trompo_lock_reason_set() -> void:
	assert_eq(_ic.lock_reason, "Grab a tortilla first")


func test_custom_required_presses_respects_export() -> void:
	var custom_station := TrompoStation.new()
	custom_station.required_presses = 1
	var custom_ic := InteractableComponent.new()
	custom_ic.name = "InteractableComponent"
	custom_ic.ism = _ism
	custom_station.add_child(custom_ic)
	add_child_autofree(custom_station)

	custom_station._on_press()
	assert_eq(custom_station._press_count, 0)  # Reset after 1 press.
	assert_true(_taco.ingredients.has(&"meat"))
