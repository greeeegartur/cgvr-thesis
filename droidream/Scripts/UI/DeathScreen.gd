extends Node2D

# The game over screen: the world dims to a spotlight around the Droid, "Game Over" and a one-line run summary appear, then Retry / Quit

class_name DeathScreen

signal retry_selected
signal back_selected

const SPOTLIGHT_SHADER := preload("res://Scenes/VFX/Spotlight.gdshader")
const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const SPOTLIGHT_START := 2.0 # Radius (in screen heights) at which the whole screen is lit
const SPOTLIGHT_END := 0.24
const SPOTLIGHT_TIME := 1.2
const BODY_LIFT := Vector2(0, -40) # From the Droid's feet to the middle of its body, in world pixels
const FLOAT_PIXELS := 2.0
const LIST_WIDTH := 92.0 # Width of the Retry / Quit rows, the panel is as wide as this plus its padding
const ROW_HEIGHT := 26 # The two options are a little bigger than the usual menu text
const ROW_FONT_SIZE := 20

var spotlight: ColorRect
var spotlight_material: ShaderMaterial
var heading: Label
var summary: Label
var panel: UIPanel
var list: UIList
var anchor: Node2D # The Droid: the light follows it through the camera
var skipped := false
var choosing := false
var shown_time := 0.0
var heading_rest_y := 0.0
var tweens: Array[Tween] = []

func _ready() -> void:
	_build()
	set_process(false)

# Builds the spotlight, the texts and the Retry / Quit list
func _build() -> void:
	var screen := get_viewport_rect().size
	
	spotlight = ColorRect.new()
	spotlight.size = screen
	spotlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spotlight_material = ShaderMaterial.new()
	spotlight_material.shader = SPOTLIGHT_SHADER
	spotlight_material.set_shader_parameter("aspect", screen.x / screen.y)
	spotlight.material = spotlight_material
	add_child(spotlight)
	
	heading = _make_label(32, true)
	heading.text = "Game Over"
	add_child(heading)
	
	summary = _make_label(16, false)
	add_child(summary)
	
	panel = UIPanel.new()
	add_child(panel)
	list = UIList.new()
	list.min_width = LIST_WIDTH
	list.center_text = true
	list.row_height = ROW_HEIGHT
	list.font_size = ROW_FONT_SIZE
	list.set_rows([{ "text": "Retry" }, { "text": "Quit" }])
	list.confirmed.connect(_on_confirmed)
	panel.add_child(list)
	panel.fit_to(list.size)
	list.position = panel.content_origin()
	
	# Layout: heading and summary in the upper middle, the panel under them
	heading.size = Vector2(screen.x, heading.get_minimum_size().y)
	summary.size = Vector2(screen.x, summary.get_minimum_size().y)
	heading_rest_y = 46.0
	heading.position = Vector2(0, heading_rest_y)
	summary.position = Vector2(0, heading_rest_y + heading.size.y + 4.0)
	panel.position = ((Vector2(screen.x, 0) - Vector2(panel.size.x, 0)) / 2.0).round() + Vector2(0, summary.position.y + summary.size.y + 18.0)

func _make_label(size: int, bold: bool) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT_BOLD if bold else UIRow.FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6 if bold else 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# Runs the whole sequence; p_anchor is the Droid, summary_text the one-line run summary. Z skips the waiting parts once
func show_death(p_anchor: Node2D, summary_text: String) -> void:
	anchor = p_anchor
	summary.text = summary_text
	skipped = false
	choosing = false
	shown_time = 0.0
	visible = true
	set_process(true)
	
	heading.modulate.a = 0.0
	summary.modulate.a = 0.0
	panel.modulate.a = 0.0
	_set_radius(SPOTLIGHT_START)
	
	# 1. The light closes around the Droid
	var closing := _tween()
	closing.tween_method(_set_radius, SPOTLIGHT_START, SPOTLIGHT_END, SPOTLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(SPOTLIGHT_TIME + 0.25)
	if skipped:
		return _finish_now()
	
	# 2. Heading, summary and options fade in one after another
	_tween().tween_property(heading, "modulate:a", 1.0, 0.5)
	await _wait(0.5)
	if skipped:
		return _finish_now()
	_tween().tween_property(summary, "modulate:a", 1.0, 0.3)
	await _wait(0.3)
	if skipped:
		return _finish_now()
	_tween().tween_property(panel, "modulate:a", 1.0, 0.3)
	await _wait(0.3)
	_finish_now()

# Waits for a time, or until Z is pressed
func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not skipped:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

# The final look: everything shown and the choice open
func _finish_now() -> void:
	for tween in tweens:
		if tween:
			tween.kill()
	tweens.clear()
	_set_radius(SPOTLIGHT_END)
	heading.modulate.a = 1.0
	summary.modulate.a = 1.0
	panel.modulate.a = 1.0
	list.select(0, false)
	choosing = true

func _tween() -> Tween:
	var tween := create_tween()
	tweens.append(tween)
	return tween

func _set_radius(value: float) -> void:
	spotlight_material.set_shader_parameter("radius", value)

func _process(delta: float) -> void:
	shown_time += delta
	
	# The light follows the Droid through the camera
	if anchor and is_instance_valid(anchor):
		var screen := get_viewport_rect().size
		var spot := get_viewport().get_canvas_transform() * anchor.global_position + get_viewport().get_canvas_transform().basis_xform(BODY_LIFT)
		spotlight_material.set_shader_parameter("center", spot / screen)
	
	# The heading floats on the shared beat, in whole pixels
	var beat := fmod(shown_time, SelectionPulse.BEAT) / SelectionPulse.BEAT
	heading.position.y = heading_rest_y - roundf(FLOAT_PIXELS * SelectionPulse.beat_envelope(beat))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not choosing:
		if event.is_action_pressed("ui_accept"):
			skipped = true
			get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_up"):
		list.move(-1)
	elif event.is_action_pressed("ui_down"):
		list.move(1)
	elif event.is_action_pressed("ui_accept"):
		list.confirm()

func _on_confirmed(index: int) -> void:
	choosing = false
	if index == 0:
		retry_selected.emit()
	else:
		back_selected.emit()
