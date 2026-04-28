class_name ToppingStation
extends Node3D

const _DROPPED_SCENE := preload("res://_src/entities/DroppedTopping.tscn")

@export var ingredient_id: StringName
@export var ingredient_cost: float = 0.10
@export var shrink_duration: float = 1.8
@export var target_band_min: float = 0.3
@export var target_band_max: float = 0.55

## Read by StateTiming to emit circle_radius_changed with the correct station identity.
var station_id: StringName:
	get: return _ic.station_id if _ic else &""

var _ic: InteractableComponent


func _ready() -> void:
	_ic = $InteractableComponent
	_ic.prerequisite_check = func() -> bool:
		var taco := GameManager.active_taco
		return taco == null or not taco.ingredients.has(&"meat")
	_ic.lock_reason = "Grab meat first"
	_ic.interacted.connect(_on_interacted)


func _on_interacted(_component: InteractableComponent) -> void:
	_ic.ism.active_station = self
	_ic.ism.transition_to(&"StateTiming")


func _evaluate(radius: float) -> void:
	var taco := GameManager.active_taco
	if taco == null:
		return
	if radius >= target_band_min and radius <= target_band_max:
		taco.add_ingredient(ingredient_id)
		EventBus.order_step_completed.emit(ingredient_id, 0, 0.0)
	else:
		taco.sloppy_flags += 1
		var drop := NodePool.checkout(_DROPPED_SCENE)
		drop.global_position = global_position + Vector3(
				randf_range(-0.2, 0.2), 0.5, randf_range(-0.2, 0.2))
		if drop.has_method(&"launch"):
			drop.call(&"launch")
		EventBus.order_step_completed.emit(ingredient_id, 1, ingredient_cost)
