extends Node

# Player settings (audio, camera shake, minigame countdown, controls): saved in user://settings.cfg and applied as soon as they change

signal changed

const FILE_PATH := "user://settings.cfg"
const MAX_STEP := 10 # Volume sliders have 10 steps
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

# Both control families always work: the arrows with Z X C, and WASD with the mouse (left click Confirm, right click Cancel) and E.
# On top, each action can get one custom key. The key pictures follow the family pressed last (physical keycodes)
const CONTROL_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel", "toggle_turn_order"]
const DEFAULT_KEYS := {
	"ui_up": KEY_UP, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT, "ui_right": KEY_RIGHT,
	"ui_accept": KEY_Z, "ui_cancel": KEY_X, "toggle_turn_order": KEY_C
}
const WASD_KEYS := {
	"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D, "toggle_turn_order": KEY_E
}
const CLICK_ACTION := "click" # Left click: Confirm in timing moments (taming, blocking, lines, Duck Flap...); menus take it through their rows instead
const RESERVED_KEYS := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_T] # Pause, the engine's own confirm keys, Space (a silent Confirm) and T (skip tutorial)

var music := MAX_STEP
var sfx := MAX_STEP
var camera_shake := true
var minigame_countdown := false
var easier_timing := false # Wider windows for the tame timing icons
var custom_keys := {} # action -> physical keycode; only the actions that have a custom key
var input_family := "arrows" # "arrows", "wasd" or "custom": the family pressed last, which the key pictures show
const SWITCH_TIME := 2000 # Msec a fullscreen switch may take (the window keeps reporting its old mode meanwhile)
var switch_until := 0
var fullscreen := false # Not saved: the game always opens windowed (a browser only allows fullscreen from a key press anyway)

signal controls_changed # The keys or the family in use changed: key pictures update

var original_events := {} # The input map as the project defines it; these always stay bound (the failsafe)

func _ready() -> void:
	for action in CONTROL_ACTIONS:
		original_events[action] = InputMap.action_get_events(action).duplicate()
	get_window().size_changed.connect(_sync_fullscreen) # Leaving fullscreen with Escape or the browser's own button is noticed too
	get_window().window_input.connect(_track_family) # Before any node takes the event, so menus that eat their input still switch the pictures
	_ensure_buses()
	load_settings()
	apply_audio()
	apply_controls()

# FULLSCREEN
# F11 or Alt + Enter switches fullscreen on and off anywhere in the game
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			set_fullscreen(not fullscreen)
			get_viewport().set_input_as_handled()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	switch_until = Time.get_ticks_msec() + SWITCH_TIME
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()

func _sync_fullscreen() -> void:
	if Time.get_ticks_msec() < switch_until:
		return # The switch we asked for is still under way
	var real := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if real != fullscreen:
		fullscreen = real
		changed.emit()

# Reads the settings file; a missing or damaged file leaves the defaults
func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(FILE_PATH) != OK:
		return
	music = clampi(int(file.get_value("audio", "music", MAX_STEP)), 0, MAX_STEP)
	sfx = clampi(int(file.get_value("audio", "sfx", MAX_STEP)), 0, MAX_STEP)
	camera_shake = bool(file.get_value("gameplay", "camera_shake", true))
	minigame_countdown = bool(file.get_value("gameplay", "minigame_countdown", false))
	easier_timing = bool(file.get_value("gameplay", "easier_timing", false))
	# Older files saved a scheme and a full custom list that started from the default keys: only real custom keys are kept
	custom_keys = {}
	var saved = file.get_value("controls", "custom_keys", {})
	if saved is Dictionary and str(file.get_value("controls", "scheme", "custom")) == "custom":
		for action in saved:
			var keycode = saved[action]
			if action in CONTROL_ACTIONS and keycode is int and keycode != DEFAULT_KEYS[action] and keycode != WASD_KEYS.get(action, 0) and not keycode in RESERVED_KEYS:
				custom_keys[action] = keycode

func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music)
	file.set_value("audio", "sfx", sfx)
	file.set_value("gameplay", "camera_shake", camera_shake)
	file.set_value("gameplay", "minigame_countdown", minigame_countdown)
	file.set_value("gameplay", "easier_timing", easier_timing)
	file.set_value("controls", "custom_keys", custom_keys)
	file.save(FILE_PATH)

# AUDIO
# Creates the Music and SFX buses if the project has none yet (real sounds can be sent to them later)
func _ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")

func set_music(step: int) -> void:
	music = clampi(step, 0, MAX_STEP)
	apply_audio()
	save_settings()
	changed.emit()

func set_sfx(step: int) -> void:
	sfx = clampi(step, 0, MAX_STEP)
	apply_audio()
	save_settings()
	changed.emit()

# Step 0 mutes, step 10 is full volume
func apply_audio() -> void:
	_set_bus_step(MUSIC_BUS, music)
	_set_bus_step(SFX_BUS, sfx)

func _set_bus_step(bus_name: String, step: int) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, step == 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(float(step) / MAX_STEP) if step > 0 else 0.0)

# GAMEPLAY
func set_camera_shake(value: bool) -> void:
	camera_shake = value
	save_settings()
	changed.emit()

func set_easier_timing(value: bool) -> void:
	easier_timing = value
	save_settings()

func set_minigame_countdown(value: bool) -> void:
	minigame_countdown = value
	save_settings()
	changed.emit()

# CONTROLS
func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)

# Gives an action a custom key; when another action already has that custom key the two swap. Returns false for reserved keys
func set_custom_key(action: String, keycode: int) -> bool:
	if keycode in RESERVED_KEYS:
		return false
	var previous: int = custom_keys.get(action, 0)
	for other in CONTROL_ACTIONS:
		if other != action and custom_keys.get(other, 0) == keycode:
			if previous != 0:
				custom_keys[other] = previous
			else:
				custom_keys.erase(other)
	if keycode == DEFAULT_KEYS[action] or keycode == WASD_KEYS.get(action, 0):
		custom_keys.erase(action) # Its own fixed key: nothing extra to bind
	else:
		custom_keys[action] = keycode
	_controls_updated()
	return true

# Clears every custom key
func reset_controls() -> void:
	custom_keys.clear()
	if input_family == "custom":
		input_family = "arrows"
	_controls_updated()

func _controls_updated() -> void:
	apply_controls()
	save_settings()
	ControlTextures.clear_custom()
	_refresh_key_pictures()
	changed.emit()

# Key pictures everywhere (hints, the controls bar and the minigames' sprites) follow the family in use
func _refresh_key_pictures() -> void:
	controls_changed.emit()
	ControlTextures.swap_in(get_tree().root)

# The family of the last key or click: a custom key shows the custom pictures, a click or WASD the WASD ones, the arrows and Z X C the default ones
func _track_family(event: InputEvent) -> void:
	var family := ""
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: int = event.physical_keycode
		if keycode in custom_keys.values():
			family = "custom"
		elif keycode in WASD_KEYS.values():
			family = "wasd"
		elif keycode in DEFAULT_KEYS.values():
			family = "arrows"
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		family = "wasd"
	if family != "" and family != input_family:
		input_family = family
		_refresh_key_pictures()

# A Confirm from the keys or a left click (for timing moments, where a click anywhere counts)
func is_confirm(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or event.is_action_pressed(CLICK_ACTION)

func confirm_just_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed(CLICK_ACTION)

# Rebuilds the input map: the project's keys and the WASD family, minus any fixed key another action took as its custom key, plus the custom keys
func apply_controls() -> void:
	for action in CONTROL_ACTIONS:
		var taken := []
		for other in custom_keys:
			if other != action:
				taken.append(custom_keys[other])
		InputMap.action_erase_events(action)
		for event in original_events[action]:
			if event is InputEventKey and (event.physical_keycode if event.physical_keycode != 0 else event.keycode) in taken:
				continue
			InputMap.action_add_event(action, event)
		var extra := []
		if WASD_KEYS.has(action):
			extra.append(WASD_KEYS[action])
		if custom_keys.has(action):
			extra.append(custom_keys[action])
		for keycode in extra:
			if keycode in taken:
				continue
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action, key_event)
		if action == "ui_cancel":
			var right := InputEventMouseButton.new()
			right.button_index = MOUSE_BUTTON_RIGHT
			InputMap.action_add_event(action, right)
	if not InputMap.has_action(CLICK_ACTION):
		InputMap.add_action(CLICK_ACTION)
		var left := InputEventMouseButton.new()
		left.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(CLICK_ACTION, left)
