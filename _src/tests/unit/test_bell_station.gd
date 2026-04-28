extends GutTest
# Tests BellStation._complete_order() tip calculation and payment logic.
# Uses NodePool autoload to checkout a real TacoBase (so return_to_pool works).
# Uses a minimal ISM with StateIdle so transition_to() in _complete_order() succeeds.

class _MockState extends Node:
	var _ism: InteractionStateMachine
	func _init_ism(ism: InteractionStateMachine) -> void: _ism = ism
	func enter() -> void: pass
	func exit() -> void: pass
	func physics_update(_d: float) -> void: pass
	func handle_input(_e: InputEvent) -> void: pass


var _station: BellStation
var _ic: InteractableComponent
var _ism: InteractionStateMachine
var _taco: TacoBase
var _taco_consumed: bool = false

const _TACO_SCENE := preload("res://_src/entities/food/TacoBase.tscn")


func before_each() -> void:
	_taco_consumed = false
	_taco = NodePool.checkout(_TACO_SCENE) as TacoBase
	GameManager.active_taco = _taco

	_ism = InteractionStateMachine.new()
	var state_idle := _MockState.new()
	state_idle.name = "StateIdle"
	_ism.add_child(state_idle)
	add_child_autofree(_ism)

	_ic = InteractableComponent.new()
	_ic.name = "InteractableComponent"
	_ic.ism = _ism

	_station = BellStation.new()
	_station.add_child(_ic)
	add_child_autofree(_station)


func after_each() -> void:
	if not _taco_consumed and GameManager.active_taco != null:
		NodePool.return_to_pool(GameManager.active_taco)
	GameManager.active_taco = null
	GameManager.active_recipe = null


func test_complete_order_null_taco_does_not_emit() -> void:
	GameManager.active_taco = null
	watch_signals(EventBus)
	_station._complete_order()
	assert_signal_not_emitted(EventBus, "order_completed")


func test_complete_order_zero_sloppy_flags_tip_one() -> void:
	_taco.sloppy_flags = 0
	var received: Array = []
	EventBus.order_completed.connect(func(p: float, t: float) -> void:
		received.append(t), CONNECT_ONE_SHOT)
	_station._complete_order()
	_taco_consumed = true
	assert_eq(received[0], 1.0)


func test_complete_order_one_sloppy_flag_tip_half() -> void:
	_taco.sloppy_flags = 1
	var received: Array = []
	EventBus.order_completed.connect(func(p: float, t: float) -> void:
		received.append(t), CONNECT_ONE_SHOT)
	_station._complete_order()
	_taco_consumed = true
	assert_eq(received[0], 0.5)


func test_complete_order_two_sloppy_flags_tip_zero() -> void:
	_taco.sloppy_flags = 2
	var received: Array = []
	EventBus.order_completed.connect(func(p: float, t: float) -> void:
		received.append(t), CONNECT_ONE_SHOT)
	_station._complete_order()
	_taco_consumed = true
	assert_eq(received[0], 0.0)


func test_complete_order_many_sloppy_flags_tip_zero() -> void:
	_taco.sloppy_flags = 5
	var received: Array = []
	EventBus.order_completed.connect(func(p: float, t: float) -> void:
		received.append(t), CONNECT_ONE_SHOT)
	_station._complete_order()
	_taco_consumed = true
	assert_eq(received[0], 0.0)


func test_complete_order_uses_recipe_sale_price() -> void:
	var recipe := Recipe.new()
	recipe.base_sale_price = 4.75
	GameManager.active_recipe = recipe
	var received: Array = []
	EventBus.order_completed.connect(func(p: float, t: float) -> void:
		received.append(p), CONNECT_ONE_SHOT)
	_station._complete_order()
	_taco_consumed = true
	assert_eq(received[0], 4.75)


func test_complete_order_no_recipe_uses_default_price() -> void:
	GameManager.active_recipe = null
	var received: Array = []
	EventBus.order_completed.connect(func(p: float, t: float) -> void:
		received.append(p), CONNECT_ONE_SHOT)
	_station._complete_order()
	_taco_consumed = true
	assert_eq(received[0], 3.50)


func test_complete_order_clears_active_taco() -> void:
	_station._complete_order()
	_taco_consumed = true
	assert_null(GameManager.active_taco)


func test_complete_order_resets_ism_held_item() -> void:
	_ism.held_item = &"meat"
	_station._complete_order()
	_taco_consumed = true
	assert_eq(_ism.held_item, &"")


func test_complete_order_transitions_ism_to_idle() -> void:
	_station._complete_order()
	_taco_consumed = true
	assert_eq(_ism.get_current_state_name(), &"StateIdle")


func test_on_interacted_no_missing_ingredients_calls_complete() -> void:
	var recipe := Recipe.new()
	recipe.required_ingredients = [&"meat"]
	GameManager.active_recipe = recipe
	_taco.add_ingredient(&"meat")
	# No modal_scene set — if missing, _complete_order is called anyway.
	# Without missing items, _complete_order fires directly.
	watch_signals(EventBus)
	_station._on_interacted(_ic)
	_taco_consumed = true
	assert_signal_emitted(EventBus, "order_completed")


func test_on_interacted_missing_ingredients_no_complete_without_modal() -> void:
	var recipe := Recipe.new()
	recipe.required_ingredients = [&"meat", &"cilantro"]
	GameManager.active_recipe = recipe
	# Taco has no ingredients — both are missing.
	# modal_scene is null → falls back to _complete_order().
	watch_signals(EventBus)
	_station._on_interacted(_ic)
	_taco_consumed = true
	# Fallback: _complete_order fires because modal_scene == null.
	assert_signal_emitted(EventBus, "order_completed")


func test_bell_lock_reason_set() -> void:
	assert_eq(_ic.lock_reason, "Nothing to serve")
