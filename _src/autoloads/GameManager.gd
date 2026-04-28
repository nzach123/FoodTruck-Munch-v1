extends Node
## Day-phase state machine and active-order refs.
##
## Phase flow:  TUTORIAL → PLAYING → END_OF_DAY
##   call start_day() to enter PLAYING and start the countdown Timer.
##   Timer fires _on_day_timeout() → END_OF_DAY + EventBus.day_ended.
##
## active_recipe defaults to default_recipe (wire TacoAlPastor.tres in Inspector).
## Overridden at runtime when EventBus.order_accepted fires (Module 7).

enum DayPhase { TUTORIAL, PLAYING, END_OF_DAY }

@export var day_duration_seconds: float = 300.0
## Wire TacoAlPastor.tres in the Inspector — used until Module 7 NPCs are live.
@export var default_recipe: Recipe = null

var current_phase: DayPhase = DayPhase.TUTORIAL
var active_recipe: Recipe = null
var active_taco: TacoBase = null

var _day_number: int = 1
var _day_timer: Timer


func _ready() -> void:
	active_recipe = default_recipe
	EventBus.order_accepted.connect(_on_order_accepted)
	_day_timer = Timer.new()
	_day_timer.one_shot = true
	_day_timer.timeout.connect(_on_day_timeout)
	add_child(_day_timer)


## Transition to PLAYING and start the day countdown.
## Call this from the title-screen or tutorial-complete handler.
func start_day(day_number: int = 1) -> void:
	_day_number = day_number
	current_phase = DayPhase.PLAYING
	_day_timer.start(day_duration_seconds)
	EventBus.day_started.emit(day_number)


func _on_day_timeout() -> void:
	current_phase = DayPhase.END_OF_DAY
	EventBus.day_ended.emit({
		"day_number": _day_number,
		"balance": EconomyManager.balance,
	})


func _on_order_accepted(_customer_id: int, recipe: Recipe) -> void:
	active_recipe = recipe
