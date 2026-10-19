extends Control
class_name UIList

# A vertical list of UIRow with one selected row; it owns the selection and visuals, the owner routes input (move, confirm)

signal selected_changed(index: int)
signal confirmed(index: int)

@export var max_visible_rows := 6 # More rows than this scroll
@export var bar_color := Color(1, 1, 1, 0.22)

var rows: Array[UIRow] = []
var selected_index := 0
var scroll_row := 0.0 # First visible row (rows move up by this)
var scroll_tween: Tween

# Replaces all rows; each entry is a Dictionary with icon, text, right (optional) and pips, pips_dim (optional)
func set_rows(entries: Array) -> void:
	for row in rows:
		row.queue_free()
	rows.clear()
	
	for entry in entries:
		var row := UIRow.new()
		row.bar_color = bar_color
		row.setup(entry.get("icon"), entry.get("text", ""), entry.get("right", ""), entry.get("pips", 0), entry.get("pips_dim", 0))
		add_child(row)
		rows.append(row)
	
	selected_index = clampi(selected_index, 0, maxi(rows.size() - 1, 0))
	_layout()
	_refresh_selection(false)

# Updates existing rows in place (same count) so a list that is open keeps its selection
func update_rows(entries: Array) -> void:
	if entries.size() != rows.size():
		set_rows(entries)
		return
	for i in rows.size():
		var entry: Dictionary = entries[i]
		rows[i].setup(entry.get("icon"), entry.get("text", ""), entry.get("right", ""), entry.get("pips", 0), entry.get("pips_dim", 0))
	_layout()

func count() -> int:
	return rows.size()

# Moves the selection by dir (wraps around)
func move(dir: int) -> void:
	if rows.is_empty():
		return
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
		confirmed.emit(selected_index)

# Size the list needs: the widest row by the visible rows
func get_wanted_size() -> Vector2:
	var width := 0.0
	for row in rows:
		width = maxf(width, row.get_wanted_width())
	return Vector2(width, mini(rows.size(), max_visible_rows) * UIRow.ROW_HEIGHT)

# Y of the selected row inside the list (for placing a popup next to it)
func get_selected_row_y() -> float:
	return (selected_index - scroll_row) * UIRow.ROW_HEIGHT

# Places the rows and sizes the list
func _layout() -> void:
	var wanted := get_wanted_size()
	custom_minimum_size = wanted
	size = wanted
	clip_contents = rows.size() > max_visible_rows
	for i in rows.size():
		rows[i].size = Vector2(wanted.x, UIRow.ROW_HEIGHT)
		rows[i].position = Vector2(0, (i - scroll_row) * UIRow.ROW_HEIGHT)

# Applies the selected look and keeps the selected row inside the visible window
func _refresh_selection(animate: bool) -> void:
	for i in rows.size():
		rows[i].set_selected(i == selected_index, animate and rows[i].is_inside_tree())
	
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
		scroll_tween = create_tween()
		scroll_tween.tween_method(_set_scroll, scroll_row, target, 0.1)
	else:
		_set_scroll(target)

func _set_scroll(value: float) -> void:
	scroll_row = value
	for i in rows.size():
		rows[i].position.y = (i - scroll_row) * UIRow.ROW_HEIGHT
