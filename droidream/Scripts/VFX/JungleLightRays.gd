extends Node2D
class_name JungleLightRays

@export var move_amount := 8.0
@export var fade_min := 0.05
@export var fade_max := 0.12
@export var cycle_time := 4.5

@onready var rays := get_children()

func _ready():
	randomize()
	for ray in rays:
		_start_ray_loop(ray)

func _start_ray_loop(ray: Node2D):
	var base_pos := ray.position
	var base_rot := ray.rotation
	var delay := randf_range(0.0, 1.2)
	
	await get_tree().create_timer(delay).timeout
	
	while is_instance_valid(ray):
		var target_x := base_pos.x + randf_range(-move_amount, move_amount)
		var target_y := base_pos.y + randf_range(-4.0, 4.0)
		var target_alpha := randf_range(fade_min, fade_max)
		var target_rot := base_rot + deg_to_rad(randf_range(-1.5, 1.5))
		
		var tween := create_tween()
		tween.tween_property(ray, "position", Vector2(target_x, target_y), cycle_time)
		tween.parallel().tween_property(ray, "rotation", target_rot, cycle_time)
		tween.parallel().tween_property(ray, "modulate:a", target_alpha, cycle_time)
		await tween.finished
		
		var tween_back := create_tween()
		tween_back.tween_property(ray, "position", base_pos, cycle_time)
		tween_back.parallel().tween_property(ray, "rotation", base_rot, cycle_time)
		tween_back.parallel().tween_property(ray, "modulate:a", randf_range(fade_min, fade_max), cycle_time)
		await tween_back.finished
