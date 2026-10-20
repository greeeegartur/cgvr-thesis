extends Node2D
class_name ShopBubble

# Tuh-U's speech bubble in the shop: a white pixel bubble with a black outline and a small tail, drawn in code and sized to the line; it keeps a gentle bob

const FONT := preload("res://Graphics/Fonts/PixelOperator.ttf")
const ANCHOR := Vector2(545, 92) # The bubble's bottom-right corner: it grows up and to the left from here, in the free band above the items
const WIDTHS := [64.0, 80.0, 100.0, 120.0, 150.0] # Bubble widths to try, the smallest that fits wins
const SIZES := [14, 13, 12, 11] # Text sizes to try, the biggest that fits wins
const PADDING := Vector2(8.0, 6.0)
const TOP_LIMIT := 8.0 # The bubble never goes above this (no cropping at the top)
const LINE_SPACING := 3.0 # The Label's default space between lines
const TAIL_LENGTH := 14.0
const TYPE_SPEED := 0.02

var label: Label
var box_size := Vector2.ZERO
var tail_target := Vector2.ZERO # Where the tail points (local)
var serial := 0 # A newer line cancels an older one
var bob_tween: Tween
var pop_tween: Tween

func _init() -> void:
	position = ANCHOR
	visible = false
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

# Shows a line; target is where Tuh-U is (screen position), the tail points toward it
func say(text: String, target: Vector2) -> void:
	serial += 1
	var mine := serial
	_fit(text)
	tail_target = target - ANCHOR
	label.text = text
	label.visible_characters = 0
	queue_redraw()
	_pop_in()
	var total := text.length()
	for i in total:
		if mine != serial:
			return
		label.visible_characters = i + 1
		await get_tree().create_timer(TYPE_SPEED).timeout
	if mine == serial:
		label.visible_characters = -1

func hide_bubble() -> void:
	serial += 1
	if not visible:
		return
	if pop_tween:
		pop_tween.kill()
	pop_tween = create_tween().set_parallel(true)
	pop_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	pop_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.12)
	await pop_tween.finished
	if serial != 0 and not pop_tween.is_valid():
		return
	visible = false
	if bob_tween:
		bob_tween.kill()

# The wrapped size of a line of text, counting the space between lines like the Label does
func _measure(text: String, width: float, font_size: int) -> Vector2:
	var raw := FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var line_height := FONT.get_height(font_size)
	var lines := maxi(1, int(round(raw.y / line_height)))
	return Vector2(raw.x, lines * (line_height + LINE_SPACING) - LINE_SPACING + 2.0)

# Picks the biggest readable text size and the smallest bubble width that holds the line
func _fit(text: String) -> void:
	var chosen_size: int = SIZES[SIZES.size() - 1]
	var chosen_width: float = WIDTHS[WIDTHS.size() - 1]
	var text_size := Vector2.ZERO
	var found := false
	for font_size in SIZES:
		for width in WIDTHS:
			text_size = _measure(text, width - PADDING.x * 2.0, font_size)
			var max_height: float = (font_size + LINE_SPACING) * 3.0 # Three lines is comfortable
			var room: float = width - PADDING.x * 2.0
			if text_size.x + 4.0 <= room and text_size.y <= max_height and text_size.y + PADDING.y * 2.0 + 2.0 <= ANCHOR.y - TOP_LIMIT: # The widest word needs a little slack too, or it gets cut
				chosen_size = font_size
				chosen_width = width
				found = true
				break
		if found:
			break
	if not found: # Safety net: the smallest size at the widest bubble, as tall as it needs
		text_size = _measure(text, chosen_width - PADDING.x * 2.0, chosen_size)
	var inner_width: float = min(chosen_width - PADDING.x * 2.0, ceilf(text_size.x) + 6.0) # Shrinks to the text when the line is short (with slack, so it never wraps differently)
	label.add_theme_font_size_override("font_size", chosen_size)
	label.size = Vector2(inner_width, text_size.y)
	box_size = Vector2(inner_width + PADDING.x * 2.0, text_size.y + PADDING.y * 2.0)
	label.position = -box_size + PADDING

func _pop_in() -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6) # Pops out of the bottom-right corner
	if pop_tween:
		pop_tween.kill()
	pop_tween = create_tween().set_parallel(true)
	pop_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if bob_tween:
		bob_tween.kill()
	position = ANCHOR
	bob_tween = create_tween().set_loops()
	bob_tween.tween_method(_bob, 0.0, 1.0, 0.7)
	bob_tween.tween_method(_bob, 1.0, 0.0, 0.7)

func _bob(amount: float) -> void:
	position.y = ANCHOR.y - roundf(amount * 2.0) # Whole pixels

func _draw() -> void:
	var rect := Rect2(-box_size, box_size)
	# Tail first, so the bubble covers its base: a little wedge from the bottom-right toward Tuh-U
	var base := Vector2(-16.0, 0.0)
	var direction := (tail_target - base).normalized()
	var tip := (base + direction * TAIL_LENGTH).round()
	for outline in [true, false]:
		var grow := 1.5 if outline else 0.0
		var color := Color.BLACK if outline else Color.WHITE
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-5.0 - grow, -1.0),
			base + Vector2(5.0 + grow, -1.0),
			tip + Vector2(0, grow),
		]), color)
	_pixel_round_rect(rect.grow(2.0), Color.BLACK)
	_pixel_round_rect(rect, Color.WHITE)

# A rectangle with softened corners (whole pixels)
func _pixel_round_rect(rect: Rect2, color: Color) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	draw_rect(Rect2(r.position + Vector2(2, 0), r.size - Vector2(4, 0)), color)
	draw_rect(Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 4)), color)
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), color)
