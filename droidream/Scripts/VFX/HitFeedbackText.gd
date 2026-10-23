extends Node2D

# Text feedback for all player activity (blocks, crits etc)

@onready var label: RichTextLabel = $RichTextLabel

var float_height := 50
const lifetime := 0.6
const INFO_LIFETIME := 1.4

const FLAIR_LIFETIME := 1.15

func play_flair(bbcode_text: String, glow_color := Color("#fff27a"), font_size := 22):
	label.text = bbcode_text
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	rotation_degrees = randf_range(-4, 4)
	label.modulate.a = 0.0
	scale = Vector2(0.15, 0.15)
	
	# Glows behind the text
	var glow: RichTextLabel = label.duplicate()
	glow.add_theme_constant_override("outline_size", 6)
	glow.add_theme_color_override("font_outline_color", glow_color)
	glow.modulate = Color(glow_color, 0.0)
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = glow_material
	add_child(glow)
	move_child(glow, 0)
	
	# Sparkles from the center of the text
	var sparkles := CPUParticles2D.new()
	var fade := Gradient.new()
	fade.set_color(0, glow_color)
	fade.set_color(1, Color(glow_color, 0.0))
	sparkles.color_ramp = fade
	sparkles.position = Vector2(47, 0)
	sparkles.one_shot = true
	sparkles.explosiveness = 1.0
	sparkles.amount = 14
	sparkles.lifetime = 0.4
	sparkles.spread = 50.0
	sparkles.direction = Vector2.UP
	sparkles.initial_velocity_min = 30.0
	sparkles.initial_velocity_max = 70.0
	sparkles.gravity = Vector2(0, 90)
	sparkles.scale_amount_min = 1.0
	sparkles.scale_amount_max = 2.5
	add_child(sparkles)
	sparkles.emitting = true
	
	# Pop with overshoot
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2.ONE * 1.7, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2.ONE * 1.4, 0.25)
	
	# Glow pulse
	var pulse := create_tween()
	pulse.tween_property(glow, "modulate:a", 0.85, 0.15)
	pulse.tween_property(glow, "modulate:a", 0.35, 0.3)
	pulse.tween_property(glow, "modulate:a", 0.7, 0.3)
	pulse.tween_property(glow, "modulate:a", 0.0, 0.5)
	
	# Float and disappear
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_property(self, "position:y", position.y - 36, FLAIR_LIFETIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(FLAIR_LIFETIME - 0.4)
	await tween.finished
	queue_free()

# Smaller and longer-lived text for items, abilities and reveals
func play_info(bbcode_text: String, info_time := INFO_LIFETIME):
	label.text = bbcode_text
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_constant_override("outline_size", 4)
	rotation_degrees = 0
	label.modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 24, info_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(info_time - 0.35)
	await tween.finished
	queue_free()

# A muted text that sinks a little and fades, for a missed icon
func play_miss(bbcode_text: String):
	label.text = bbcode_text
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_constant_override("outline_size", 4)
	rotation_degrees = randf_range(-3, 3)
	label.modulate.a = 0.0
	scale = Vector2(1.1, 1.1)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.5)
	tween.tween_property(self, "position:y", position.y + 14, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	await tween.finished
	queue_free()

# The standard pop; strength scales its size (a Try is smaller than a Good)
func play(bbcode_text: String, strength := 1.0):
	label.text = bbcode_text
	rotation_degrees = randf_range(-4, 4)
	label.modulate.a = 0.0
	scale = Vector2(1.35, 0.65)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.08)
	
	# Stretching/scaling
	tween.parallel().tween_property(
		self,
		"scale",
		Vector2(0.75, 1.25),
		0.12
	)
	tween.tween_property(
		self,
		"scale",
		Vector2.ONE * 1.35 * strength,
		lifetime
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Positioning
	tween.parallel().tween_property(
		self,
		"position:x",
		position.x + randf_range(-12, 12),
		lifetime
	)
	tween.parallel().tween_property(
		self,
		"position:y",
		position.y - 40,
		lifetime
	)
	
	# Disappearing
	tween.parallel().tween_property(
		label,
		"modulate:a",
		0.0,
		0.25
	).set_delay(0.35)
	await tween.finished
	queue_free()
