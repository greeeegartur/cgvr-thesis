extends Node

# This script directs the new tutorial: a short and straightforward walk through intent, types, taming (with its timing), blocking, abilities, items, dreams and the shop
# Its dialogue is written out in Resources/tutorial-new-script.md; like the first director the logic is for this one specific scene, so there is no future-proofing

class_name TutorialDirectorNew

@onready var black := $"../UI/Black"
@onready var combat_manager := $"../CombatManager"
@onready var player_visual := $"../World/PlayerVisual"
@onready var player_turn_ui := $"../UI/CombatUI/PlayerTurnUi"
@onready var camera := $"../Camera2D"
@onready var ufo := $"../World/TuhU"
@onready var tutorial_text: TutorialText = $"../UI/TutorialText"
@onready var tutorial_overlay := $"../TutorialOverlay" # Above the UI, follows the camera: Tuh-U lives here so no UI element covers him
@onready var ui_layer := $"../UI"


# Tuh-U talks in the pixel bubble of the shop (above him, growing to the right, a blinking arrow while it waits for Confirm)
var bubble: ShopBubble
var bubble_widths: Array = BUBBLE_WIDTHS
const BUBBLE_WIDTHS := [120.0, 150.0, 190.0, 230.0]
const DREAM_BUBBLE_WIDTHS := [120.0, 150.0, 190.0] # Beside the dream box, which must stay uncovered
const BUBBLE_LAYER := 90 # Above the minigame layer, below the pause menu
const STUTTER_TIME := 5.0 # Seconds without activity before the "Press Z" hint

var ufo_idle_tween : Tween

const TUTORIAL_COLORS := {
	"creatures": "#33a642",        # light green
	"taming": "#cc8623",           # light orange
	"abilities": "#6e47b3",        # purple
	"items": "#397fb3",            # light blue
	"type": "#1dad38",             # green
	"trust": "#c87dd4",            # dreamish pink
	"hurt": "#ff4d4d",             # red
	"sky": "#e8d04d",              # neon yellow
	"water": "#4da6ff",            # blue
	"earth": "#664220",            # brown
	"droid": "#636363",            # gray
	"bolts": "#ffd700"             # golden
}

# Where Tuh-U stands while he talks (the camera is in its normal wide view for every line, so these are screen positions too). Every move is a real flight with a reason; the far
# right is only for the dream box. The bubble needs about 45 px above him, and neither he nor it may cover the gear, the HUD rows in the top left, the Droid, the beetle's meter or the dream box
const SPOT_INTRO := Vector2(190, 150) # Near the Droid, greeting it
const SPOT_BEETLE_HEIGHT := 140.0 # Straight above the beetle looking down on it (its x comes from the beetle, see beetle_spot)
const SPOT_GEAR := Vector2(110, 150) # The Droid's side, clear of the gear's "Tame" label and icons: the gear, the type panel, the Droid's reactions and watching it act (still in view when the camera zooms in)
const SPOT_DREAM := Vector2(550, 175) # Low on the right, beside the dream box (the bubble sits next to the box, not over it)
const SPOT_OUTRO := Vector2(180, 175) # In front of the Droid, low enough that even a three line bubble clears the HUD (the dream box is gone and the gear UI hidden)
const PAUSE_SHORT := 0.1 # Beats between a bubble leaving, Tuh-U moving and the next bubble
const PAUSE_SETTLE := 0.15
const TUTORIAL_BEETLE_HP := 20.0 # The beetle is tough in the tutorial, so the first tame never fills its meter (the dream comes later, on purpose)
const BEETLE_ID := "beetle"
const EARTH_INDEX := 1 # Sky, Earth, Water

var beetle: CombatEntity
var skipping := false

func _ready():
	ControlTextures.swap_in(get_tree().current_scene) # The key pictures of the scheme in use
	var bubble_layer := CanvasLayer.new()
	bubble_layer.layer = BUBBLE_LAYER
	add_child(bubble_layer)
	bubble = ShopBubble.new()
	bubble_layer.add_child(bubble)

	# Dreams count down in the tutorial (the player is told that this can be turned off)
	MinigameCountdown.reset(true) # The tutorial's own dream counts down, whatever was known before
	Settings.set_minigame_countdown(true)
	combat_manager.tutorial_hold_minigame = true

	PlayerData.set_guesses(4, 4, 4) # All types have chips for the type question; only Earth keeps them after it
	tutorial_text.visible = true # The scene keeps it hidden for the first tutorial; the hints and the controls bar are used here
	tutorial_text.pin_hint([["SPACE", "Skip tutorial"]]) # Space leaves the tutorial at any time
	ufo.visible = false
	ufo.reparent(tutorial_overlay, true) # Once, while he faces right: reparenting a flipped node would turn it upside down
	ufo.rotation = 0.0
	ufo.scale = Vector2.ONE

	# The Droid's HP icon and the HUD are hidden before the first frame is seen (the black cover is still on); the nodes below this one are only ready after this frame
	await get_tree().process_frame
	hide_hp_now()
	hide_hud()

	lock_input()
	await play_tutorial()

# Space skips the whole tutorial at any time (not while the pause menu is open)
func _input(event: InputEvent) -> void:
	if skipping or PauseMenu.active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		skip_tutorial()

# Leaves the tutorial for the game: a fade, a fresh run and the combat scene
func skip_tutorial() -> void:
	skipping = true
	tutorial_text.unpin_hint()
	combat_manager._pause_combat()
	player_turn_ui.lock_input()
	_stop_ufo_idle()
	bubble.visible = false # Not end_say(): hiding a waiting line would let the director run on to its next line
	ufo.visible = false
	await fade_into_black()
	Engine.time_scale = 1.0 # In case a hit-stop was running
	PlayerData.reset_run()
	get_tree().change_scene_to_file("res://Scenes/Screens/CombatScene.tscn")

func lock_input():
	combat_manager._pause_combat()
	combat_manager.player_turn_ui.lock_input()
	player_visual.set_input_enabled(false)

func unlock_input():
	combat_manager._resume_combat()
	player_visual.set_input_enabled(true)

func fade_from_black():
	black.visible = true
	var tween = create_tween()
	tween.tween_property(black, "modulate:a", 0.0, 1.0)
	await tween.finished
	black.visible = false

func fade_into_black():
	black.visible = true

	var tween = create_tween()
	tween.tween_property(black, "modulate:a", 1.0, 1.2)
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
	# The camera starts at its base view like in the combat scene (it must not be reset here: its home position is only known once it is ready)
	await fade_from_black()

	await intro_scene()
	await gear_scene()
	await type_scene()
	await taming_scene()
	await blocking_scene()
	await abilities_items_scene()
	await dream_scene()
	await outro_scene()

# INTRO: the beetle enters and Tuh-U explains intent
func intro_scene():
	lock_input()
	await wait(0.5)

	# The beetle enters the encounter (quickly) and is tougher than usual
	beetle = await combat_manager.start_tutorial_combat([BEETLE_ID])
	beetle.max_hp = TUTORIAL_BEETLE_HP
	beetle.hp = TUTORIAL_BEETLE_HP
	beetle.axis_max = TUTORIAL_BEETLE_HP
	var beetle_visual: Node2D = enemy_visual_for_beetle()
	beetle_visual.axis_bar.axis_max = TUTORIAL_BEETLE_HP
	hide_hp_now() # The setup shows it again; it appears for the blocking part
	beetle_visual.modulate.a = 0.0
	create_tween().tween_property(beetle_visual, "modulate:a", 1.0, 0.3)
	await wait(1.0)

	# Tuh-U appears from above, facing the Droid
	ufo.position = Vector2(SPOT_INTRO.x, -40.0)
	face_left()
	ufo.visible = true
	await ufo.glide_in(SPOT_INTRO.y)
	_start_ufo_idle()
	await wait(PAUSE_SETTLE)

	hop()
	await say("Hey, I’m Tuh-U! Welcome to the demo of [b]Droidream[/b]!", "normal")
	await say("Let’s go through the basics.", "happy")

	# Tuh-U goes to the beetle
	await stage(beetle_spot(), beetle_visual)
	await say("This is a %s." % bb("creatures", "creature"), "down")
	await say("To get past it, you need to choose your %s." % bb("taming", "intent"), "normal")
	await say("You can either %s or %s a creature." % [bb("hurt", "kill"), bb("taming", "tame")], "normal")
	await say("Doing either requires you to know the %s." % bb("type", "creature’s type"), "normal")
	await end_say()

# GEAR: the options of the turn, and the player opens "Tame"
func gear_scene():
	await stage(SPOT_GEAR, player_visual)

	combat_manager.tutorial_begin_player_turn_locked() # The gear appears with "Tame" selected, locked until Tuh-U is done
	tutorial_text.show_hint(TutorialText.HintType.PLAYER_TURN)
	await wait(PAUSE_SETTLE) # The gear pops in first

	await say("Here you can see your different options in %s." % bb("creatures", "encounters"), "normal")
	await overlay_say("Try selecting %s!" % bb("taming", "Tame"), "happy")

	unlock_gear()
	await wait_until(func(): return player_turn_ui.state == player_turn_ui.State.ATTACK_TYPE_SELECT)
	player_turn_ui.lock_input() # The type panel is open, but nothing can be chosen while Tuh-U talks
	tutorial_text.hide_text()
	await end_say()
	await wait(PAUSE_SETTLE) # The panel finishes opening

# TYPE: Tuh-U asks what type the beetle is; the player answers in the real tame panel (all chips are 4 for it)
func type_scene():
	await stage(SPOT_GEAR, player_visual) # He stays where he is (the same beat): his bubble is above the panel, which stays clear

	await say("A creature can be one of these %s." % bb("type", "types"), "down")
	await overlay_say("What %s do you think this %s is?" % [bb("type", "type"), bb("creatures", "creature")], "normal")

	var answer := await ask_type()
	await end_say()
	await wait(PAUSE_SHORT)

	if answer == CombatTypes.EntityType.EARTH:
		await say("That’s right!", "happy")
		await ufo.hop()
		await say("By %s the creature as an %s creature, you will %s it!" % [bb("taming", "taming"), bb("earth", "earth"), bb("taming", "tame")], "normal")
		await say("Any other %s will %s it." % [bb("type", "type"), bb("hurt", "kill")], "sad")
	else:
		await say("Not quite...", "sad")
		await say("By %s the creature as this %s, you will %s it." % [bb("taming", "taming"), bb("type", "type"), bb("hurt", "kill")], "normal")
		await say("This one walks on the ground, so it’s an %s creature." % bb("earth", "earth"), "normal")
	face_right() # Toward the beetle
	await say("Usually just looking at a creature is enough to know its %s." % bb("type", "type"), "normal")
	await end_say()
	await player_turn_ui._close_menu("attack") # The panel closes here and opens again when the player tames, so it never stands where Tuh-U flies next
	await wait(PAUSE_SHORT)

# TAMING: the timing icons, then the player tames the beetle as an earth creature
func taming_scene():
	await stage(beetle_spot(), enemy_visual_for_beetle()) # Right above the beetle, looking down on it

	await say("When %s, you'll have to match icons that fly towards the %s." % [bb("taming", "taming"), bb("creatures", "creature")], "down")
	await say("During this, press Z when two icons %s!" % bb("taming", "meet"), "down")
	await say("The more you %s, the better you %s!" % [bb("taming", "match"), bb("taming", "tame")], "happy")
	await stage(SPOT_GEAR, player_visual) # Back on the Droid's side, out of the way of its walk and the icons
	hop()
	await overlay_say("Now try %s it as an %s creature!" % [bb("taming", "taming"), bb("earth", "earth")], "normal")

	await unlock_type_panel()
	await wait_until(func(): return player_turn_ui.state == player_turn_ui.State.ENEMY_SELECT)
	await end_say() # The bubble goes away once the player is picking the target
	var result: Array = await wait_for_attack()

	var perfect_timing: bool = result[0]
	lock_input()
	await stage(SPOT_GEAR, player_visual) # The camera settles back before he talks

	hop()
	if perfect_timing:
		await say("Wow, you’ve got a real knack for this!", "happy")
	else:
		await say("That was great!", "happy")
	await say("There’s also the %s option in the options menu if taming feels too difficult." % bb("taming", "'easier timing'"), "normal")
	await say("You can always access it when pressing ESC!", "normal")
	# A slight pause, then Tuh-U steps back to his spot ready for the next lines
	await stage(beetle_spot(), enemy_visual_for_beetle()) # Above the beetle again, facing it, for its turn
	await say("Every time you %s, one of that %s is used." % [bb("taming", "tame"), bb("type", "type")], "normal")
	hop()
	await say("Acquiring %s restores them though! You'll find many ways to acquire them!" % [bb("droid", "chips")], "happy")
	await end_say()

# BLOCKING: the beetle attacks, the player presses Z to block
func blocking_scene():
	await say("%s fight back too! This is a jungle after all." % bb("creatures", "Creatures"), "sad")
	await say("When one attacks, press Z right before it hits to %s." % bb("items", "block"), "normal")
	await say("Get ready! This one's about to attack!", "sad")
	await end_say()

	player_visual.show_hp()
	await wait(0.3)

	for attempt in 2:
		player_turn_ui.hide_player_turn_ui()
		await wait(0.25)
		unlock_input()
		combat_manager._enemy_turn()
		await combat_manager.player_turn_started # The beetle's turn is over, the turn goes back to the player
		lock_input()
		await stage(SPOT_GEAR, player_visual) # The camera settles before he talks

		if combat_manager.last_enemy_hit_blocked:
			hop()
			await say("Nice block!", "happy")
			await end_say()
			break
		if attempt == 0:
			await say("Yowch! That seems like it hurt.", "sad")
			await say("For practice let’s try that one more time!", "normal")
			await end_say()
		else:
			await say("Don't worry, you’ll get the hang of it!", "happy")
			await end_say()
	await wait(PAUSE_SHORT)

# ABILITIES AND ITEMS: the gear shows both, the HUD in the top left holds them
func abilities_items_scene():
	await stage(SPOT_GEAR, player_visual) # By the gear, whose options he talks about

	player_turn_ui._move_gear(1)
	await wait(PAUSE_SETTLE) # The gear turns to abilities
	await say("Your %s are stronger actions that can help you during encounters." % bb("abilities", "abilities"), "happy")
	await say("After use, they'll need some time to %s." % bb("water", "cool down"), "normal")
	await end_say()

	player_turn_ui._move_gear(1)
	await wait(PAUSE_SETTLE)
	await say("And your %s are single-use consumables that do a plethora of cool stuff!" % bb("items", "items"), "happy")
	await say("%s drop them when %s, so %s is encouraged!" % [bb("creatures", "Creatures"), bb("taming", "tamed"), bb("taming", "taming")], "happy")
	await end_say()

	player_turn_ui._move_gear(1)
	await wait(PAUSE_SETTLE)
	reveal_hud(false) # The top left appears as he mentions it
	hop()
	await say("Whatever you own shows up in the %s." % bb("droid", "top left"), "normal")
	await say("You can get %s and %s from %s, rewards and shops." % [bb("abilities", "abilities"), bb("items", "items"), bb("creatures", "creatures")], "normal")
	await end_say()

# DREAM: the beetle is one hit from trusting, the player tries its dream
func dream_scene():
	await stage(beetle_spot(), player_visual) # He faces left, toward the Droid, for the whole dream part

	combat_manager.tutorial_prepare_dummy_for_minigame() # The next hit fills the meter
	await wait(PAUSE_SETTLE)

	await say("Once a %s is close to being tamed, it starts to %s you." % [bb("creatures", "creature"), bb("trust", "trust")], "down")
	await say("And once it does, you, as a %s, are able to %s." % [bb("droid", "droid"), bb("trust", "seal that bond")], "normal")
	await say("You’ll see a vision called a %s, and you must %s it to finish taming!" % [bb("trust", "dream"), bb("trust", "realise")], "happy")
	await say("Each new dream starts with a countdown. You can turn it off in the options menu.", "normal")

	await stage(SPOT_GEAR, player_visual)
	hop()
	bubble_widths = [190.0, 230.0] # One wide line, so it stays below the HUD rows
	await overlay_say("Let’s try %s!" % bb("trust", "sealing a dream"), "happy")
	bubble_widths = BUBBLE_WIDTHS
	unlock_gear()
	await wait_until(func(): return player_turn_ui.state == player_turn_ui.State.ATTACK_TYPE_SELECT)
	player_turn_ui.set_attack_index(EARTH_INDEX) # The panel opens on its first row, so Earth is selected once it is open
	await wait_until(func(): return player_turn_ui.state == player_turn_ui.State.ENEMY_SELECT)
	await end_say()
	var minigame = await wait_for_minigame()

	lock_input()
	await explain_dream(minigame)

func explain_dream(_minigame):
	bubble_widths = DREAM_BUBBLE_WIDTHS
	await stage(SPOT_DREAM, player_visual) # The dream box is already on screen; the camera goes wide behind it and he stands beside it, looking at it
	face_left() # Turned toward the dream box, the Droid and the stage once he is there

	await say("This is a %s." % bb("trust", "creature’s dream"), "normal")
	await say("They're different for each %s. As a %s, you'll see what to do in each one." % [bb("creatures", "creature"), bb("droid", "droid")], "normal")
	await say("All %s are quick, so be sure to fulfil them fast!" % bb("trust", "dreams"), "normal")
	await end_say()
	await wait(PAUSE_SHORT)

	combat_manager.tutorial_minigame_released.emit() # The countdown, then the dream
	bubble_widths = BUBBLE_WIDTHS
	var success: bool = await combat_manager.tutorial_minigame_finished
	MinigameCountdown.mark_known("dream_beetle_rush") # Played through: the beetle dream does not count down again after the tutorial

	lock_input()
	await ufo.shake()
	await wait(0.4)
	await stage(SPOT_OUTRO, player_visual, false, 1.2) # Back to the stage after the dream box has gone

	if success:
		hop()
		await say("Good job %s!" % bb("trust", "realising the dream"), "happy")
	else:
		await say("Don’t worry, it was just practice! You'll get it next time.", "sad")
	await say("Most %s only have to be %s once, but some are more powerful!" % [bb("creatures", "creatures"), bb("taming", "tamed")], "normal")
	await end_say()
	await wait(PAUSE_SHORT)

# OUTRO: the shop and the journey
func outro_scene():
	lock_input()
	player_turn_ui.hide_player_turn_ui()
	await stage(SPOT_OUTRO, player_visual)

	hop()
	await say("That’s all the basics!", "happy")
	await say("Between encounters I’ll set up a %s for us." % bb("items", "shop"), "normal")
	await say("Spend your %s there on different stuff, like %s and %s." % [bb("bolts", "bolts"), bb("items", "items"), bb("abilities", "abilities")], "normal")
	reveal_hud(true) # The bolts appear as he mentions them
	await say("You can see your %s in the top right." % bb("bolts", "bolts"), "normal")
	hop()
	await say("Are you ready? Let’s go!", "happy")
	face_left()
	await end_say()

	await player_visual.hop()
	await walk_out_and_finish()

# HELPERS

func bb(key: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [TUTORIAL_COLORS[key], text]

func say(text: String, mood := "normal"):
	if skipping:
		await wait(1000.0) # The scene is about to change; the script stops here
	_set_mood(mood)
	_stop_ufo_idle() # He holds still while he talks, so the tail of the bubble keeps pointing at him
	await bubble.say_and_wait(text, _bubble_target())

# The bubble leaves (and the call returns when it is gone), so it never stays behind while Tuh-U or the camera moves
func end_say():
	if bubble.visible:
		await bubble.hide_bubble()
	bubble.configure(ShopBubble.ANCHOR)

# Overlay lines stay visible without waiting for a confirm: the player has something to do before the tutorial goes on
func overlay_say(text: String, mood := "normal"):
	if skipping:
		await wait(1000.0)
	_set_mood(mood)
	_stop_ufo_idle()
	await bubble.say(text, _bubble_target(), true)

func _set_mood(mood: String):
	bubble.set_mood(mood)
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
			ufo.play_look_right() # The sideways-looking face, mirrored by his facing: his eyes are visibly turned toward the Droid (left) or the beetle (right) on plain lines

# The bubble sits above Tuh-U and grows to the right; returns where its tail points
func _bubble_target() -> Vector2:
	var ufo_screen: Vector2 = ufo.get_global_transform_with_canvas().origin
	bubble.configure(ufo_screen + Vector2(-16, -36), true, bubble_widths)
	return ufo_screen + Vector2(0, -20)

func move_ufo_to(pos: Vector2, duration := 0.75, restart_idle := true):
	_stop_ufo_idle()
	await ufo.move_to(pos, duration)

	if restart_idle:
		_start_ufo_idle()

# A hop while he talks (not waited for, so it plays under the line)
func hop():
	ufo.hop()

# The HP icon of the Droid, gone at once (hide_hp fades it over a second)
func hide_hp_now():
	player_visual.hp_icon.visible = false
	player_visual.hp_icon.modulate.a = 0.0

# The top HUD is shown in two parts: the top left (power, defense, abilities and items) and the bolts in the top right
func hide_hud():
	var hud: Control = combat_manager.ui.player_stats_hud
	hud.visible = true
	hud.modulate.a = 1.0
	for row in hud.get_children():
		row.modulate.a = 0.0

func reveal_hud(bolts: bool):
	var hud: Control = combat_manager.ui.player_stats_hud
	for row in hud.get_children():
		if (row.name == "BoltsRow") == bolts:
			create_tween().tween_property(row, "modulate:a", 1.0, 0.3)

func wait(seconds: float):
	await get_tree().create_timer(seconds).timeout

# The normal wide camera, waited for until it has settled
func set_wide():
	await end_say()
	var at_base: bool = camera.global_position.distance_to(camera.default_position) < 2.0 and camera.zoom.is_equal_approx(camera.zoom_normal)
	if not at_base: # Already there: no pause
		await camera.reset_camera()
		await wait(PAUSE_SHORT)

# Gets ready for a new set of lines: the bubble leaves, the camera is wide and settled, Tuh-U flies to his spot and turns toward what he talks about (nothing if null)
func stage(spot: Vector2, toward: Node2D, keep_camera := false, duration := 0.55):
	await end_say()
	await wait(PAUSE_SHORT)
	if not keep_camera:
		await set_wide()
	face_from(spot.x, toward)
	await move_ufo_to(spot, duration)
	await wait(PAUSE_SETTLE)

# Turns Tuh-U toward a node as seen from where he will stand (x), left or right: his eyes are always on a character, except at the very end when he runs off
func face_from(x: float, toward: Node2D):
	if toward == null:
		return
	if toward.global_position.x < x:
		face_left()
	else:
		face_right()

# Straight above the beetle (its node sits at its center)
func beetle_spot() -> Vector2:
	return Vector2(enemy_visual_for_beetle().global_position.x, SPOT_BEETLE_HEIGHT)

func face_left():
	ufo.flip_toward_left()

func face_right():
	ufo.flip_toward_right()

func enemy_visual_for_beetle() -> Node2D:
	return combat_manager.enemy_visuals.get(beetle)

func get_month_day_string() -> String:
	var date := Time.get_datetime_dict_from_system()
	return "%02d/%02d" % [date["day"], date["month"]]

# Opens the gear for the player (the turn UI stays as it is, only its input state changes)
func unlock_gear():
	combat_manager._resume_combat()
	player_turn_ui.state = player_turn_ui.State.OPTION_SELECT

# Opens the type panel again with "Earth" selected (Sky and Water have no chips in the tutorial) and lets the player choose
func unlock_type_panel():
	combat_manager._resume_combat()
	player_turn_ui.set_attack_index(EARTH_INDEX)
	await player_turn_ui._open_menu("attack", false)

# Waits until a condition is true; after a few idle seconds a "Press Z" hint shows (any key press counts as activity)
func wait_until(condition: Callable):
	var idle := 0.0
	var hinted := false
	while not condition.call():
		await get_tree().process_frame
		if PauseMenu.active:
			continue
		idle += get_process_delta_time()
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right") \
				or Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
			idle = 0.0
		if not hinted and idle > STUTTER_TIME:
			hinted = true
			tutorial_text.show_hint(TutorialText.HintType.SELECT_Z)
	if hinted:
		tutorial_text.hide_text()

# Waits for the player's tame (the sequence included) and returns [perfect_timing, minigame_started]
func wait_for_attack() -> Array:
	var done := [false, false, false]
	var on_resolved := func(critical: bool, minigame_started: bool):
		done[0] = true
		done[1] = critical
		done[2] = minigame_started
	combat_manager.tutorial_attack_resolved.connect(on_resolved, CONNECT_ONE_SHOT)
	await wait_until(func(): return done[0])
	return [done[1], done[2]]

# Waits for a dream to start and returns its minigame
func wait_for_minigame():
	var started := []
	var on_started := func(minigame):
		started.append(minigame)
	combat_manager.tutorial_minigame_started.connect(on_started, CONNECT_ONE_SHOT)
	await wait_until(func(): return not started.is_empty())
	return started[0]

# Tuh-U's type question in the real tame panel: every type shows 4 chips, a choice only comes back as the answer (no chip is used and the combat does not go on to the
# target selection: a tutorial exception in PlayerTurnUI), then the chips are back to Earth only. Returns the chosen CombatTypes.EntityType
func ask_type() -> int:
	PlayerData.set_guesses(4, 4, 4)
	player_turn_ui.update_guess_display()
	player_turn_ui.attack_list.select(0, false)
	player_turn_ui.tutorial_pick_only = true
	player_turn_ui.state = player_turn_ui.State.ATTACK_TYPE_SELECT
	tutorial_text.show_hint(TutorialText.HintType.SHOP) # The controls bar: Move and Confirm
	
	var chosen := [-1]
	player_turn_ui.tutorial_type_picked.connect(func(type): chosen[0] = type, CONNECT_ONE_SHOT)
	await wait_until(func(): return chosen[0] >= 0)
	
	player_turn_ui.lock_input()
	player_turn_ui.tutorial_pick_only = false
	tutorial_text.hide_text()
	PlayerData.set_guesses(0, 4, 0) # Only Earth again
	player_turn_ui.update_guess_display()
	return chosen[0]

func walk_out_and_finish():
	await set_wide()
	ufo.flip_toward_right()
	player_visual.anim.play("player_walk")

	var tween := create_tween()
	tween.tween_property(player_visual, "global_position:x", 760, 1.7)
	tween.parallel().tween_property(ufo, "global_position:x", 800, 1.5)
	await tween.finished

	await fade_into_black()
	PlayerData.reset_run()
	get_tree().change_scene_to_file("res://Scenes/Screens/CombatScene.tscn")
