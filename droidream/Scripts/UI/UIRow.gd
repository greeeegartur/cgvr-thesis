extends Control
class_name UIRow

# One selectable row for UI lists: optional icon, text, text on the right and cooldown pips; it slides, brightens and nudges when selected (the bar and marker belong to UIList's cursor)

const FONT := preload("res://Graphics/Fonts/PixelOperator.ttf")
const PIP_TEXTURE := preload("res://Graphics/Sprites/UI/axis_select.png")
const PIP_COLOR := Color(0.859, 0.906, 0.451)
const FONT_SIZE := 16
const ROW_HEIGHT := 20
const MARKER_WIDTH := 8 # Room for the marker on the left
const SLIDE := 4.0 # How far a selected row slides right
const RIGHT_PAD := 8.0 # Room after the content, so the bar always extends past the right text (even when popped)
const NUDGE := 2.0 # How far a selected row moves right at the peak of the beat (pixels)
const BOUNCE_DISTANCE := 5.0 # How far it jolts when the cursor arrives (pixels)
const DIM := Color(0.55, 0.55, 0.55)
const SELECTED_REST := Color(0.85, 0.85, 0.85) # Selected text rests a little below white and flashes up to it on the beat
const FLASH_SHADER := preload("res://Scenes/UI/FlashWhite.gdshader")
const BOUNCE_TIME := 0.16 # Jolt when the cursor arrives

var content: HBoxContainer
var icon_rect: TextureRect
var text_label: Label
var right_label: Label
var pip_box: HBoxContainer
var flash_material: ShaderMaterial
var selected := false
var pulse_tween: Tween
var slide_tween: Tween
var slide_x := float(MARKER_WIDTH) # Resting x of the content (changes with selection)
var nudge_x := 0.0 # Extra x from the bounce and the beat

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
	
	# The whole row's content flashes through one shared material
	flash_material = ShaderMaterial.new()
	flash_material.shader = FLASH_SHADER
	content.material = flash_material
	for node in [icon_rect, text_label, right_label, pip_box]:
		node.use_parent_material = true
	
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
		pip.use_parent_material = true
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
	_stop_pulse()
	if slide_tween:
		slide_tween.kill()
	
	var target_x := MARKER_WIDTH + (SLIDE if value else 0.0)
	var target_color := SELECTED_REST if value else DIM
	if animate:
		slide_tween = create_tween().set_parallel()
		slide_tween.tween_method(_set_slide_x, slide_x, target_x, 0.12)
		slide_tween.tween_property(content, "modulate", target_color, 0.1)
	else:
		_set_slide_x(target_x)
		content.modulate = target_color
	nudge_x = 0.0
	_apply_x()
	flash_material.set_shader_parameter("flash", 0.0)
	
	if value and is_inside_tree():
		if animate:
			bounce()
		else:
			_start_pulse()

# Text is never scaled (it shimmers); the row moves in whole pixels instead and the beat also flashes its opacity
func _set_slide_x(value: float) -> void:
	slide_x = value
	_apply_x()

func _apply_x() -> void:
	content.position.x = roundf(slide_x + nudge_x)

# Jolts the row to the right and back (used when the cursor arrives), then goes on with the beat
func bounce() -> void:
	_stop_pulse()
	var tween := create_tween()
	tween.tween_method(func(t: float):
		nudge_x = BOUNCE_DISTANCE * sin(t * PI) * (1.0 - t * 0.5)
		_apply_x(), 0.0, 1.0, BOUNCE_TIME)
	tween.finished.connect(func(): if selected: _start_pulse())
	pulse_tween = tween

func _start_pulse() -> void:
	_stop_pulse()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_method(_apply_pop, 0.0, 1.0, SelectionPulse.BEAT)

func _stop_pulse() -> void:
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

# One point of the beat (phase 0..1): a 1-2 px nudge and a flash toward white
func _apply_pop(phase: float) -> void:
	var envelope := SelectionPulse.beat_envelope(phase)
	nudge_x = NUDGE * envelope
	_apply_x()
	flash_material.set_shader_parameter("flash", envelope) # Flashes toward white instead of dimming
