extends Node
class_name PatienceComponent

signal expired

@export var max_patience: float = 30.0
@export var drain_rate: float = 1.0

var current_patience: float
var is_active: bool = false
var _paused: bool = false


func _ready() -> void:
	current_patience = max_patience
	EventBus.order_accepted.connect(_on_order_accepted)
	EventBus.order_completed.connect(_on_order_resolved)
	EventBus.customer_left_angry.connect(_on_order_resolved)


func start() -> void:
	current_patience = max_patience
	is_active = true
	_paused = false


func stop() -> void:
	is_active = false


func _physics_process(delta: float) -> void:
	if not is_active or _paused:
		return
	
	current_patience -= delta * drain_rate
	if current_patience <= 0.0:
		current_patience = 0.0
		is_active = false
		expired.emit()


func get_patience_ratio() -> float:
	return current_patience / max_patience


func _on_order_accepted(_customer_id: int, _recipe: Recipe) -> void:
	# If this is the active customer, we might want to pause drain.
	# The spec says: "_drain_rate is paused when the order is accepted"
	# We need a way to know if this component belongs to the accepted customer.
	# For simplicity, if we only have one order at a time, we can pause all?
	# But actually, the spec implies the order is for a specific customer.
	# For now, let's assume the first customer in queue is the one whose order is accepted.
	# QueueManager will handle pausing the specific customer.
	pass


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func _on_order_resolved(_p1 = null, _p2 = null) -> void:
	# Generic resolution for cleanup if needed.
	pass
