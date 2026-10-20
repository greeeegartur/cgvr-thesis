extends Node2D
class_name TuhU

@onready var sprite: Sprite2D = $Sprite2D
@onready var hover_particles: CPUParticles2D = $HoverParticles
@onready var emotion_bubble: Node2D = $EmotionBubble
@onready var emotion_icon: Sprite2D = $EmotionBubble/Bubble

@export var normal_texture: Texture2D
@export var happy_texture: Texture2D
@export var sad_texture: Texture2D
@export var look_right_texture: Texture2D
@export var look_down_texture: Texture2D
@export var look_up_texture: Texture2D

@export var worry_emote: Texture2D
@export var exclamation_emote: Texture2D
@export var question_emote: Texture2D

var texture_tween: Tween
var emote_tween: Tween
var move_tween: Tween

# Floating: a layered hover (slow bob, a tiny side drift, a slight rocking tilt), a soft glow under him and twinkling stars
const BOB := 4.0 # Pixels up and down
const DRIFT := 2.0 # Pixels sideways, on its own rhythm
const ROCK := 2.0 # Degrees of tilt
const GLOW_COLOR := Color(0.47843137, 0.9647059, 0.9764706)
const GLOW_BASE_ALPHA := 0.26
const GLOW_PULSE := 0.1

var hover_time := 0.0
var hover_amount := 0.0 # 0 when travelling, 1 when hovering; blends the layered motion in and out
var hovering := false
var effects_strength := 1.0 # Glow and stars fade a little while he travels
var sprite_base := Vector2.ZERO
var particles_base := Vector2.ZERO
var glow: Sprite2D
var stars: Stars
var hover_tween: Tween
var effects_tween: Tween

# A few tiny sparkles that rise from the glow under him, twinkle and fade
class Stars extends Node2D:
	const COUNT := 4
	const LIFE := 2.2 # Seconds one sparkle lives
	var seeds: Array[Dictionary] = []
	var time := 0.0
	
	func _ready() -> void:
		for i in COUNT:
			seeds.append({ "x": randf_range(-11.0, 11.0), "offset": float(i) / COUNT, "sway": randf() * TAU })
	
	func _process(delta: float) -> void:
		time += delta
		queue_redraw()
	
	func _draw() -> void:
		for seed in seeds:
			var t := fmod(time / LIFE + seed["offset"], 1.0) # 0 at the glow, 1 when it faded
			var pos := Vector2(seed["x"] + sin(time * 1.4 + seed["sway"]) * 2.0, 20.0 - t * 14.0).round() # From below him, rising toward him
			var alpha := sin(t * PI) * 0.7
			var color := Color(0.8, 1.0, 1.0, alpha)
			if t > 0.35 and t < 0.65: # A brief twinkle: a tiny plus
				draw_rect(Rect2(pos + Vector2(-1, 0), Vector2(3, 1)), color)
				draw_rect(Rect2(pos + Vector2(0, -1), Vector2(1, 3)), color)
			else:
				draw_rect(Rect2(pos, Vector2(1, 1)), color)


func _ready():
	emotion_bubble.visible = false
	sprite_base = sprite.position
	_setup_effects()
	
	play_normal()

# Better thruster sparks, the soft glow below and the twinkling stars (all in his cyan)
func _setup_effects() -> void:
	particles_base = hover_particles.position
	hover_particles.amount = 18
	hover_particles.lifetime = 0.95
	hover_particles.emission_sphere_radius = 7.0
	hover_particles.spread = 28.0
	hover_particles.gravity = Vector2(0, 26)
	hover_particles.initial_velocity_min = 8.0
	hover_particles.initial_velocity_max = 22.0
	hover_particles.tangential_accel_min = -10.0 # A slight sideways wobble
	hover_particles.tangential_accel_max = 10.0
	hover_particles.scale_amount_min = 0.5
	hover_particles.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.85, 1.0, 1.0, 0.95), GLOW_COLOR, Color(GLOW_COLOR, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	hover_particles.color_ramp = fade
	hover_particles.emitting = true
	
	# A dim pool of light under him (additive, a radial gradient, no new art)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(GLOW_COLOR, 0.9), Color(GLOW_COLOR, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	glow = Sprite2D.new()
	glow.texture = texture
	glow.position = particles_base + Vector2(0, 5)
	glow.scale = Vector2(1.6, 0.7)
	glow.z_index = -2
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	add_child(glow)
	
	stars = Stars.new()
	stars.z_index = 1
	add_child(stars)

func _process(delta: float) -> void:
	hover_time += delta
	hover_amount = move_toward(hover_amount, 1.0 if hovering else 0.0, delta * 1.6)
	var offset := Vector2(sin(hover_time * 0.9) * DRIFT, sin(hover_time * 1.3) * BOB) * hover_amount
	sprite.position = sprite_base + offset
	hover_particles.position = particles_base + offset
	glow.position = particles_base + Vector2(0, 5) + offset * 0.5
	stars.position = sprite_base + offset # The sparkles start below him
	sprite.rotation_degrees = sin(hover_time * 0.8) * ROCK * hover_amount * signf(scale.x)
	var pulse := GLOW_BASE_ALPHA + sin(hover_time * 1.6) * GLOW_PULSE
	glow.modulate.a = pulse * effects_strength
	stars.modulate.a = effects_strength

# Starts or stops the idle float (it blends in and out)
func set_hovering(on: bool) -> void:
	hovering = on

func _set_effects(strength: float, duration := 0.4) -> void:
	if effects_tween:
		effects_tween.kill()
	effects_tween = create_tween()
	effects_tween.tween_property(self, "effects_strength", strength, duration)

# Swoops in from above and slightly to the side: a soft curve, a tilt that straightens out, then he settles into the hover (no overshoot)
func glide_in(target_y: float, duration := 1.2) -> void:
	if move_tween:
		move_tween.kill()
	hovering = false
	hover_amount = 0.0
	var end_x := position.x
	var lean := signf(scale.x)
	position = Vector2(end_x + 34.0, -24.0)
	rotation_degrees = 12.0 * lean
	_set_effects(0.4, 0.1)
	move_tween = create_tween().set_parallel(true)
	move_tween.tween_property(self, "position:y", target_y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "position:x", end_x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "rotation_degrees", 0.0, duration * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await move_tween.finished
	hovering = true
	_set_effects(1.0, 0.8)

# Leaves upward: a quick dip first (anticipation), then a tilted glide off the top that speeds up
func glide_out(duration := 0.8) -> void:
	if move_tween:
		move_tween.kill()
	var lean := signf(scale.x)
	var start := position
	_set_effects(0.4, 0.25)
	move_tween = create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(self, "position:y", start.y + 6.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "rotation_degrees", -6.0 * lean, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.chain().set_parallel(true)
	move_tween.tween_property(self, "position:y", -34.0, duration - 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	move_tween.tween_property(self, "position:x", start.x + 28.0, duration - 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	move_tween.tween_property(self, "rotation_degrees", 10.0 * lean, duration - 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await move_tween.finished
	hovering = false

# Back to a neutral pose (after he left)
func reset_pose() -> void:
	hovering = false
	hover_amount = 0.0
	rotation_degrees = 0.0
	_set_effects(1.0, 0.0)


func play_normal():
	_set_texture(normal_texture)


func play_happy():
	_set_texture(happy_texture)


func play_sad():
	_set_texture(sad_texture)


func play_look_right():
	_set_texture(look_right_texture)


func play_look_down():
	_set_texture(look_down_texture)


func play_look_up():
	_set_texture(look_up_texture)


func _set_texture(texture: Texture2D):
	if texture == null:
		return
	
	if texture_tween:
		texture_tween.kill()
	
	sprite.texture = texture
	sprite.scale = Vector2(1.44, 1.76)
	
	texture_tween = create_tween()
	texture_tween.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


func flip_toward_left():
	scale.x = -abs(scale.x)


func flip_toward_right():
	scale.x = abs(scale.x)


func set_facing_left(is_left: bool):
	if is_left:
		flip_toward_left()
	else:
		flip_toward_right()


func bubble_emote(emote_id: String, duration := 1.5):
	var texture := _get_emote_texture(emote_id)
	if texture == null:
		return
	
	if emote_tween:
		emote_tween.kill()
	
	emotion_icon.texture = texture
	emotion_bubble.visible = true
	emotion_bubble.modulate.a = 0.0
	emotion_bubble.scale = Vector2.ZERO
	
	emote_tween = create_tween()
	emote_tween.tween_property(emotion_bubble, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	emote_tween.parallel().tween_property(emotion_bubble, "modulate:a", 1.0, 0.12)
	emote_tween.tween_interval(duration)
	emote_tween.tween_property(emotion_bubble, "scale", Vector2.ZERO, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	emote_tween.parallel().tween_property(emotion_bubble, "modulate:a", 0.0, 0.15)
	
	await emote_tween.finished
	emotion_bubble.visible = false


func move_to(target: Vector2, duration := 0.75):
	if move_tween:
		move_tween.kill()
	
	var lean := clampf((target.x - global_position.x) / 60.0, -1.0, 1.0) * 6.0 * signf(scale.x) # A small tilt toward where he is going
	move_tween = create_tween().set_parallel(true)
	move_tween.tween_property(self, "global_position", target, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)
	var tilt := create_tween()
	tilt.tween_property(self, "rotation_degrees", lean, duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tilt.tween_property(self, "rotation_degrees", 0.0, duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await move_tween.finished


func hop():
	var base_y := position.y
	var tween := create_tween()
	tween.tween_property(self, "position:y", base_y - 16, 0.12)
	tween.tween_property(self, "position:y", base_y, 0.18)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished


func shake():
	var original := position
	var tween := create_tween()
	for i in 4:
		tween.tween_property(self, "position", original + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
	tween.tween_property(self, "position", original, 0.08)
	await tween.finished


func _get_emote_texture(emote_id: String) -> Texture2D:
	match emote_id:
		"worry":
			return worry_emote
		"exclamation":
			return exclamation_emote
		"question":
			return question_emote
	
	push_warning("Unknown Tuh-U emote: " + emote_id)
	return null
