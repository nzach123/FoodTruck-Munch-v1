class_name InteractionStateMachine
extends Node

## Populate in the Inspector to set explicit state ordering, or leave empty to
## auto-discover all child nodes as states (first child = initial state).
@export var states: Array[Node]

## The InteractableComponent the player is currently aiming at.
## Set each physics tick by Player._update_raycast(). Read by StateIdle.physics_update().
## Player sets this BEFORE ISM._physics_process() runs — scene-tree child ordering guarantees it.
var focused_interactable: InteractableComponent = null

## What the player is currently holding. Set by holding states in enter()/exit().
## Stations read this in prerequisite_check instead of comparing state name strings.
## Values: &"" (empty), &"tortilla", &"meat"
var held_item: StringName = &""

## The station node currently driving a mid-interaction state (e.g. StateTrompo).
## Set by the station before calling transition_to(); cleared in the state's exit().
var active_station: Node = null

## Set by Player._ready(). The Node3D that held TacoBase nodes are reparented under.
## Stations read this instead of traversing the scene tree themselves.
var wieldables_node: Node3D = null
## Set by Player._ready(). TacoBase snaps to this Marker3D's position on checkout.
var hand_anchor: Marker3D = null

var _current_state: Node = null
# StringName → Node lookup; populated in _ready() from state_nodes.
var _state_map: Dictionary = {}


func _ready() -> void:
	# Use the Inspector array when explicitly populated; fall back to child auto-discovery.
	var state_nodes: Array = states if not states.is_empty() else get_children()
	for state in state_nodes:
		_state_map[StringName(state.name)] = state
		# Inject self into each state so states can call transition_to().
		if state.has_method(&"_init_ism"):
			state._init_ism(self)
	if state_nodes.size() > 0:
		_current_state = state_nodes[0]
		_current_state.enter()


func _physics_process(delta: float) -> void:
	if _current_state:
		_current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _current_state:
		_current_state.handle_input(event)


## Exits the current state and enters the named one.
## state_name must exactly match the Node.name of a registered state child.
func transition_to(state_name: StringName) -> void:
	var next: Node = _state_map.get(state_name)
	if next == null:
		push_error("InteractionStateMachine.transition_to: '%s' is not a registered state." \
				% state_name)
		return
	if next == _current_state:
		return  # Already in this state — no-op.
	if _current_state:
		_current_state.exit()
	_current_state = next
	_current_state.enter()


## Returns the Node.name of the currently active state, or "" if none.
func get_current_state_name() -> StringName:
	return StringName(_current_state.name) if _current_state else &""
