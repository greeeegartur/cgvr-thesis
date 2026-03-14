extends Node2D

# Text feedback for all player activity (blocks, crits etc)

@onready var label: RichTextLabel = $RichTextLabel

var float_height := 50
const lifetime := 0.6

func play(bbcode_text: String):
	#label.text = bbcode_text
	#label.modulate.a = 0
	#scale = Vector2(0.7, 0.7)
#
	#var tween = create_tween()
	#tween.parallel().tween_property(label, "modulate:a", 1.0, 0.08)
	#tween.parallel().tween_property(
		#self,
		#"position:y",
		#position.y - float_height,
		#lifetime
	#).set_trans(Tween.TRANS_SINE)
	#tween.parallel().tween_property(
		#self,
		#"scale",
		#Vector2.ONE * 1.2,
		#lifetime
	#).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	#tween.tween_property(label, "modulate:a", 0.0, 0.25)
#
	#await tween.finished
	#queue_free()
	#
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
		Vector2.ONE * 1.35,
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
