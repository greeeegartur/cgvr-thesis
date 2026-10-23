extends Node

# This script is the glue that starts stages and transitions them to stops, next rounds and areas

class_name StageFlowController

# Exported variables
@onready var area_manager := $"../AreaManager"
@onready var combat_manager := $"../CombatManager"
@onready var stop_manager := $"../StopManager"
@onready var player_visual := $"../World/PlayerVisual"
@onready var camera := $"../Camera2D"
@onready var rewards_screen := $"../UI/RewardsScreen"
@onready var death_screen := $"../UI/DeathScreen"
@onready var tutorial_text := $"../UI/TutorialText"
@onready var boon_screen := $"../UI/BoonSelectionScreen"
@onready var boon_manager := $"../BoonManager"
@onready var combat_ui := $"../UI/CombatUI"
@onready var black := $"../UI/Black"

@onready var background := $"../World/CombatBackground"

const INTRO_FADE := 0.9 # The black fades away (and the encounter music fades in) over this
const DEATH_MUSIC_FADE := 1.0
const ENDING_MUSIC_FADE := 3.0
const PLAYER_COMBAT_POS := Vector2(96, 277)
const PLAYER_WALK_IN_OFFSET := Vector2(-190, 0)

func _ready():
	combat_manager.combat_end.connect(_on_combat_finished)
	stop_manager.stop_finished.connect(_on_stop_finished)
	area_manager.area_changed.connect(_on_area_changed)
	combat_manager.player_died.connect(_on_player_died)
	death_screen.retry_selected.connect(_on_retry)
	death_screen.back_selected.connect(_on_back_to_title)
	
	# Starts the current stage from AreaManager (deferred so the sibling World nodes finish their _ready first)
	start_stage.call_deferred()

func start_stage(reset := false):
	combat_manager._resume_combat()
	
	var stage = area_manager.get_current_stage()
	var enemies = stage.generate() # Specifically enemy_ids
	print()
	print("Entering stage: ", area_manager.stage_index)
	print(enemies)
	
	combat_ui.show_encounter(area_manager.stage_index, area_manager.get_current_area().stages.size(), not reset)
	if _should_play_area_intro():
		await _start_stage_with_intro(enemies, reset)
	else:
		player_visual.show_hp(ScreenMotion.HP_FADE_TIME) # Comes back with the next encounter
		combat_manager._start_combat(enemies)

# INTRO METHODS
func _should_play_area_intro() -> bool:
	return area_manager.stage_index == 0

func _start_stage_with_intro(enemies: Array, reset := false):
	combat_manager._pause_combat()
	combat_ui.hide_player_stats_hud()
	player_visual.hide_hp()
	
	black.visible = true
	black.modulate.a = 1.0
	if reset:
		camera.reset_camera()
		await get_tree().create_timer(0.3).timeout
	
	await combat_manager.prepare_combat_for_intro(enemies)
	
	player_visual.position = PLAYER_COMBAT_POS + PLAYER_WALK_IN_OFFSET
	player_visual.set_home_position()
	
	Music.play_encounter(INTRO_FADE) # The encounter music comes in with the fade from black (also after a retry)
	await _fade_from_black(INTRO_FADE)
	await player_visual.walk_in_to(PLAYER_COMBAT_POS, PLAYER_WALK_IN_OFFSET)
	
	await get_tree().create_timer(0.3).timeout
	
	player_visual.show_hp()
	combat_manager.begin_combat_after_intro()
	
	combat_manager._resume_combat()
	await combat_ui.show_player_stats_hud()
	combat_ui.refresh_player_hud()

func _fade_from_black(duration := 0.9):
	black.visible = true
	black.modulate.a = 1.0
	
	var tween := create_tween()
	tween.tween_property(black, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	await tween.finished
	black.visible = false

# Transitions from stage -> stop
func _on_combat_finished(victory: bool, rewards):
	if not victory:
		_on_player_died() # Should actually be called with signal, but fallback in case of faulty execution
		return
	
	await _play_victory_sequence(rewards)

# Separating flow in case of future additions
func _on_player_died():
	await _play_death_sequence()

func _play_death_sequence():
	Music.fade_out(DEATH_MUSIC_FADE)
	combat_ui.hide_player_stats_hud()
	combat_manager.player_turn_ui.hide_player_turn_ui()
	tutorial_text.hide_text()
	player_visual.hide_hp()
	camera.ability_push_in(player_visual, Vector2(1.5, 1.5), 1.6) # A slow push toward the Droid while it falls
	
	await player_visual.play_defeat()
	var summary := "Stage %d of %d  \u00b7  Tamed %d  \u00b7  Killed %d" % [area_manager.stage_index + 1, area_manager.get_current_area().stages.size(), PlayerData.get_total_tamed_count(), PlayerData.get_total_killed_count()]
	await death_screen.show_death(player_visual, summary)
	
	# Confirmation handled by death screen signals

func _on_retry():
	print()
	print("Retrying!")
	await _fade_into_black(0.6) # Through black instead of popping back
	death_screen.hide()
	
	# Technical resets
	combat_manager._force_full_reset()
	area_manager.reset_to_first_area()
	PlayerData.reset_run()
	
	# Player visual + UI resets
	player_visual.anim.play("player_idle")
	player_visual.update_hp(PlayerData.max_hp, PlayerData.max_hp)
	combat_manager._setup_ui()
	combat_ui.refresh_player_hud()
	
	# Combat reset
	start_stage(true)

# Quit on the game over screen: fades to black and shows the title screen
func _on_back_to_title():
	SceneTransition.go_to_title(get_tree())

const REWARDS_DELAY := 0.4 # Seconds after the victory camera starts before the rewards appear

func _play_victory_sequence(rewards: Dictionary):
	Music.set_calm("stop", true) # The music blends into the tutorial track while the world is dimmed
	Music.set_calm("dream", false)
	# Combat end
	combat_manager._pause_combat() # 1. Pausing combat
	combat_ui.hide_player_stats_hud()
	player_visual.hide_hp(ScreenMotion.HP_FADE_TIME)
	# After a Ball or Multi-Tame the camera stays in the encounter for a moment, so the result can land
	if combat_manager.victory_delay > 0.0:
		await get_tree().create_timer(combat_manager.victory_delay).timeout
	combat_manager.victory_delay = 0.0
	
	combat_manager.fade_out_defeated() # The creatures fade away while the camera starts moving, the world dims behind the Droid
	combat_manager._world_gray_out(true, true)
	# TO-DO: await player_visual.play_victory() # 2. Showing player visual victory animation
	camera.victory_focus_on_player(player_visual) # 3. Camera zooms in and focuses on player for victory screen
	await get_tree().create_timer(REWARDS_DELAY).timeout # The camera is already on its way when the rewards pop up
	rewards_screen.show_rewards(rewards) # 4. Rewards menu pops up
	
	# Confirmation
	await rewards_screen.confirmed # 5. Waits until rewards are confirmed
	await rewards_screen.hide_rewards() # 6. Hides victory screen menu
	await _show_boons() # 7. Boon selection
	player_visual.update_hp(PlayerData.hp, PlayerData.max_hp) # UI updates
	combat_ui.refresh_player_hud()
	
	await camera.reset_camera() # 8. Resets camera
	
	if _is_demo_final_stage(): # 8.5. If ending has been reached
		await _enter_demo_ending_stop()
		return
	
	await _enter_stop() # 9. Stop entering logic
	await combat_ui.show_player_stats_hud()
	combat_ui.refresh_player_hud()

func _show_boons():
	var boons = boon_manager.roll_boons()
	boon_screen.show_boons(boons)
	tutorial_text.show_hint(TutorialText.HintType.BOON_SELECT)
	await boon_screen.boon_selected
	tutorial_text.hide_text()
	combat_ui.refresh_player_hud()

func _enter_stop():
	await stop_manager.enter_stop()
	tutorial_text.show_hint(TutorialText.HintType.SHOP)

# Transitions from stop -> next stage (also checks for next area and advances to next area if so)
func _on_stop_finished():
	tutorial_text.hide_text()
	var old_area_index = area_manager.area_index
	area_manager.advance_stage()
	if area_manager.area_index != old_area_index:
		return
	combat_manager._resume_combat()
	await start_stage()

# Reacts to AreaManager method and transitions to next area
func _on_area_changed(new_area: AreaData):
	await _transition_to_next_area(new_area)
	start_stage()

 # TO-DO
func _transition_to_next_area(area: AreaData):
	await player_visual.walk_off_screen()
	await background.transition_to(area)
	#await player_visual.walk_in()

func _is_demo_final_stage() -> bool:
	return area_manager.area_index == 0 and area_manager.stage_index == area_manager.get_current_area().stages.size() - 1 # The demo ends after the Jungle's last stage

func _enter_demo_ending_stop():
	get_tree().current_scene.set_meta("no_restart", true) # The pause menu no longer offers Restart once the ending has begun
	Music.fade_out(ENDING_MUSIC_FADE) # The music fades away as the ending begins
	combat_manager._world_gray_out(false, true) # The dim of the rewards and boons goes
	tutorial_text.hide_text()
	combat_ui.hide_player_stats_hud()
	combat_manager._pause_combat()
	
	await stop_manager.enter_demo_ending_stop()
	await _fade_into_black()
	
	PlayerData.reset_run()
	get_tree().change_scene_to_file("res://Scenes/Screens/TitleScreen.tscn")

func _fade_into_black(duration := 1.2):
	black.visible = true
	black.modulate.a = 0.0
	
	var tween := create_tween()
	tween.tween_property(black, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
