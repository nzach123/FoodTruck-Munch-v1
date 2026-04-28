extends GutTest

# Tests use a fresh NodePool instance (not the autoload) to avoid corrupting
# the global pool state that gameplay depends on.
var _pool: Node
const _TACO_SCENE := preload("res://_src/entities/food/TacoBase.tscn")
const _FRAGMENT_SCENE := preload("res://_src/entities/MeatFragment.tscn")


func before_each() -> void:
	var script := load("res://_src/autoloads/NodePool.gd")
	_pool = Node.new()
	_pool.set_script(script)
	add_child_autofree(_pool)
	# Clear prewarmed nodes from _ready() to start tests from zero.
	# _ready is called when the node enters the tree (via add_child_autofree).
	_pool._pools.clear()
	_pool._active.clear()


func test_pool_size_zero_for_unknown_scene() -> void:
	assert_eq(_pool.get_pool_size(_TACO_SCENE), 0)


func test_active_count_zero_for_unknown_scene() -> void:
	assert_eq(_pool.get_active_count(_TACO_SCENE), 0)


func test_prewarm_fills_pool() -> void:
	_pool.prewarm(_TACO_SCENE, 3)
	assert_eq(_pool.get_pool_size(_TACO_SCENE), 3)


func test_prewarm_twice_accumulates() -> void:
	_pool.prewarm(_TACO_SCENE, 2)
	_pool.prewarm(_TACO_SCENE, 1)
	assert_eq(_pool.get_pool_size(_TACO_SCENE), 3)


func test_prewarm_zero_is_noop() -> void:
	_pool.prewarm(_TACO_SCENE, 0)
	assert_eq(_pool.get_pool_size(_TACO_SCENE), 0)


func test_checkout_reduces_pool_size() -> void:
	_pool.prewarm(_TACO_SCENE, 2)
	var node: Node = _pool.checkout(_TACO_SCENE)
	assert_eq(_pool.get_pool_size(_TACO_SCENE), 1)
	_pool.return_to_pool(node)


func test_checkout_increments_active_count() -> void:
	_pool.prewarm(_TACO_SCENE, 2)
	var node: Node = _pool.checkout(_TACO_SCENE)
	assert_eq(_pool.get_active_count(_TACO_SCENE), 1)
	_pool.return_to_pool(node)


func test_checkout_returns_non_null_node() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: Node = _pool.checkout(_TACO_SCENE)
	assert_not_null(node)
	_pool.return_to_pool(node)


func test_checkout_exhausted_pool_still_returns_node() -> void:
	var node: Node = _pool.checkout(_TACO_SCENE)
	assert_not_null(node)
	_pool.return_to_pool(node)


func test_checkout_node_is_visible() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: Node = _pool.checkout(_TACO_SCENE)
	assert_true(node.visible)
	_pool.return_to_pool(node)


func test_prewarm_nodes_are_invisible() -> void:
	_pool.prewarm(_TACO_SCENE, 2)
	for child in _pool.get_children():
		if child.has_meta(&"_pool_scene"):
			assert_false(child.visible, "Pooled node should be hidden")


func test_node_has_pool_scene_meta_after_checkout() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: Node = _pool.checkout(_TACO_SCENE)
	assert_true(node.has_meta(&"_pool_scene"))
	_pool.return_to_pool(node)


func test_pool_scene_meta_matches_source_scene() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: Node = _pool.checkout(_TACO_SCENE)
	assert_eq(node.get_meta(&"_pool_scene"), _TACO_SCENE)
	_pool.return_to_pool(node)


func test_return_to_pool_restores_pool_size() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: Node = _pool.checkout(_TACO_SCENE)
	_pool.return_to_pool(node)
	assert_eq(_pool.get_pool_size(_TACO_SCENE), 1)


func test_return_to_pool_decrements_active_count() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: Node = _pool.checkout(_TACO_SCENE)
	_pool.return_to_pool(node)
	assert_eq(_pool.get_active_count(_TACO_SCENE), 0)


func test_return_to_pool_hides_node() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: Node = _pool.checkout(_TACO_SCENE)
	_pool.return_to_pool(node)
	assert_false(node.visible)


func test_return_to_pool_calls_reset_on_taco_base() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: TacoBase = _pool.checkout(_TACO_SCENE) as TacoBase
	node.add_ingredient(&"meat")
	node.sloppy_flags = 2
	_pool.return_to_pool(node)
	# After reset(), both should be cleared.
	assert_eq(node.ingredients.size(), 0)
	assert_eq(node.sloppy_flags, 0)


func test_return_non_pooled_node_does_not_crash() -> void:
	var orphan := Node.new()
	add_child(orphan)
	# push_warning fires but must not crash.
	_pool.return_to_pool(orphan)
	remove_child(orphan)
	orphan.free() # Use free() instead of queue_free() to avoid orphans in tests.


func test_active_count_never_goes_below_zero() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var node: Node = _pool.checkout(_TACO_SCENE)
	_pool.return_to_pool(node)
	_pool.return_to_pool(node)  # Double return — active should clamp at 0.
	assert_true(_pool.get_active_count(_TACO_SCENE) >= 0)


func test_get_stats_returns_array() -> void:
	_pool.prewarm(_TACO_SCENE, 2)
	var stats: Array = _pool.get_stats()
	assert_true(stats.size() > 0)


func test_get_stats_entry_has_required_keys() -> void:
	_pool.prewarm(_TACO_SCENE, 2)
	var stats: Array = _pool.get_stats()
	var entry: Dictionary = stats[0]
	assert_true(entry.has("name"))
	assert_true(entry.has("active"))
	assert_true(entry.has("free"))


func test_get_stats_counts_match_pool_state() -> void:
	_pool.prewarm(_TACO_SCENE, 3)
	var node: Node = _pool.checkout(_TACO_SCENE)
	var stats: Array = _pool.get_stats()
	var entry: Dictionary = stats[0]
	assert_eq(entry.active, 1)
	assert_eq(entry.free, 2)
	_pool.return_to_pool(node)


func test_get_stats_name_is_filename_without_extension() -> void:
	_pool.prewarm(_TACO_SCENE, 1)
	var stats: Array = _pool.get_stats()
	assert_eq(stats[0].name, "TacoBase")


func test_checkout_multiple_scenes_tracked_separately() -> void:
	_pool.prewarm(_TACO_SCENE, 2)
	_pool.prewarm(_FRAGMENT_SCENE, 3)
	assert_eq(_pool.get_pool_size(_TACO_SCENE), 2)
	assert_eq(_pool.get_pool_size(_FRAGMENT_SCENE), 3)
