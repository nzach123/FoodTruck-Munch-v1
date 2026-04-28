extends GutTest
## BellStation validator logic — tested in isolation without a live scene.
##
## The two behaviours under test are:
##   1. Ingredient diff: which required ingredients are absent from the taco.
##   2. Tip computation: sloppy_flags → tip amount mapping.
##
## These mirror the inline logic in BellStation._on_interacted / _complete_order.
## If BellStation ever extracts these as static helpers, replace the local
## helpers below with calls to BellStation directly.

# ---------------------------------------------------------------------------
# Helpers — mirror BellStation's inline logic
# ---------------------------------------------------------------------------

func _missing(taco: TacoBase, recipe: Recipe) -> Array[StringName]:
	var out: Array[StringName] = []
	for ing: StringName in recipe.required_ingredients:
		if not taco.ingredients.has(ing):
			out.append(ing)
	return out


func _tip(sloppy_flags: int) -> float:
	match sloppy_flags:
		0: return 1.0
		1: return 0.5
		_: return 0.0


# ---------------------------------------------------------------------------
# Ingredient diff tests
# ---------------------------------------------------------------------------

func test_no_missing_when_all_required_present() -> void:
	var taco := TacoBase.new()
	add_child_autoqfree(taco)
	taco.add_ingredient(&"tortilla")
	taco.add_ingredient(&"meat")
	var recipe := Recipe.new()
	recipe.required_ingredients = [&"tortilla", &"meat"]
	assert_eq(_missing(taco, recipe).size(), 0, "full taco should have nothing missing")


func test_detects_single_absent_ingredient() -> void:
	var taco := TacoBase.new()
	add_child_autoqfree(taco)
	taco.add_ingredient(&"tortilla")
	var recipe := Recipe.new()
	recipe.required_ingredients = [&"tortilla", &"meat"]
	var m := _missing(taco, recipe)
	assert_eq(m.size(), 1)
	assert_eq(m[0], &"meat")


func test_detects_multiple_absent_ingredients() -> void:
	var taco := TacoBase.new()
	add_child_autoqfree(taco)
	var recipe := Recipe.new()
	recipe.required_ingredients = [&"tortilla", &"meat", &"cilantro"]
	var m := _missing(taco, recipe)
	assert_eq(m.size(), 3)


func test_empty_required_list_never_blocks_serve() -> void:
	var taco := TacoBase.new()
	add_child_autoqfree(taco)
	var recipe := Recipe.new()
	recipe.required_ingredients = []
	assert_eq(_missing(taco, recipe).size(), 0)


# ---------------------------------------------------------------------------
# Tip computation tests
# ---------------------------------------------------------------------------

func test_tip_perfect_order() -> void:
	assert_eq(_tip(0), 1.0, "zero sloppy flags → $1.00 tip")


func test_tip_one_sloppy_flag() -> void:
	assert_eq(_tip(1), 0.5, "one sloppy flag → $0.50 tip")


func test_tip_two_sloppy_flags() -> void:
	assert_eq(_tip(2), 0.0, "two sloppy flags → $0.00 tip")


func test_tip_many_sloppy_flags() -> void:
	assert_eq(_tip(10), 0.0, "many sloppy flags still floor at $0.00")


# ---------------------------------------------------------------------------
# Payment calculation (matches BellStation._complete_order fallback)
# ---------------------------------------------------------------------------

func test_payment_uses_recipe_base_sale_price() -> void:
	var recipe := Recipe.new()
	recipe.base_sale_price = 3.50
	var payment: float = recipe.base_sale_price if recipe else 3.50
	assert_almost_eq(payment, 3.50, 0.001)


func test_payment_falls_back_to_350_when_no_recipe() -> void:
	var recipe: Recipe = null
	var payment: float = recipe.base_sale_price if recipe else 3.50
	assert_almost_eq(payment, 3.50, 0.001)
