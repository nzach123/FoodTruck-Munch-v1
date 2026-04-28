extends GutTest

var _taco: TacoBase


func before_each() -> void:
	_taco = TacoBase.new()
	add_child_autofree(_taco)


func test_ingredients_default_empty() -> void:
	assert_eq(_taco.ingredients.size(), 0)


func test_sloppy_flags_default_zero() -> void:
	assert_eq(_taco.sloppy_flags, 0)


func test_add_ingredient_appends_id() -> void:
	_taco.add_ingredient(&"meat")
	assert_eq(_taco.ingredients.size(), 1)
	assert_eq(_taco.ingredients[0], &"meat")


func test_add_ingredient_multiple_appends_all() -> void:
	_taco.add_ingredient(&"tortilla")
	_taco.add_ingredient(&"meat")
	_taco.add_ingredient(&"cilantro")
	assert_eq(_taco.ingredients.size(), 3)


func test_add_ingredient_allows_duplicates() -> void:
	_taco.add_ingredient(&"meat")
	_taco.add_ingredient(&"meat")
	assert_eq(_taco.ingredients.size(), 2)


func test_add_ingredient_has_returns_true() -> void:
	_taco.add_ingredient(&"onion")
	assert_true(_taco.ingredients.has(&"onion"))


func test_has_ingredient_false_before_add() -> void:
	assert_false(_taco.ingredients.has(&"cilantro"))


func test_reset_clears_ingredients() -> void:
	_taco.add_ingredient(&"meat")
	_taco.add_ingredient(&"cilantro")
	_taco.reset()
	assert_eq(_taco.ingredients.size(), 0)


func test_reset_zeros_sloppy_flags() -> void:
	_taco.sloppy_flags = 3
	_taco.reset()
	assert_eq(_taco.sloppy_flags, 0)


func test_reset_zeros_position() -> void:
	_taco.position = Vector3(1.0, 2.0, 3.0)
	_taco.reset()
	assert_eq(_taco.position, Vector3.ZERO)


func test_reset_zeros_rotation() -> void:
	_taco.rotation = Vector3(0.5, 1.0, 1.5)
	_taco.reset()
	assert_eq(_taco.rotation, Vector3.ZERO)


func test_reset_does_not_affect_other_instances() -> void:
	var other := TacoBase.new()
	add_child_autofree(other)
	other.add_ingredient(&"tomato")
	_taco.reset()
	assert_eq(other.ingredients.size(), 1)


func test_sloppy_flags_set_directly() -> void:
	_taco.sloppy_flags = 2
	assert_eq(_taco.sloppy_flags, 2)


func test_ingredients_is_typed_array() -> void:
	_taco.add_ingredient(&"salsa")
	assert_true(_taco.ingredients is Array)
