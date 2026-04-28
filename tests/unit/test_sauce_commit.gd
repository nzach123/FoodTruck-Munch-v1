extends GutTest
# Tests SauceStation._commit() branch logic in isolation.
# Sets up a SauceStation + InteractableComponent child so _ready() resolves _ic,
# then manipulates GameManager state directly (autoload is available at test time).

var _station: SauceStation
var _ic: InteractableComponent
var _taco: TacoBase


func before_each() -> void:
	_taco = TacoBase.new()
	add_child_autofree(_taco)
	GameManager.active_taco = _taco

	_ic = InteractableComponent.new()
	_ic.name = "InteractableComponent"
	_ic.station_id = &"salsa_verde"

	_station = SauceStation.new()
	_station.add_child(_ic)
	add_child_autofree(_station)


func after_each() -> void:
	GameManager.active_taco = null


func test_commit_null_taco_does_not_emit() -> void:
	GameManager.active_taco = null
	watch_signals(EventBus)
	_station._commit(0.7)
	assert_signal_not_emitted(EventBus, "order_step_completed")


func test_commit_green_zone_min_boundary_adds_ingredient() -> void:
	_station._commit(_station.green_zone_min)
	assert_true(_taco.ingredients.has(&"salsa_verde"))


func test_commit_green_zone_max_boundary_adds_ingredient() -> void:
	_station._commit(_station.green_zone_max)
	assert_true(_taco.ingredients.has(&"salsa_verde"))


func test_commit_inside_green_zone_adds_ingredient() -> void:
	_station._commit(0.72)  # Between default 0.6 and 0.85.
	assert_true(_taco.ingredients.has(&"salsa_verde"))


func test_commit_inside_green_zone_emits_quality_zero() -> void:
	watch_signals(EventBus)
	_station._commit(0.72)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"salsa_verde", 0, 0.0])


func test_commit_overfill_does_not_add_ingredient() -> void:
	_station._commit(0.9)  # Above default max 0.85.
	assert_false(_taco.ingredients.has(&"salsa_verde"))


func test_commit_overfill_emits_quality_one() -> void:
	watch_signals(EventBus)
	_station._commit(0.9)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"salsa_verde", 1, 0.0])


func test_commit_underfill_does_not_add_ingredient() -> void:
	_station._commit(0.3)  # Below default min 0.6.
	assert_false(_taco.ingredients.has(&"salsa_verde"))


func test_commit_underfill_emits_quality_one() -> void:
	watch_signals(EventBus)
	_station._commit(0.3)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"salsa_verde", 1, 0.0])


func test_commit_zero_gauge_is_underfill() -> void:
	watch_signals(EventBus)
	_station._commit(0.0)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"salsa_verde", 1, 0.0])


func test_commit_full_gauge_is_overfill() -> void:
	watch_signals(EventBus)
	_station._commit(1.0)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"salsa_verde", 1, 0.0])


func test_commit_uses_ic_station_id_in_emit() -> void:
	_ic.station_id = &"hot_sauce"
	watch_signals(EventBus)
	_station._commit(0.72)
	assert_signal_emitted_with_parameters(EventBus, "order_step_completed",
			[&"hot_sauce", 0, 0.0])


func test_commit_adds_ic_station_id_as_ingredient() -> void:
	_ic.station_id = &"hot_sauce"
	_station._commit(0.72)
	assert_true(_taco.ingredients.has(&"hot_sauce"))


func test_green_zone_defaults() -> void:
	assert_eq(_station.green_zone_min, 0.6)
	assert_eq(_station.green_zone_max, 0.85)


func test_tap_increment_default() -> void:
	assert_eq(_station.tap_increment, 0.15)


func test_idle_commit_time_default() -> void:
	assert_eq(_station.idle_commit_time, 0.4)


func test_station_id_property_delegates_to_ic() -> void:
	_ic.station_id = &"crema"
	assert_eq(_station.station_id, &"crema")
