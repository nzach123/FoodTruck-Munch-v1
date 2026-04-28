class_name PromptComponent
extends Node3D

## The Label3D that renders the world-space hint. Must be a child of this node.
## Billboard mode is enforced in _ready() regardless of Inspector setting.
@export var prompt_label: Label3D
## Text shown when the station is accessible. Format: "[E] Grab Tortilla"
@export var key_hint: StringName
## Text shown when is_locked() is true. Format: "Grab a tortilla first"
@export var locked_hint: StringName
## Leave null to auto-discover the sibling InteractableComponent.
## Set explicitly if the scene tree has multiple InteractableComponents under the same parent.
@export var interactable_override: InteractableComponent


func _ready() -> void:
	visible = false
	if prompt_label:
		# Enforce billboard so the label always faces the camera in world space.
		prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	var ic := _resolve_interactable()
	if ic:
		ic.focused.connect(_on_focused)
		ic.unfocused.connect(_on_unfocused)
	else:
		push_warning("PromptComponent on '%s': no sibling InteractableComponent found." \
				% get_parent().name)


## Makes the prompt visible with the appropriate hint text.
## locked=true shows locked_hint; locked=false shows key_hint.
func show_prompt(locked: bool) -> void:
	visible = true
	if prompt_label:
		prompt_label.text = locked_hint if locked else key_hint


## Hides the prompt and clears the label text.
func hide_prompt() -> void:
	visible = false
	if prompt_label:
		prompt_label.text = ""


func _on_focused(component: InteractableComponent) -> void:
	show_prompt(component.is_locked())


func _on_unfocused() -> void:
	hide_prompt()


## Searches the parent node for the first InteractableComponent child.
## interactable_override takes priority if set.
func _resolve_interactable() -> InteractableComponent:
	if interactable_override:
		return interactable_override
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is InteractableComponent:
			return child as InteractableComponent
	return null
