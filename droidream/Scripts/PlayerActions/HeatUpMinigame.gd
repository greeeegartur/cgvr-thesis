extends Control
class_name HeatUpMinigame

signal finished(power_bonus: int)
signal prompt_hit(position: Vector2)

@export var PromptScene: PackedScene
@export var duration := 5.0
@export var prompt_lifetime := 0.9
@export var min_prompts := 4
@export var max_prompts := 6
@onready var prompt_area := $PromptArea

var _hits := 0
var _spawned := 0
var _resolved := 0
var _target_prompt_count := 0
var _running := false

func play():
	_running = true
	_hits = 0
	_spawned = 0
	_resolved = 0
	_target_prompt_count = randi_range(min_prompts, max_prompts)
	
	var elapsed := 0.0
	var next_spawn_time := randf_range(0.3, 0.65)
	
	while elapsed < duration and _spawned < _target_prompt_count:
		await get_tree().process_frame
		var delta = get_process_delta_time()
		elapsed += delta
		
		if elapsed >= next_spawn_time:
			_spawn_prompt()
			_spawned += 1
			next_spawn_time += randf_range(0.35, 0.9)
	
	while _resolved < _spawned:
		await get_tree().process_frame
	
	_running = false
	finished.emit(_hits_to_bonus(_hits, _target_prompt_count))

func _spawn_prompt():
	var prompt = PromptScene.instantiate()
	prompt_area.add_child(prompt)
	prompt.lifetime = prompt_lifetime
	prompt.setup()
	_place_prompt_randomly(prompt)
	
	prompt.resolved.connect(
		func(success: bool):
			_resolved += 1
			if success:
				_hits += 1,
		CONNECT_ONE_SHOT
	)
	
	prompt.play_prompt()

func _place_prompt_randomly(prompt: Control):
	var area_size = prompt_area.size
	var prompt_size := Vector2(64, 64)
	var margin := 16.0
	
	prompt.position = Vector2(
		randf_range(margin, area_size.x - prompt_size.x - margin),
		randf_range(margin, area_size.y - prompt_size.y - margin)
	)

func _hits_to_bonus(hits: int, total: int) -> int:
	if total <= 0:
		return 1
	if hits == total:
		return 3
	elif hits >= int(ceil(total / 2.0)):
		return 2
	return 1
