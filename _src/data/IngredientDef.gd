class_name IngredientDef
extends Resource

enum InteractionType { INSTANT, DISCRETE_COUNTER, TAP_ACCUMULATE, TIMING }

@export var ingredient_id: StringName
@export var cost: float
@export var interaction_type: InteractionType
