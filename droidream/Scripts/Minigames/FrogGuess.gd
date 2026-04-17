extends BaseMinigame
class_name FrogGuess

@export var FrogEntityScene: PackedScene
@export var DamageNumberScene: PackedScene

@export var background_textures: Array[Texture2D]
@export var real_frog_textures: Array[Texture2D]
@export var fake_frog_textures: Array[Texture2D]

@onready var play_area: Control = $VisualRoot/PlayArea
@onready var background_rect: TextureRect = $VisualRoot/PlayArea/BackgroundRect
@onready var entities_node: Node2D = $VisualRoot/PlayArea/Entities
@onready var hint_label: Label = $VisualRoot/UI/Hint
@onready var guess_label: Label = $VisualRoot/UI/GuessUI/GuessLabel
@onready var reveal_left: Marker2D = $VisualRoot/PlayArea/RevealBounds/Left
@onready var reveal_right: Marker2D = $VisualRoot/PlayArea/RevealBounds/Right

var current_guess := 1
var answer_count := 0
var revealed := false
var input_locked := false

const MIN_ENTITIES := 2
const MAX_ENTITIES := 9
const MIN_SCALE := 0.6
const MAX_SCALE := 1.6
const DAMAGE_PER_MISS := 0.2
const REVEAL_SCALE := 2.0
const POSITION_ATTEMPTS := 16

func _ready():
	set_duration(6.0)
	
	progress_bar.max_value = max_duration
	progress_bar.value = max_duration
	timer_label.text = "%.1fs" % max_duration
	
	if background_textures.size() > 0:
		background_rect.texture = background_textures.pick_random()
	
	update_guess_label()
	spawn_entities()
	
	# FOR TESTING ONLY
	# await get_tree().process_frame
	play()

func _process(delta):
	super._process(delta)
	
	if not running:
		return
	
	if not revealed:
		update_timer_ui()

func _unhandled_input(event):
	if not running or input_locked or revealed:
		return
	
	if event.is_action_pressed("ui_left"):
		change_guess(-1)
	elif event.is_action_pressed("ui_right"):
		change_guess(1)
	elif event.is_action_pressed("ui_accept"):
		confirm_guess()

func change_guess(amount: int) -> void:
	current_guess = clamp(current_guess + amount, 1, 9)
	update_guess_label()

func update_guess_label() -> void:
	guess_label.text = str(current_guess)

func spawn_entities() -> void:
	var total_entities := randi_range(MIN_ENTITIES, MAX_ENTITIES)
	answer_count = 0
	
	for i in range(total_entities):
		var is_real_frog := randf() < 0.65
		
		# Safety fallback: guarantee at least one real frog by making the last one real if needed
		if i == total_entities - 1 and answer_count == 0:
			is_real_frog = true
		
		var texture: Texture2D
		if is_real_frog:
			if real_frog_textures.is_empty():
				continue
			texture = real_frog_textures.pick_random()
			answer_count += 1
		else:
			if fake_frog_textures.is_empty():
				continue
			texture = fake_frog_textures.pick_random()
		
		var frog = FrogEntityScene.instantiate()
		entities_node.add_child(frog)
		
		var random_scale := randf_range(MIN_SCALE, MAX_SCALE)
		var random_color := Color.from_hsv(randf(), randf_range(0.35, 0.9), randf_range(0.75, 1.0))
		
		frog.setup(texture, is_real_frog, random_color, random_scale)
		frog.position = get_random_position_for_entity()

func get_random_position_for_entity() -> Vector2: # Copy pasted from Bat Flash
	var x = randf_range(-116, 116)
	var y = randf_range(-96, 96)
	return Vector2(x, y)
	

func overlaps_existing(candidate_pos: Vector2, candidate_half_size: Vector2) -> bool:
	for child in entities_node.get_children():
		var sprite := child.get_node("Sprite2D") as Sprite2D
		var tex_size := Vector2(48, 48)
		if sprite.texture:
			tex_size = sprite.texture.get_size()
		
		var other_half = tex_size * child.scale * 0.5
		var dist = candidate_pos - child.position
		
		var min_dist_x = candidate_half_size.x + other_half.x - 8.0
		var min_dist_y = candidate_half_size.y + other_half.y - 8.0
		
		if abs(dist.x) < min_dist_x and abs(dist.y) < min_dist_y:
			return true
	
	return false

func confirm_guess() -> void:
	input_locked = true
	revealed = true
	set_process_input(false)
	set_process_unhandled_input(false)
	
	await reveal_sequence()

func reveal_sequence() -> void:
	# Remove fakes
	for child in entities_node.get_children():
		if not child.is_real:
			var tween := create_tween()
			tween.tween_property(child, "scale", Vector2.ZERO, 0.2)
			tween.parallel().tween_property(child, "modulate:a", 0.0, 0.2)
			tween.finished.connect(child.queue_free)
	
	await get_tree().create_timer(0.25).timeout
	
	var real_frogs: Array = []
	for child in entities_node.get_children():
		if child.is_real:
			real_frogs.append(child)
	
	# Stack all real frogs in the middle
	var tween := create_tween()
	tween.set_parallel(true)
	
	for frog in real_frogs:
		tween.tween_property(frog, "position", Vector2.ZERO, 0.35)
		tween.tween_property(frog, "scale", Vector2.ONE * REVEAL_SCALE, 0.35)
	
	await tween.finished
	
	# Only show the final count on the last frog
	if not real_frogs.is_empty():
		real_frogs[-1].show_count(answer_count)
	
	await get_tree().create_timer(0.7).timeout
	
	resolve_result()

func resolve_result() -> void:
	var difference = abs(current_guess - answer_count)
	
	if difference == 0:
		end(true)
		return
	
	var damage := DAMAGE_PER_MISS * float(difference)
	damage_taken.emit(damage, play_area.global_position)
	spawn_damage_number(damage)
	await hit_stop(0.1)
	shake_node(float(difference))
	end(false)

func spawn_damage_number(damage: float) -> void:
	if not DamageNumberScene:
		return
	
	var dmg_scene = DamageNumberScene.instantiate()
	dmg_scene.global_position = play_area.global_position
	add_child(dmg_scene)
	dmg_scene.z_index = 10
	dmg_scene.play(damage, false)

func on_timeout():
	# Time ran out before confirming a guess
	# I would count that as failure with full reveal first, so player sees answer
	input_locked = true
	revealed = true
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	
	current_guess = clamp(current_guess, 1, 9)
	await reveal_sequence()
