extends GutTest
## HUDPill state machine tests.
##
## Instantiates HUDPill directly — no AnimationPlayer wired — so the null
## guard inside _apply_state() must protect every branch.  Colour values are
## tested with a tolerance to allow future palette tweaks without breaking tests.

var _pill: HUDPill


func before_each() -> void:
	_pill = HUDPill.new()
	add_child_autoqfree(_pill)


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_state_is_pending() -> void:
	assert_eq(_pill.state, HUDPill.PillState.PENDING)


# ---------------------------------------------------------------------------
# PENDING
# ---------------------------------------------------------------------------

func test_pending_sets_grey_modulate() -> void:
	_pill.state = HUDPill.PillState.ACTIVE   # move away first
	_pill.state = HUDPill.PillState.PENDING
	assert_almost_eq(_pill.modulate.r, 0.5, 0.05)
	assert_almost_eq(_pill.modulate.g, 0.5, 0.05)
	assert_almost_eq(_pill.modulate.b, 0.5, 0.05)


# ---------------------------------------------------------------------------
# ACTIVE
# ---------------------------------------------------------------------------

func test_active_sets_white_modulate() -> void:
	_pill.state = HUDPill.PillState.ACTIVE
	assert_almost_eq(_pill.modulate.r, 1.0, 0.05)
	assert_almost_eq(_pill.modulate.g, 1.0, 0.05)
	assert_almost_eq(_pill.modulate.b, 1.0, 0.05)


# ---------------------------------------------------------------------------
# PERFECT
# ---------------------------------------------------------------------------

func test_perfect_sets_green_dominant_modulate() -> void:
	_pill.state = HUDPill.PillState.PERFECT
	assert_gt(_pill.modulate.g, 0.7, "green channel should dominate")
	assert_lt(_pill.modulate.r, 0.5, "red should not dominate")


# ---------------------------------------------------------------------------
# SLOPPY
# ---------------------------------------------------------------------------

func test_sloppy_sets_orange_modulate() -> void:
	_pill.state = HUDPill.PillState.SLOPPY
	assert_gt(_pill.modulate.r, 0.7, "red channel should dominate for orange")
	assert_lt(_pill.modulate.b, 0.5, "blue should be low for orange")


# ---------------------------------------------------------------------------
# Transitions
# ---------------------------------------------------------------------------

func test_can_transition_pending_to_active() -> void:
	_pill.state = HUDPill.PillState.ACTIVE
	assert_eq(_pill.state, HUDPill.PillState.ACTIVE)


func test_can_transition_active_to_perfect() -> void:
	_pill.state = HUDPill.PillState.ACTIVE
	_pill.state = HUDPill.PillState.PERFECT
	assert_eq(_pill.state, HUDPill.PillState.PERFECT)


func test_can_transition_active_to_sloppy() -> void:
	_pill.state = HUDPill.PillState.ACTIVE
	_pill.state = HUDPill.PillState.SLOPPY
	assert_eq(_pill.state, HUDPill.PillState.SLOPPY)


func test_can_reset_to_pending_from_any_state() -> void:
	for s in [HUDPill.PillState.ACTIVE, HUDPill.PillState.PERFECT, HUDPill.PillState.SLOPPY]:
		_pill.state = s
		_pill.state = HUDPill.PillState.PENDING
		assert_eq(_pill.state, HUDPill.PillState.PENDING,
				"should reset from state %d" % s)


# ---------------------------------------------------------------------------
# ingredient_id setter
# ---------------------------------------------------------------------------

func test_set_ingredient_id() -> void:
	_pill.set_ingredient_id(&"cilantro")
	assert_eq(_pill.ingredient_id, &"cilantro")


func test_ingredient_id_is_empty_by_default() -> void:
	assert_eq(_pill.ingredient_id, &"")
