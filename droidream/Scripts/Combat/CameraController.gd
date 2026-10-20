extends Camera2D
class_name CombatCamera

# This script is responsible for all camera movement in the combat scene (player and enemy turns)

# Sizes of camera impacts, so hits and crits stay proportional (shake in pixels, pop as extra zoom)
enum Impact { SMALL, MEDIUM, LARGE }
const IMPACTS := {
	Impact.SMALL: { "shake": 4.0, "time": 0.22, "pop": 0.0 },
	Impact.MEDIUM: { "shake": 6.0, "time": 0.32, "pop": 0.0 },
	Impact.LARGE: { "shake": 9.0, "time": 0.55, "pop": 0.18 }
}

# Framing of several subjects at once (target select, multi-target abilities)
const ZOOM_ACTION := Vector2(1.34, 1.34) # Zoom while the Droid tames or blocks, a little closer than the normal focus
const VICTORY_ZOOM := Vector2(2.4, 2.4)
const VICTORY_DROID_POSITION := Vector2(140, 215) # Where the Droid appears on screen during the rewards and the boon selection
const ZOOM_LOWER := 28.0 # Pixels the view moves down per 1.0 of extra zoom
const RESET_TIME := 0.9 # Going back to the normal frame is slow and eased, so the changes between screens feel smooth
const GROUP_PADDING := 90.0 # Space kept on each side of the outermost subjects
const ANTICIPATE_ZOOM := 1.06 # Slow push toward an attacker during its wind-up
const WIDE_LOWER := 30.0 # The wide frame sits lower, so parts can also come in from below the Droid
const WIDE_ZOOM := Vector2(1.15, 1.15) # Ability frame that shows the whole play area (Repair)

# Camera zoom variables
@export var zoom_normal = Vector2(1.0, 1.0)
@export var zoom_focus = Vector2(1.23, 1.23)

# Camera movement variable
@export var follow_speed := 3.0
@export var x_offset := 60.0

# Temporary zoom system
var base_zoom: Vector2
var zoom_tween: Tween

# Camera's position variables
var default_position: Vector2
var follow_target: Node2D = null
var y_bias := 0.0 # Extra pixels the view sits lower (wide ability frames need room under the Droid)
var focus_zoom := Vector2(1.23, 1.23) # Zoom of the current follow
var follow_group: Array = [] # Subjects framed together (their x center is followed)
var override = false

func _ready():
	default_position = global_position
	zoom = zoom_normal
	base_zoom = zoom_normal
	zoom = zoom_normal

func _process(delta):
	# If shouldn't be following
	if override:
		return
	
	# Follows only X-axis position, might rework if making bigger enemies
	var target_x := default_position.x
	if follow_target:
		target_x = follow_target.global_position.x + x_offset
	elif not follow_group.is_empty():
		target_x = _group_center_x()
	
	# Staggering behind with delay to not feel stiff
	global_position.x = lerp(
		global_position.x,
		target_x,
		delta * follow_speed
	)
	
	# The closer the zoom, the lower the view sits, so the characters' feet stay on screen
	global_position.y = lerp(
		global_position.y,
		default_position.y + (zoom.x - 1.0) * ZOOM_LOWER + y_bias,
		delta * follow_speed
	)

# CombatManager functions to call
# Follows given entity with a given offset (80 for player for example)
func follow(node: Node2D, offset := 0.0, zoom_amount := Vector2.ZERO):
	follow_target = node
	follow_group.clear()
	y_bias = 0.0
	x_offset = offset
	focus_zoom = zoom_focus if zoom_amount == Vector2.ZERO else zoom_amount
	# Focuses on entity
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", focus_zoom, 0.3)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)

# Stops following entity
func stop_follow():
	follow_target = null
	follow_group.clear()
	y_bias = 0.0
	# Resets zoom
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", zoom_normal, 0.3)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)


# Camera shake for critical hits/powerful attacks: a rolling earthquake that rumbles on a few steady frequencies and dies away
# (it is added on top of the camera offset, so following and zoom keep working while it shakes)
var shake_offset := Vector2.ZERO
var shake_tween: Tween

func shake(intensity := 6.0, time := 0.15):
	if shake_tween:
		shake_tween.kill()
	shake_tween = create_tween()
	shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shake_tween.tween_method(func(progress: float):
		var seconds := progress * time
		var strength := intensity * pow(1.0 - progress, 1.4)
		_set_shake(Vector2(
			(sin(seconds * 41.0) * 0.7 + sin(seconds * 67.0 + 1.3) * 0.3) * strength * 0.8,
			(sin(seconds * 33.0 + 0.7) * 0.75 + sin(seconds * 57.0) * 0.25) * strength
		)), 0.0, 1.0, time)
	shake_tween.finished.connect(func(): _set_shake(Vector2.ZERO))

# Swaps the shake part of the camera offset
func _set_shake(value: Vector2) -> void:
	offset += value - shake_offset
	shake_offset = value

# For critical hits
func pop_zoom(amount := 0.18, duration := 0.17):
	var tween := create_tween()
	tween.tween_property(self, "zoom", zoom * (1.0 + amount), duration * 0.4)
	tween.tween_property(self, "zoom", zoom, duration * 0.6)

# Zoom in for the victory screen; the rewards and the boon selection that follows share this angle (the Droid stands on the left)
func victory_focus_on_player(target: Node2D) -> void:
	override = true
	follow_target = null
	follow_group.clear()
	
	if zoom_tween:
		zoom_tween.kill()
		zoom_tween = null
	
	# Camera sits on the Droid, shifted so the Droid appears at VICTORY_DROID_POSITION on screen at the final zoom
	var shift := (get_viewport_rect().size / 2.0 - VICTORY_DROID_POSITION) / VICTORY_ZOOM.x
	
	# A hold, a slow push past the final zoom and a soft settle
	await get_tree().create_timer(0.3).timeout
	var tween := create_tween()
	tween.tween_property(self, "global_position", target.global_position, 1.3)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "zoom", VICTORY_ZOOM * 1.06, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "offset", shift, 1.1)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "zoom", VICTORY_ZOOM, 0.4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func reset_camera():
	follow_target = null
	follow_group.clear()
	y_bias = 0.0
	override = true
	
	if zoom_tween:
		zoom_tween.kill()
		zoom_tween = null
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", default_position, RESET_TIME)
	tween.parallel().tween_property(self, "zoom", zoom_normal, RESET_TIME)
	tween.parallel().tween_property(self, "offset", Vector2.ZERO, RESET_TIME)
	
	await tween.finished
	override = false

func ability_focus_on_player(target: Node2D, zoom_amount: Vector2, duration := 0.4):
	_ability_frame(target, zoom_amount, duration)

# Frames several subjects together: follows their x center and zooms so they fit with some space around them (up to max_zoom)
func frame_group(nodes: Array, duration := 0.35, max_zoom := 0.0) -> void:
	follow_target = null
	follow_group = nodes.filter(func(n): return is_instance_valid(n))
	x_offset = 0.0
	if follow_group.is_empty():
		return
	
	var xs: Array[float] = []
	for node in follow_group:
		xs.append(node.global_position.x)
	var span: float = xs.max() - xs.min() + GROUP_PADDING * 2.0
	var fit := clampf(get_viewport_rect().size.x / span, zoom_normal.x, max_zoom if max_zoom > 0.0 else zoom_focus.x)
	focus_zoom = Vector2(fit, fit)
	
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", Vector2(fit, fit), duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

func _group_center_x() -> float:
	var min_x := INF
	var max_x := -INF
	for node in follow_group:
		if is_instance_valid(node):
			min_x = minf(min_x, node.global_position.x)
			max_x = maxf(max_x, node.global_position.x)
	return (min_x + max_x) / 2.0 if min_x <= max_x else default_position.x

# A shake and zoom pop of one of the preset sizes
func impact(size: Impact) -> void:
	var data: Dictionary = IMPACTS[size]
	if data.pop > 0.0:
		pop_zoom(data.pop)
	shake(data.shake, data.time)

# Slow push toward an attacker during its wind-up (the zoom resets with the next follow or stop_follow)
func anticipate(duration := 0.7) -> void:
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", focus_zoom * ANTICIPATE_ZOOM, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

# Wide ability frame on the player: the whole play area stays visible (Repair)
func ability_frame_wide(target: Node2D, duration := 0.4) -> void:
	_ability_frame(target, WIDE_ZOOM, duration)
	y_bias = WIDE_LOWER

# Gentle push-in on the player for abilities that happen on them (Heat Up, Harden)
func ability_push_in(target: Node2D, zoom_amount := Vector2(1.3, 1.3), duration := 0.4) -> void:
	_ability_frame(target, zoom_amount, duration)

func _ability_frame(target: Node2D, zoom_amount: Vector2, duration: float) -> void:
	follow_target = target
	follow_group.clear()
	x_offset = 0.0
	override = false
	if zoom_tween:
		zoom_tween.kill()
	base_zoom = zoom
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", zoom_amount, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
