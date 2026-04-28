extends Node

# PackedScene → Array[Node]: nodes currently in the free list
var _pools: Dictionary = {}
# PackedScene → int: count of nodes currently checked out (not in free list)
var _active: Dictionary = {}


func _ready() -> void:
	prewarm(preload("res://_src/entities/food/TacoBase.tscn"), 3)
	prewarm(preload("res://_src/entities/MeatFragment.tscn"), 9)
	prewarm(preload("res://_src/entities/DroppedTopping.tscn"), 6)
	prewarm(preload("res://_src/entities/Customer.tscn"), 3)


func prewarm(scene: PackedScene, count: int) -> void:
	_ensure_pool(scene)
	for i in count:
		var node := _instantiate(scene)
		node.visible = false
		_pools[scene].append(node)


func checkout(scene: PackedScene) -> Node:
	_ensure_pool(scene)
	var node: Node
	if _pools[scene].size() > 0:
		node = _pools[scene].pop_back()
	else:
		# Fallback allocation — only fires if prewarm count was too low.
		# Warning tells designers to increase the prewarm budget.
		push_warning("NodePool.checkout: pool exhausted for '%s' — instantiating at runtime." \
				% scene.resource_path.get_file())
		node = _instantiate(scene)
	node.visible = true
	_active[scene] += 1
	return node


func return_to_pool(node: Node) -> void:
	if not node.has_meta(&"_pool_scene"):
		push_warning("NodePool.return_to_pool: '%s' was not checked out from this pool." % node.name)
		return
	var scene := node.get_meta(&"_pool_scene") as PackedScene
	# Restore NodePool as parent before reset so reparented nodes (e.g. TacoBase
	# held under Player's hand Marker3D) don't remain in the wrong scene subtree.
	if node.get_parent() != self:
		node.reparent(self)
	# reset() contract: pooled nodes implement reset() to clear per-use state.
	# Checked via has_method to keep the pool generic — no base class required.
	if node.has_method(&"reset"):
		node.reset()
	node.visible = false
	_pools[scene].append(node)
	_active[scene] = max(0, _active[scene] - 1)


func get_pool_size(scene: PackedScene) -> int:
	return _pools.get(scene, []).size()


func get_active_count(scene: PackedScene) -> int:
	return _active.get(scene, 0)


# Returns Array[Dictionary{name, active, free}] — consumed by DebugOverlay.
func get_stats() -> Array:
	var result: Array = []
	for scene: PackedScene in _pools:
		result.append({
			"name": scene.resource_path.get_file().get_basename(),
			"active": _active.get(scene, 0),
			"free": _pools[scene].size(),
		})
	return result


func _instantiate(scene: PackedScene) -> Node:
	var node := scene.instantiate()
	# Tag with origin scene for O(1) reverse-lookup on return_to_pool.
	node.set_meta(&"_pool_scene", scene)
	add_child(node)
	return node


func _ensure_pool(scene: PackedScene) -> void:
	if not _pools.has(scene):
		_pools[scene] = []
		_active[scene] = 0
