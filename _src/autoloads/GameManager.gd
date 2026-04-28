extends Node

enum DayPhase { TUTORIAL, PLAYING, END_OF_DAY }

@export var day_duration_seconds: float = 300.0
## Fallback recipe used during Phase C (no customer NPC yet).
## Wire TacoAlPastor.tres here in the Inspector.
## Overridden at runtime when EventBus.order_accepted fires (Module 7).
@export var default_recipe: Recipe = null

var current_phase: DayPhase = DayPhase.TUTORIAL
## The recipe the player is currently assembling against.
## Set from default_recipe on _ready(); overridden by order_accepted in Module 7.
var active_recipe: Recipe = null
## The TacoBase node currently checked out from NodePool.
## Set by TortillaStation on checkout; cleared by BellStation on order complete.
var active_taco: TacoBase = null


func _ready() -> void:
	active_recipe = default_recipe
	EventBus.order_accepted.connect(_on_order_accepted)


func _on_order_accepted(_customer_id: int, recipe: Recipe) -> void:
	active_recipe = recipe
