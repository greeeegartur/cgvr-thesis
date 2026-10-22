extends Node
class_name TameSequence

# The tame timing sequence: 2-3 shadow icons appear on the creature, an icon curves toward each one and the player presses Z while it travels;
# the results decide the damage multiplier (see Resources/prd/tame-timing-sequence.md). All numbers are constants here, so tuning is quick.

enum Result { PERFECT, GOOD, TRY, MISS }

signal pressed # Every counted press (the Droid snaps into a pose)
signal last_icon_started # The last icon leaves its start point (the camera eases in)
signal icon_judged(index: int, result: int, spot: Vector2, count: int) # The spot is kept even if the icon was cleared meanwhile

# Timing (seconds, in game time, so the pause menu and the hit-stop stop the icons and the windows together)
const HALF := 0.51 # Time from the start of an icon to its shadow: the moment to press
const FULL := 0.97 # The whole curve (the icon fades out between the half-point and here)
const SHADOW_IN := 0.07 # A shadow fades in this long before its icon starts to count down
const FIRST_LEAD := 0.25 # The first icon waits a little after its shadow appeared, the others less
const LEAD := 0.085
const AFTER_PRESS := 0.1 # The feedback of a press plays this long before the next shadow appears (the old ones stay)
const PERFECT_WINDOW := 0.09
const GOOD_WINDOW := 0.22
const EASIER_FACTOR := 1.5
const RECALIBRATION_PERFECT_FACTOR := 1.25
const MIN_ICONS := 2
const MAX_ICONS := 3

# Sounds
const SWOOSH_PEAK := 0.65 # Seconds into the swoosh file where it is loudest: it is started so this lands on the shadow
const SWOOSH_FADE_IN := 0.12
const SWOOSH_FADE_OUT := 0.15 # After a press the swoosh gets out of the way of the press sound
const SWOOSH_STEP := 2.0 # Semitones each further icon of a sequence swooshes higher

# Damage multipliers
const MULT_ALL_MISS := 0.75
const MULT_TRIED := 1.0
const MULT_ANY_PERFECT := 1.25
const MULT_ALL_PERFECT := 1.5
const MULT_ALL_PERFECT_RECALIBRATION := 1.75

# Chip restore: each Perfect rolls, at most one chip per sequence
const CHIP_CHANCE := 0.12
const CHIP_CHANCE_LAST_ALL_PERFECT := 0.16

# Where icons start from
const START_DISTANCE := Vector2(90.0, 120.0)
const START_DIRECTIONS := 8
const TURN := Vector2(50.0, 75.0) # Degrees the path bends by around the shadow: one smooth sweep, to either side
const SCREEN_MARGIN := 12.0
const MAX_SPOT_COVERAGE := 0.25 # One shadow may hide at most this share of the creature
const MAX_TOTAL_COVERAGE := 0.45 # All shadows together at most this share (they all stay until the end)
const SHADOW_RADIUS := 12.0 # Half the size of a landed icon
const MIN_SPOT_DISTANCE := 44.0 # The spots of one sequence are at least this far apart
const RING_MARGIN := 18.0 # How far outside the creature's edge the ring of spots lies
const RING_POINTS := 16

var last_direction := -1
var icons: Array[TameIcon] = []

# PURE RULES (static, so they can be tested without a scene)

# The windows in seconds around the landing: [perfect, good]
static func windows(easier := false, recalibration := false) -> Array:
	var perfect := PERFECT_WINDOW
	var good := GOOD_WINDOW
	if easier:
		perfect *= EASIER_FACTOR
		good *= EASIER_FACTOR
	if recalibration:
		perfect *= RECALIBRATION_PERFECT_FACTOR
	return [perfect, good]

# Judges one press by how far it was from the half-point of the curve (seconds)
static func judge(error: float, easier := false, recalibration := false) -> int:
	var w := windows(easier, recalibration)
	if error <= w[0]:
		return Result.PERFECT
	if error <= w[1]:
		return Result.GOOD
	return Result.TRY

# All missed 0.75, at least one tried 1.0, at least one Perfect 1.25, all Perfect 1.5 (1.75 with Recalibration)
static func multiplier(results: Array, recalibration := false) -> float:
	if results.is_empty():
		return MULT_TRIED
	var perfects := results.count(Result.PERFECT)
	var misses := results.count(Result.MISS)
	if perfects == results.size():
		return MULT_ALL_PERFECT_RECALIBRATION if recalibration else MULT_ALL_PERFECT
	if perfects > 0:
		return MULT_ANY_PERFECT
	if misses == results.size():
		return MULT_ALL_MISS
	return MULT_TRIED

# True when a chip is restored: each Perfect rolls, one chip at most; the last roll is better when every icon was Perfect
static func roll_chip(results: Array, rng: RandomNumberGenerator = null) -> bool:
	var all_perfect := not results.is_empty() and results.count(Result.PERFECT) == results.size()
	for i in results.size():
		if results[i] != Result.PERFECT:
			continue
		var chance := CHIP_CHANCE_LAST_ALL_PERFECT if (all_perfect and i == results.size() - 1) else CHIP_CHANCE
		var roll := rng.randf() if rng else randf()
		if roll <= chance:
			return true
	return false

# THE SEQUENCE
# Plays the whole sequence on a creature and returns the results (one per icon); a new icon only appears after the previous one was judged, and the old shadows stay
func play(enemy_visual: EnemyVisual, player_visual: Node2D, layer: Node2D, camera: Camera2D) -> Array:
	var spots := _pick_spots(enemy_visual, player_visual, camera)
	var count := mini(randi_range(MIN_ICONS, MAX_ICONS), spots.size())
	var results: Array = []
	icons.clear()
	Sfx.reset_press_ladder()
	for i in count:
		# This icon's shadow appears (the previous one is already gone)
		var icon := TameIcon.new()
		layer.add_child(icon)
		icons.append(icon)
		icon.show_shadow(spots[i])
		await _wait(SHADOW_IN + (FIRST_LEAD if i == 0 else LEAD))
		
		if i == count - 1:
			last_icon_started.emit()
		icon.begin_travel(_pick_start(icon.spot, enemy_visual, player_visual, camera), _pick_turn())
		var swoosh := Sfx.play("tame_swoosh", icon.spot, {
			"from": maxf(SWOOSH_PEAK - HALF, 0.0), # The loudest moment lands on the shadow, the perfect moment
			"fade_in": SWOOSH_FADE_IN,
			"pitch": Sfx.semitones(i * SWOOSH_STEP),
		})
		var swoosh_serial := Sfx.serial_of(swoosh)
		var result: int = await _run_icon(icon)
		results.append(result)
		_play_result_sound(result, icon.spot, swoosh, swoosh_serial)
		icon_judged.emit(i, result, spots[i], count)
		
		# The feedback plays, then the next shadow appears; the finished ones stay where they are until clear() at the end (no wait after the last one)
		if i < count - 1:
			await _wait(AFTER_PRESS)
	if count > 0 and results.count(Result.PERFECT) == results.size():
		Sfx.play("all_perfect", enemy_visual)
	return results

# The press sound of a judged icon (each landed press climbs the press ladder; a miss does not), and the swoosh fades out
func _play_result_sound(result: int, spot: Vector2, swoosh: Node, swoosh_serial: int) -> void:
	match result:
		Result.PERFECT:
			Sfx.play_press(true, spot)
		Result.GOOD:
			Sfx.play_press(false, spot)
		Result.TRY:
			Sfx.play_press(false, spot) # An early or late press still lands, only weaker
		_:
			Sfx.play("blocking", spot, { "pitch": 1.1, "volume": -4.0 }) # A missed icon
	Sfx.stop(swoosh, SWOOSH_FADE_OUT if result != Result.MISS else FULL - HALF, swoosh_serial)

# Runs one icon: it flies its curve, the first press is judged against the half-point, no press by then (plus the Good window) is a miss
func _run_icon(icon: TameIcon) -> int:
	var w := windows(Settings.easier_timing, PlayerData.has_ability("recalibration"))
	var elapsed := 0.0
	var result := Result.MISS
	while true:
		await get_tree().process_frame
		if not is_instance_valid(icon):
			return Result.MISS # The sequence was cleared under it
		elapsed += get_process_delta_time()
		icon.set_progress(_progress_at(elapsed))
		icon.set_preview_time(elapsed)
		
		if not PauseMenu.active and Input.is_action_just_pressed("ui_accept"):
			result = judge(absf(elapsed - HALF), Settings.easier_timing, PlayerData.has_ability("recalibration"))
			pressed.emit()
			break
		if elapsed >= HALF + w[1]:
			break # Too late: a miss (the icon keeps flying and fading)
	
	match result:
		Result.PERFECT:
			icon.lock(true)
		Result.GOOD:
			icon.lock(false)
		Result.TRY:
			icon.freeze_try()
		_:
			icon.miss(FULL - elapsed)
	return result

# The icon's curve parameter at a time: the half-point of the curve is exactly the moment to press, the rest follows in the remaining time
func _progress_at(elapsed: float) -> float:
	if elapsed <= HALF:
		return 0.5 * elapsed / HALF
	return minf(0.5 + 0.5 * (elapsed - HALF) / (FULL - HALF), 1.0)

# Waits in game time (the grace and the gap; presses are ignored meanwhile)
func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

# Fades the icons out when the sequence is over (not waited for: the damage and the effects start at once)
func clear() -> void:
	for icon in icons:
		if is_instance_valid(icon):
			icon.finish(0.2)
	icons.clear()

# SPOTS AND STARTS

# Spots around and on the creature in world coordinates: spots on the Droid, on the meter or off screen are skipped,
# one that hides too much of the creature is skipped, and the chosen spots are kept far apart
func _pick_spots(enemy_visual: EnemyVisual, player_visual: Node2D, camera: Camera2D) -> Array:
	var shape := CreatureShape.new(enemy_visual)
	var rect := shape.world_rect
	# A ring of points around the creature (even a small one gets three shadows) plus one on its upper body
	var candidates: Array = []
	var center := rect.get_center()
	for i in RING_POINTS:
		var angle := TAU * float(i) / RING_POINTS
		candidates.append(center + Vector2(cos(angle) * (rect.size.x * 0.5 + RING_MARGIN), sin(angle) * (rect.size.y * 0.5 + RING_MARGIN)))
	candidates.append(Vector2(center.x, rect.position.y + rect.size.y * 0.25)) # Center-high, on the body
	var view := _camera_rect(camera).grow(-SCREEN_MARGIN)
	var meter: Rect2 = enemy_visual.axis_bar.bar.get_global_rect().grow(8.0)
	var droid_sprite := player_visual.get_node_or_null("Visual/Sprite2D") as Sprite2D
	var droid := Rect2()
	if droid_sprite:
		droid = (droid_sprite.global_transform * droid_sprite.get_rect()).grow(10.0)
	var valid: Array = []
	for candidate in candidates:
		if view.has_point(candidate) and not meter.has_point(candidate) and not droid.has_point(candidate) and shape.coverage([candidate], SHADOW_RADIUS) <= MAX_SPOT_COVERAGE:
			valid.append(candidate)
	# Not enough good spots: add the rest of the candidates (they are the fallback)
	for candidate in candidates:
		if valid.size() < MAX_ICONS and not valid.has(candidate):
			valid.append(candidate)
	valid.shuffle()
	# Pick spots far apart: start anywhere, then always take the one farthest from the spots chosen so far
	var chosen: Array = [valid[0]]
	while chosen.size() < MAX_ICONS:
		var best: Variant = null
		var best_distance := 0.0
		for candidate in valid:
			if chosen.has(candidate):
				continue
			var nearest := INF
			for other in chosen:
				nearest = minf(nearest, other.distance_to(candidate))
			if nearest > best_distance:
				best_distance = nearest
				best = candidate
		if best == null or (best_distance < MIN_SPOT_DISTANCE and chosen.size() >= MIN_ICONS):
			break
		var test := chosen.duplicate()
		test.append(best)
		if chosen.size() >= MIN_ICONS and shape.coverage(test, SHADOW_RADIUS) > MAX_TOTAL_COVERAGE:
			break # A third shadow would hide too much of the creature
		chosen.append(best)
	return chosen

func _pick_turn() -> float:
	return deg_to_rad(randf_range(TURN.x, TURN.y)) * (1.0 if randf() < 0.5 else -1.0)

# A start point in one of 8 directions (never the same twice in a row) that is on screen and not on the meter or the Droid
func _pick_start(spot: Vector2, enemy_visual: EnemyVisual, player_visual: Node2D, camera: Camera2D) -> Vector2:
	var view := _camera_rect(camera).grow(-SCREEN_MARGIN)
	var meter: Rect2 = enemy_visual.axis_bar.bar.get_global_rect().grow(6.0)
	var droid_sprite := player_visual.get_node_or_null("Visual/Sprite2D") as Sprite2D
	var droid: Rect2 = Rect2()
	if droid_sprite:
		droid = (droid_sprite.global_transform * droid_sprite.get_rect()).grow(6.0)
	var order := range(START_DIRECTIONS)
	order.shuffle()
	for index in order:
		if index == last_direction:
			continue
		var angle := TAU * float(index) / START_DIRECTIONS
		var start := spot + Vector2(cos(angle), sin(angle)) * randf_range(START_DISTANCE.x, START_DISTANCE.y)
		if view.has_point(start) and not meter.has_point(start) and not droid.has_point(start):
			last_direction = index
			return start
	return spot + Vector2(0, -START_DISTANCE.x) # Fallback: straight above

func _camera_rect(camera: Camera2D) -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

# The visible shape of a creature: its opaque area in world coordinates and how much a set of round shadows would hide of it
class CreatureShape extends RefCounted:
	var sprite: Sprite2D
	var image: Image
	var frame_origin := Vector2i.ZERO
	var frame_size := Vector2i.ONE
	var world_rect := Rect2()
	var opaque_samples: Array[Vector2] = []
	
	func _init(enemy_visual: EnemyVisual) -> void:
		sprite = enemy_visual.visual.get_node("Sprite2D") as Sprite2D
		image = sprite.texture.get_image()
		frame_size = Vector2i(image.get_width() / sprite.hframes, image.get_height() / sprite.vframes)
		frame_origin = Vector2i((sprite.frame % sprite.hframes) * frame_size.x, (sprite.frame / sprite.hframes) * frame_size.y)
		var min_p := Vector2(INF, INF)
		var max_p := Vector2(-INF, -INF)
		for y in range(0, frame_size.y, 2):
			for x in range(0, frame_size.x, 2):
				if image.get_pixel(frame_origin.x + x, frame_origin.y + y).a > 0.2:
					var world: Vector2 = sprite.global_transform * (Vector2(x, y) - Vector2(frame_size) * 0.5 + sprite.offset)
					opaque_samples.append(world)
					min_p = min_p.min(world)
					max_p = max_p.max(world)
		world_rect = Rect2(min_p, max_p - min_p) if not opaque_samples.is_empty() else Rect2(sprite.global_position - Vector2(16, 16), Vector2(32, 32))
	
	# The share of the creature's opaque samples that lie under round shadows of the given radius
	func coverage(spots: Array, radius: float) -> float:
		if opaque_samples.is_empty():
			return 0.0
		var hidden := 0
		for sample in opaque_samples:
			for spot in spots:
				if sample.distance_to(spot) <= radius:
					hidden += 1
					break
		return float(hidden) / opaque_samples.size()
