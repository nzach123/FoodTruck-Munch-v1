class_name BellStation
extends Node3D

@export var modal_scene: PackedScene

var _ic: InteractableComponent


func _ready() -> void:
	_ic = $InteractableComponent
	_ic.prerequisite_check = func() -> bool:
		return GameManager.active_taco == null
	_ic.lock_reason = "Nothing to serve"
	_ic.interacted.connect(_on_interacted)


func _on_interacted(_component: InteractableComponent) -> void:
	var taco := GameManager.active_taco
	if taco == null:
		return
	var recipe := GameManager.active_recipe
	var missing: Array[StringName] = []
	if recipe:
		for ing: StringName in recipe.required_ingredients:
			if not taco.ingredients.has(ing):
				missing.append(ing)
	if missing.is_empty():
		_complete_order()
	else:
		_show_modal(missing)


func _show_modal(missing: Array[StringName]) -> void:
	if modal_scene == null:
		# No modal scene wired — serve as sloppy by default.
		_complete_order()
		return
	var modal := modal_scene.instantiate()
	get_tree().current_scene.add_child(modal)
	if modal.has_method(&"setup"):
		modal.call(&"setup", missing,
				Callable(self, "_complete_order"),
				Callable(self, "_cancel_serve"))
	_ic.ism.active_station = self
	_ic.ism.transition_to(&"StateBellModal")


func _cancel_serve() -> void:
	_ic.ism.transition_to(&"StateHoldingMeat")


func _complete_order() -> void:
	var taco := GameManager.active_taco
	if taco == null:
		return
	var tip: float
	match taco.sloppy_flags:
		0: tip = 1.0
		1: tip = 0.5
		_: tip = 0.0
	var payment := GameManager.active_recipe.base_sale_price \
			if GameManager.active_recipe else 3.50
	EventBus.order_completed.emit(payment, tip)
	NodePool.return_to_pool(taco)
	GameManager.active_taco = null
	_ic.ism.held_item = &""
	_ic.ism.transition_to(&"StateIdle")
