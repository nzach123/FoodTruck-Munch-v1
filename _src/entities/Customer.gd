extends CharacterBody3D
class_name Customer

@export var walk_speed: float = 2.5
@export var patience_component: PatienceComponent
@export var nav_agent: NavigationAgent3D
@export var anim_player: AnimationPlayer
@export var patience_bar: PatienceBar

var customer_id: int
var target_slot: Marker3D
var _is_arrived: bool = false
var _is_leaving: bool = false


func _ready() -> void:
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.3
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	patience_component.expired.connect(_on_patience_expired)


func setup(id: int, slot: Marker3D) -> void:
	customer_id = id
	target_slot = slot
	_is_arrived = false
	_is_leaving = false
	nav_agent.target_position = target_slot.global_position
	patience_component.stop()


func _physics_process(delta: float) -> void:
	if patience_bar:
		patience_bar.set_value(patience_component.get_patience_ratio())
		patience_bar.set_active(patience_component.is_active)

	if _is_leaving:
		_handle_navigation(delta)
		if nav_agent.is_navigation_finished():
			_despawn()
		return

	if not _is_arrived:
		_handle_navigation(delta)
		if nav_agent.is_navigation_finished():
			_on_arrival()
	else:
		# Face the counter/player
		var look_target = global_position + Vector3.RIGHT # Assuming counter is in +X or something
		# Actually, let's just make them look towards the truck interior
		# For now, stay static.
		pass


func _handle_navigation(_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		return

	var next_path_pos := nav_agent.get_next_path_position()
	var new_velocity := (next_path_pos - global_position).normalized() * walk_speed
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()
	
	if velocity.length() > 0.1:
		var look_dir = velocity
		look_dir.y = 0
		if look_dir.length() > 0.01:
			look_at(global_position + look_dir, Vector3.UP)


func _on_arrival() -> void:
	_is_arrived = true
	patience_component.start()
	# Optional: Face the counter
	look_at(global_position + Vector3(-1, 0, 0), Vector3.UP) # Counter is roughly at -X


func _on_patience_expired() -> void:
	EventBus.customer_left_angry.emit(1.50)
	leave()


func leave() -> void:
	_is_leaving = true
	_is_arrived = false
	patience_component.stop()
	# Target a despawn point (e.g. back to start)
	nav_agent.target_position = Vector3(5, 0, 0) # Placeholder despawn point


func _despawn() -> void:
	NodePool.return_to_pool(self)


func reset() -> void:
	_is_arrived = false
	_is_leaving = false
	velocity = Vector3.ZERO
	patience_component.stop()
	visible = false
