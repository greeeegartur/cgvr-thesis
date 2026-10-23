extends CanvasLayer
class_name OptionsMenu

# The Options container used by the title screen and the pause menu: audio sliders, camera shake, minigame countdown and easier timing toggles, and the Controls page

signal closed

enum Page { MAIN, CONTROLS }

const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const MIN_WIDTH := 190.0
const LIST_WIDTH := 224.0 # Rows are always this wide, so the list never changes size when a value changes (On / Off, the slider)
const PIP_COUNT := 10
const ACTION_NAMES := {
	"ui_up": "Up", "ui_down": "Down", "ui_left": "Left", "ui_right": "Right",
	"ui_accept": "Confirm", "ui_cancel": "Cancel", "toggle_turn_order": "Turn order"
}
const OPEN_TIME := 0.18
const ARROW_NAMES := { "ui_up": "Up", "ui_down": "Down", "ui_left": "Left", "ui_right": "Right", "ui_accept": "Z", "ui_cancel": "X", "toggle_turn_order": "C" }
const WASD_NAMES := { "ui_up": "W", "ui_down": "S", "ui_left": "A", "ui_right": "D", "ui_accept": "LMB", "ui_cancel": "RMB", "toggle_turn_order": "E" }
const COLUMN_TITLES := ["Arrows", "WASD", "Custom"]

var is_open := false
var muffled_close := true # Leaving plays the muffled close (in the game); the title uses the normal back sound, like its Play popup
var page := Page.MAIN
var capturing := ""  # The action whose key is being chosen ("" when not capturing)
var dim: ColorRect
var panel: UIPanel
var title: Label
var note: Label
var list: UIList
var header: Control # The column titles over the Controls table
var hint: HBoxContainer
var hint_size := Vector2.ZERO
var open_tween: Tween
var note_tween: Tween

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	
	panel = UIPanel.new()
	add_child(panel)
	
	title = _make_label(32, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	
	note = _make_label(16, false)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(note)
	
	list = UIList.new()
	list.ignore_time_scale = true
	list.max_visible_rows = 9 # The custom keys page has 9 rows
	list.min_width = LIST_WIDTH
	list.confirmed.connect(_on_confirmed)
	list.clicked.connect(_on_clicked)
	panel.add_child(list)
	
	header = Control.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for column_title in COLUMN_TITLES:
		var cell := _make_label(16, true)
		cell.text = column_title
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.size = Vector2(UIRow.COLUMN_WIDTH, 18)
		header.add_child(cell)
	panel.add_child(header)
	
	hint = HBoxContainer.new()
	hint.add_theme_constant_override("separation", 16)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hint)

func _make_label(size: int, bold: bool) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT_BOLD if bold else UIRow.FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6 if bold else 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# Opens on the main page; use_dim darkens what is behind (the title screen), the pause menu already dims its own world
func open(use_dim := true) -> void:
	dim.visible = use_dim
	is_open = true
	visible = true
	_show_main()
	if open_tween:
		open_tween.kill()
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	dim.modulate.a = 0.0
	open_tween = create_tween().set_ignore_time_scale(true).set_parallel()
	open_tween.tween_property(panel, "modulate:a", 1.0, OPEN_TIME)
	open_tween.tween_property(panel, "scale", Vector2.ONE, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(dim, "modulate:a", 1.0, OPEN_TIME)

func close() -> void:
	is_open = false # Input stops being taken at once
	if open_tween:
		open_tween.kill()
	open_tween = create_tween().set_ignore_time_scale(true).set_parallel()
	open_tween.tween_property(panel, "modulate:a", 0.0, OPEN_TIME)
	open_tween.tween_property(dim, "modulate:a", 0.0, OPEN_TIME)
	await open_tween.finished
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	get_viewport().set_input_as_handled()
	
	# Choosing a key for an action takes the next key press
	if capturing != "":
		if event is InputEventKey and event.pressed and not event.echo:
			_capture_key(event)
		return
	
	if event is InputEventKey and event.echo and not (event.is_action("ui_left") or event.is_action("ui_right")):
		return
	
	# The mouse wheel over a slider steps it
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var row := list._row_at(list.get_global_mouse_position())
		if page == Page.MAIN and row in [0, 1]:
			if row != list.selected_index:
				list.select(row)
			_adjust(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		return
	
	if event.is_action_pressed("ui_up"):
		list.move(-1)
	elif event.is_action_pressed("ui_down"):
		list.move(1)
	elif event.is_action_pressed("ui_left", true):
		_adjust(-1)
	elif event.is_action_pressed("ui_right", true):
		_adjust(1)
	elif event.is_action_pressed("ui_accept"):
		list.confirm()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_back()

# PAGES
func _show_main() -> void:
	page = Page.MAIN
	_fill("Options", "", _main_entries(), 0, [["Z", "Confirm"], ["X", "Back"]])

func _main_entries() -> Array:
	return [
		{ "text": "Music", "pips": PIP_COUNT, "pips_dim": PIP_COUNT - Settings.music, "pips_dim_end": true },
		{ "text": "SFX", "pips": PIP_COUNT, "pips_dim": PIP_COUNT - Settings.sfx, "pips_dim_end": true },
		{ "text": "Camera shake", "right": _on_off(Settings.camera_shake) },
		{ "text": "Minigame countdown", "right": _on_off(Settings.minigame_countdown) },
		{ "text": "Easier timing", "right": _on_off(Settings.easier_timing) },
		{ "text": "Fullscreen", "right": _on_off(Settings.fullscreen) },
		{ "text": "Controls" },
		{ "text": "Back" }
	]

func _show_controls(selected := 0) -> void:
	page = Page.CONTROLS
	_fill("Controls", "", _controls_entries(), selected, [["Z", "Change key"], ["X", "Back"]])

# One row per action: its arrows key, its WASD / mouse key and its custom key (the one being chosen shows "...")
func _controls_entries() -> Array:
	var entries := []
	for action in Settings.CONTROL_ACTIONS:
		var custom := "..." if capturing == action else (Settings.key_name(Settings.custom_keys[action]) if Settings.custom_keys.has(action) else "-")
		entries.append({ "text": ACTION_NAMES[action], "columns": [ARROW_NAMES[action], WASD_NAMES[action], custom] })
	entries.append({ "text": "Reset custom controls" })
	entries.append({ "text": "Back" })
	return entries

# Fills the panel for a page and sizes and centers it
func _fill(title_text: String, note_text: String, entries: Array, selected: int, hints: Array) -> void:
	if note_tween:
		note_tween.kill()
	title.text = title_text
	note.text = note_text
	note.modulate.a = 1.0
	list.set_rows(entries)
	list.select(selected, false)
	_set_hint(hints)
	_layout()

func _layout() -> void:
	var title_size := title.get_minimum_size()
	var note_size := note.get_minimum_size() if note.text != "" else Vector2.ZERO
	var list_size := list.size
	var width := maxf(MIN_WIDTH, maxf(title_size.x, maxf(note_size.x, maxf(list_size.x, hint_size.x))))
	
	var y := 0.0
	title.position = Vector2(0, y)
	title.size = Vector2(width, title_size.y)
	y += title_size.y + 6.0
	note.visible = note.text != ""
	if note.text != "":
		note.position = Vector2(0, y)
		note.size = Vector2(width, note_size.y)
		y += note_size.y + 4.0
	header.visible = page == Page.CONTROLS
	if header.visible: # Over the columns, which end where the rows' content ends (unselected rows)
		header.position = Vector2((width - list_size.x) / 2.0, y)
		var columns_end := list_size.x - UIRow.SLIDE - UIRow.RIGHT_PAD
		for i in header.get_child_count():
			header.get_child(i).position = Vector2(columns_end - (COLUMN_TITLES.size() - i) * UIRow.COLUMN_WIDTH, 0)
		y += 18.0
	list.position = Vector2((width - list_size.x) / 2.0, y)
	y += list_size.y + 10.0
	hint.size = Vector2(width, hint_size.y)
	hint.position = Vector2(0, y)
	y += hint_size.y
	
	panel.fit_to(Vector2(width, y))
	var origin := panel.content_origin()
	title.position += origin
	note.position += origin
	list.position += origin
	header.position += origin
	hint.position += origin
	
	var screen := get_viewport().get_visible_rect().size
	panel.position = ((screen - panel.size) / 2.0).round()
	panel.pivot_offset = panel.size / 2.0

func _set_hint(pairs: Array) -> void:
	for child in hint.get_children():
		hint.remove_child(child)
		child.queue_free()
	hint_size = Vector2.ZERO
	for pair in pairs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := KeyIcon.new()
		icon.setup(pair[0], 1.5)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(icon)
		var word := _make_label(16, false)
		word.text = pair[1]
		item.add_child(word)
		hint.add_child(item)
		hint_size.x += icon.custom_minimum_size.x + 5.0 + word.get_minimum_size().x + (16.0 if hint_size.x > 0.0 else 0.0)
		hint_size.y = maxf(hint_size.y, maxf(icon.custom_minimum_size.y, word.get_minimum_size().y))

# ACTIONS
func _on_off(value: bool) -> String:
	return "On" if value else "Off"

# Left / Right: sliders move one step, toggles switch
func _adjust(direction: int) -> void:
	if page != Page.MAIN:
		return
	match list.selected_index:
		0:
			Settings.set_music(Settings.music + direction)
		1:
			Settings.set_sfx(Settings.sfx + direction)
		2:
			Settings.set_camera_shake(not Settings.camera_shake)
		3:
			Settings.set_minigame_countdown(not Settings.minigame_countdown)
		4:
			Settings.set_easier_timing(not Settings.easier_timing)
		5:
			Settings.set_fullscreen(not Settings.fullscreen)
		_:
			return
	# Sliders play the move sound at their new level (the SFX slider is heard right away), toggles click like a confirm
	Sfx.play_ui("option_move" if list.selected_index <= 1 else "option_select")
	list.update_rows(_main_entries())

func _on_confirmed(index: int) -> void:
	match page:
		Page.MAIN:
			match index:
				2, 3, 4, 5:
					_adjust(1)
				6:
					_show_controls()
				7:
					_back()
		Page.CONTROLS:
			var actions: Array = Settings.CONTROL_ACTIONS
			if index < actions.size():
				_start_capture(actions[index])
			elif index == actions.size():
				Settings.reset_controls()
				list.update_rows(_controls_entries())
			else:
				_back()

# A click on a volume pip sets that step (the first pip mutes when the volume is already on it)
func _on_clicked(index: int) -> void:
	if page != Page.MAIN or index > 1:
		return
	var pips: Array = list.rows[index].pip_box.get_children()
	for i in pips.size():
		if pips[i].get_global_rect().grow(1.0).has_point(list.get_global_mouse_position()):
			var current := Settings.music if index == 0 else Settings.sfx
			var step := 0 if i == 0 and current == 1 else i + 1
			if index == 0:
				Settings.set_music(step)
			else:
				Settings.set_sfx(step)
			Sfx.play_ui("option_move")
			list.update_rows(_main_entries())
			return

func _back() -> void:
	if page == Page.MAIN and muffled_close:
		Sfx.play_menu_close() # Leaving the options is a muffled close
	else:
		Sfx.play_cancel()
	match page:
		Page.MAIN:
			close()
		Page.CONTROLS:
			_show_main()
			list.select(6, false)

# KEY CAPTURE
func _start_capture(action: String) -> void:
	capturing = action
	list.update_rows(_controls_entries())
	_show_note("Press a key for %s (ESC cancels)" % ACTION_NAMES[action], 0.0)

func _capture_key(event: InputEventKey) -> void:
	Sfx.play_ui("option_select")
	var action := capturing
	capturing = ""
	_show_note("", 0.0)
	var accepted := event.physical_keycode == KEY_ESCAPE or Settings.set_custom_key(action, event.physical_keycode)
	list.update_rows(_controls_entries())
	if not accepted:
		_show_note("That key is reserved", 1.4)

# A short note under the title (empty text clears it); seconds 0 keeps it until something else changes
func _show_note(text: String, seconds: float) -> void:
	note.text = text
	note.modulate.a = 1.0
	_layout()
	if note_tween:
		note_tween.kill()
	if seconds > 0.0:
		note_tween = create_tween().set_ignore_time_scale(true)
		note_tween.tween_interval(seconds)
		note_tween.tween_callback(func(): note.text = ""; _layout())
