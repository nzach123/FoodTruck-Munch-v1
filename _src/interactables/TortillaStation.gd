class_name TortillaStation
extends Node3D

const _TACO_SCENE := preload("res://_src/entities/food/TacoBase.tscn")

var _ic: InteractableComponent


func _ready() -> void:
	_ic = $InteractableComponent
	_ic.prerequisite_check = func() -> bool:
		return GameManager.active_taco != null
	_ic.lock_reason = "Already holding a taco"
	_ic.interacted.connect(_on_interacted)


func _on_interacted(_component: InteractableComponent) -> void:
	var ism := _ic.ism
	var taco := NodePool.checkout(_TACO_SCENE) as TacoBase
	if taco == null:
		push_error("TortillaStation: TacoBase checkout returned null.")
		return
	if ism.wieldables_node:
		taco.reparent(ism.wieldables_node)
	if ism.hand_anchor:
		taco.global_position = ism.hand_anchor.global_position
	GameManager.active_taco = taco
	EventBus.order_step_completed.emit(&"tortilla", 0, 0.0)
	ism.active_station = null
	ism.transition_to(&"StateHoldingTortilla")
