extends Node

enum DayPhase { TUTORIAL, PLAYING, END_OF_DAY }

@export var day_duration_seconds: float = 300.0

var current_phase: DayPhase = DayPhase.TUTORIAL
