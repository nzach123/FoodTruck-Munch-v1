extends GutTest


func test_base_sale_price_default() -> void:
	var r := Recipe.new()
	assert_eq(r.base_sale_price, 3.50)


func test_required_ingredients_default_empty() -> void:
	var r := Recipe.new()
	assert_eq(r.required_ingredients.size(), 0)


func test_optional_ingredients_default_empty() -> void:
	var r := Recipe.new()
	assert_eq(r.optional_ingredients.size(), 0)


func test_recipe_name_assignment() -> void:
	var r := Recipe.new()
	r.recipe_name = &"TacoAlPastor"
	assert_eq(r.recipe_name, &"TacoAlPastor")


func test_required_ingredients_assignment() -> void:
	var r := Recipe.new()
	r.required_ingredients = [&"tortilla", &"meat", &"cilantro"]
	assert_eq(r.required_ingredients.size(), 3)
	assert_true(r.required_ingredients.has(&"meat"))


func test_optional_ingredients_assignment() -> void:
	var r := Recipe.new()
	r.optional_ingredients = [&"guacamole"]
	assert_eq(r.optional_ingredients.size(), 1)


func test_food_cost_assignment() -> void:
	var r := Recipe.new()
	r.food_cost = 1.25
	assert_eq(r.food_cost, 1.25)


func test_base_sale_price_override() -> void:
	var r := Recipe.new()
	r.base_sale_price = 5.00
	assert_eq(r.base_sale_price, 5.00)


func test_recipe_is_resource() -> void:
	var r := Recipe.new()
	assert_true(r is Resource)
