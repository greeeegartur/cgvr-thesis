extends Control

# This script is responsible for setting up the enemy entities' "health bar" UI so to say
# In Droidream, enemies have axis bars that can shift to the left or right, left representing the kill option and the right side representing the tame option

# Node variables
@onready var line: TextureRect = $AxisLine
@onready var bar: TextureRect = $AxisBar
@onready var Kill: Label = $Kill
@onready var Tame: Label = $Tame
@onready var tame_container := $TameContainer

# Flair
const GLOW_SHADER := preload("res://Scenes/VFX/MeterGlow.gdshader")
const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const NOT_YET_RATIO := 0.85 # Furthest the pointer goes (of the full range) while the creature is not yet tamed or killed
const SLIDE_TIME := 0.3
const END_GAP := 7.0 # Pixels the pointer stays short of the bar's end until the creature is tamed or killed
const NEAR_END_SCALE := 1.25 # Pointer size just before the end
const GHOST_SPACING := 3.0 # Pixels of pointer travel between trail copies
const TRAIL_FADE := 0.25
const LABEL_WIDTH := 30.0
const TAME_COLORS := [Color("#ff4ac0"), Color("#ff8ae0"), Color("#d83aff")]
const KILL_COLORS := [Color("#ff2a2a"), Color("#ff6a3a"), Color("#c01030")]
const DIM_LABEL := Color(0.55, 0.55, 0.55)
var glow_rect: TextureRect
var flash_tween: Tween
var ratio_now := 0.0
var trail_color := Color.WHITE
var last_ghost_x := 0.0
var flicker_timer := 0.0
var strobe := false

# Tame container variables
const BASE_SCALE := Vector2.ONE
const BIG_SCALE  := Vector2(1.2, 1.2)
var trust := 0 # Initial trust variables, trust = index
var trust_max := 0 # Actual max that will be set by setup_trust

# Axis variables
@export var axis_max := 100.0
@export var move_range := 38.0 # Exact pixels to go either side of the axis bar
@export var center_x := 0.0
@export var min_scale := 1.0
@export var max_scale := 1.7

func _ready():
	center_x = line.position.x
	_setup_glow()
	_setup_labels()

# Overlay with the bar's own texture so the glow takes the bar's shape (the texture itself stays untouched)
func _setup_glow() -> void:
	glow_rect = TextureRect.new()
	glow_rect.texture = bar.texture
	glow_rect.position = bar.position
	glow_rect.size = bar.size
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter("pointer_x", (line.position.x + line.size.x * 0.5) / bar.size.x)
	glow_rect.material = mat
	add_child(glow_rect)
	move_child(glow_rect, bar.get_index() + 1)

# Bold, outlined labels pinned to the left and right edges of the bar
func _setup_labels() -> void:
	for label in [Kill, Tame]:
		label.add_theme_font_override("font", FONT_BOLD)
		label.add_theme_constant_override("outline_size", 4)
		label.size.x = LABEL_WIDTH
	Kill.position.x = bar.position.x
	Kill.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	Tame.position.x = bar.position.x + bar.size.x - LABEL_WIDTH
	Tame.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

# The pointer only reaches an end of the bar when the creature is really tamed or killed; everything before stops short of it
func _display_ratio(ratio: float) -> float:
	if absf(ratio) >= 1.0 - 0.001:
		return signf(ratio)
	return ratio * NOT_YET_RATIO

# Moves the pointer with a springy slide, a trail and a hit flash, and lights the meter toward the side it leans to
func update_axis(value: float, delta_value := 0):
	# Checks for old ongoing tweens and stops them to not overload
	if line.has_meta("axis_tween"):
		var old_tween: Tween = line.get_meta("axis_tween")
		if old_tween and old_tween.is_running():
			old_tween.kill()
	
	var ratio = _display_ratio(clamp(value / axis_max, -1.0, 1.0)) # Setting ratio limits by axis texture
	var target_x = center_x + _visual_ratio(ratio) * move_range # Target position of line, goes either left or right
	var impact = clamp(abs(delta_value) / axis_max, 0.0, 1.0)
	var moved := not is_equal_approx(target_x, line.position.x)
	var resting_scale = _get_resting_scale(ratio)
	
	# Everything about the side the pointer leans to
	var side_color := _side_color(ratio)
	ratio_now = ratio
	trail_color = side_color
	if moved:
		_flash(impact)
		_pop_label(Kill if ratio < 0.0 else Tame)
	
	# Pointer: springy slide in whole pixels; trail ghosts appear along the way
	var tween := create_tween()
	line.set_meta("axis_tween", tween)
	var start_x: float = line.position.x
	tween.set_parallel(true)
	tween.tween_method(func(x: float): _move_pointer(roundf(x)), start_x, target_x, SLIDE_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	line.scale = Vector2.ONE * (resting_scale.x + 0.5 * impact + (0.25 if moved else 0.0)) # Pop, settles below
	tween.tween_property(line, "scale", resting_scale, SLIDE_TIME)
	_update_labels(ratio)

# Moves the pointer and leaves a fading copy behind every few pixels
func _move_pointer(x: float) -> void:
	if abs(x - last_ghost_x) >= GHOST_SPACING:
		last_ghost_x = x
		_spawn_ghost()
	line.position.x = x
	glow_rect.material.set_shader_parameter("pointer_x", (x + line.size.x * 0.5) / bar.size.x)

func _spawn_ghost() -> void:
	var ghost := TextureRect.new()
	ghost.texture = line.texture
	ghost.position = line.position
	ghost.size = line.size
	ghost.pivot_offset = line.pivot_offset
	ghost.scale = line.scale
	ghost.modulate = Color(trail_color, 0.7)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	move_child(ghost, line.get_index())
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, TRAIL_FADE)
	fade.finished.connect(ghost.queue_free)

# White flash over the bar and pointer; stronger for bigger hits
func _flash(impact: float) -> void:
	if flash_tween:
		flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_method(_set_hit, 0.5 + 0.5 * impact, 0.0, 0.18)
	line.self_modulate = Color(2.5, 2.5, 2.5)
	flash_tween.parallel().tween_property(line, "self_modulate", Color.WHITE, 0.2)

func _set_hit(value: float) -> void:
	glow_rect.material.set_shader_parameter("hit", value)

func _side_color(ratio: float) -> Color:
	return TAME_COLORS[0] if ratio >= 0.0 else KILL_COLORS[0]

# The labels light up on the side the pointer leans to; the other dims
func _update_labels(ratio: float) -> void:
	var tame_lit := ratio > 0.0
	var kill_lit := ratio < 0.0
	Tame.modulate = TAME_COLORS[0] if tame_lit else (Color.WHITE if ratio == 0.0 else DIM_LABEL)
	Kill.modulate = KILL_COLORS[0] if kill_lit else (Color.WHITE if ratio == 0.0 else DIM_LABEL)

func _pop_label(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 1.35
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Stuttering flicker: hold a value, then snap to a new one; faster and brighter toward the ends, strobing at the very edge
func _process(delta: float) -> void:
	flicker_timer -= delta
	if flicker_timer > 0.0:
		return
	var edge := absf(ratio_now)
	flicker_timer = randf_range(0.06, 0.12) * lerpf(1.3, 0.5, edge)
	var palette: Array = TAME_COLORS if ratio_now >= 0.0 else KILL_COLORS
	var brightness := randf_range(0.5, 1.0) * lerpf(0.5, 1.0, edge)
	if edge >= 1.0: # Only a tamed or killed creature strobes
		strobe = not strobe
		brightness = 1.4 if strobe else 0.45
	elif randf() < 0.25:
		brightness *= 1.3 # An occasional bright snap
	var color: Color = palette.pick_random()
	var mat: ShaderMaterial = glow_rect.material
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("strength", brightness * (0.0 if is_zero_approx(ratio_now) else 1.0))
	line.modulate = Color.WHITE.lerp(color, 0.5 * edge) if not is_zero_approx(ratio_now) else Color.WHITE

# The pointer only reaches the very end of the bar when the creature is tamed or killed; everything else stops visibly short of it
func _visual_ratio(ratio: float) -> float:
	if absf(ratio) >= 1.0:
		return signf(ratio)
	return ratio * (1.0 - END_GAP / move_range)

# Calculates a state scale for the axis line based on given ratio (the big end size is only for tamed/killed)
func _get_resting_scale(ratio: float):
	var s: float = max_scale if absf(ratio) >= 1.0 else lerpf(min_scale, NEAR_END_SCALE, absf(ratio))
	return Vector2(s, s)

# Sets up a specific enemy's trust slots UI
func setup_trust(max_value: int):
	trust = 0
	trust_max = max_value
	
	for i in tame_container.get_child_count():
		var slot = tame_container.get_child(i)
		slot.visible = i < trust_max
		slot.modulate = Color(0.25, 0.25, 0.25)
		slot.scale = Vector2.ONE
	
	update_tame_container_scales_for_enemy()

# Tween animation for gaining trust
func gain_trust():
	# Failsafe check
	if trust >= trust_max:
		return
	
	# Gets specific trust slot by trust index
	var slot := tame_container.get_child(trust)
	trust += 1
	
	# Animating back to normal modulate level
	var tween := create_tween()
	tween.tween_property(slot, "modulate", Color.WHITE, 0.25)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Quick scale pop effect
	slot.scale = Vector2(1.4, 1.4)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

# Updates tame slot scales depending on how many there are for the enemy, TO-DO: Test
func update_tame_container_scales_for_enemy():
	var items := []
	for child in tame_container.get_children():
		if child is TextureRect and child.visible:
			items.append(child)
	
	match items.size():
		1:
			items[0].scale = BASE_SCALE
		
		2:
			items[0].scale = BIG_SCALE
			items[1].scale = BIG_SCALE
		
		3:
			items[0].scale = BIG_SCALE
			items[1].scale = BASE_SCALE
			items[2].scale = BIG_SCALE
