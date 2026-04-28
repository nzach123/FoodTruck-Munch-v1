extends GutTest
# Tests ToppingStation._evaluate() hit/miss logic.
# Miss path checks out a DroppedTopping from the GLOBAL NodePool autoload (prewarmed),
# so pool state may change; DroppedTopping lifetime timer returns it automatically.

var _station: ToppingStation
var _ic: InteractableComponent
var _taco: TacoBase

const _TACO_SCENE := preload("res://_src/entities/food/TacoBase.tscn")


func before_each() -> void:
	_taco = NodePool.checkout(_TACO_SCENE) as TacoBase
	GameManager.active_taco = _taco

	_ic = InteractableComponent.new()
	_ic.name = "InteractableComponent"
	_ic.station_id = &"cilantro_station"

	_station = ToppingStation.new()
	_station.ingredient_id = &"cilantro"
	_station.add_child(_ic)
	add_child_autofree(_station)


func after_each() -> void:
	if GameManager.active_taco != null:
		NodePool.return_to_pool(GameManager.active_taco)
		GameManager.active_taco = null


func test_evaluate_null_taco_does_not_emit() -> void:
	GameManager.active_taco = null
	watch_signals(EventBus)
	_station._evaluate(0.4)
	assert_signal_not_emitted(EventBus, "order_step_completed")


func test_evaluate_hit_adds_ingredient() -> void:
	var mid := (_station.target_band_min + _station.target_band_max) * 0.5
	_station._evaluate(mid)
	assert_true(_taco.ingredients.has(&"cilantro"))


func test_evaluate_hit_emits_quality_zero() -> void:
	var mid := (_station.target_band_min + _station.target_band_max) * 0.5
	watch_signals(EventBus)
	_station._evaluate(mid)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"cilantro", 0, 0.0])


func test_evaluate_at_min_boundary_is_hit() -> void:
	_station._evaluate(_station.target_band_min)
	assert_true(_taco.ingredients.has(&"cilantro"))


func test_evaluate_at_max_boundary_is_hit() -> void:
	_station._evaluate(_station.target_band_max)
	assert_true(_taco.ingredients.has(&"cilantro"))


func test_evaluate_miss_above_band_does_not_add_ingredient() -> void:
	_station._evaluate(1.0)  # Above default max 0.55.
	assert_false(_taco.ingredients.has(&"cilantro"))


func test_evaluate_miss_above_band_increments_sloppy_flags() -> void:
	_station._evaluate(1.0)
	assert_eq(_taco.sloppy_flags, 1)


func test_evaluate_miss_above_band_emits_quality_one() -> void:
	watch_signals(EventBus)
	_station._evaluate(1.0)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"cilantro", 1, _station.ingredient_cost])


func test_evaluate_miss_below_band_does_not_add_ingredient() -> void:
	_station._evaluate(0.0)  # Below default min 0.3.
	assert_false(_taco.ingredients.has(&"cilantro"))


func test_evaluate_miss_below_band_increments_sloppy_flags() -> void:
	_station._evaluate(0.0)
	assert_eq(_taco.sloppy_flags, 1)


func test_evaluate_multiple_misses_accumulate_sloppy_flags() -> void:
	_station._evaluate(0.0)
	_station._evaluate(0.0)
	assert_eq(_taco.sloppy_flags, 2)


func test_target_band_defaults() -> void:
	assert_eq(_station.target_band_min, 0.3)
	assert_eq(_station.target_band_max, 0.55)


func test_ingredient_cost_default() -> void:
	assert_eq(_station.ingredient_cost, 0.10)


func test_shrink_duration_default() -> void:
	assert_eq(_station.shrink_duration, 1.8)


func test_station_id_property_delegates_to_ic() -> void:
	_ic.station_id = &"test_station"
	assert_eq(_station.station_id, &"test_station")


func test_topping_lock_reason_set() -> void:
	assert_eq(_ic.lock_reason, "Grab meat first")


func test_ingredient_id_used_in_hit_emit() -> void:
	_station.ingredient_id = &"tomato"
	var mid := (_station.target_band_min + _station.target_band_max) * 0.5
	watch_signals(EventBus)
	_station._evaluate(mid)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"tomato", 0, 0.0])
