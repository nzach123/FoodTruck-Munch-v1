class_name Recipe
extends Resource

@export var recipe_name: StringName
@export var required_ingredients: Array[StringName]
@export var optional_ingredients: Array[StringName]
@export var base_sale_price: float = 3.50
## Computed from ingredient costs; set per-recipe in the Inspector.
@export var food_cost: float
