extends Node

# This script is responsible for all things cutscenes, most heavily on the tutorial cutscene
# The logic here just has to work in the context of super specific tutorials, so there won't be any inherent future-proofing or commenting

class_name TutorialDirector

@onready var black := $"../UI/Black"
@onready var combat_manager := $"../CombatManager"
@onready var player_visual := $"../World/PlayerVisual"
@onready var player_turn_ui := $"../UI/CombatUI/PlayerTurnUi"
@onready var camera := $"../Camera2D"
@onready var ufo := $"../World/TuhU"
@onready var speech_bubble := $"../UI/SpeechBubble"
@onready var hint_node := $"../UI/HintNode"
@onready var tutorial_overlay := $"../UI/TutorialOverlay"

var original_ufo_parent: Node
var original_speech_parent: Node
var ufo_was_on_overlay := false

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

const UFO_POS_INTRO := Vector2(166, 227)
const UFO_POS_DUMMY := Vector2(390, 195)
const UFO_POS_GEAR := Vector2(145, 185)
const UFO_POS_TYPE_PANEL := Vector2(245, 165)
const UFO_POS_MINIGAME_RIGHT := Vector2(555, 205)
const UFO_POS_OUTRO := Vector2(150, 205)

var dummy_enemy: CombatEntity

func _ready():
	await speech_bubble.ready
	
	PlayerData.set_guesses(0, 4, 0)
	player_visual.hide_hp()
	speech_bubble.set_target(ufo)
	speech_bubble.hide_tail()
	combat_manager.ui.hide_player_stats_hud()
	
	lock_input()
	await play_tutorial()

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
	combat_manager.player_turn_ui.lock_input()
	player_visual.set_input_enabled(false)

func unlock_input():
	combat_manager._resume_combat()
	player_visual.set_input_enabled(true)

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
	camera.follow(player_visual)
	_start_ufo_idle()
	await get_tree().create_timer(1.5).timeout
	
	await intro_scene()
	await guided_combat_phase()
	await dream_tutorial_phase()
	await outro_scene()

func intro_scene():
	lock_input()
	
	# Initial speech before the scene fully fades in.
	speech_bubble.set_target(ufo)
	speech_bubble.hide_tail()
	
	await say("Hey! Are you alright?", "normal")
	await say("Come on, wake up!", "normal")
	end_say()
	
	await fade_from_black()
	speech_bubble.show_tail()
	
	# Droid wakes up.
	await get_tree().create_timer(1.0).timeout
	
	await say("..Oh. You were… sleeping here?", "normal")
	await say("Quite an odd place for a nap, don’t you think?", "happy")
	end_say()
	
	# Droid notices the jungle.
	await player_visual.bubble_emote("question")
	await get_tree().create_timer(0.25).timeout
	
	await say("Huh? You’re lost?", "normal")
	await say("So this isn’t a lifestyle choice, what a relief!", "happy")
	end_say()
	
	# Droid nods silently.
	await player_nod()
	
	await say("..Oh, right. You’re actually lost.", "normal")
	end_say()
	
	# Camera focuses on Tuh-U introduction.
	camera.follow(ufo)
	await get_tree().create_timer(0.35).timeout
	
	await say("My name is [b]Tuh-U[/b], I know these parts well.", "normal")
	end_say()
	
	camera.follow(player_visual)
	await get_tree().create_timer(0.25).timeout
	
	await say("Can you describe your home? Maybe I can point you in the right direction.", "normal")
	end_say()
	
	# Droid explains. Tuh-U reacts.
	await player_explain()
	await ufo.bubble_emote("exclamation")
	
	await say("Ah! I know this place.", "happy")
	await say("Wow, though.. You’ve come quite a long way.", "normal")
	end_say()
	
	await player_visual.bubble_emote("worry")
	
	await say("To get back, you’d need to cross the cliffside.", "right")
	await say("But the cliffside is beyond this jungle and a cavern system.", "normal")
	await say("It’s no easy path, the road is full of all sorts of %s." % bb("creatures", "wild creatures"), "sad")
	await say("For someone so young like yourself… It can be a dangerous journey.", "sad")
	end_say()
	
	# Droid shows creature book.
	await player_show_book()
	
	await say("Oh, wow! A %s book!" % bb("creatures", "creature"), "happy")
	await say("I didn’t think you were this talented! No offense.", "happy")
	await say("You must be an expert at %s then?" % bb("taming", "taming creatures"), "happy")
	end_say()
	
	await player_frown()
	await get_tree().create_timer(0.65).timeout
	
	await say("..Or not?", "sad")
	end_say()
	
	await get_tree().create_timer(1.4).timeout
	
	await say("Not to worry though, I can teach you the basics.", "happy")
	end_say()
	
	await player_visual.bubble_emote("exclamation")
	
	await say("The journey ahead would still be difficult, but I see great ambition in you!", "happy")
	await say("With a little help, I’m sure you can make it back home!", "happy")
	end_say()
	
	await get_tree().create_timer(0.25).timeout
	
	# Tuh-U thinks, turns, and prepares the tutorial dummy.
	ufo.flip_toward_right()
	await say("..Let’s see now…", "normal")
	end_say()
	
	await spawn_dummy_enemy()

func spawn_dummy_enemy():
	camera.follow(ufo)
	await move_ufo_to(UFO_POS_DUMMY, 0.9, false)
	
	ufo.play_look_down()
	await get_tree().create_timer(0.65).timeout
	
	var tutorial_enemy_ids := ["dummy"]
	dummy_enemy = await combat_manager.start_tutorial_combat(tutorial_enemy_ids)
	
	await camera.reset_camera()
	_start_ufo_idle()
	
	await say("This should work!", "happy")
	end_say()
	
	ufo.flip_toward_left()
	await get_tree().create_timer(0.25).timeout
	await say("Are you ready? Let’s begin!", "happy")
	end_say()

func guided_combat_phase():
	lock_input()
	combat_manager.tutorial_begin_player_turn_locked()
	combat_manager.player_turn_ui.visible = true
	
	await move_ufo_to(UFO_POS_GEAR, 0.7)
	camera.follow(ufo)
	
	await say("When confronting a %s, there are several ways to handle it." % bb("creatures", "creature"), "normal")
	
	player_turn_ui._move_gear(1)
	await get_tree().create_timer(0.2).timeout
	
	await say("You could use your various %s!" % bb("abilities", "abilities"), "happy")
	await say("..Which you don’t have!", "normal")
	
	player_turn_ui._move_gear(1)
	await get_tree().create_timer(0.2).timeout
	
	await say("Or your plethora of %s!" % bb("items", "items"), "happy")
	await say("..Which you also don’t have as of %s!" % get_month_day_string(), "normal")
	
	player_turn_ui._move_gear(1)
	await get_tree().create_timer(0.2).timeout
	
	await overlay_say("..But the general course of action would be to %s creatures." % bb("taming", "tame"), "normal")
	await wait_for_accept()
	
	combat_manager.player_turn_ui.state = combat_manager.player_turn_ui.State.ATTACK_TYPE_SELECT
	player_turn_ui.lock_input()
	
	await camera.reset_camera()
	await move_ufo_to(UFO_POS_TYPE_PANEL, 0.6)
	ufo.set_facing_left(false)
	
	await say("In order to %s, you must know what %s of creature it is." % [
		bb("taming", "tame a creature"),
		bb("type", "type")
	], "normal")
	await say("Treating them as the %s they are makes the %s %s." % [
		bb("type", "type"),
		bb("creatures", "creature"),
		bb("trust", "trust you")
	], "normal")
	await say("..Any other %s can %s, or even worse…" % [
		bb("type", "type"),
		bb("hurt", "hurt the creature")
	], "sad")
	end_say()
	
	await move_ufo_to(UFO_POS_DUMMY, 0.7)
	camera.follow(enemy_visual_for_dummy())
	
	await say("A %s can be guessed by their characteristics." % bb("type", "creature’s type"), "normal")
	await say("Usually just looking at %s is enough to know." % bb("creatures", "a creature"), "down")
	await say("Does it %s? Can it %s? Is it just %s?" % [
		bb("sky", "fly"),
		bb("water", "swim"),
		bb("earth", "standing menacingly")
	], "happy")
	await say("Like this dummy here, who is extraordinarily ordinary, is still rooted to %s." % bb("earth", "the ground"), "normal")
	await say("If it were alive, it would be an %s." % bb("earth", "earth creature"), "normal")
	end_say()
	
	await camera.reset_camera()
	await overlay_say("For practice, try %s as an %s!" % [
		bb("taming", "taming it"),
		bb("earth", "earth creature")
	], "normal")
	
	await tutorial_wait_for_first_earth_hit()

func dream_tutorial_phase():
	await say("Now there’s one more important thing I want to show you..", "normal")
	end_say()
	
	await move_ufo_to(UFO_POS_DUMMY + Vector2(-30, 0), 0.65)
	camera.follow(enemy_visual_for_dummy())
	
	combat_manager.tutorial_prepare_dummy_for_minigame()
	await get_tree().create_timer(0.35).timeout
	
	await say("Once a %s is close to being tamed, it starts to %s." % [
		bb("creatures", "creature"),
		bb("trust", "trust you")
	], "down")
	await say("And once it fully does, you, as a %s, have the ability to %s." % [
		bb("droid", "droid"),
		bb("trust", "seal that bond")
	], "normal")
	await say("What you’ll see is a vision of that %s." % bb("trust", "creature’s dream"), "normal")
	await say("A %s is unique to a creature and they can be… well, anything really." % bb("trust", "dream"), "happy")
	await say("For practice sake, let’s pretend the dummy has a %s." % bb("trust", "dream"), "normal")
	end_say()
	
	await camera.reset_camera()
	
	await overlay_say("Let’s try %s it one last time!" % bb("taming", "taming"), "normal")
	await wait_for_accept()
	
	combat_manager.tutorial_unlock_player_turn_ui()
	combat_manager.player_turn_ui.menu_indices[combat_manager.player_turn_ui.MENU_ATTACK] = 1
	
	var minigame = await combat_manager.tutorial_minigame_started
	lock_input()
	
	if minigame.has_method("set_tutorial_paused"):
		minigame.set_tutorial_paused(true)
	else:
		get_tree().paused = true
	
	await explain_minigame(minigame)


func outro_scene():
	lock_input()
	combat_manager.player_turn_ui.hide_player_turn_ui()
	
	camera.follow(ufo)
	await move_ufo_to(UFO_POS_OUTRO, 0.6)
	
	await say("For a first time you picked up on %s real fast!" % bb("taming", "taming"), "happy")
	await say("Seeing you in practice.. I’m sure you’ll make it back home in one piece.", "happy")
	await say("I haven’t seen talent like yours in a long time.", "happy")
	await say("If it’s not much of a bother… I got to thinking.", "down")
	await say("Would you be okay with me accompanying you to the cliffside?", "normal")
	end_say()
	
	await player_visual.hop()
	await get_tree().create_timer(0.25).timeout
	await player_visual.bubble_emote("exclamation")
	await ufo.hop()
	
	await say("I’m glad! We’re sure to make quite the power team!", "happy")
	await say("I’ll set up all sorts of %s on the way for us to rest." % bb("items", "stops"), "happy")
	await say("If you find any %s, you can buy all sorts of stuff I find!" % bb("bolts", "bolts"), "happy")
	await say("%s can also attack you during encounters, so stopping once in a while is a must." % bb("creatures", "Wild creatures"), "down")
	await say("Though with me by your side, I’m sure we’ll make it there just fine!", "happy")
	await say("Are you ready? Let’s go!", "normal")
	end_say()
	
	await walk_out_and_finish()

# HELPERS

func bb(key: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [TUTORIAL_COLORS[key], text]

func say(text: String, mood := "normal", target: Node2D = ufo):
	speech_bubble.set_target(target)
	
	match mood:
		"happy":
			ufo.play_happy()
		"sad":
			ufo.play_sad()
		"right":
			ufo.play_look_right()
		"down":
			ufo.play_look_down()
		"up":
			ufo.play_look_up()
		_:
			ufo.play_normal()
	
	speech_bubble.show_bubble()
	await speech_bubble.say_line(text)

func end_say():
	speech_bubble.hide_bubble()

func overlay_say(text: String, mood := "normal"):
	await say(text, mood)
	hint_node.visible = true
	hint_in()

func wait_for_accept():
	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame
	
	hint_out()
	hint_node.visible = false

func move_ufo_to(pos: Vector2, duration := 0.75, restart_idle := true):
	_stop_ufo_idle()
	await ufo.move_to(pos, duration)
	
	if restart_idle:
		_start_ufo_idle()

func tutorial_wait_for_first_earth_hit():
	combat_manager.tutorial_unlock_player_turn_ui()
	combat_manager.player_turn_ui.menu_indices[combat_manager.player_turn_ui.MENU_ATTACK] = 1 # Earth, based on Sky/Earth/Water order
	
	hint_node.visible = true
	hint_in()
	
	var result = await combat_manager.tutorial_attack_resolved
	hint_out()
	hint_node.visible = false
	
	var critical: bool = result[0]
	
	combat_manager.tutorial_lock_player_turn_ui()
	lock_input()
	await camera.reset_camera()
	
	if critical:
		await say("Wow, you’ve got a real knack for this!", "happy")
		await say("I was about to teach you %s during %s, but it seems you figured it out yourself!" % [
			bb("taming", "a neat trick"),
			bb("taming", "taming")
		], "happy")
	else:
		await say("That was great! You’re a natural!", "happy")
	await get_tree().create_timer(0.25).timeout
	end_say()
	await get_tree().create_timer(0.25).timeout
	await explain_memory_chips()
	
	if not critical:
		await crit_tutorial_phase()

func explain_memory_chips():
	await say("After %s, one of that last %s will be used." % [
		bb("taming", "taming a creature"),
		bb("type", "type")
	], "normal")
	await say("You’re a %s, so an action like %s processes your %s." % [
		bb("droid", "droid"),
		bb("taming", "taming"),
		bb("type", "memory")
	], "normal")
	await say("It’s cool though! On the way you’re bound to get more %s that will restore your %s!" % [
		bb("droid", "chips"),
		bb("type", "memory")
	], "happy")
	end_say()
	await get_tree().create_timer(0.25).timeout

func crit_tutorial_phase():
	await overlay_say("Let’s try %s the dummy again, but this time I want to show you %s!" % [
		bb("taming", "taming"),
		bb("taming", "a neat trick")
	], "normal")
	await wait_for_accept()
	
	combat_manager.tutorial_unlock_player_turn_ui()
	combat_manager.player_turn_ui.menu_indices[combat_manager.player_turn_ui.MENU_ATTACK] = 1
	
	await overlay_say("Once you start %s, try %s right before making contact with the creature." % [
		bb("taming", "taming"),
		bb("taming", "timing")
	], "normal")
	await wait_for_accept()
	
	var result = await combat_manager.tutorial_attack_resolved
	var critical: bool = result[0]
	
	combat_manager.tutorial_lock_player_turn_ui()
	lock_input()
	
	end_say()
	await camera.reset_camera()
	
	if critical:
		await say("Wow, you’ve got a real knack for this!", "happy")
	else:
		await say("That’s okay. The timing is tricky at first!", "sad")
		await say("I'm sure you'll get it right the more you %s." % [
			bb("taming", "tame")
		], "normal")
	
	await say("Lots of actions can be %s when confronting %s, so always stay alert!" % [
		bb("taming", "timed"),
		bb("creatures", "creatures")
	], "happy")
	end_say()
	await get_tree().create_timer(0.25).timeout

func explain_minigame(minigame):
	move_tutorial_actors_above_minigame()
	lock_input()
	
	await move_ufo_to(UFO_POS_MINIGAME_RIGHT, 0.5)
	ufo.set_facing_left(false)
	speech_bubble.set_target(ufo)
	
	await say("This is what a %s looks like." % bb("trust", "creature’s dream"), "normal")
	await say("Each one’s settings and conditions can be different, it all depends on the %s." % bb("creatures", "creature"), "normal")
	await say("As a %s, you can see these conditions and will know what to do." % bb("droid", "droid"), "normal")
	await say("Though %s can’t be seen for long, so it’s important to realise them quick!" % bb("trust", "dreams"), "sad")
	await say("Let’s see… The dummy wants you to…", "up")
	
	await overlay_say("[b]“Press Z”[/b]? For charges? Who even is Z?", "normal")
	end_say()
	minigame.set_tutorial_paused(false)
	var success = await _wait_for_tutorial_minigame_finished()
	
	lock_input()
	await ufo.shake()
	await get_tree().create_timer(0.4).timeout
	await ufo.move_to(UFO_POS_OUTRO, 1.5)
	camera.follow(player_visual)
	
	if success:
		await say("…Well that was something.", "normal")
		await say("Though good job on %s!" % bb("trust", "realising the dream"), "happy")
		await say("You really look like you know what you’re doing!", "happy")
	else:
		await say("Huh. What a confusing dream.", "normal")
		await say("Don’t worry about not %s, it was just a dummy." % bb("trust", "realising it"), "normal")
		await say("In normal circumstances though, I would suggest to be more alert.", "normal")
	
	end_say()
	await get_tree().create_timer(0.25).timeout

func walk_out_and_finish():
	camera.reset_camera()
	ufo.flip_toward_right()
	player_visual.anim.play("player_walk")
	
	var tween := create_tween()
	tween.tween_property(player_visual, "global_position:x", 760, 1.7)
	tween.parallel().tween_property(ufo, "global_position:x", 800, 1.5)
	await tween.finished
	
	await fade_into_black()
	PlayerData.reset_run()
	get_tree().change_scene_to_file("res://Scenes/CombatScene.tscn")

func enemy_visual_for_dummy() -> Node2D:
	if dummy_enemy == null:
		return null
	
	return combat_manager.enemy_visuals.get(dummy_enemy)

func get_month_day_string() -> String:
	var date := Time.get_datetime_dict_from_system()
	return "%02d/%02d" % [date["month"], date["day"]]

func player_nod():
	# Replace with an actual nod animation later if you make one.
	var base_y = player_visual.position.y
	var tween := create_tween()
	tween.tween_property(player_visual, "position:y", base_y + 4, 0.12)
	tween.tween_property(player_visual, "position:y", base_y, 0.12)
	tween.tween_property(player_visual, "position:y", base_y + 4, 0.12)
	tween.tween_property(player_visual, "position:y", base_y, 0.12)
	await tween.finished


func player_explain():
	# Small placeholder "talking/gesturing" movement.
	var original = player_visual.position
	var tween := create_tween()
	tween.tween_property(player_visual, "position:x", original.x + 4, 0.12)
	tween.tween_property(player_visual, "position:x", original.x - 4, 0.12)
	tween.tween_property(player_visual, "position:x", original.x, 0.12)
	await tween.finished


func player_show_book():
	# Replace with a book animation later.
	await player_visual.bubble_emote("exclamation", 1.0)
	await get_tree().create_timer(0.25).timeout


func player_frown():
	# Optional hook if you later add a frown texture/animation.
	if player_visual.anim.has_animation("player_frown"):
		player_visual.anim.play("player_frown")
		await get_tree().create_timer(0.6).timeout
	else:
		await get_tree().create_timer(0.35).timeout

func move_tutorial_actors_above_minigame():
	if ufo_was_on_overlay:
		return
	
	ufo_was_on_overlay = true
	
	original_ufo_parent = ufo.get_parent()
	original_speech_parent = speech_bubble.get_parent()
	
	ufo.reparent(tutorial_overlay, true)
	speech_bubble.reparent(tutorial_overlay, true)
	
	ufo.z_index = 100
	speech_bubble.layer = 101


func restore_tutorial_actors_layer():
	if not ufo_was_on_overlay:
		return
	
	ufo_was_on_overlay = false
	
	ufo.reparent(original_ufo_parent, true)
	speech_bubble.reparent(original_speech_parent, true)
	
	ufo.z_index = 0
	speech_bubble.z_index = 0
	
	speech_bubble.set_target(ufo)

func _wait_for_tutorial_minigame_finished() -> bool:
	var success: bool = await combat_manager.tutorial_minigame_finished
	return success
