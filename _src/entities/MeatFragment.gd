class_name MeatFragment
extends Node3D

@export var lifetime: float = 2.0

var _timer: float = 0.0
var _active: bool = false

@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer")


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_active = false
		NodePool.return_to_pool(self)


func play() -> void:
	_timer = lifetime
	_active = true
	if _anim and _anim.has_animation(&"fly"):
		_anim.play(&"fly")


func reset() -> void:
	_active = false
	_timer = 0.0
	if _anim:
		_anim.stop()
	position = Vector3.ZERO
	rotation = Vector3.ZERO
