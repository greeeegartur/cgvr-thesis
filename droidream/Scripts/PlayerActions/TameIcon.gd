extends Node2D
class_name TameIcon

# One icon of the tame timing sequence: a dark shadow on the creature and an icon that flies a full curve past it, shrinking toward the shadow (the half-point of the curve is the moment to press)
# and fading out after it; judged presses lock it in, freeze it or make the shadow shake (everything is in the VFX layer, in world coordinates)

enum State { SHADOW, TRAVELING, LOCKED_PERFECT, LOCKED_GOOD, TRY, MISS }

const SHAPES := [
	preload("res://Graphics/Sprites/Minigames/MultiTameShapes/multitame_circle.png"),
	preload("res://Graphics/Sprites/Minigames/MultiTameShapes/multitame_square.png"),
	preload("res://Graphics/Sprites/Minigames/MultiTameShapes/multitame_triangle.png"),
]
const OUTLINE_SHADER := preload("res://Scenes/VFX/TargetOutline.gdshader")
const FINAL_SCALE := 1.5 # The 16 px shapes at 1.5x are 24 px: big enough to read, small enough to leave the creature visible
const START_SCALE := 3.3 # 2.2x the final size
const SHADOW_COLOR := Color(0.04, 0.04, 0.08, 0.6)
const PREVIEW_TIME := 0.2 # The dotted arc is shown this long
const PREVIEW_DOTS := 8
const HALF := 0.5 # The icon passes its shadow at this part of the curve
const PULSE_AT := 0.42 # The shadow pulses once just before the icon reaches it
const AFTER_SCALE := 1.4 # After the shadow the icon grows a little while it fades

var state := State.SHADOW
var spot := Vector2.ZERO # Where the shadow sits (and where the icon lands)
var start_pos := Vector2.ZERO
var control_pos := Vector2.ZERO
var end_pos := Vector2.ZERO
var progress := 0.0
var preview_alpha := 0.0
var pulsed := false
var shadow: Sprite2D
var traveler: Sprite2D
var texture: Texture2D
var fly_tween: Tween # A missed icon keeps flying and fading on its own

func _init() -> void:
	texture = SHAPES.pick_random()
	shadow = Sprite2D.new()
	shadow.texture = texture
	shadow.scale = Vector2.ONE * FINAL_SCALE
	shadow.modulate = Color(SHADOW_COLOR, 0.0)
	shadow.material = _outline(Color(1, 1, 1, 0.4))
	add_child(shadow)
	traveler = Sprite2D.new()
	traveler.texture = texture
	traveler.visible = false
	traveler.material = _outline(Color(1, 1, 1, 1.0))
	add_child(traveler)
	z_index = 4

func _outline(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_width", 1.0)
	material.set_shader_parameter("outline_color", color)
	return material

# The shadow fades in on its spot
func show_shadow(at: Vector2, delay := 0.0) -> void:
	spot = at
	shadow.position = at
	create_tween().tween_property(shadow, "modulate:a", SHADOW_COLOR.a, 0.15).set_delay(delay)

# Starts the flight from a point: a smooth curve that passes the shadow at its half-point and swings on to the other side (turn is the angle the path bends by, positive or negative)
func begin_travel(from: Vector2, turn: float) -> void:
	state = State.TRAVELING
	start_pos = from
	end_pos = spot + (spot - from).rotated(turn) # Leaves the shadow turned by that angle, as far as it came
	control_pos = 2.0 * spot - 0.5 * (from + end_pos) # Makes the curve pass exactly through the shadow at the half-point
	progress = 0.0
	pulsed = false
	traveler.visible = true
	traveler.position = from
	traveler.scale = Vector2.ONE * START_SCALE
	# A flash and an outline pulse at the start
	traveler.modulate = Color(3, 3, 3, 1)
	create_tween().tween_property(traveler, "modulate", Color.WHITE, 0.12)
	var mat := traveler.material as ShaderMaterial
	mat.set_shader_parameter("outline_width", 2.0)
	create_tween().tween_method(func(v: float): mat.set_shader_parameter("outline_width", v), 2.0, 1.0, 0.25)
	preview_alpha = 1.0
	queue_redraw()

# Moves the icon along the whole curve at a steady speed: it shrinks until the shadow, then grows a little and fades out
func set_progress(t: float) -> void:
	progress = clampf(t, 0.0, 1.0)
	traveler.position = _bezier(progress)
	if progress <= HALF:
		traveler.scale = Vector2.ONE * lerpf(START_SCALE, FINAL_SCALE, progress / HALF)
		traveler.modulate.a = 1.0
	else:
		var after := (progress - HALF) / (1.0 - HALF)
		traveler.scale = Vector2.ONE * lerpf(FINAL_SCALE, FINAL_SCALE * AFTER_SCALE, after)
		traveler.modulate.a = 1.0 - after # Fades out after the half-point
	if progress >= PULSE_AT and not pulsed:
		pulsed = true
		_pulse_shadow()
	queue_redraw()

# The dotted preview fades over its first moments
func set_preview_time(elapsed: float) -> void:
	preview_alpha = clampf(1.0 - elapsed / PREVIEW_TIME, 0.0, 1.0)
	queue_redraw()

func _bezier(t: float) -> Vector2:
	var a := start_pos.lerp(control_pos, t)
	var b := control_pos.lerp(end_pos, t)
	return a.lerp(b, t)

func _pulse_shadow() -> void:
	var tween := create_tween()
	tween.tween_property(shadow, "scale", Vector2.ONE * FINAL_SCALE * 1.25, 0.08)
	tween.tween_property(shadow, "scale", Vector2.ONE * FINAL_SCALE, 0.1)

func _draw() -> void:
	if preview_alpha <= 0.0 or state != State.TRAVELING:
		return
	for i in range(1, PREVIEW_DOTS + 1):
		var t := HALF * float(i) / (PREVIEW_DOTS + 1) # The dots show the way to the shadow
		var pos := _bezier(t).round()
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.7 * preview_alpha))

# Perfect: the icon snaps into the shadow with a pop (the caller adds the burst)
func lock(perfect: bool) -> void:
	state = State.LOCKED_PERFECT if perfect else State.LOCKED_GOOD
	preview_alpha = 0.0
	shadow.visible = false
	var tween := create_tween()
	if perfect:
		traveler.position = spot
		traveler.scale = Vector2.ONE * FINAL_SCALE * 1.5
		traveler.modulate = Color(2.5, 2.2, 1.2, 1.0) # A gold flash
		tween.set_parallel(true)
		tween.tween_property(traveler, "scale", Vector2.ONE * FINAL_SCALE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(traveler, "modulate", Color.WHITE, 0.25)
	else:
		tween.tween_property(traveler, "position", spot, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(traveler, "scale", Vector2.ONE * FINAL_SCALE, 0.12)

# Try: the icon stays where it is, shrinks a little and fades
func freeze_try() -> void:
	state = State.TRY
	preview_alpha = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(traveler, "scale", traveler.scale * 0.85, 0.35)
	tween.tween_property(traveler, "modulate:a", 0.0, 0.35)
	create_tween().tween_property(shadow, "modulate:a", 0.25, 0.25)

# Miss: the icon flies on along its curve while it fades out (the sequence does not wait for it), the shadow shakes and turns dark
func miss(fly_time := 0.3) -> void:
	state = State.MISS
	preview_alpha = 0.0
	var from := progress
	fly_tween = create_tween()
	fly_tween.tween_method(set_progress, from, 1.0, maxf(fly_time, 0.05))
	var base := shadow.position
	var tween := create_tween()
	for i in 4:
		tween.tween_property(shadow, "position", base + Vector2(2.0 if i % 2 == 0 else -2.0, 0), 0.04)
	tween.tween_property(shadow, "position", base, 0.04)
	create_tween().tween_property(shadow, "modulate", Color(0, 0, 0, 0.25), 0.25)

# Fades everything out at the end of the sequence
func finish(duration := 0.3) -> void:
	if fly_tween:
		fly_tween.kill() # The icon is leaving anyway (and a freed icon must not be called)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(shadow, "modulate:a", 0.0, duration)
	tween.tween_property(traveler, "modulate:a", 0.0, duration)
	await tween.finished
	queue_free()
