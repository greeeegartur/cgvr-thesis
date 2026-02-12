extends Node

# This script is the glue that starts stages and transitions them to stops, next rounds and areas

class_name StageFlowController

# Exported variables
@onready var area_manager := $"../AreaManager"
@onready var combat_manager := $"../CombatManager"
@onready var stop_manager := $"../StopManager"
@onready var enemy_spawner := $"../EnemySpawner"
@onready var player_visual := $"../World/PlayerVisual"
@onready var camera := $"../Camera2D"
@onready var rewards_screen := $"../UI/RewardsScreen"

# TO-DO: make backgrounds scenes
@onready var background := $"../World/Background"

func _ready():
	combat_manager.combat_end.connect(_on_combat_finished)
	stop_manager.stop_finished.connect(_on_stop_finished)
	area_manager.area_changed.connect(_on_area_changed)
	
	# Starts the current stage from AreaManager
	start_stage()

func start_stage():
	combat_manager.resume_combat()
	
	var stage = area_manager.get_current_stage()
	var enemies = enemy_spawner.generate(stage) # Specifically enemy_ids
	print()
	print("Entering stage: ", area_manager.stage_index)
	print(enemies)
	
	combat_manager._start_combat(enemies)

# Transitions from stage -> stop
func _on_combat_finished(victory: bool, rewards):
	if not victory:
		return
	
	await _play_victory_sequence(rewards)
	
	#if area_manager.get_current_stage().has_stop:
		#await _enter_stop()
	#else:
		## In case I want to make a rush mode in the future
		#_on_stop_finished()

func _play_victory_sequence(rewards: Dictionary):
	# Combat end
	combat_manager.pause_combat() # 1. Pausing combat
	# TO-DO: await player_visual.play_victory() # 2. Showing player visual victory animation
	camera.victory_focus_on_player(player_visual) # 3. Camera zooms in and focuses on player for victory screen
	rewards_screen.show_rewards(rewards) # 4. Rewards menu pops up
	
	# Confirmation
	await rewards_screen.confirmed # 5. Waits until rewards are confirmed
	await rewards_screen.hide_rewards() # 6. Hides victory screen menu
	await camera.reset_camera() # 7. Resets camera
	await _enter_stop() # 8. Stop entering logic

func _enter_stop():
	await stop_manager.enter_stop()

# Transitions from stop -> next stage (also checks for next area and advances to next area if so)
func _on_stop_finished():
	area_manager.advance_stage()
	combat_manager.resume_combat()
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
