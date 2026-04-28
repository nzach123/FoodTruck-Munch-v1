class_name SauceStation
extends Node3D

@export var green_zone_min: float = 0.6
@export var green_zone_max: float = 0.85
@export var idle_commit_time: float = 0.4
@export var tap_increment: float = 0.15
@export var overfill_animation_player: AnimationPlayer

## Read by StateSauce to emit sauce_gauge_changed with the correct station identity.
var station_id: StringName:
	get: return _ic.station_id if _ic else &""

var _ic: InteractableComponent


func _ready() -> void:
	_ic = $InteractableComponent
	_ic.prerequisite_check = func() -> bool:
		var taco := GameManager.active_taco
		if taco == null or not taco.ingredients.has(&"meat"):
			return true
		var recipe := GameManager.active_recipe
		if recipe == null:
			return false
		for ing: StringName in recipe.required_ingredients:
			if ing in [&"cilantro", &"tomato", &"onion"]:
				if not taco.ingredients.has(ing):
					return true
		return false
	_ic.lock_reason = "Add toppings first"
	_ic.interacted.connect(_on_interacted)


func _on_interacted(_component: InteractableComponent) -> void:
	_ic.ism.active_station = self
	_ic.ism.transition_to(&"StateSauce")


func _commit(gauge: float) -> void:
	var taco := GameManager.active_taco
	if taco == null:
		return
	if gauge > green_zone_max:
		if overfill_animation_player \
				and overfill_animation_player.has_animation(&"sauce_overfill"):
			overfill_animation_player.play(&"sauce_overfill")
		EventBus.order_step_completed.emit(_ic.station_id, 1, 0.0)
	elif gauge >= green_zone_min:
		taco.add_ingredient(_ic.station_id)
		EventBus.order_step_completed.emit(_ic.station_id, 0, 0.0)
	else:
		EventBus.order_step_completed.emit(_ic.station_id, 1, 0.0)
