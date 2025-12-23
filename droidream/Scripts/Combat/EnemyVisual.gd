extends Node2D

# Universal attack pattern logic for all enemies, uses emitters for connecting animations

class_name EnemyVisual

signal attack_hit
signal attack_finished

@onready var anim := $AnimationPlayer

func play_attack(animation_name: String):
	anim.play(animation_name)

func on_attack_hit():
	attack_hit.emit()

func _ready():
	anim.animation_finished.connect(on_anim_finished)

func on_anim_finished(name: String):
	if name != "idle":
		attack_finished.emit()
