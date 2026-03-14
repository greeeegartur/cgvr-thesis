extends BaseMinigame

# Script logic for the Small Bat enemy's minigame Bat Flash

# HOW TO PLAY?
# The player has to find all bats hidden in a cave with a flashlight
# Once the player has found a bat(s), the player has to flash them a couple of times to make them fly away.
# When all bats are found, the minigame is successfully completed 

class_name BatFlash

@export var BatScene: PackedScene
@export var DamageNumberScene: PackedScene

@onready var bats_node := $VisualRoot/PlayArea/Bats
@onready var flashlight := $VisualRoot/PlayArea/Flashlight
@onready var light := $VisualRoot/PlayArea/Flashlight/PointLight2D
@onready var flash_area := $VisualRoot/PlayArea/Flashlight/FlashArea
@onready var play_area := $VisualRoot/PlayArea
@onready var darkness := $VisualRoot/PlayArea/DarknessOverlay


@export var background_textures : Array[Texture2D]
@onready var background := $VisualRoot/PlayArea/CaveBackground
@export var bat_variants : Array[Texture2D]

# Base variables
var flashlight_speed := 600.0
var flash_cooldown := false
var base_light_scale := 2.42
var base_light_radius := 0.25
var bats_remaining := 0
var timer_active := true

const DAMAGE := 0.5


func _ready():
	# Setup with bat spawning
	set_duration(5.0)
	background.texture = background_textures.pick_random()
	darkness.material.set_shader_parameter("radius", base_light_radius)
	set_process_unhandled_input(true)
	spawn_bats()
	
	# Progress bar setup
	progress_bar.max_value = max_duration
	progress_bar.value = max_duration
	timer_label.text = "%.1fs" % max_duration

	# Starting minigame – FOR TESTING INSIDE SCENE, DO NOT TURN ON FOR COMBATMANAGER
	#await get_tree().process_frame
	#play()

func _process(delta):
	super._process(delta) # For elapsing variable and minigame end condition
	
	if not running:
		return
	
	handle_movement(delta)
	if timer_active:
		update_timer_ui()
	
	# Shader updates
	var uv_pos = flashlight.position / play_area.size
	darkness.material.set_shader_parameter("light_pos", uv_pos)



func handle_movement(delta):
	var dir := Vector2.ZERO
	
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	
	dir = dir.normalized()
	
	flashlight.position += dir * flashlight_speed * delta
	
	var radius = 40.0
	flashlight.position.x = clamp(flashlight.position.x, radius, play_area.size.x - radius)
	flashlight.position.y = clamp(flashlight.position.y, radius, play_area.size.y - radius)


func _unhandled_input(event):
	if not running:
		return
	
	if event.is_action_pressed("ui_accept"):
		flash()

# Bat flashing logic, checks an Area2D overlapping entities and applies take_damage to them if inside
func flash():
	if flash_cooldown:
		return
	
	# Start flash
	flash_cooldown = true
	
	var overlapping = flash_area.get_overlapping_areas()
	for area in overlapping:
		if area.is_in_group("flash_bat"):
			area.take_damage(1)
	
	play_flash_effect()
	
	# Cooldown for flash + end
	await get_tree().create_timer(0.15).timeout
	flash_cooldown = false

func play_flash_effect():
	var tween = create_tween()
	tween.tween_property(darkness.material, "shader_parameter/radius", 0.35, 0.1)  # expand
	tween.tween_property(darkness.material, "shader_parameter/radius", 0.25, 0.1)   # shrink back

# BAT ENTITY LOGIC
# Bat scale depending on count
func get_bat_scale(count: int) -> float:
	match count:
		2: return 0.85
		3: return 0.75
		4: return 0.55
		5: return 0.4
	return 1.0 # Won't reach this

func spawn_bats():
	var count := randi_range(2, 5)
	bats_remaining = count
	
	var scale := get_bat_scale(count)
	
	for i in range(count):
		var chosen_variant = bat_variants.pick_random()
		var bat = BatScene.instantiate()
		bats_node.add_child(bat)
		
		bat.position = get_random_screen_position()
		bat.scale = Vector2.ONE * scale
		var bat_hp = randi_range(2, 3)
		bat.setup(chosen_variant, bat_hp)
		
		bat.died.connect(_on_bat_died)

func get_random_screen_position(padding: float = 10.0) -> Vector2:
	# In bounds, don't want to do math for this
	var x = randf_range(-116, 116)
	var y = randf_range(-96, 96)
	return Vector2(x, y)


# Bat dying logic
func _on_bat_died(bat):
	bats_remaining -= 1
	
	# Flash size increases
	base_light_radius += 0.02
	darkness.material.set_shader_parameter("radius", base_light_radius)

	print(bats_remaining)
	if bats_remaining <= 0:
		win_sequence()

# Spawns combat scene's damage number near the player hand
func spawn_damage_number(damage: float):
	if not DamageNumberScene:
		return
	
	var dmg_scene = DamageNumberScene.instantiate()
	dmg_scene.global_position = flash_area.global_position
	add_child(dmg_scene)
	dmg_scene.z_index = 5 # Above flashlight
	dmg_scene.play(damage, false)

# Minigame end logic
func win_sequence():
	timer_active = false
	set_process_unhandled_input(false)
	# Covers the entire screen with flash
	var tween = create_tween()
	tween.tween_property(darkness.material, "shader_parameter/radius", 3.0, 0.6)
	await tween.finished
	
	end(true)

func on_timeout():
	# Damaging player and ending minigame
	damage_taken.emit(DAMAGE, flash_area.global_position)
	spawn_damage_number(DAMAGE)
	hit_stop(0.1)
	shake_node(1)
	end(false)
