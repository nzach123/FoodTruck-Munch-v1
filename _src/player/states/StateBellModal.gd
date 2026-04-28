class_name StateBellModal
extends Node

var _ism: InteractionStateMachine


func _init_ism(ism: InteractionStateMachine) -> void:
	_ism = ism


func enter() -> void:
	_ism.held_item = &"meat"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func exit() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
