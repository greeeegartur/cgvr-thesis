extends Node

# This script is responsible for all things cutscenes, most heavily on the tutorial cutscene
# The logic here just has to work in the context of super specific tutorials, so there won't be any inherent future-proofing or commenting

class_name TutorialDirector

@onready var top_bar := $"../UI/BlackBars/Above"
@onready var bottom_bar := $"../UI/BlackBars/Below"
@onready var black := $"../UI/Black"
@onready var combat_manager := $"../CombatManager"
@onready var player_visual := $"../World/PlayerVisual"
@onready var camera := $"../Camera2D"
@onready var ufo := $"../World/TuhU"
@onready var speech_bubble := $"../UI/SpeechBubble"

var ufo_idle_tween : Tween

func _ready():
	await speech_bubble.ready
	player_visual.hide_hp()
	speech_bubble.set_target(ufo)
	speech_bubble.hide_tail()
	enter_cinematic()
	
	intro_scene()

func lock_input():
	combat_manager._pause_combat()
	set_process_input(false)

func unlock_input():
	combat_manager._resume_combat()

func enter_cinematic():
	var tween := create_tween()
	tween.tween_property(top_bar, "size:y", 45, 0.45)
	tween.parallel().tween_property(bottom_bar, "size:y", 45, 0.45)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

func exit_cinematic():
	var tween := create_tween()
	tween.tween_property(top_bar, "size:y", 0, 0.45)
	tween.parallel().tween_property(bottom_bar, "size:y", 0, 0.45)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

func fade_from_black():
	await get_tree().create_timer(0.45).timeout
	
	black.visible = true
	var tween = create_tween()
	tween.tween_property(black, "modulate:a", 0.0, 1.8)
	await tween.finished
	
	black.visible = false

func fade_into_black():
	black.visible = true
	
	var tween = create_tween()
	tween.tween_property(black, "modulate:a", 1.0, 1.8)
	await tween.finished

func _start_ufo_idle():
	_stop_ufo_idle()

	ufo_idle_tween = create_tween()
	ufo_idle_tween.set_loops()

	ufo_idle_tween.tween_property(
		ufo,
		"position:y",
		ufo.position.y + 10,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	ufo_idle_tween.tween_property(
		ufo,
		"position:y",
		ufo.position.y,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_ufo_idle():
	if ufo_idle_tween:
		ufo_idle_tween.kill()
		ufo_idle_tween = null

func play_tutorial():
	await intro_scene()
	await spawn_dummy_enemy()
	await guided_combat_phase()
	await minigame_interruption()
	await outro_scene()

func intro_scene():
	_start_ufo_idle()
	
	await speech_bubble.say("Hey! Are you alright?")
	
	await fade_from_black()
	speech_bubble.show_tail()
	
	await speech_bubble.say("..Were you... sleeping here?")
	
	print("intro before combat")

func spawn_dummy_enemy():
	print("spawn dummy here")

func guided_combat_phase():
	print("combat starts and tuhu talks here during combat")

func minigame_interruption():
	print("tuhu appears and talks during minigame")

func outro_scene():
	print("droid walks to the right of the scene")
