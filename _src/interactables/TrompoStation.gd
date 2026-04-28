class_name TrompoStation
extends Node3D

const _FRAGMENT_SCENE := preload("res://_src/entities/MeatFragment.tscn")

@export var required_presses: int = 3
@export var animation_player: AnimationPlayer

var _ic: InteractableComponent
var _press_count: int = 0


func _ready() -> void:
	_ic = $InteractableComponent
	_ic.prerequisite_check = func() -> bool:
		return _ic.ism == null or _ic.ism.held_item != &"tortilla"
	_ic.lock_reason = "Grab a tortilla first"
	_ic.interacted.connect(_on_interacted)


func _on_interacted(_component: InteractableComponent) -> void:
	_ic.ism.active_station = self
	_ic.ism.transition_to(&"StateTrompo")


func _on_press() -> void:
	_press_count += 1
	var anim_name := "meat_spin_%dx" % _press_count
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	for _i in _press_count:
		var fragment := NodePool.checkout(_FRAGMENT_SCENE)
		fragment.global_position = global_position + Vector3(
				randf_range(-0.15, 0.15), 0.6, randf_range(-0.15, 0.15))
		if fragment.has_method(&"play"):
			fragment.call(&"play")
	if _press_count >= required_presses:
		_press_count = 0
		if GameManager.active_taco:
			GameManager.active_taco.add_ingredient(&"meat")
		EventBus.order_step_completed.emit(&"meat", 0, 0.75)
		_ic.ism.transition_to(&"StateHoldingMeat")


func reset_count() -> void:
	_press_count = 0
