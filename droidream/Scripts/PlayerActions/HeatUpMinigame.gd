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

const RING_SLOTS := 7 # Positions on the upper half of a ring around the Droid (the lower half is the ground)
const RING_RADIUS := Vector2(105.0, 80.0) # Half width and height of the ring in world pixels
const RING_LIFT := Vector2(0, -45) # The ring's center is at the Droid's body (its position is at its feet)

var anchor: Node2D # The Droid: prompts appear on a ring around it
var free_slots: Array = []
var prompt_offsets := {} # Prompt -> its place on the ring (world pixels from the Droid), so it follows the camera

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
	
	prompt.hit.connect(func(spot: Vector2): prompt_hit.emit(spot)) # For the explosion on every key that is hit
	prompt.resolved.connect(
		func(success: bool):
			_resolved += 1
			if success:
				_hits += 1,
		CONNECT_ONE_SHOT
	)
	
	prompt.play_prompt()

# Gives a prompt a free slot on a ring around the Droid; _process keeps it there while the camera moves
func _place_prompt_randomly(prompt: Control):
	if free_slots.is_empty():
		for i in RING_SLOTS:
			free_slots.append(i)
		free_slots.shuffle()
	var slot: int = free_slots.pop_back()
	var angle := PI + PI * float(slot) / (RING_SLOTS - 1) # From the left, over the top, to the right
	prompt_offsets[prompt] = RING_LIFT + Vector2(cos(angle) * RING_RADIUS.x, sin(angle) * RING_RADIUS.y)
	_follow_ring(prompt)

func _process(_delta: float) -> void:
	for prompt in prompt_offsets.keys():
		if is_instance_valid(prompt):
			_follow_ring(prompt)

func _follow_ring(prompt: Control) -> void:
	var prompt_size := Vector2(64, 64)
	var center := get_viewport_rect().size * Vector2(0.3, 0.6)
	if anchor and is_instance_valid(anchor):
		var canvas := get_viewport().get_canvas_transform()
		center = canvas * anchor.global_position + canvas.basis_xform(prompt_offsets[prompt])
	var screen := get_viewport_rect().size
	# The key is drawn around the prompt's origin, so the origin is the center
	prompt.position = Vector2(
		clampf(center.x, prompt_size.x / 2.0 + 8.0, screen.x - prompt_size.x / 2.0 - 8.0),
		clampf(center.y, prompt_size.y / 2.0 + 8.0, screen.y - prompt_size.y / 2.0 - 8.0)
	)

func _hits_to_bonus(hits: int, total: int) -> int:
	if total <= 0:
		return 1
	if hits == total:
		return 3
	elif hits >= int(ceil(total / 2.0)):
		return 2
	return 1
