extends GutTest


func test_is_resource() -> void:
	var d := IngredientDef.new()
	assert_true(d is Resource)


func test_ingredient_id_default_empty() -> void:
	var d := IngredientDef.new()
	assert_eq(d.ingredient_id, &"")


func test_cost_default_zero() -> void:
	var d := IngredientDef.new()
	assert_eq(d.cost, 0.0)


func test_ingredient_id_assignment() -> void:
	var d := IngredientDef.new()
	d.ingredient_id = &"cilantro"
	assert_eq(d.ingredient_id, &"cilantro")


func test_cost_assignment() -> void:
	var d := IngredientDef.new()
	d.cost = 0.15
	assert_eq(d.cost, 0.15)


func test_interaction_type_assignment() -> void:
	var d := IngredientDef.new()
	d.interaction_type = IngredientDef.InteractionType.TIMING
	assert_eq(d.interaction_type, IngredientDef.InteractionType.TIMING)


func test_enum_instant_value() -> void:
	assert_eq(IngredientDef.InteractionType.INSTANT, 0)


func test_enum_discrete_counter_value() -> void:
	assert_eq(IngredientDef.InteractionType.DISCRETE_COUNTER, 1)


func test_enum_tap_accumulate_value() -> void:
	assert_eq(IngredientDef.InteractionType.TAP_ACCUMULATE, 2)


func test_enum_timing_value() -> void:
	assert_eq(IngredientDef.InteractionType.TIMING, 3)


func test_interaction_type_default() -> void:
	var d := IngredientDef.new()
	assert_eq(d.interaction_type, IngredientDef.InteractionType.INSTANT)
