extends Control
class_name EncounterCounter

# A row of pips in the top right of the HUD that shows which encounter of the stage run the player is on: cleared pips are filled, the current one is larger and pulses, the last one is a flag

const SPACING := 14.0 # Distance between two pip centers
const PIP := 6.0 # Size of a normal pip
const CURRENT_PIP := 8.0 # Size of the current pip
const LINE_COLOR := Color(1, 1, 1, 0.35)
const DONE_COLOR := Color(1, 1, 1, 1)
const TODO_COLOR := Color(0.55, 0.55, 0.6, 1)
const FLAG_COLOR := Color("#ffd24a") # The end of the run stands out
const OUTLINE := Color(0, 0, 0, 0.85)
const POP_TIME := 0.22
const PULSE_SPEED := 4.0

var count := 5 # Encounters in the area (the last pip is the flag)
var index := 0 # The current encounter (0 is the first)
var pop_index := -1 # The pip that just got filled
var pop := 1.0 # 0 to 1, how far its pop has come
var grow := 1.0 # 0 to 1, how far the new current pip has grown
var tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _row_size()
	size = _row_size()

# Width of the row for the current count (the pips, plus room for the bigger current pip)
func _row_size() -> Vector2:
	return Vector2((count - 1) * SPACING + CURRENT_PIP + 2.0, 12.0)

# Sets how many encounters the row shows; the row keeps its right edge where it is
func set_count(new_count: int) -> void:
	if new_count == count or new_count < 1:
		return
	var right := position.x + size.x
	count = new_count
	custom_minimum_size = _row_size()
	size = _row_size()
	position.x = right - size.x
	queue_redraw()

# Shows the encounter the player is on; moving forward plays the fill and grow animation, anything else just snaps
func set_progress(new_index: int, animate := true) -> void:
	new_index = clampi(new_index, 0, count - 1)
	if tween:
		tween.kill()
	if animate and new_index == index + 1:
		pop_index = index
		pop = 0.0
		grow = 0.0
		index = new_index
		tween = create_tween().set_parallel(true)
		tween.tween_property(self, "pop", 1.0, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "grow", 1.0, POP_TIME).set_delay(POP_TIME * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		index = new_index
		pop_index = -1
		pop = 1.0
		grow = 1.0
	queue_redraw()

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	var center_y := _row_size().y * 0.5
	var first_x := CURRENT_PIP * 0.5 + 1.0
	draw_line(Vector2(first_x, center_y), Vector2(first_x + (count - 1) * SPACING, center_y), LINE_COLOR, 1.0)

	for i in count:
		var center := Vector2(first_x + i * SPACING, center_y).round()
		var is_last := i == count - 1
		if i < index:
			# Cleared; the one that just got filled pops
			var scale_now := 1.0 + (0.5 * sin(pop * PI) if i == pop_index else 0.0)
			_draw_pip(center, PIP * scale_now, true, is_last, i == pop_index and pop < 1.0)
		elif i == index:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED)
			var current_size := lerpf(PIP, CURRENT_PIP, grow) + roundf(pulse)
			_draw_pip(center, current_size, false, is_last, true)
		else:
			_draw_pip(center, PIP, false, is_last, false)

# A square pip with a dark outline (the last pip is a flag): filled when cleared, hollow when not, with a white frame when it is the current one
func _draw_pip(center: Vector2, pip_size: float, filled: bool, flag: bool, highlight: bool) -> void:
	var half := roundf(pip_size * 0.5)
	if flag:
		_draw_flag(center, half, filled, highlight)
		return
	var rect := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
	draw_rect(rect.grow(1.0), OUTLINE)
	if filled:
		draw_rect(rect, DONE_COLOR)
	else:
		draw_rect(rect, Color(0.12, 0.12, 0.16, 1))
		draw_rect(rect, DONE_COLOR if highlight else TODO_COLOR, false, 1.0)

# The last encounter: a flag on a pole, gold once reached and outlined while it is still ahead
func _draw_flag(center: Vector2, half: float, filled: bool, highlight: bool) -> void:
	var color := FLAG_COLOR if (filled or highlight) else TODO_COLOR
	var top := center + Vector2(-half + 1.0, -half - 1.0)
	var bottom := center + Vector2(-half + 1.0, half + 1.0)
	draw_line(top + Vector2(0, -1), bottom + Vector2(0, 1), OUTLINE, 3.0)
	draw_line(top, bottom, color, 1.0)
	var flag := PackedVector2Array([top, top + Vector2(half * 2.0 + 1.0, half * 0.7), top + Vector2(0, half * 1.4)])
	draw_colored_polygon(flag, color if (filled or highlight) else Color(0.12, 0.12, 0.16, 1))
	draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), color if not (filled or highlight) else OUTLINE, 1.0)
