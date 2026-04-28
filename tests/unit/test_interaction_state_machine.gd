extends GutTest

# Minimal stub state — satisfies ISM's expected interface without game logic.
class _MockState extends Node:
	var entered := false
	var exited := false
	var enter_count := 0
	var exit_count := 0
	var _ism: InteractionStateMachine

	func _init_ism(ism: InteractionStateMachine) -> void:
		_ism = ism

	func enter() -> void:
		entered = true
		enter_count += 1

	func exit() -> void:
		exited = true
		exit_count += 1

	func physics_update(_delta: float) -> void:
		pass

	func handle_input(_event: InputEvent) -> void:
		pass


var _ism: InteractionStateMachine
var _state_a: _MockState
var _state_b: _MockState


func before_each() -> void:
	_ism = InteractionStateMachine.new()
	_state_a = _MockState.new()
	_state_a.name = "StateA"
	_state_b = _MockState.new()
	_state_b.name = "StateB"
	_ism.add_child(_state_a)
	_ism.add_child(_state_b)
	add_child_autofree(_ism)


func test_initial_state_is_first_child() -> void:
	assert_eq(_ism.get_current_state_name(), &"StateA")


func test_initial_state_enter_called() -> void:
	assert_true(_state_a.entered)


func test_transition_to_valid_state_changes_current() -> void:
	_ism.transition_to(&"StateB")
	assert_eq(_ism.get_current_state_name(), &"StateB")


func test_transition_to_calls_exit_on_old_state() -> void:
	_ism.transition_to(&"StateB")
	assert_true(_state_a.exited)


func test_transition_to_calls_enter_on_new_state() -> void:
	_ism.transition_to(&"StateB")
	assert_true(_state_b.entered)


func test_transition_same_state_is_noop() -> void:
	_state_a.exit_count = 0
	_state_a.enter_count = 1  # Reset from initial enter.
	_ism.transition_to(&"StateA")
	assert_eq(_state_a.exit_count, 0)
	assert_eq(_state_a.enter_count, 1)


func test_transition_invalid_name_does_not_crash() -> void:
	# Must not throw — only push_error.
	_ism.transition_to(&"DoesNotExist")
	assert_eq(_ism.get_current_state_name(), &"StateA")


func test_transition_invalid_name_state_unchanged() -> void:
	_ism.transition_to(&"DoesNotExist")
	assert_eq(_ism.get_current_state_name(), &"StateA")


func test_transition_back_and_forth() -> void:
	_ism.transition_to(&"StateB")
	_ism.transition_to(&"StateA")
	assert_eq(_ism.get_current_state_name(), &"StateA")


func test_held_item_default_empty() -> void:
	assert_eq(_ism.held_item, &"")


func test_held_item_settable() -> void:
	_ism.held_item = &"tortilla"
	assert_eq(_ism.held_item, &"tortilla")


func test_focused_interactable_default_null() -> void:
	assert_null(_ism.focused_interactable)


func test_active_station_default_null() -> void:
	assert_null(_ism.active_station)


func test_wieldables_node_default_null() -> void:
	assert_null(_ism.wieldables_node)


func test_hand_anchor_default_null() -> void:
	assert_null(_ism.hand_anchor)


func test_state_map_populated_for_both_states() -> void:
	# Transition to each state to verify map has both entries.
	_ism.transition_to(&"StateB")
	assert_eq(_ism.get_current_state_name(), &"StateB")
	_ism.transition_to(&"StateA")
	assert_eq(_ism.get_current_state_name(), &"StateA")


func test_init_ism_called_on_child_states() -> void:
	# _ism reference is injected into each state's _ism field.
	assert_eq(_state_a._ism, _ism)
	assert_eq(_state_b._ism, _ism)


func test_get_current_state_name_returns_string_name() -> void:
	var name := _ism.get_current_state_name()
	assert_true(name is StringName)
