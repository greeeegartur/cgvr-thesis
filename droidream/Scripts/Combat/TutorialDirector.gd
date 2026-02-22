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
@onready var hint_node := $"../UI/HintNode"

# Timer hint logic
var idle_timer := 0.0
var hint_delay := 6.0

var ufo_idle_tween : Tween

const TUTORIAL_COLORS := {
	"creatures": "#8df59a",        # light green
	"taming": "#ffb347",           # light orange
	"abilities": "#b388ff",        # purple
	"items": "#7ec8ff",            # light blue
	"type": "#5cff7a",             # green
	"trust": "#ff9de2",            # dreamish pink
	"hurt": "#ff4d4d",             # red
	"sky": "#f7ff3c",              # neon yellow
	"water": "#4da6ff",            # blue
	"earth": "#8b5a2b",            # brown
	"droid": "#bfbfbf",            # gray
	"bolts": "#ffd700"             # golden
}


func _ready():
	await speech_bubble.ready
	player_visual.hide_hp()
	speech_bubble.set_target(ufo)
	speech_bubble.hide_tail()
	enter_cinematic()
	
	intro_scene()

func _process(delta: float):
	if speech_bubble.visible and speech_bubble.mode == SpeechBubble.BubbleMode.CINEMATIC:
		idle_timer += delta
		
		if Input.is_action_just_pressed("ui_accept"):
			idle_timer = -6.0
			hint_out()
			hint_node.visible = false
		
		if idle_timer > hint_delay:
			hint_node.visible = true
			hint_in()

func hint_in():
	hint_node.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(hint_node, "modulate:a", 1.0, 0.2)
	await tween.finished

func hint_out():
	var tween = create_tween()
	tween.tween_property(hint_node, "modulate:a", 0.0, 0.2)
	await tween.finished

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
	await camera.follow(player_visual)
	await get_tree().create_timer(1.0).timeout
	
	speech_bubble.show_bubble()
	await speech_bubble.say_line("Hey! Are you alright?")
	await speech_bubble.say_line("Come on, wake up!")
	speech_bubble.hide_bubble()
	
	await fade_from_black()
	speech_bubble.show_tail()
	
	speech_bubble.show_bubble()
	await speech_bubble.say_line("..Oh. You were… sleeping here?")
	# ufo.play_happy()
	await speech_bubble.say_line("Quite an odd place for a nap, don’t you think?")
	speech_bubble.hide_bubble()
	
	# *The Droid looks around, notices it’s in a jungle, question mark bubble*
	await get_tree().create_timer(1).timeout
	
	# ufo.play_normal()
	speech_bubble.show_bubble()
	await speech_bubble.say_line("Huh? You’re lost?")
	# ufo.play_happy()
	await speech_bubble.say_line("So this isn’t a lifestyle choice. What a relief!")
	speech_bubble.hide_bubble()
	
	# *The Droid nods at Tuh-U without emotion*
	await get_tree().create_timer(1).timeout
	
	speech_bubble.show_bubble()
	# ufo.play_normal()
	await speech_bubble.say_line("..Oh, right. You’re actually lost.")
	speech_bubble.hide_bubble()
	
	#*Camera zooms in on Tuh-U*
	await get_tree().create_timer(1).timeout
	
	speech_bubble.show_bubble()
	await speech_bubble.say_line("My name is [b]Tuh-U[/b], I know these parts well.")
	speech_bubble.hide_bubble() 
	
	await get_tree().create_timer(1).timeout
	#*Camera zooms out to previous position*
	
	speech_bubble.show_bubble()
	await speech_bubble.say_line("Can you describe your home? Maybe I can point you in the right direction.")
	speech_bubble.hide_bubble()
	
	#*The Droid explains where it last dozed off, Tuh-U exclamation mark bubble*
	await get_tree().create_timer(1).timeout
	
	speech_bubble.show_bubble()
	# ufo.play_happy()
	await speech_bubble.say_line("Ah! I know this place.")
	await speech_bubble.say_line("Wow, though.. You’ve come quite a long way. ")
	speech_bubble.hide_bubble()
	
	await get_tree().create_timer(1).timeout
	#*Worry bubble for The Droid*
	
	speech_bubble.show_bubble()
	# ufo.play_look_right()
	await speech_bubble.say_line("To get back, you’d need to cross the cliffside.")
	await speech_bubble.say_line("But the cliffside itself is beyond this jungle and a cavern system..")
	# ufo.play_sad()
	await speech_bubble.say_line("It’s no easy path, the road is full of all sorts of [color=#8df59a]wild creatures[/color].")
	await speech_bubble.say_line("For someone so young like yourself… It can be a dangerous journey.")
	speech_bubble.hide_bubble()
	
	await get_tree().create_timer(1).timeout
	#*The Droid shows Tuh-U its book about creatures*
	
	speech_bubble.show_bubble()
	# ufo.play_happy()
	await speech_bubble.say_line("Oh, wow! A [color=#8df59a]creature book[/color]!")
	await speech_bubble.say_line("I didn’t think you were this talented! No offense.")
	await speech_bubble.say_line("You must be an expert at [color=#ffb347]taming creatures[/color] then?")
	speech_bubble.hide_bubble()
	
	#*Worry bubble for The Droid as it frowns*
	await get_tree().create_timer(1).timeout
	
	speech_bubble.show_bubble()
	# ufo.play_sad()
	await speech_bubble.say_line("..Or not?")
	speech_bubble.hide_bubble()
	
	# Pause for a few seconds
	await get_tree().create_timer(2).timeout
	
	speech_bubble.show_bubble()
	# ufo.play_happy()
	await speech_bubble.say_line("Not to worry though, I can teach you the basics.")
	speech_bubble.hide_bubble()
	
	#*The Droid is surprised, exclamation mark bubble*
	await get_tree().create_timer(1).timeout
	
	speech_bubble.show_bubble()
	await speech_bubble.say_line("The journey ahead would still be difficult, but I see great ambition in you!")
	await speech_bubble.say_line("With a little help, I’m sure you can make it back home!")
	speech_bubble.hide_bubble()
	
	# ufo.flip()
	await get_tree().create_timer(1).timeout
	
	speech_bubble.show_bubble()
	# ufo.play_normal()
	await speech_bubble.say_line("..Let’s see now… ")
	speech_bubble.hide_bubble()
	
	#*Tuh-U flies to the right, camera follows*
	#*Tuh-U releases a beam and spawns in a Dummy*
	await get_tree().create_timer(1).timeout
	camera.reset_camera()
	#*Camera returns to combat scene standard*
	
	speech_bubble.show_bubble()
	await speech_bubble.say_line("This should work!")
	speech_bubble.hide_bubble()
	
	# ufo.flip()
	await get_tree().create_timer(1).timeout
	
	speech_bubble.show_bubble()
	# ufo.play_happy()
	await speech_bubble.say_line("Are you ready? Let’s begin!")
	speech_bubble.hide_bubble()


func spawn_dummy_enemy():
	print("spawn dummy here")

func guided_combat_phase():
	print("combat starts and tuhu talks here during combat")

func minigame_interruption():
	print("tuhu appears and talks during minigame")

func outro_scene():
	print("droid walks to the right of the scene")

# HELPERS

func bb(key: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [TUTORIAL_COLORS[key], text]
