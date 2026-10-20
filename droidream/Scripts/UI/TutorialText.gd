extends CanvasLayer
class_name TutorialText

# This script is responsible for the instruction text during combat ("Press Z to block" etc.): outlined text with key icons anchored to what it is about, and the controls bar at the bottom

# Different states for it to react accordingly
enum HintType {
	PLAYER_TURN,
	PLAYER_SELECT,
	BOON_SELECT,
	SHOP,
	CRIT,
	BLOCK,
	REPAIR,
	MULTITAME,
	HEATUP,
	HARDEN,
	BALL
}

# Hint data: "text" is a list of BBCode strings and {"key": ...} icons shown in one line; "screen" places subject-less text on the screen;
# "top_left" places the line by its top-left corner instead, "font" sets its size; "bar" is the controls bar as [key, word] pairs
const HINTS := {
	HintType.PLAYER_TURN: { "bar": [["ARROWS", "Move"], ["Z", "Confirm"], ["X", "Cancel"], ["C", "Turn order"]] },
	HintType.PLAYER_SELECT: {
		"text": ["Select a [hint kind=wave]target[/hint]!"], "screen": Vector2(400, 56),
		"bar": [["ARROWS", "Move"], ["Z", "Confirm"], ["X", "Cancel"]]
	},
	HintType.BOON_SELECT: {
		"text": ["Select a [hint kind=wave]boon[/hint]!"], "screen": Vector2(135, 26), "font": 28,
		"bar": [["ARROWS", "Move"], ["Z", "Confirm"]]
	},
	HintType.SHOP: { "bar": [["ARROWS", "Move"], ["Z", "Confirm"]] },
	HintType.CRIT: { "text": ["Press", {"key": "Z"}, "right before hitting to [color=#ffd93d][hint kind=wave]crit[/hint][/color]!"], "subject": Vector2(0, -120) },
	HintType.BLOCK: { "text": ["Press", {"key": "Z"}, "before a hit to [color=#6bd0ff][hint kind=shake]block[/hint][/color]!"], "subject": Vector2(0, -72) },
	HintType.REPAIR: { "text": ["Press", {"key": "ARROWS"}, "towards yourself to [color=#7dff8a][hint kind=wave]absorb[/hint][/color] parts!"], "subject": Vector2(0, -138) },
	HintType.MULTITAME: { "text": ["Press", {"key": "Z"}, "when the shapes are [color=#ffd93d][hint kind=wave]aligned[/hint][/color]!"], "subject": Vector2(0, -200) },
	HintType.HEATUP: { "text": ["Press the [color=#ff6b6b][hint kind=wave]keys[/hint][/color] to power up!"], "subject": Vector2(0, -175) },
	HintType.HARDEN: { "text": ["Press keys in the correct [color=#6bd0ff][hint kind=wave]order[/hint][/color] for greater defense!"], "subject": Vector2(0, -135) },
	HintType.BALL: { "text": ["Press", {"key": "Z"}, "when the meter is fully [color=#ffd93d][hint kind=wave]one color[/hint][/color]!"], "screen": Vector2(500, 56) }
}

# Keys on the controls bar and the input actions that flash them when pressed
const KEY_ACTIONS := {
	"Z": ["ui_accept"],
	"X": ["ui_cancel"],
	"C": ["toggle_turn_order"],
	"ARROWS": ["ui_left", "ui_right", "ui_up", "ui_down"]
}

const FONT := preload("res://Graphics/Fonts/PixelOperator.ttf")
const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const FONT_SIZE := 24 # Instruction text is as big as the key icons next to it
const BAR_FONT_SIZE := 16 # The controls bar is a reminder, so its words and keys are small
const OUTLINE_SIZE := 6
const TEXT_DROP := 3 # Space above each text piece so its letters sit on the middle line of the key icons
const BAR_MARGIN := Vector2(10, 6) # Space between the controls bar and the bottom left corner
# Key icon sizes (whole numbers so pixels stay crisp): big enough to read at a glance, the arrow cluster is already tall
const MESSAGE_ICON_SCALE := { "Z": 2, "X": 2, "C": 2, "ARROWS": 1 }
const BAR_ICON_SCALE := { "Z": 1.7, "X": 1.7, "C": 1.7, "ARROWS": 0.85 }
const SCREEN_MARGIN := 8.0
const HUD_KEEP_CLEAR := Rect2(0, 0, 290, 90) # The top-left HUD: text about a subject is pushed below it
const POP_TIME := 0.25
const POP_DROP := 10.0 # How far above its place the text starts when it pops in
const FLOAT_PIXELS := 2.0 # How far the text rises on the beat
const FADE_TIME := 0.2

var current_state: HintType
var message: Control # The instruction line
var bar: Control # The controls bar
var message_icons: Array[KeyIcon] = []
var bar_icons: Array[KeyIcon] = []
var anchor: Node2D # What the message is about (null for subject-less text)
var anchor_offset := Vector2.ZERO # Offset from the anchor in world pixels
var screen_position := Vector2.ZERO # Where subject-less text sits (its center)
var top_left_position := Vector2.ZERO # Same, by its top-left corner (used when set)
var use_top_left := false
var font_size := FONT_SIZE
var shown_time := 0.0
var fade := 0.0 # 0..1 overall opacity, moves toward fade_target
var fade_target := 0.0
var flash_until := {} # Key name -> time its pressed look ends

func _ready() -> void:
	set_process(true)

# Shows the hint of a state; anchor is the node the text is about (the Droid, a creature...), nothing needed for the controls bar and subject-less text
func show_hint(type: HintType, p_anchor: Node2D = null) -> void:
	# The same hint that is already showing stays as it is (no re-pop, no flicker)
	if fade_target > 0.0 and (message or bar) and type == current_state and p_anchor == anchor:
		return
	current_state = type
	var data: Dictionary = HINTS[type]
	_retire_nodes()
	
	anchor = p_anchor if data.has("subject") else null # Subject-less hints sit at their screen position
	anchor_offset = data.get("subject", Vector2.ZERO)
	screen_position = data.get("screen", Vector2.ZERO)
	use_top_left = data.has("top_left")
	top_left_position = data.get("top_left", Vector2.ZERO)
	font_size = data.get("font", FONT_SIZE)
	if data.has("text"):
		message = _build_line(data.text, message_icons)
		message.modulate.a = 0.0
		add_child(message)
	if data.has("bar"):
		bar = _build_bar(data.bar)
		bar.modulate.a = 0.0
		add_child(bar)
	
	shown_time = 0.0
	fade = 0.0
	fade_target = 1.0
	_update(0.0) # Placed right away, so it never shows for a frame in the wrong place

# Fades the hint out
func hide_text() -> void:
	fade_target = 0.0

func _process(delta: float) -> void:
	_update(delta)

func _update(delta: float) -> void:
	shown_time += delta
	fade = move_toward(fade, fade_target, delta / (POP_TIME if fade_target > fade else FADE_TIME))
	if fade <= 0.0 and fade_target <= 0.0:
		_clear()
		return
	
	var beat := fmod(shown_time, SelectionPulse.BEAT) / SelectionPulse.BEAT
	if message:
		_place_message(beat)
	if bar:
		var bar_size := bar.get_combined_minimum_size()
		bar.position = Vector2(BAR_MARGIN.x, get_viewport().get_visible_rect().size.y - bar_size.y - BAR_MARGIN.y)
		bar.modulate.a = fade
		_flash_pressed_keys()
	
	# Icons in the message press on the beat
	for icon in message_icons:
		icon.set_pressed(beat > 0.15 and beat < 0.4)

# Puts the message above its anchor (through the camera), clamped to the screen, with the pop-in drop and the beat float
func _place_message(beat: float) -> void:
	var center := screen_position
	if anchor and is_instance_valid(anchor):
		var canvas := get_viewport().get_canvas_transform()
		center = canvas * anchor.global_position + canvas.basis_xform(anchor_offset)
	
	var size := message.get_combined_minimum_size()
	message.size = size
	var top_left := top_left_position if use_top_left else center - size / 2.0
	var screen := get_viewport().get_visible_rect().size
	top_left.x = clampf(top_left.x, SCREEN_MARGIN, screen.x - size.x - SCREEN_MARGIN)
	top_left.y = clampf(top_left.y, SCREEN_MARGIN, screen.y - size.y - SCREEN_MARGIN)
	if anchor and Rect2(top_left, size).intersects(HUD_KEEP_CLEAR):
		top_left.y = HUD_KEEP_CLEAR.end.y + 2.0
	
	var pop := 1.0 - clampf(shown_time / POP_TIME, 0.0, 1.0)
	var drop := roundf(POP_DROP * pop * pop) # Eases in with a quick settle (whole pixels)
	var lift := roundf(FLOAT_PIXELS * SelectionPulse.beat_envelope(beat))
	message.position = Vector2(roundf(top_left.x), roundf(top_left.y) - drop - lift)
	message.modulate.a = fade

# Pressing a key on the bar shows it pressed for a moment
func _flash_pressed_keys() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for icon in bar_icons:
		for action in KEY_ACTIONS.get(icon.key_name, []):
			if Input.is_action_just_pressed(action):
				flash_until[icon.key_name] = now + 0.12
		icon.set_pressed(flash_until.get(icon.key_name, 0.0) > now)

# Builds one line: text pieces and key icons side by side
func _build_line(pieces: Array, icon_list: Array[KeyIcon]) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for piece in pieces:
		if piece is Dictionary:
			var icon := KeyIcon.new()
			icon.setup(piece.key, MESSAGE_ICON_SCALE[piece.key])
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(icon)
			icon_list.append(icon)
		else:
			line.add_child(_make_label(piece))
	return line

# Builds the controls bar: key icon + one word per pair
func _build_bar(pairs: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in pairs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := KeyIcon.new()
		icon.setup(pair[0], BAR_ICON_SCALE[pair[0]])
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(icon)
		bar_icons.append(icon)
		item.add_child(_make_label(pair[1], BAR_FONT_SIZE))
		row.add_child(item)
	return row

# One outlined text piece (BBCode, with the hint effect), in a margin that lowers it onto the key icons' middle line
func _make_label(text: String, size := font_size) -> Control:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", FONT)
	label.add_theme_font_override("bold_font", FONT_BOLD)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_font_size_override("bold_font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.custom_effects = [HintTextEffect.new()]
	label.text = text
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", TEXT_DROP)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)
	return margin

# Fades the nodes that are showing out on their own while a new hint takes their place
func _retire_nodes() -> void:
	for node in [message, bar]:
		if is_instance_valid(node):
			var tween: Tween = node.create_tween()
			tween.tween_property(node, "modulate:a", 0.0, 0.12)
			tween.finished.connect(node.queue_free)
	message = null
	bar = null
	message_icons.clear()
	bar_icons.clear()

func _clear() -> void:
	for node in [message, bar]:
		if is_instance_valid(node):
			node.queue_free()
	message = null
	bar = null
	message_icons.clear()
	bar_icons.clear()
