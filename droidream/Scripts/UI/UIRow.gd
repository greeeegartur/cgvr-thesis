extends Control
class_name UIRow

# One selectable row for UI lists: optional icon, text, text on the right and cooldown pips; it has the shared selected look (marker, slide, bar, pop)

const FONT := preload("res://Graphics/Fonts/PixelOperator.ttf")
const PIP_TEXTURE := preload("res://Graphics/Sprites/UI/axis_select.png")
const PIP_COLOR := Color(0.859, 0.906, 0.451)
const FONT_SIZE := 16
const ROW_HEIGHT := 20
const MARKER_WIDTH := 8 # Room for the marker on the left
const SLIDE := 4.0 # How far a selected row slides right
const RIGHT_PAD := 8.0 # Room after the content, so the bar always extends past the right text (even when popped)
const POP := 0.05 # How much a selected row grows at the peak of the beat
const DIM := Color(0.6, 0.6, 0.6)

var content: HBoxContainer
var icon_rect: TextureRect
var text_label: Label
var right_label: Label
var pip_box: HBoxContainer
var bar_color := Color(1, 1, 1, 0.22)
var selected := false
var pulse_tween: Tween
var slide_tween: Tween

func _init() -> void:
	custom_minimum_size.y = ROW_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.position = Vector2(MARKER_WIDTH, 0)
	add_child(content)
	
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(icon_rect)
	
	text_label = _make_label()
	content.add_child(text_label)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size.x = 8
	content.add_child(spacer)
	
	right_label = _make_label()
	content.add_child(right_label)
	
	pip_box = HBoxContainer.new()
	pip_box.add_theme_constant_override("separation", 1)
	content.add_child(pip_box)
	
	set_selected(false, false)

func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# Fills the row: pips is how many cooldown pips exist and pips_dim how many of them are still cooling down (drawn dark)
func setup(icon: Texture2D, text: String, right_text := "", pips := 0, pips_dim := 0) -> void:
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	text_label.text = text
	right_label.text = right_text
	right_label.visible = right_text != ""
	set_pips(pips, pips_dim)

# Rebuilds the cooldown pips
func set_pips(pips: int, pips_dim := 0) -> void:
	for child in pip_box.get_children():
		child.queue_free()
	pip_box.visible = pips > 0
	for i in pips:
		var pip := TextureRect.new()
		pip.texture = PIP_TEXTURE
		pip.stretch_mode = TextureRect.STRETCH_KEEP
		pip.self_modulate = PIP_COLOR * (0.3 if i < pips_dim else 1.0)
		pip.modulate.a = 1.0
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip_box.add_child(pip)

func set_right_text(text: String) -> void:
	right_label.text = text
	right_label.visible = text != ""

# Width the row needs: marker room, content, the slide and the room after it
func get_wanted_width() -> float:
	return MARKER_WIDTH + content.get_combined_minimum_size().x + SLIDE + RIGHT_PAD

# Stretches the content over the row so right text lines up at the end of the bar
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and content:
		content.size = Vector2(size.x - MARKER_WIDTH - SLIDE - RIGHT_PAD, ROW_HEIGHT)
		content.pivot_offset = content.size / 2.0

# Shows or hides the selected look; animate is false for the initial state
func set_selected(value: bool, animate := true) -> void:
	selected = value
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
	if slide_tween:
		slide_tween.kill()
	
	var target_x := MARKER_WIDTH + (SLIDE if value else 0.0)
	var target_color := Color.WHITE if value else DIM
	if animate:
		slide_tween = create_tween().set_parallel()
		slide_tween.tween_property(content, "position:x", target_x, 0.12)
		slide_tween.tween_property(content, "modulate", target_color, 0.1)
		slide_tween.tween_property(content, "scale", Vector2.ONE, 0.1)
	else:
		content.position.x = target_x
		content.modulate = target_color
		content.scale = Vector2.ONE
	
	if value and is_inside_tree():
		pulse_tween = create_tween().set_loops()
		pulse_tween.tween_method(_apply_pop, 0.0, 1.0, SelectionPulse.BEAT)
	queue_redraw()

# One point of the pop on the shared selection beat (phase 0..1)
func _apply_pop(phase: float) -> void:
	var envelope := sin(phase / SelectionPulse.ATTACK_RATIO * PI * 0.5) if phase < SelectionPulse.ATTACK_RATIO \
		else cos((phase - SelectionPulse.ATTACK_RATIO) / (1.0 - SelectionPulse.ATTACK_RATIO) * PI * 0.5)
	content.scale = Vector2.ONE * (1.0 + POP * envelope)

# Highlight bar and marker, drawn in whole pixels
func _draw() -> void:
	if not selected:
		return
	draw_rect(Rect2(0, 1, size.x, size.y - 2), bar_color)
	var mid := roundi(size.y / 2.0)
	for i in 4:
		draw_rect(Rect2(1 + i, mid - 3 + i, 1, 7 - i * 2), Color.WHITE)
