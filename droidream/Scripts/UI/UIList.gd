extends Control
class_name UIList

# A vertical list of UIRow with one selected row; it owns the selection and visuals, the owner routes input (move, confirm)

signal selected_changed(index: int)
signal confirmed(index: int)

@export var max_visible_rows := 6 # More rows than this scroll
@export var row_height := UIRow.ROW_HEIGHT # Taller rows for bigger text
@export var font_size := UIRow.FONT_SIZE
@export var bold := false
@export var min_width := 0.0 # Rows are at least this wide
@export var center_text := false # Rows center their text
@export var ignore_time_scale := false # True for menus that keep animating while the game is frozen (the pause menu)
@export var play_sounds := true # Moving and confirming play the menu sounds (owners that judge a confirm themselves turn this off)

const TRAVEL_TIME := 0.12

var cursor: UICursor
var cursor_row := 0.0 # Where the cursor is, in rows (it travels between rows)
var cursor_tween: Tween
var rows: Array[UIRow] = []
var selected_index := 0
var scroll_row := 0.0 # First visible row (rows move up by this)
var scroll_tween: Tween

func _init() -> void:
	cursor = UICursor.new()
	add_child(cursor)

# Colors the highlight bar
func set_bar_color(color: Color) -> void:
	cursor.bar_color = color
	cursor.queue_redraw()

# Replaces all rows; each entry is a Dictionary with icon, text, right (optional) and pips, pips_dim (optional)
func set_rows(entries: Array) -> void:
	for row in rows:
		row.queue_free()
	rows.clear()
	
	for entry in entries:
		var row := UIRow.new()
		row.ignore_time_scale = ignore_time_scale
		row.center_text = center_text
		row.row_height = row_height
		row.font_size = font_size
		row.bold = bold
		row.setup(entry.get("icon"), entry.get("text", ""), entry.get("right", ""), entry.get("pips", 0), entry.get("pips_dim", 0), entry.get("pips_dim_end", false))
		add_child(row)
		rows.append(row)
	
	selected_index = clampi(selected_index, 0, maxi(rows.size() - 1, 0))
	cursor_row = selected_index
	_layout()
	_refresh_selection(false)

# Updates existing rows in place (same count) so a list that is open keeps its selection
func update_rows(entries: Array) -> void:
	if entries.size() != rows.size():
		set_rows(entries)
		return
	for i in rows.size():
		var entry: Dictionary = entries[i]
		rows[i].setup(entry.get("icon"), entry.get("text", ""), entry.get("right", ""), entry.get("pips", 0), entry.get("pips_dim", 0), entry.get("pips_dim_end", false))
	_layout()

func count() -> int:
	return rows.size()

# Moves the selection by dir (wraps around)
func move(dir: int) -> void:
	if rows.is_empty():
		return
	if rows.size() > 1 and play_sounds:
		Sfx.play_ui("option_move")
	select(wrapi(selected_index + dir, 0, rows.size()))

# Selects a row by index
func select(index: int, animate := true) -> void:
	if rows.is_empty():
		selected_index = 0
		return
	selected_index = clampi(index, 0, rows.size() - 1)
	_refresh_selection(animate)
	selected_changed.emit(selected_index)

# Confirms the selected row
func confirm() -> void:
	if not rows.is_empty():
		if play_sounds:
			Sfx.play_ui("option_select")
		confirmed.emit(selected_index)

# Size the list needs: the widest row by the visible rows
func get_wanted_size() -> Vector2:
	var width := min_width
	for row in rows:
		width = maxf(width, row.get_wanted_width())
	return Vector2(width, mini(rows.size(), max_visible_rows) * row_height)

# Y of the selected row inside the list (for placing a popup next to it)
func get_selected_row_y() -> float:
	return (selected_index - scroll_row) * row_height

# Places the rows and sizes the list
func _layout() -> void:
	var wanted := get_wanted_size()
	custom_minimum_size = wanted
	size = wanted
	clip_contents = rows.size() > max_visible_rows
	cursor.size = Vector2(wanted.x, row_height)
	cursor.visible = not rows.is_empty()
	_place_cursor()
	for i in rows.size():
		rows[i].size = Vector2(wanted.x, row_height)
		rows[i].position = Vector2(0, (i - scroll_row) * row_height)

# Applies the selected look and keeps the selected row inside the visible window
func _refresh_selection(animate: bool) -> void:
	for i in rows.size():
		rows[i].set_selected(i == selected_index, animate and rows[i].is_inside_tree())
	_travel_cursor(animate)
	
	var target_scroll := scroll_row
	if selected_index < scroll_row:
		target_scroll = selected_index
	elif selected_index > scroll_row + max_visible_rows - 1:
		target_scroll = selected_index - max_visible_rows + 1
	target_scroll = clampf(target_scroll, 0.0, maxf(rows.size() - max_visible_rows, 0.0))
	_scroll_to(target_scroll, animate)

func _scroll_to(target: float, animate: bool) -> void:
	if scroll_tween:
		scroll_tween.kill()
	if animate and is_inside_tree():
		scroll_tween = create_tween().set_ignore_time_scale(ignore_time_scale)
		scroll_tween.tween_method(_set_scroll, scroll_row, target, 0.1)
	else:
		_set_scroll(target)

func _set_scroll(value: float) -> void:
	scroll_row = value
	for i in rows.size():
		rows[i].position.y = (i - scroll_row) * row_height
	_place_cursor()

# Moves the cursor to the selected row (eased, with a small overshoot)
func _travel_cursor(animate: bool) -> void:
	if cursor_tween:
		cursor_tween.kill()
	if animate and is_inside_tree():
		cursor_tween = create_tween().set_ignore_time_scale(ignore_time_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cursor_tween.tween_method(_set_cursor_row, cursor_row, float(selected_index), TRAVEL_TIME)
	else:
		_set_cursor_row(float(selected_index))

func _set_cursor_row(value: float) -> void:
	cursor_row = value
	_place_cursor()

# The cursor follows its row on screen, also while the list scrolls
func _place_cursor() -> void:
	cursor.position = Vector2(0, (cursor_row - scroll_row) * row_height)
