extends Node

# Player settings (audio, camera shake, minigame countdown, controls): saved in user://settings.cfg and applied as soon as they change

signal changed

const FILE_PATH := "user://settings.cfg"
const MAX_STEP := 10 # Volume sliders have 10 steps
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

# Actions the controls choice can add keys to, with the key each scheme gives them (physical keycodes)
const CONTROL_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel", "toggle_turn_order"]
const DEFAULT_KEYS := {
	"ui_up": KEY_UP, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT, "ui_right": KEY_RIGHT,
	"ui_accept": KEY_Z, "ui_cancel": KEY_X, "toggle_turn_order": KEY_C
}
const WASD_KEYS := {
	"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D,
	"ui_accept": KEY_U, "ui_cancel": KEY_I, "toggle_turn_order": KEY_O
}
const RESERVED_KEYS := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER] # Pause and the engine's own confirm keys

var music := MAX_STEP
var sfx := MAX_STEP
var camera_shake := true
var minigame_countdown := false
var easier_timing := false # Wider windows for the tame timing icons
var controls_scheme := "default" # "default", "wasd" or "custom"
var custom_keys := {} # action -> physical keycode, for the custom scheme

signal controls_changed # The control scheme or the keys changed: key pictures update

var original_events := {} # The input map as the project defines it; these always stay bound (the failsafe)

func _ready() -> void:
	for action in CONTROL_ACTIONS:
		original_events[action] = InputMap.action_get_events(action).duplicate()
	_ensure_buses()
	load_settings()
	apply_audio()
	apply_controls()

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
	controls_scheme = str(file.get_value("controls", "scheme", "default"))
	if not controls_scheme in ["default", "wasd", "custom"]:
		controls_scheme = "default"
	var saved = file.get_value("controls", "custom_keys", {})
	custom_keys = saved if saved is Dictionary else {}

func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music)
	file.set_value("audio", "sfx", sfx)
	file.set_value("gameplay", "camera_shake", camera_shake)
	file.set_value("gameplay", "minigame_countdown", minigame_countdown)
	file.set_value("gameplay", "easier_timing", easier_timing)
	file.set_value("controls", "scheme", controls_scheme)
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
# The key an action uses in the chosen scheme (what the Controls screen shows)
func key_for(action: String) -> int:
	match controls_scheme:
		"wasd":
			return WASD_KEYS[action]
		"custom":
			return custom_keys.get(action, DEFAULT_KEYS[action])
	return DEFAULT_KEYS[action]

func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)

func set_scheme(scheme: String) -> void:
	controls_scheme = scheme
	if scheme == "custom" and custom_keys.is_empty():
		for action in CONTROL_ACTIONS:
			custom_keys[action] = DEFAULT_KEYS[action] # The custom list starts from the default keys
	apply_controls()
	save_settings()
	_refresh_key_pictures()
	changed.emit()

# Gives an action a custom key; when another action already uses that key the two keys swap. Returns false for reserved keys
func set_custom_key(action: String, keycode: int) -> bool:
	if keycode in RESERVED_KEYS:
		return false
	for each in CONTROL_ACTIONS:
		if not custom_keys.has(each):
			custom_keys[each] = DEFAULT_KEYS[each]
	var previous: int = custom_keys[action]
	for other in CONTROL_ACTIONS:
		if other != action and custom_keys[other] == keycode:
			custom_keys[other] = previous
	custom_keys[action] = keycode
	controls_scheme = "custom"
	apply_controls()
	save_settings()
	changed.emit()
	return true

# Back to the default keys only
func reset_controls() -> void:
	controls_scheme = "default"
	custom_keys.clear()
	apply_controls()
	save_settings()
	_refresh_key_pictures()
	changed.emit()

# Key pictures everywhere (hints, the controls bar and the minigames' sprites) follow the scheme in use
func _refresh_key_pictures() -> void:
	controls_changed.emit()
	ControlTextures.swap_in(get_tree().root)

# Rebuilds the input map: the original keys always stay, the chosen scheme's keys are added on top
func apply_controls() -> void:
	for action in CONTROL_ACTIONS:
		InputMap.action_erase_events(action)
		for event in original_events[action]:
			InputMap.action_add_event(action, event)
		if controls_scheme == "default":
			continue
		var extra := key_for(action)
		if extra == DEFAULT_KEYS[action]:
			continue
		var key_event := InputEventKey.new()
		key_event.physical_keycode = extra
		InputMap.action_add_event(action, key_event)
