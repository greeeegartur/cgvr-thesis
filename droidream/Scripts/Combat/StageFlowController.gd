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

# TO-DO: make backgrounds scenes
@onready var background := $"../World/Background"

func _ready():
	combat_manager.combat_end.connect(_on_combat_finished)
	stop_manager.stop_finished.connect(_on_stop_finished)
	area_manager.area_changed.connect(_on_area_changed)
	combat_manager.player_died.connect(_on_player_died)
	death_screen.retry_selected.connect(_on_retry)
	death_screen.back_selected.connect(_on_back_to_title)

	
	# Starts the current stage from AreaManager
	start_stage()

func start_stage():
	combat_manager._resume_combat()
	
	var stage = area_manager.get_current_stage()
	var enemies = stage.generate() # Specifically enemy_ids
	print()
	print("Entering stage: ", area_manager.stage_index)
	print(enemies)
	
	combat_manager._start_combat(enemies)

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
	camera.follow(player_visual)
	
	await player_visual.play_defeat()
	await death_screen.show_death()
	
	# Confirmation handled by death screen signals

func _on_retry():
	print()
	print("Retrying!")
	death_screen.hide()
	
	# Technical resets
	combat_manager._force_full_reset()
	area_manager.reset_to_first_area()
	PlayerData.reset_run()
	
	# Player visual + UI resets
	player_visual.anim.play("player_idle")
	player_visual.update_hp(PlayerData.max_hp, PlayerData.max_hp)
	combat_manager._setup_ui()
	
	# Combat reset
	start_stage()

# TO-DO
func _on_back_to_title():
	print("Back to title (not implemented yet)")

func _play_victory_sequence(rewards: Dictionary):
	# Combat end
	combat_manager._pause_combat() # 1. Pausing combat
	# TO-DO: await player_visual.play_victory() # 2. Showing player visual victory animation
	camera.victory_focus_on_player(player_visual) # 3. Camera zooms in and focuses on player for victory screen
	rewards_screen.show_rewards(rewards) # 4. Rewards menu pops up
	
	# Confirmation
	await rewards_screen.confirmed # 5. Waits until rewards are confirmed
	await rewards_screen.hide_rewards() # 6. Hides victory screen menu
	await get_tree().create_timer(0.15).timeout
	await _show_boons() # 7. Boon selection
	player_visual.update_hp(PlayerData.hp, PlayerData.max_hp) # UI updates
	
	await camera.reset_camera() # 8. Resets camera
	await _enter_stop() # 9. Stop entering logic

func _show_boons():
	var boons = boon_manager.roll_boons()
	boon_screen.show_boons(boons)
	await boon_screen.boon_selected

func _enter_stop():
	await stop_manager.enter_stop()
	tutorial_text.show_hint(TutorialText.HintType.SHOP)

# Transitions from stop -> next stage (also checks for next area and advances to next area if so)
func _on_stop_finished():
	tutorial_text.hide_text()
	area_manager.advance_stage()
	combat_manager._resume_combat()
	start_stage()

# Reacts to AreaManager method and transitions to next area
func _on_area_changed(new_area: AreaData):
	await _transition_to_next_area(new_area)
	start_stage()

 # TO-DO
func _transition_to_next_area(area: AreaData):
	await player_visual.walk_off_screen()
	await background.transition_to(area)
	await player_visual.walk_in()
