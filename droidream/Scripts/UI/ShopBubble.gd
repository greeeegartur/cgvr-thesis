extends Node2D
class_name ShopBubble

# Tuh-U's speech bubble (shop reactions, the demo ending and the tutorial): a white pixel bubble with a black outline and a small tail, drawn in code and sized to the line; it keeps a gentle bob
# A line may use [color] tags to emphasise words (they are ignored when measuring)

const FONT := preload("res://Graphics/Fonts/PixelOperator.ttf")
const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const ANCHOR := Vector2(545, 92) # The bubble's bottom-right corner: it grows up and to the left from here, in the free band above the items
const WIDTHS := [64.0, 80.0, 100.0, 120.0, 150.0] # Bubble widths to try, the smallest that fits wins
const SIZES := [14, 13, 12, 11] # Text sizes to try, the biggest that fits wins
const PADDING := Vector2(8.0, 6.0)
const TOP_LIMIT := 8.0 # The bubble never goes above this (no cropping at the top)
const LINE_SPACING := 3.0 # The Label's default space between lines
const TAIL_LENGTH := 14.0
const TYPE_SPEED := 0.02

var label: RichTextLabel
var box_size := Vector2.ZERO
var tail_target := Vector2.ZERO # Where the tail points (local)
var serial := 0 # A newer line cancels an older one
var anchor := ANCHOR # The bubble's corner on the screen (bottom-right, or bottom-left when it grows to the right)
var grow_right := false
var widths: Array = WIDTHS
var waiting := false # A line that waits for Confirm shows a small blinking arrow
var skippable := false # While a line types out and may be skipped, one Confirm shows the rest of it at once
var skip_requested := false
var bob_tween: Tween
var pop_tween: Tween

func _init() -> void:
	position = anchor
	visible = false
	set_process(false)
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("normal_font", FONT)
	label.add_theme_font_override("bold_font", FONT_BOLD)
	label.add_theme_color_override("default_color", Color.BLACK)
	label.add_theme_constant_override("line_separation", int(LINE_SPACING))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

# Where the bubble sits: anchor is its bottom corner; to_right grows it to the right of the anchor (the ending), otherwise to the left (the shop)
func configure(at: Vector2, to_right := false, width_list: Array = WIDTHS) -> void:
	anchor = at
	grow_right = to_right
	widths = width_list

# Shows a line; target is where Tuh-U is (screen position), the tail points toward it
func say(text: String, target: Vector2, allow_skip := false) -> void:
	serial += 1
	var mine := serial
	waiting = false
	_fit(text)
	var screen := get_viewport().get_visible_rect().size
	if grow_right: # Never past the screen edge, whatever the line made it
		anchor.x = minf(anchor.x, screen.x - box_size.x - 6.0)
	else:
		anchor.x = maxf(anchor.x, box_size.x + 6.0)
	anchor.y = maxf(anchor.y, box_size.y + TOP_LIMIT) # A tall line never goes above the screen (it sits lower instead of being cut off)
	tail_target = target - anchor
	label.text = text
	label.visible_characters = 0
	queue_redraw()
	_pop_in()
	var total := _plain(text).length()
	skippable = allow_skip # Read as an input event, so a quick press between two letters is never missed
	skip_requested = false
	for i in total:
		if mine != serial:
			return
		if skip_requested:
			break
		label.visible_characters = i + 1
		await get_tree().create_timer(TYPE_SPEED).timeout
	if mine == serial:
		label.visible_characters = -1
		skippable = false

func _input(event: InputEvent) -> void:
	if skippable and event.is_action_pressed("ui_accept"):
		skip_requested = true

# A line that waits for Confirm before it returns (the ending's dialogue)
func say_and_wait(text: String, target: Vector2) -> void:
	await say(text, target, true)
	var mine := serial
	waiting = true
	set_process(true)
	await get_tree().process_frame # The press that skipped the typing does not count
	while mine == serial:
		await get_tree().process_frame
		if not PauseMenu.active and Input.is_action_just_pressed("ui_accept"):
			break
	waiting = false
	set_process(false)
	queue_redraw()

func hide_bubble() -> void:
	serial += 1
	skippable = false
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

# The text without its tags (what is measured and what is typed)
func _plain(text: String) -> String:
	var tags := RegEx.new()
	tags.compile("\\[[^\\]]*\\]")
	return tags.sub(text, "", true)

# The wrapped size of a line of text, counting the space between lines like the Label does
func _measure(text: String, width: float, font_size: int) -> Vector2:
	var raw := FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var line_height := FONT.get_height(font_size)
	var lines := maxi(1, int(round(raw.y / line_height)))
	return Vector2(raw.x, lines * (line_height + LINE_SPACING) - LINE_SPACING + 2.0)

# Picks the biggest readable text size and the smallest bubble width that holds the line
func _fit(line: String) -> void:
	var text := _plain(line)
	var slack := 8.0 if line.contains("[b]") else 0.0 # Bold letters are wider than the regular ones the line is measured with
	var chosen_size: int = SIZES[SIZES.size() - 1]
	var chosen_width: float = widths[widths.size() - 1]
	var text_size := Vector2.ZERO
	var found := false
	for font_size in SIZES:
		for width in widths:
			text_size = _measure(text, width - PADDING.x * 2.0, font_size)
			var max_height: float = (font_size + LINE_SPACING) * 3.0 # Three lines is comfortable
			var room: float = width - PADDING.x * 2.0
			if text_size.x + 4.0 + slack <= room and text_size.y <= max_height and text_size.y + PADDING.y * 2.0 + 2.0 <= anchor.y - TOP_LIMIT: # The widest word needs a little slack too, or it gets cut
				chosen_size = font_size
				chosen_width = width
				found = true
				break
		if found:
			break
	if not found: # Safety net: the smallest size at the widest bubble, as tall as it needs
		text_size = _measure(text, chosen_width - PADDING.x * 2.0, chosen_size)
	var inner_width: float = min(chosen_width - PADDING.x * 2.0, ceilf(text_size.x) + 6.0 + slack) # Shrinks to the text when the line is short (with slack, so it never wraps differently)
	label.add_theme_font_size_override("normal_font_size", chosen_size)
	label.add_theme_font_size_override("bold_font_size", chosen_size)
	label.size = Vector2(inner_width, text_size.y)
	box_size = Vector2(inner_width + PADDING.x * 2.0, text_size.y + PADDING.y * 2.0)
	label.position = (Vector2(PADDING.x, -box_size.y + PADDING.y) if grow_right else -box_size + PADDING)

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
	position = anchor
	bob_tween = create_tween().set_loops()
	bob_tween.tween_method(_bob, 0.0, 1.0, 0.7)
	bob_tween.tween_method(_bob, 1.0, 0.0, 0.7)

func _process(_delta: float) -> void:
	if waiting:
		queue_redraw() # The arrow blinks

func _bob(amount: float) -> void:
	position.y = anchor.y - roundf(amount * 2.0) # Whole pixels

func _draw() -> void:
	var rect := Rect2(Vector2(0, -box_size.y), box_size) if grow_right else Rect2(-box_size, box_size)
	# Tail first, so the bubble covers its base: a little wedge from the bottom-right toward Tuh-U
	var base := Vector2(16.0, 0.0) if grow_right else Vector2(-16.0, 0.0)
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
	if waiting and int(Time.get_ticks_msec() / 350) % 2 == 0: # A small blinking arrow: press Confirm to go on
		var corner := rect.end - Vector2(10, 9)
		for i in 3:
			draw_rect(Rect2(corner + Vector2(i, i), Vector2(5 - i * 2, 1)), Color.BLACK)

# A rectangle with softened corners (whole pixels)
func _pixel_round_rect(rect: Rect2, color: Color) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	draw_rect(Rect2(r.position + Vector2(2, 0), r.size - Vector2(4, 0)), color)
	draw_rect(Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 4)), color)
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), color)
