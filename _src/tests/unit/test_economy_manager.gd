extends GutTest
## EconomyManager unit tests.
##
## Tests call handler methods directly — no signal emit — so each case is
## isolated from other listeners on EventBus.  balance is saved/restored
## around each test so the autoload singleton stays clean.

var _saved_balance: float


func before_each() -> void:
	_saved_balance = EconomyManager.balance
	EconomyManager.balance = 5.00


func after_each() -> void:
	EconomyManager.balance = _saved_balance


# ---------------------------------------------------------------------------
# order_completed
# ---------------------------------------------------------------------------

func test_perfect_order_adds_payment_plus_tip() -> void:
	EconomyManager._on_order_completed(3.50, 1.00)
	assert_almost_eq(EconomyManager.balance, 9.50, 0.001)


func test_sloppy_one_flag_adds_payment_plus_half_tip() -> void:
	EconomyManager._on_order_completed(3.50, 0.50)
	assert_almost_eq(EconomyManager.balance, 9.00, 0.001)


func test_sloppy_two_flags_adds_payment_no_tip() -> void:
	EconomyManager._on_order_completed(3.50, 0.00)
	assert_almost_eq(EconomyManager.balance, 8.50, 0.001)


func test_order_completed_emits_balance_changed() -> void:
	watch_signals(EventBus)
	EconomyManager._on_order_completed(3.50, 1.00)
	assert_signal_emitted(EventBus, "balance_changed")
	var p := get_signal_parameters(EventBus, "balance_changed")
	assert_almost_eq(float(p[0]), 9.50, 0.001, "new_balance should be 9.50")
	assert_almost_eq(float(p[1]), 4.50, 0.001, "delta should be 4.50")


# ---------------------------------------------------------------------------
# order_rejected
# ---------------------------------------------------------------------------

func test_rejected_order_deducts_food_cost() -> void:
	EconomyManager._on_order_rejected(0.10)
	assert_almost_eq(EconomyManager.balance, 4.90, 0.001)


func test_rejected_order_emits_balance_changed_with_negative_delta() -> void:
	watch_signals(EventBus)
	EconomyManager._on_order_rejected(0.25)
	assert_signal_emitted(EventBus, "balance_changed")
	var p := get_signal_parameters(EventBus, "balance_changed")
	assert_almost_eq(float(p[1]), -0.25, 0.001, "delta should be negative")


# ---------------------------------------------------------------------------
# customer_left_angry
# ---------------------------------------------------------------------------

func test_angry_customer_deducts_penalty() -> void:
	EconomyManager._on_customer_angry(1.50)
	assert_almost_eq(EconomyManager.balance, 3.50, 0.001)


func test_angry_customer_emits_balance_changed() -> void:
	watch_signals(EventBus)
	EconomyManager._on_customer_angry(1.50)
	assert_signal_emitted(EventBus, "balance_changed")


# ---------------------------------------------------------------------------
# Floor at zero
# ---------------------------------------------------------------------------

func test_balance_cannot_go_negative_on_angry() -> void:
	EconomyManager.balance = 0.00
	EconomyManager._on_customer_angry(99.99)
	assert_eq(EconomyManager.balance, 0.00, "balance floors at 0.00")


func test_balance_cannot_go_negative_on_rejected() -> void:
	EconomyManager.balance = 0.00
	EconomyManager._on_order_rejected(99.99)
	assert_eq(EconomyManager.balance, 0.00, "balance floors at 0.00")


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func test_save_and_load_roundtrip() -> void:
	EconomyManager.balance = 42.75
	EconomyManager.save()
	EconomyManager.balance = 0.00
	EconomyManager.load_data()
	assert_almost_eq(EconomyManager.balance, 42.75, 0.001)
