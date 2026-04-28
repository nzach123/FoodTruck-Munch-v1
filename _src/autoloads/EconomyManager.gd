extends Node
## Ledger autoload.  Owns the player balance, connects to all money-flow signals,
## and persists state to user://save.json (< 4 KB budget).
##
## Signal flow (read-only from outside — write via EventBus signals):
##   EventBus.order_completed(payment, tip)   → balance += payment + tip
##   EventBus.order_rejected(food_cost)       → balance -= food_cost
##   EventBus.customer_left_angry(penalty)    → balance -= penalty
##   All three → EventBus.balance_changed(new_balance, delta)

var balance: float = 5.00


func _ready() -> void:
	EventBus.order_completed.connect(_on_order_completed)
	EventBus.order_rejected.connect(_on_order_rejected)
	EventBus.customer_left_angry.connect(_on_customer_angry)


# ---------------------------------------------------------------------------
# Signal handlers (underscore prefix = internal; callable directly in tests)
# ---------------------------------------------------------------------------

func _on_order_completed(payment: float, tip: float) -> void:
	var delta := payment + tip
	balance += delta
	EventBus.balance_changed.emit(balance, delta)


func _on_order_rejected(food_cost: float) -> void:
	_deduct(food_cost)


func _on_customer_angry(penalty: float) -> void:
	_deduct(penalty)


func _deduct(amount: float) -> void:
	var delta := -amount
	balance = maxf(0.0, balance + delta)
	EventBus.balance_changed.emit(balance, delta)


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func save() -> void:
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	if file == null:
		push_error("EconomyManager: save failed — %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({"balance": balance}))
	file.close()


func load_data() -> void:
	if not FileAccess.file_exists("user://save.json"):
		return
	var file := FileAccess.open("user://save.json", FileAccess.READ)
	if file == null:
		push_error("EconomyManager: load failed — %s" % error_string(FileAccess.get_open_error()))
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has("balance"):
		balance = float(parsed["balance"])
