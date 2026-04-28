class_name MidnightMunchHUD
extends CanvasLayer
## Top-level HUD: balance label + order-progress pill strip.
##
## Scene setup (editor only):
##   MidnightMunchHUD (CanvasLayer, layer = 5)
##   └─ VBoxContainer
##      ├─ BalanceLabel     (Label)         ← wire to @export balance_label
##      └─ PillContainer    (HBoxContainer) ← wire to @export pill_container
##         ├─ HUDPill  ingredient_id="tortilla"
##         ├─ HUDPill  ingredient_id="meat"
##         ├─ HUDPill  ingredient_id="cilantro"
##         ├─ HUDPill  ingredient_id="tomato"
##         ├─ HUDPill  ingredient_id="onion"
##         ├─ HUDPill  ingredient_id="white_sauce"
##         └─ HUDPill  ingredient_id="red_sauce"
##
## Signal flow (no new EventBus signals needed):
##   order_step_completed("tortilla", …) → reset_for_new_order (tortilla always first)
##   order_step_completed(any, quality)  → pill goes PERFECT or SLOPPY
##   order_completed(payment, tip)       → all pills back to PENDING
##   balance_changed(new_balance, delta) → balance_label text

@export var balance_label: Label
@export var pill_container: HBoxContainer

## ingredient_id → HUDPill; built once in _ready() from pill_container children.
var _pill_map: Dictionary = {}


func _ready() -> void:
	_build_pill_map()
	EventBus.order_step_completed.connect(_on_order_step_completed)
	EventBus.order_completed.connect(_on_order_completed)
	EventBus.balance_changed.connect(_on_balance_changed)
	_refresh_balance(EconomyManager.balance)


func _build_pill_map() -> void:
	if pill_container == null:
		push_warning("MidnightMunchHUD: pill_container not wired — pills disabled")
		return
	for child: Node in pill_container.get_children():
		var pill := child as HUDPill
		if pill == null or pill.ingredient_id == &"":
			continue
		_pill_map[pill.ingredient_id] = pill


## Reset pills to match a new recipe: required → ACTIVE, all others → PENDING.
## Called internally when "tortilla" step completes (tortilla is always step 1).
## Also callable externally for Module 7 (order_accepted path).
func reset_for_new_order(recipe: Recipe) -> void:
	for pill: HUDPill in _pill_map.values():
		pill.state = HUDPill.PillState.PENDING
	if recipe == null:
		return
	for id: StringName in recipe.required_ingredients:
		if _pill_map.has(id):
			(_pill_map[id] as HUDPill).state = HUDPill.PillState.ACTIVE


## Called by EventBus.order_step_completed.
## "tortilla" arriving means a new order has started — trigger a full reset first.
func _on_order_step_completed(ingredient: StringName, quality: int, _food_cost: float) -> void:
	if ingredient == &"tortilla":
		reset_for_new_order(GameManager.active_recipe)
	if not _pill_map.has(ingredient):
		return
	var pill := _pill_map[ingredient] as HUDPill
	pill.state = HUDPill.PillState.PERFECT if quality == 0 else HUDPill.PillState.SLOPPY


## Called by EventBus.order_completed — clear pills after an order is served.
func _on_order_completed(_payment: float, _tip: float) -> void:
	for pill: HUDPill in _pill_map.values():
		pill.state = HUDPill.PillState.PENDING


## Called by EventBus.balance_changed.
func _on_balance_changed(new_balance: float, _delta: float) -> void:
	_refresh_balance(new_balance)


func _refresh_balance(amount: float) -> void:
	if balance_label:
		balance_label.text = "$%.2f" % amount
