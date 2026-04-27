class_name DebugOverlay
extends CanvasLayer

const FPS_INTERVAL: float = 0.5

var _lbl_fps: Label
var _lbl_ism: Label
var _lbl_held: Label
var _lbl_quality: Label
var _lbl_locked: Label
var _pool_container: VBoxContainer
# Pool key (scene basename) → Label; new entries created lazily, never destroyed.
var _pool_labels: Dictionary = {}

var _fps_timer: float = 0.0
var _last_quality_str: String = "—"
var _last_locked_str: String = "—"


func _ready() -> void:
	layer = 10
	visible = false  # Player._unhandled_input toggles this via F3
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8.0, 8.0)

	var root_vbox := VBoxContainer.new()
	panel.add_child(root_vbox)

	_add_label(root_vbox, "=== MIDNIGHT MUNCH DEBUG ===")
	_lbl_fps     = _add_label(root_vbox, "FPS: —")
	_lbl_ism     = _add_label(root_vbox, "ISM State: —")
	_lbl_held    = _add_label(root_vbox, "Held Item: —")
	_lbl_quality = _add_label(root_vbox, "Last Quality: —")
	_lbl_locked  = _add_label(root_vbox, "Last Locked: —")

	root_vbox.add_child(HSeparator.new())
	_add_label(root_vbox, "— Pool Stats —")
	_pool_container = VBoxContainer.new()
	root_vbox.add_child(_pool_container)


func _add_label(parent: Control, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	parent.add_child(lbl)
	return lbl


func _connect_signals() -> void:
	EventBus.order_step_completed.connect(_on_order_step_completed)
	EventBus.station_locked_attempt.connect(_on_station_locked)


func _process(delta: float) -> void:
	if not visible:
		return
	_fps_timer += delta
	if _fps_timer >= FPS_INTERVAL:
		_fps_timer = 0.0
		_refresh()


func _refresh() -> void:
	_lbl_fps.text     = "FPS: %d" % Engine.get_frames_per_second()
	_lbl_quality.text = "Last Quality: %s" % _last_quality_str
	_lbl_locked.text  = "Last Locked: %s" % _last_locked_str
	_refresh_pool_stats()


func _refresh_pool_stats() -> void:
	for stat: Dictionary in NodePool.get_stats():
		var key: String = stat["name"]
		if not _pool_labels.has(key):
			# First appearance of this pool type — create its label once.
			_pool_labels[key] = _add_label(_pool_container, "")
		(_pool_labels[key] as Label).text = \
				"%s  active: %d  free: %d" % [key, stat["active"], stat["free"]]


func _on_order_step_completed(ingredient: StringName, quality: int) -> void:
	_lbl_held.text = "Held Item: %s" % ingredient
	_last_quality_str = "Perfect (0)" if quality == 0 else "Sloppy (1)"


func _on_station_locked(station_id: StringName, reason: String) -> void:
	_last_locked_str = "%s — %s" % [station_id, reason]
