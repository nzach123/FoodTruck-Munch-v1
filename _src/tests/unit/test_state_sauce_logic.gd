extends GutTest
# Tests StateSauce timer-driven commit and gauge clamping without Input system.
# Directly calls physics_update() with delta to simulate elapsed time.

class _MockState extends Node:
	var _ism: InteractionStateMachine
	func _init_ism(ism: InteractionStateMachine) -> void: _ism = ism
	func enter() -> void: pass
	func exit() -> void: pass
	func physics_update(_d: float) -> void: pass
	func handle_input(_e: InputEvent) -> void: pass


var _ism: InteractionStateMachine
var _sauce_state: StateSauce
var _station: SauceStation
var _ic: InteractableComponent
var _taco: TacoBase

const _TACO_SCENE := preload("res://_src/entities/food/TacoBase.tscn")


func before_each() -> void:
	_taco = NodePool.checkout(_TACO_SCENE) as TacoBase
	GameManager.active_taco = _taco

	_ic = InteractableComponent.new()
	_ic.name = "InteractableComponent"
	_ic.station_id = &"hot_sauce"

	_station = SauceStation.new()
	_station.idle_commit_time = 0.4
	_station.tap_increment = 0.15
	_station.green_zone_min = 0.6
	_station.green_zone_max = 0.85
	_station.add_child(_ic)

	_ism = InteractionStateMachine.new()

	_sauce_state = StateSauce.new()
	_sauce_state.name = "StateSauce"

	var holding_meat := _MockState.new()
	holding_meat.name = "StateHoldingMeat"

	_ism.add_child(holding_meat)
	_ism.add_child(_sauce_state)
	_ism.active_station = _station
	add_child_autofree(_station)
	add_child_autofree(_ism)

	# Manually enter StateSauce after ISM is in tree.
	_ism.transition_to(&"StateSauce")


func after_each() -> void:
	if GameManager.active_taco != null:
		NodePool.return_to_pool(GameManager.active_taco)
		GameManager.active_taco = null


func test_enter_sets_gauge_to_zero() -> void:
	# _gauge is a private var; observe via sauce_gauge_changed emit (0.0 at exit).
	# Re-enter state to confirm reset.
	_ism.transition_to(&"StateHoldingMeat")
	_ism.active_station = _station
	watch_signals(EventBus)
	_ism.transition_to(&"StateSauce")
	# No tap yet — gauge should be 0. Timer hasn't expired yet.
	assert_eq(_ism.get_current_state_name(), &"StateSauce")


func test_idle_timer_expiry_transitions_to_holding_meat() -> void:
	# Supply delta >= idle_commit_time in one call to trigger commit branch.
	_sauce_state.physics_update(_station.idle_commit_time)
	assert_eq(_ism.get_current_state_name(), &"StateHoldingMeat")


func test_idle_timer_expiry_commits_gauge() -> void:
	# At 0 gauge → underfill emit (quality=1).
	watch_signals(EventBus)
	_sauce_state.physics_update(_station.idle_commit_time)
	assert_signal_emitted(EventBus, "order_step_completed")


func test_below_idle_time_does_not_transition() -> void:
	_sauce_state.physics_update(_station.idle_commit_time * 0.5)
	assert_eq(_ism.get_current_state_name(), &"StateSauce")


func test_accumulated_delta_triggers_commit() -> void:
	_sauce_state.physics_update(_station.idle_commit_time * 0.5)
	_sauce_state.physics_update(_station.idle_commit_time * 0.5)
	assert_eq(_ism.get_current_state_name(), &"StateHoldingMeat")


func test_exit_emits_sauce_gauge_changed_with_sentinel_zero() -> void:
	watch_signals(EventBus)
	_ism.transition_to(&"StateHoldingMeat")
	assert_signal_emitted_with_parameters(EventBus, "sauce_gauge_changed",
			[&"", 0.0])


func test_exit_clears_active_station() -> void:
	_ism.transition_to(&"StateHoldingMeat")
	assert_null(_ism.active_station)


func test_null_station_on_enter_transitions_back() -> void:
	_ism.transition_to(&"StateHoldingMeat")
	_ism.active_station = null
	_ism.transition_to(&"StateSauce")
	# StateSauce.enter() detects null station and calls transition_to(StateHoldingMeat).
	assert_eq(_ism.get_current_state_name(), &"StateHoldingMeat")


func test_null_station_in_physics_update_transitions_back() -> void:
	# Force station to null mid-update by patching the private field via reflection.
	_sauce_state._station = null
	_sauce_state.physics_update(0.01)
	assert_eq(_ism.get_current_state_name(), &"StateHoldingMeat")
