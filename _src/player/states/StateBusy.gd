class_name StateBusy
extends Node

var _ism: InteractionStateMachine


## Injected by InteractionStateMachine._ready(). Do not call this manually.
func _init_ism(ism: InteractionStateMachine) -> void:
	_ism = ism


func enter() -> void:
	# Nothing should transition here — stations own their transitions.
	# This fires during development if a station forgets to call transition_to().
	push_warning("StateBusy.enter: unexpected transition — a station failed to call transition_to().")


func exit() -> void:
	pass


## StateBusy does not poll input. The active Station script manages its own tick logic
## (e.g. DiscreteCounter press count, TapAccumulate gauge, Timing circle shrink).
## The Station calls _ism.transition_to() when the interaction completes.
func physics_update(_delta: float) -> void:
	pass


## Available for state-level interrupts (e.g. a cancel action).
func handle_input(_event: InputEvent) -> void:
	pass
