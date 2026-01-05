extends Node2D

# Universal attack pattern logic for all enemies, uses emitters for connecting animations in CombatManager

class_name EnemyVisual

signal attack_started
signal attack_hit
signal attack_finished

@onready var anim := $AnimationPlayer
@onready var visual: Node2D = $Visual

var home_position : Vector2 # The enemy's original position
var attack_position : Vector2 # The position where the enemy's pattern will connect to the (intended) player sprite

# Enemy moves to position, attacks, returns back to original position
func play_attack(animation_name: String):
	await _move_to_attack_position()
	attack_started.emit()
	anim.play(animation_name)

func on_attack_hit():
	attack_hit.emit()

func _ready():
	home_position = global_position
	attack_position = home_position + Vector2(-320, 0)
	anim.animation_finished.connect(on_anim_finished)

func on_anim_finished(name: String):
	if name == "idle":
		return
	await _move_to_home_position()
	attack_finished.emit()

# Movement methods for connecting patterns using tweens (same methods just in reverse)
func _move_to_attack_position():
	var tween := create_tween()
	tween.tween_property(self, "global_position", attack_position, 1.5)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func _move_to_home_position():
	var tween := create_tween()
	tween.tween_property(self, "global_position", home_position, 1.5)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)
	await tween.finished
