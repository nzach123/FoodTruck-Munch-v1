class_name Player
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var gravity: float = 9.8
## Designer-facing value. Applied internally as: sensitivity * 0.01 rad/pixel.
## At the default of 0.3, a 100-pixel swipe rotates ~17°.
@export var mouse_sensitivity: float = 0.3
## Gates CrouchingCollisionShape and CrouchRayCast. Keep false until crouch is scoped.
@export var enable_crouch: bool = false

@onready var _neck: Node3D = $Body/Neck
@onready var _raycast: RayCast3D = $Body/Neck/Head/Eyes/Camera/InteractionRaycast
@onready var _staircheck: RayCast3D = $StaircheckRayCast3D
@onready var _crouch_shape: CollisionShape3D = $CrouchingCollisionShape
@onready var _crouch_ray: RayCast3D = $CrouchRayCast

# Accumulates raw mouse delta between physics ticks. Consumed and reset each tick.
var _mouse_delta: Vector2 = Vector2.ZERO
# Cached per-physics-tick; Module B wires InteractableComponent signals here.
var _last_collider: Node = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not enable_crouch:
		_crouch_shape.disabled = true
		_staircheck.enabled = false
		_crouch_ray.enabled = false


func _unhandled_input(event: InputEvent) -> void:
	# Accumulate ONLY — no transform mutations here.
	# Applying in _physics_process ensures determinism against WASM input batching.
	if event is InputEventMouseMotion:
		_mouse_delta += event.relative
	elif OS.is_debug_build() and event.is_action_pressed("toggle_debug"):
		# CanvasLayer nodes sit outside Godot's viewport input tree and cannot reliably
		# receive _unhandled_input. Player owns all input; overlay just reacts.
		var overlay := get_node_or_null("DebugOverlay") as CanvasLayer
		if overlay:
			overlay.visible = not overlay.visible


func _physics_process(delta: float) -> void:
	_apply_look()
	_apply_movement(delta)
	_update_raycast()


func _apply_look() -> void:
	rotate_y(-_mouse_delta.x * mouse_sensitivity * 0.01)
	_neck.rotate_x(-_mouse_delta.y * mouse_sensitivity * 0.01)
	_neck.rotation.x = clamp(_neck.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	_mouse_delta = Vector2.ZERO


func _apply_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	# get_vector returns x=strafe, y=forward/back — transform to world space using
	# only the Player's yaw basis (not neck pitch) so W always moves forward.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()


# Cache the focused collider; on change Module B will emit focused/unfocused
# signals to the collider's InteractableComponent.
func _update_raycast() -> void:
	var collider := _raycast.get_collider() as Node
	if collider != _last_collider:
		_last_collider = collider


# Required by the AnimationPlayer → Player connection in TruckInterior.tscn.
# Wired in Module B for head-bob and crouch transitions.
func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	pass
