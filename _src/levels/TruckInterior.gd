class_name TruckInterior
extends Node3D

const _DEFAULT_RECIPE := preload("res://_src/data/recipes/TacoAlPastor.tres")

func _ready() -> void:
	if GameManager.active_recipe == null:
		GameManager.active_recipe = _DEFAULT_RECIPE
	GameManager.start_day(1)
