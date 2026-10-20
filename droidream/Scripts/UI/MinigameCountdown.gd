extends RefCounted
class_name MinigameCountdown

# The 3, 2, 1 before a minigame the player has not met yet in this run (creature dreams and ability minigames); it can be switched off in Options

const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const NUMBER_TIME := 1.0 # Seconds each number takes
const START_SCALE := 1.7 # Each number starts big and zooms inward toward its center while it fades out
const END_SCALE := 0.45
const FONT_SIZE := 64

static var seen := {} # Minigames that already counted down in this run

# Forgets what was seen (a new run, Retry)
static func reset() -> void:
	seen.clear()

# Counts down before the minigame with the given key, the first time only; returns at once when it is off or already seen.
# host is any node in the scene (the countdown runs in game time, so pausing stops it)
static func play(host: Node, key: String) -> void:
	if not Settings.minigame_countdown or seen.has(key):
		return
	seen[key] = true
	
	var layer := CanvasLayer.new()
	layer.layer = 60
	host.add_child(layer)
	
	var screen := host.get_viewport().get_visible_rect().size
	var label := Label.new()
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 90)
	label.position = (screen - label.size) / 2.0 + Vector2(0, -20)
	label.pivot_offset = label.size / 2.0
	layer.add_child(label)
	
	for number in [3, 2, 1]:
		label.text = str(number)
		label.scale = Vector2.ONE * START_SCALE
		label.modulate.a = 1.0
		var tween := host.create_tween().set_parallel()
		tween.tween_property(label, "scale", Vector2.ONE * END_SCALE, NUMBER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 0.0, NUMBER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
	
	layer.queue_free()
