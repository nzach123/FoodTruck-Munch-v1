class_name TacoBase
extends Node3D

var ingredients: Array[StringName] = []
var sloppy_flags: int = 0


func add_ingredient(id: StringName) -> void:
	ingredients.append(id)


func reset() -> void:
	ingredients.clear()
	sloppy_flags = 0
	position = Vector3.ZERO
	rotation = Vector3.ZERO
