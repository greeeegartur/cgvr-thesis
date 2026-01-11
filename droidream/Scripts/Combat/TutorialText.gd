extends Node2D

# This script is responsible for tutorial texts during turns like "Press Z to block" etc.

class_name TutorialText

@onready var label := $Text/Label
@onready var z_icon := $Text/Sprite2D
@onready var anim := $Text/AnimationPlayer

# Methods for turns
func show_text(text: String):
	label.text = text
	visible = true
	modulate.a = 0.0
	
	# Press Z
	anim.play("press")
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

func hide_text():
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func():
		anim.stop()
		visible = false
	)

func show_crit_hint():
	z_icon.position = Vector2(62.0, 9.0)
	show_text("Press      right before hitting the enemy to crit!")

func show_block_hint():
	z_icon.position = Vector2(50.0, 9.0)
	show_text("Press      right before the enemy hits to block!")
