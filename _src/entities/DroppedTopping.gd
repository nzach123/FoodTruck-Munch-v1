class_name DroppedTopping
extends RigidBody3D

@export var lifetime: float = 5.0

var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	# freeze = true when pooled; skip countdown until actually launched.
	if freeze:
		return
	_timer -= delta
	if _timer <= 0.0:
		NodePool.return_to_pool(self)


func launch() -> void:
	_timer = lifetime
	freeze = false
	apply_central_impulse(Vector3(
			randf_range(-0.5, 0.5), 1.5, randf_range(-0.5, 0.5)))


func reset() -> void:
	# Jolt requires freeze before zeroing velocity.
	freeze = true
	_timer = 0.0
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
