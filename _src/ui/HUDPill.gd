class_name HUDPill
extends Panel
## One slot in the order-progress HUD.
##
## State machine: PENDING → ACTIVE → PERFECT | SLOPPY
## Driven entirely by MidnightMunchHUD, which maps ingredient StringNames to
## pill instances and sets .state in response to EventBus.order_step_completed.
##
## AnimationPlayer is optional — wire it in the Inspector.
## The "pulse" animation should loop and modulate alpha 0.5 → 1.0 at 2 Hz.

enum PillState { PENDING, ACTIVE, PERFECT, SLOPPY }

## Set in the Inspector per-pill so MidnightMunchHUD can build its lookup map.
@export var ingredient_id: StringName
## Optional — null-safe throughout.  Wire in Inspector to enable pulse.
@export var animation_player: AnimationPlayer

## Assigning this property applies the visual change immediately.
## GDScript 4: direct assignment inside the setter does NOT recurse.
var state: PillState = PillState.PENDING:
	set(next):
		state = next
		_apply_visual(next)


func _apply_visual(next: PillState) -> void:
	match next:
		PillState.PENDING:
			modulate = Color(0.5, 0.5, 0.5, 1.0)
			if animation_player:
				animation_player.stop()
		PillState.ACTIVE:
			modulate = Color.WHITE
			if animation_player:
				animation_player.play(&"pulse")
		PillState.PERFECT:
			modulate = Color(0.2, 0.9, 0.3, 1.0)
			if animation_player:
				animation_player.stop()
		PillState.SLOPPY:
			modulate = Color(1.0, 0.5, 0.1, 1.0)
			if animation_player:
				animation_player.stop()


func set_ingredient_id(id: StringName) -> void:
	ingredient_id = id
