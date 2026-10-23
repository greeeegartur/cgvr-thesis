extends Node

# The game's sound system: plays sound effects from a pool of players on the SFX bus (panned a little by where they happen on screen)
# (the music lives in Music.gd); the SFX bus follows the volume slider in Settings

const POOL_SIZE := 24 # Players for sounds that happen in the world (panned)
const FLAT_POOL_SIZE := 12 # Players for centered sounds (UI, Tuh-U's voice, minigames on the screen)
const PAN_STRENGTH := 0.0 # Every sound plays centered (panning by screen position made the creatures' side sound heavier)
const SFX_BUS := "SFX"
const MUFFLED_BUS := "SFX Muffled" # A low-passed branch of the SFX bus for hollow, distant versions of a sound
const MUFFLED_CUTOFF := 900.0
const SILENT_DB := -60.0
const CUT_FADE := 0.04 # A cut sound fades over this, so it never clicks
const PRESS_STEP_MAX := 7 # Semitones the press ladder climbs at most (a fifth)
const LIMITER_CEILING_DB := -1.0 # Stacked sounds are kept below this, so they never clip
const MASTER_CEILING_DB := -0.5 # The sound effects and the music together never go above this
const DUCK_IDS := ["hurt", "block_break", "killed", "tamed", "all_perfect"] # The music dips under these

const SOUND_FILES := [
	preload("res://Scripts/Data/Sounds/option_move.tres"),
	preload("res://Scripts/Data/Sounds/option_select.tres"),
	preload("res://Scripts/Data/Sounds/text_speech.tres"),
	preload("res://Scripts/Data/Sounds/tuhu_fly.tres"),
	preload("res://Scripts/Data/Sounds/hop.tres"),
	preload("res://Scripts/Data/Sounds/droid_move.tres"),
	preload("res://Scripts/Data/Sounds/beetle_walk.tres"),
	preload("res://Scripts/Data/Sounds/beetle_rush_walk.tres"),
	preload("res://Scripts/Data/Sounds/bat_flap.tres"),
	preload("res://Scripts/Data/Sounds/bat_screech.tres"),
	preload("res://Scripts/Data/Sounds/bat_attack.tres"),
	preload("res://Scripts/Data/Sounds/frog_hop.tres"),
	preload("res://Scripts/Data/Sounds/frog_flies.tres"),
	preload("res://Scripts/Data/Sounds/frog_attack.tres"),
	preload("res://Scripts/Data/Sounds/duck_walk.tres"),
	preload("res://Scripts/Data/Sounds/duck_quack.tres"),
	preload("res://Scripts/Data/Sounds/stat_change.tres"),
	preload("res://Scripts/Data/Sounds/modifier_indicator.tres"),
	preload("res://Scripts/Data/Sounds/healing.tres"),
	preload("res://Scripts/Data/Sounds/blocking.tres"),
	preload("res://Scripts/Data/Sounds/block_break.tres"),
	preload("res://Scripts/Data/Sounds/hurt.tres"),
	preload("res://Scripts/Data/Sounds/tame_swoosh.tres"),
	preload("res://Scripts/Data/Sounds/normal_press.tres"),
	preload("res://Scripts/Data/Sounds/perfect_press.tres"),
	preload("res://Scripts/Data/Sounds/light_explosion.tres"),
	preload("res://Scripts/Data/Sounds/all_perfect.tres"),
	preload("res://Scripts/Data/Sounds/killed.tres"),
	preload("res://Scripts/Data/Sounds/minigame_enter.tres"),
	preload("res://Scripts/Data/Sounds/dream_open.tres"),
	preload("res://Scripts/Data/Sounds/dream_exit.tres"),
	preload("res://Scripts/Data/Sounds/dream_end.tres"),
	preload("res://Scripts/Data/Sounds/tamed.tres"),
	preload("res://Scripts/Data/Sounds/beetle_flicked.tres"),
	preload("res://Scripts/Data/Sounds/flashlight.tres"),
	preload("res://Scripts/Data/Sounds/shop_buy.tres"),
]

var sounds := {} # id -> SoundData
var loop_streams := {} # id -> a looping copy of the stream
var last_played := {} # id -> time of the last play (msec), for cooldowns
var pool: Array[AudioStreamPlayer2D] = []
var flat_pool: Array[AudioStreamPlayer] = []
var owner_offsets := {} # Instance id -> dB a node's sounds are raised by (a creature's block window)
var serial := 0 # Every play gets a number, so a late fade or cut never stops a player that was reused meanwhile
var paused := false
var press_step := 0 # The rising press ladder of the current tame sequence or ability
var log_plays := OS.is_debug_build() and OS.get_cmdline_user_args().has("--sfx-log") # Prints every play with its frame (for checking a recorded playthrough)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for data in SOUND_FILES:
		sounds[data.id] = data
	_add_limiter()
	_add_muffled_bus()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.bus = SFX_BUS
		player.max_distance = 100000.0 # No falling off with distance, only panning
		player.panning_strength = PAN_STRENGTH
		add_child(player)
		pool.append(player)
	for i in FLAT_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		flat_pool.append(player)

# A limiter at the end of the SFX bus, so many sounds at once are squeezed instead of clipping
func _add_limiter() -> void:
	var index := AudioServer.get_bus_index(SFX_BUS)
	if index == -1:
		return
	for i in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(index, limiter)
	var master_limiter := AudioEffectHardLimiter.new()
	master_limiter.ceiling_db = MASTER_CEILING_DB
	AudioServer.add_bus_effect(0, master_limiter)

# A bus that sends into SFX through a low-pass filter (so the SFX slider and the limiter still apply)
func _add_muffled_bus() -> void:
	if AudioServer.get_bus_index(MUFFLED_BUS) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, MUFFLED_BUS)
	AudioServer.set_bus_send(index, SFX_BUS)
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = MUFFLED_CUTOFF
	AudioServer.add_bus_effect(index, filter)

# PLAYING
# Plays a sound by id; at is where it happens in the world (a Node2D or a Vector2) for panning, null plays it centered
# options: "volume" (dB on top of its level), "pitch" (multiplier), "from" (seconds into the file), "fade_in" (seconds),
# "length" (seconds until it is cut with a short fade), "loop" (repeats until stopped), "muffled" (through the low-pass bus)
func play(id: String, at: Variant = null, options := {}) -> Node:
	var data: SoundData = sounds.get(id)
	if data == null:
		push_error("Unknown sound: " + id)
		return null

	# Cooldown: a play right after the last one is dropped
	var now := Time.get_ticks_msec()
	if data.cooldown > 0.0 and now - int(last_played.get(id, -100000)) < int(data.cooldown * 1000.0):
		return null
	last_played[id] = now
	if id in DUCK_IDS:
		Music.duck()

	# Voice cap: restarting sounds stop their voice, others replace the oldest once the cap is reached
	var playing := _voices_of(id)
	if data.restart:
		for voice in playing:
			_cut(voice)
		playing.clear()
	while playing.size() >= data.max_voices:
		_cut(playing.pop_front())

	var centered: bool = at == null or data.ui
	var player: Node = _free_player(centered)
	serial += 1
	player.set_meta("id", id)
	player.set_meta("serial", serial)
	player.set_meta("started", now)
	player.set_meta("ui", data.ui)
	var owner_id: int = at.get_instance_id() if at is Node2D else 0
	player.set_meta("owner", owner_id)
	if not centered:
		player.global_position = at.global_position if at is Node2D else at

	player.stream = _loop_stream(id) if options.get("loop", false) else data.stream
	player.bus = MUFFLED_BUS if options.get("muffled", false) else SFX_BUS
	var base_db: float = data.volume_db + float(options.get("volume", 0.0))
	player.set_meta("base_db", base_db)
	player.pitch_scale = float(options.get("pitch", 1.0)) * (1.0 + randf_range(-data.pitch_variation, data.pitch_variation))
	player.stream_paused = false

	var fade_in: float = options.get("fade_in", 0.0)
	var level_db: float = base_db + float(owner_offsets.get(owner_id, 0.0))
	player.volume_db = SILENT_DB if fade_in > 0.0 else level_db
	player.play(float(options.get("from", 0.0)))
	if log_plays:
		print("SFX %d %s %.1f %.3f %.2f" % [Engine.get_process_frames(), id, base_db, player.pitch_scale, float(options.get("from", 0.0))])
	if paused and not data.ui:
		player.stream_paused = true
	if fade_in > 0.0:
		fade_to(player, level_db, fade_in)
	if options.has("length"):
		_cut_after(player, float(options["length"]))
	return player

# Plays a centered sound (menus, Tuh-U's voice, minigames drawn on the screen)
func play_ui(id: String, options := {}) -> Node:
	return play(id, null, options)

# Backing out of a menu: the confirm sound, lower and softer
func play_cancel() -> void:
	play_ui("option_select", { "pitch": 0.8, "volume": -3.0 })

# Leaving the options: a muffled, lower confirm, as if the menu closes away from you
func play_menu_close() -> void:
	play_ui("option_select", { "pitch": 0.85, "volume": 4.0, "muffled": true }) # The filter takes most of its brightness away, so it gets more level back

# A denied action (no chips, on cooldown, can't afford): the miss sound, soft and low
func play_deny() -> void:
	play_ui("blocking", { "pitch": 0.85, "volume": -8.0 })

# Pitch multiplier for a number of semitones
func semitones(steps: float) -> float:
	return pow(2.0, steps / 12.0)

# THE PRESS LADDER
# Starts a new tame sequence or ability: the first landed press is at the base pitch again
func reset_press_ladder() -> void:
	press_step = 0

# A landed press (perfect or normal) at the ladder's pitch; each one climbs a semitone, up to a fifth
func play_press(perfect: bool, at: Variant = null) -> void:
	play("perfect_press" if perfect else "normal_press", at, { "pitch": semitones(press_step) })
	press_step = mini(press_step + 1, PRESS_STEP_MAX)

# STOPPING AND FADING
# Stops a player a play returned (with a fade if given); with the play's serial (serial_of), a player that was reused for another sound meanwhile is left alone
func stop(player: Node, fade := 0.0, serial_id := 0) -> void:
	if player == null or not is_instance_valid(player):
		return
	if serial_id != 0 and player.get_meta("serial", 0) != serial_id:
		return
	if fade <= 0.0:
		player.stop()
		return
	var keep: int = player.get_meta("serial", 0)
	var tween := fade_to(player, SILENT_DB, fade)
	tween.finished.connect(func(): if player.get_meta("serial", 0) == keep: player.stop())

# The number of the play a player is busy with (to stop exactly that play later)
func serial_of(player: Node) -> int:
	return player.get_meta("serial", 0) if player and is_instance_valid(player) else 0

# Fades a playing sound to a volume (in dB) with a sine curve
func fade_to(player: Node, volume_db: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", volume_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

# Sets a playing sound's volume relative to its own level (0 = its normal level)
func set_level(player: Node, offset_db: float) -> void:
	if player and is_instance_valid(player) and player.playing:
		player.volume_db = float(player.get_meta("base_db", 0.0)) + offset_db

# Seconds a sound's file lasts
func length_of(id: String) -> float:
	var data: SoundData = sounds.get(id)
	return data.stream.get_length() if data else 0.0

# Raises (or lowers) every sound of one node by offset_db: the playing ones fade there, new ones start there
func set_owner_level(owner: Node, offset_db: float, fade := 0.08) -> void:
	var id := owner.get_instance_id()
	if offset_db == 0.0:
		owner_offsets.erase(id)
	else:
		owner_offsets[id] = offset_db
	for player in pool:
		if player.playing and player.get_meta("owner", 0) == id:
			fade_to(player, float(player.get_meta("base_db", 0.0)) + offset_db, fade)

# Whether a sound with this id is playing right now
func is_playing(id: String) -> bool:
	return not _voices_of(id).is_empty()

# Stops every voice of a sound (with a fade if given)
func stop_id(id: String, fade := 0.0) -> void:
	for voice in _voices_of(id):
		stop(voice, fade)

# Stops all sound effects at once (a scene change)
func stop_all() -> void:
	for player in pool + flat_pool:
		player.stop()
	owner_offsets.clear()

# PAUSE
# The pause menu freezes the gameplay sounds where they are; menu sounds keep playing
func set_paused(on: bool) -> void:
	paused = on
	for player in pool + flat_pool:
		if player.playing and not player.get_meta("ui", false):
			player.stream_paused = on

# HELPERS
# The players currently playing a sound id, oldest first
func _voices_of(id: String) -> Array:
	var result := []
	for player in pool + flat_pool:
		if player.playing and player.get_meta("id", "") == id:
			result.append(player)
	result.sort_custom(func(a, b): return a.get_meta("started", 0) < b.get_meta("started", 0))
	return result

# A player that is not playing, or the one that has been playing the longest
func _free_player(centered: bool) -> Node:
	var players: Array = (flat_pool as Array) if centered else (pool as Array)
	var oldest: Node = players[0]
	for player in players:
		if not player.playing:
			return player
		if player.get_meta("started", 0) < oldest.get_meta("started", 0):
			oldest = player
	oldest.stop()
	return oldest

# Stops a voice with a very short fade, so it does not click
func _cut(player: Node) -> void:
	stop(player, CUT_FADE)

# Cuts a sound after a time (the time follows the game's speed, so a pause holds it too)
func _cut_after(player: Node, seconds: float) -> void:
	var keep: int = player.get_meta("serial", 0)
	await get_tree().create_timer(maxf(seconds - CUT_FADE, 0.0)).timeout
	if is_instance_valid(player) and player.get_meta("serial", 0) == keep:
		_cut(player)

# A looping copy of a sound's stream (the shared stream stays one-shot)
func _loop_stream(id: String) -> AudioStream:
	if not loop_streams.has(id):
		var copy: AudioStream = sounds[id].stream.duplicate()
		if copy is AudioStreamWAV:
			copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
			copy.loop_begin = 0
			copy.loop_end = int(copy.get_length() * copy.mix_rate) # In frames (works for compressed data too)
		elif "loop" in copy:
			copy.loop = true
		loop_streams[id] = copy
	return loop_streams[id]
