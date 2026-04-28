extends GutTest

var _ic: InteractableComponent


func before_each() -> void:
	_ic = InteractableComponent.new()
	add_child_autofree(_ic)


func test_is_locked_no_callable_returns_false() -> void:
	assert_false(_ic.is_locked())


func test_is_locked_callable_true_returns_true() -> void:
	_ic.prerequisite_check = func() -> bool: return true
	assert_true(_ic.is_locked())


func test_is_locked_callable_false_returns_false() -> void:
	_ic.prerequisite_check = func() -> bool: return false
	assert_false(_ic.is_locked())


func test_is_locked_invalid_callable_returns_false() -> void:
	# Empty Callable() is not valid — should behave like no check (false).
	_ic.prerequisite_check = Callable()
	assert_false(_ic.is_locked())


func test_interact_emits_interacted_signal() -> void:
	watch_signals(_ic)
	_ic.interact()
	assert_signal_emitted(_ic, "interacted")


func test_interact_signal_passes_self_as_argument() -> void:
	var received: Array = []
	_ic.interacted.connect(func(comp: InteractableComponent) -> void:
		received.append(comp))
	_ic.interact()
	assert_eq(received.size(), 1)
	assert_eq(received[0], _ic)


func test_interact_emits_once_per_call() -> void:
	watch_signals(_ic)
	_ic.interact()
	_ic.interact()
	assert_signal_emit_count(_ic, "interacted", 2)


func test_default_lock_reason_empty() -> void:
	assert_eq(_ic.lock_reason, "")


func test_lock_reason_assignment() -> void:
	_ic.lock_reason = "Need meat first"
	assert_eq(_ic.lock_reason, "Need meat first")


func test_default_interaction_type_instant() -> void:
	assert_eq(_ic.interaction_type, InteractableComponent.InteractionType.INSTANT)


func test_station_id_default_empty() -> void:
	assert_eq(_ic.station_id, &"")


func test_station_id_assignment() -> void:
	_ic.station_id = &"salsa_verde"
	assert_eq(_ic.station_id, &"salsa_verde")


func test_required_action_assignment() -> void:
	_ic.required_action = &"interact_e"
	assert_eq(_ic.required_action, &"interact_e")


func test_ism_default_null() -> void:
	assert_null(_ic.ism)


func test_ic_enum_matches_ingredient_def_enum() -> void:
	assert_eq(int(InteractableComponent.InteractionType.INSTANT),
			int(IngredientDef.InteractionType.INSTANT))
	assert_eq(int(InteractableComponent.InteractionType.TIMING),
			int(IngredientDef.InteractionType.TIMING))
