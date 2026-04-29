extends BaseMinigame
class_name DuckFlap

@export var FishScene: PackedScene
@export var DamageNumberScene: PackedScene
@export var backgrounds : Array[Texture2D]

@export var flap_strength := 235.0
@export var gravity := 520.0
@export var max_fall_speed := 340.0
@export var forward_speed := 115.0
@export var fish_spawn_interval_min := 0.55
@export var fish_spawn_interval_max := 0.95
@export var fish_jump_duration_min := 1.0
@export var fish_jump_duration_max := 1.4
@export var fish_target_count := 5
@export var max_hits := 3
@export var combat_damage_per_hit := 0.25
@export var player_start_pos := Vector2(78, 122)
@export var respawn_invuln_time := 0.45

@onready var play_area: Control = $VisualRoot/PlayArea
@onready var fish_layer: Node2D = $VisualRoot/PlayArea/FishLayer
@onready var player: Area2D = $VisualRoot/PlayArea/Player
@onready var player_sprite: Sprite2D = $VisualRoot/PlayArea/Player/Sprite2D
@onready var water_hitbox: Area2D = $VisualRoot/PlayArea/WaterHitbox
@onready var sea_clip: Control = $VisualRoot/PlayArea/SeaClip
@onready var sea_a: TextureRect = $VisualRoot/PlayArea/SeaClip/SeaA
@onready var sea_b: TextureRect = $VisualRoot/PlayArea/SeaClip/SeaB
@onready var health_container := $VisualRoot/UI/HealthContainer
@onready var fish_label: Label = $VisualRoot/UI/FishLabel
@onready var sky_back : TextureRect = $VisualRoot/PlayArea/SkyBG

var velocity := Vector2.ZERO
var hits_taken := 0
var fish_collected := 0

var flight_started := false
var spawn_active := false
var player_locked := false
var win_started := false
var scroll_offset := 0.0
var sea_loop_width := 266.0

var timer_active := true
const TOP_PADDING := 22.0
const SIDE_PADDING := 18.0
const WATER_SURFACE_Y := 178.0

func _ready():
	set_duration(8.5) # actual is 6.5

	progress_bar.max_value = max_duration
	progress_bar.value = max_duration
	timer_label.text = "%.1fs" % max_duration
	sky_back.texture = backgrounds.pick_random()
	setup_scrollers()

	player.position = player_start_pos
	update_health()
	update_fish_label()

	# optional for testing
	# await get_tree().process_frame
	# play()

func play():
	await animate_in()
	start()
	spawn_active = true
	spawn_loop()

func start():
	super.start()
	velocity = Vector2.ZERO
	player_locked = false
	win_started = false
	timer_active = true
	flight_started = false

func _process(delta):
	super._process(delta)

	if not running:
		return
	
	if timer_active:
		update_timer_ui()

	if not player_locked and flight_started:
		update_player_physics(delta)

	update_fish_entities(delta)
	update_scrolling(delta)
	check_player_collisions()

func _unhandled_input(event):
	if not running or player_locked:
		return

	if event.is_action_pressed("ui_accept"):
		if not flight_started:
			flight_started = true
		flap()

func flap():
	velocity.y = -flap_strength

	# tiny squash/stretch
	var tween := create_tween()
	tween.tween_property(player_sprite, "scale", Vector2(1.58, 0.92), 0.05)
	tween.tween_property(player_sprite, "scale", Vector2.ONE * 1.5, 0.08)
	player_sprite.frame = 1
	await get_tree().create_timer(0.1).timeout
	player_sprite.frame = 0

func update_player_physics(delta: float) -> void:
	velocity.y += gravity * delta
	velocity.y = min(velocity.y, max_fall_speed)

	player.position.y += velocity.y * delta

	var min_y := TOP_PADDING
	var max_y := WATER_SURFACE_Y - 10.0

	player.position.y = clamp(player.position.y, min_y, max_y)
	player.position.x = clamp(player.position.x, SIDE_PADDING, play_area.size.x - SIDE_PADDING)

	# light tilt
	player.rotation = clamp(velocity.y * 0.0018, -0.35, 0.5)

func update_scrolling(delta: float) -> void:
	scroll_pair(sea_a, sea_b, forward_speed * 0.55, delta, sea_loop_width)

func scroll_pair(a: Control, b: Control, speed: float, delta: float, loop_width: float) -> void:
	a.position.x -= speed * delta
	b.position.x -= speed * delta
	
	if a.position.x <= -loop_width:
		a.position.x = b.position.x + loop_width
	elif b.position.x <= -loop_width:
		b.position.x = a.position.x + loop_width

func spawn_loop() -> void:
	while running and spawn_active:
		spawn_fish()
		await get_tree().create_timer(
			randf_range(fish_spawn_interval_min, fish_spawn_interval_max)
		).timeout

func spawn_fish() -> void:
	if not FishScene:
		return

	var fish = FishScene.instantiate()
	fish_layer.add_child(fish)

	var spawn_x := play_area.size.x + randf_range(0.0, -70.0)
	var base_y := randf_range(WATER_SURFACE_Y - 4.0, WATER_SURFACE_Y + 46.0)
	var peak_y := randf_range(24.0, WATER_SURFACE_Y - 64.0)
	var drift_speed := randf_range(forward_speed * 0.9, forward_speed * 1.2)
	var life_time := randf_range(fish_jump_duration_min, fish_jump_duration_max)

	fish.position = Vector2(spawn_x, base_y)

	if fish.has_method("setup"):
		fish.setup(base_y, peak_y, drift_speed, life_time)

func update_fish_entities(delta: float) -> void:
	for fish in fish_layer.get_children():
		if fish.has_method("step"):
			fish.step(delta)

func check_player_collisions() -> void:
	if damage_cooldown or win_started:
		return

	# Water fail
	if player.position.y >= WATER_SURFACE_Y - 18.0:
		deal_damage()
		return

	# Fish catch
	for fish in fish_layer.get_children():
		if fish.get("collected"):
			continue
		
		if player.global_position.distance_to(fish.global_position) <= 30.0:
			collect_fish(fish)
			break

func collect_fish(fish: Node) -> void:
	fish.collected = true

	var tween := create_tween()
	tween.tween_property(fish, "scale", Vector2.ONE * 1.35, 0.08)
	tween.parallel().tween_property(fish, "modulate:a", 0.0, 0.12)
	tween.finished.connect(fish.queue_free)

	fish_collected += 1
	update_fish_label()

	if fish_collected >= fish_target_count and not win_started:
		win_sequence()

func deal_damage() -> void:
	if damage_cooldown or not running:
		return

	damage_cooldown = true
	hits_taken += 1

	damage_taken.emit(combat_damage_per_hit, player.global_position)
	spawn_damage_number(combat_damage_per_hit)

	await hit_stop(0.08)
	shake_node(float(hits_taken))

	update_health()

	if hits_taken >= max_hits:
		end(false)
		return

	await respawn_player()

	await get_tree().create_timer(respawn_invuln_time).timeout
	damage_cooldown = false

func respawn_player() -> void:
	player_locked = true
	velocity = Vector2.ZERO
	player.position = player_start_pos
	player.rotation = 0.0

	await flicker_player()

	player_locked = false

func flicker_player() -> void:
	var tween := create_tween()
	tween.tween_property(player_sprite, "modulate:a", 0.25, 0.08)
	tween.tween_property(player_sprite, "modulate:a", 1.0, 0.08)
	tween.tween_property(player_sprite, "modulate:a", 0.25, 0.08)
	tween.tween_property(player_sprite, "modulate:a", 1.0, 0.08)
	await tween.finished

func win_sequence() -> void:
	win_started = true
	spawn_active = false
	player_locked = true
	velocity = Vector2.ZERO
	timer_active = false

	set_process_unhandled_input(false)

	# freeze timer progression visually and stop fish motion
	var old_duration = max_duration
	max_duration = 90.0

	for fish in fish_layer.get_children():
		if fish.has_method("freeze"):
			fish.freeze()

	var tween := create_tween()
	tween.tween_property(player_sprite, "scale", Vector2(1.65, 1.65), 0.1)
	tween.tween_property(player_sprite, "scale", Vector2.ONE * 1.5, 0.1)
	await tween.finished

	await get_tree().create_timer(1.0).timeout
	max_duration = old_duration
	end(true)

func on_timeout():
	if win_started:
		return

	spawn_active = false
	end(false)

func update_health():
	for i in range(health_container.get_child_count()):
		var icon := health_container.get_child(i)
		icon.visible = i < max_hits
		icon.modulate = Color("ffffffff") if i + 1 > hits_taken else Color(1.0, 1.0, 1.0, 0.094)

func update_fish_label() -> void:
	fish_label.text = "%d/%d" % [fish_collected, fish_target_count]

func spawn_damage_number(damage: float) -> void:
	if not DamageNumberScene:
		return

	var dmg_scene = DamageNumberScene.instantiate()
	dmg_scene.global_position = player.global_position
	add_child(dmg_scene)
	dmg_scene.z_index = 10
	dmg_scene.play(damage, false)

func setup_scrollers() -> void:
	sea_clip.clip_contents = true
	
	sea_a.position = Vector2(0.0, 0.0)
	sea_b.position = Vector2(sea_loop_width, 0.0)
