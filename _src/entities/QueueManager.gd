extends Node
class_name QueueManager

@export var customer_scene: PackedScene
@export var queue_slots: Array[Marker3D]
@export var spawn_point: Marker3D
@export var despawn_point: Marker3D

var _active_customers: Array[Customer] = []
var _next_id: int = 1


func _ready() -> void:
	EventBus.order_completed.connect(_on_order_resolved)
	EventBus.customer_left_angry.connect(_on_order_resolved)
	
	# Initial spawn delay
	get_tree().create_timer(2.0).timeout.connect(try_spawn_customer)


func try_spawn_customer() -> void:
	if GameManager.current_phase != GameManager.DayPhase.PLAYING:
		return
		
	if _active_customers.size() >= queue_slots.size():
		return
		
	# Find first empty slot
	var slot_index = -1
	for i in queue_slots.size():
		var slot_taken = false
		for c in _active_customers:
			if c.target_slot == queue_slots[i]:
				slot_taken = true
				break
		if not slot_taken:
			slot_index = i
			break
	
	if slot_index == -1:
		return
		
	var customer := NodePool.checkout(customer_scene) as Customer
	customer.global_position = spawn_point.global_position
	customer.setup(_next_id, queue_slots[slot_index])
	_active_customers.append(customer)
	_next_id += 1
	
	# If this is the first customer, automatically accept their order for now
	# In a fuller game, the player might need to interact to accept.
	if _active_customers.size() == 1:
		_accept_order(customer)

	# Schedule next spawn check
	get_tree().create_timer(randf_range(5.0, 10.0)).timeout.connect(try_spawn_customer)


func _accept_order(customer: Customer) -> void:
	EventBus.order_accepted.emit(customer.customer_id, GameManager.active_recipe)
	# Spec says: _drain_rate is paused when the order is accepted
	customer.patience_component.pause()


func _on_order_resolved(_p1 = null, _p2 = null) -> void:
	# Assume the first customer in queue is the one who was resolved
	if _active_customers.size() > 0:
		var customer = _active_customers.pop_front()
		customer.leave()
		
		# If there are more customers, accept the next one
		if _active_customers.size() > 0:
			# Small delay before accepting next order
			get_tree().create_timer(1.0).timeout.connect(func():
				if _active_customers.size() > 0:
					_accept_order(_active_customers[0])
			)
