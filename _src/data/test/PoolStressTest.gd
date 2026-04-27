## Verification script for Module 1 — delete after profiler confirms zero frame spikes.
extends Node

const TOPPING_SCENE: PackedScene = preload("res://_src/entities/food/ToppingItem.tscn")
const STRESS_COUNT: int = 100


func _ready() -> void:
	NodePool.prewarm(TOPPING_SCENE, STRESS_COUNT)

	var checked_out: Array[Node] = []
	for i in STRESS_COUNT:
		checked_out.append(NodePool.checkout(TOPPING_SCENE))
	for node in checked_out:
		NodePool.return_to_pool(node)

	print("[PoolStressTest] %d nodes checked out and returned. Open Profiler → Script row — confirm < 2 ms, zero spikes." % STRESS_COUNT)
