extends Node3D
class_name PatienceBar

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar


func set_value(ratio: float) -> void:
	progress_bar.value = ratio * 100.0


func set_active(active: bool) -> void:
	visible = active
