extends Node

# The game's music: the title track, and the encounter and tutorial tracks that play in sync (the tutorial track is the encounter music with fewer instruments),
# so a blend between them never breaks the rhythm. Everything runs on the Music bus, which follows the Music slider in Settings.

enum Mode { NONE, TITLE, ENCOUNTER, TUTORIAL }

const TITLE_PATH := "res://Sounds/Music/Loop/Title.wav"
const ENCOUNTER_PATH := "res://Sounds/Music/Loop/Encounter.wav"
const TUTORIAL_PATH := "res://Sounds/Music/Loop/Tutorial.wav"

const MUSIC_BUS := "Music"
const ENCOUNTER_GAIN_DB := 9.5 # Brings the encounter music to about -19 LUFS, level with the sound effects (the tutorial track shares this gain)
const TITLE_GAIN_DB := 9.0 # The title stays about 8 dB softer than the encounter, as it was written
const CALM_FADE := 1.0 # Seconds to blend into the tutorial track (a dream or the stop starts)
const ENERGETIC_FADE := 1.5 # ...and back into the encounter track
const ENERGETIC_DELAY := 0.6 # A calm moment must be over for this long before the encounter track returns (dream after dream, a dream into the rewards)
const DUCK_DB := -2.0 # The music dips this much under the biggest sound effects
const DUCK_RELEASE := 0.5
const PAUSE_DB := -6.0 # Softer and muffled while the pause menu is open
const PAUSE_CUTOFF := 1200.0
const PAUSE_TIME := 0.25
const LIMITER_CEILING_DB := -1.0
const SILENT_DB := -80.0

var mode := Mode.NONE
var title_player: AudioStreamPlayer
var game_player: AudioStreamPlayer # Plays the encounter and the tutorial track together
var game_streams: AudioStreamSynchronized
var lowpass: AudioEffectLowPassFilter
var lowpass_index := -1

var fade_pos := 0.0 # 0 silent, 1 full: the fade in and out of whatever plays
var fade_rate := 0.0 # Per second, positive in, negative out
var stopping := false # A fade out stops the music when it is done
var blend := 0.0 # 0 is the encounter track, 1 the tutorial track (amplitude blend: the instruments both tracks share stay at one level)
var blend_rate := 0.0
var calm_holders := {}
var energetic_wait := 0.0 # Counts down once nothing wants the calm anymore
var duck_level := 0.0
var pause_amount := 0.0
var pause_on := false
var last_usec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # The pause freezes game time, the music keeps its own
	# Loaded here (not preloaded), so the script still compiles in the editor before the music files are imported
	var TITLE: AudioStreamWAV = load(TITLE_PATH)
	var ENCOUNTER: AudioStreamWAV = load(ENCOUNTER_PATH)
	var TUTORIAL: AudioStreamWAV = load(TUTORIAL_PATH)
	for stream in [TITLE, ENCOUNTER, TUTORIAL]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)

	title_player = AudioStreamPlayer.new()
	title_player.bus = MUSIC_BUS
	title_player.stream = TITLE
	add_child(title_player)

	game_streams = AudioStreamSynchronized.new()
	game_streams.stream_count = 2
	game_streams.set_sync_stream(0, ENCOUNTER)
	game_streams.set_sync_stream(1, TUTORIAL)
	game_player = AudioStreamPlayer.new()
	game_player.bus = MUSIC_BUS
	game_player.stream = game_streams
	add_child(game_player)

	_prepare_bus()
	last_usec = Time.get_ticks_usec()

# The Music bus gets a limiter (so the louder music never clips) and a low-pass filter for the pause
func _prepare_bus() -> void:
	var index := AudioServer.get_bus_index(MUSIC_BUS)
	if index == -1:
		return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(index, limiter)
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(index, lowpass)
	lowpass_index = AudioServer.get_bus_effect_count(index) - 1
	AudioServer.set_bus_effect_enabled(index, lowpass_index, false)

# PLAYING
# The title track, fading in
func play_title(fade_in := 1.5) -> void:
	_begin(Mode.TITLE, fade_in)
	title_player.play()

# The encounter track from its start, fading in (every combat scene start, and a retry after the death screen)
func play_encounter(fade_in := 0.9) -> void:
	_begin(Mode.ENCOUNTER, fade_in)
	blend = 0.0
	blend_rate = 0.0
	game_player.play()

# The tutorial track from its start, fading in (Tuh-U's first line); it stays on the tutorial track the whole tutorial
func play_tutorial(fade_in := 1.5) -> void:
	if mode == Mode.TUTORIAL: # Already started (or already fading out at the end of the tutorial): a later line never restarts it
		return
	_begin(Mode.TUTORIAL, fade_in)
	blend = 1.0
	blend_rate = 0.0
	game_player.play()

# Fades whatever plays out and stops it
func fade_out(duration: float) -> void:
	if mode == Mode.NONE:
		return
	calm_holders.clear()
	stopping = true
	fade_rate = -1.0 / maxf(duration, 0.01)

# Stops at once (the music of a scene that is about to be replaced)
func stop_now() -> void:
	title_player.stop()
	game_player.stop()
	mode = Mode.NONE
	stopping = false
	fade_pos = 0.0
	fade_rate = 0.0

func _begin(new_mode: Mode, fade_in: float) -> void:
	set_paused_dim(false) # A new scene never starts muffled (quitting from the pause menu leaves the pause on)
	pause_amount = 0.0
	title_player.stop()
	game_player.stop()
	mode = new_mode
	calm_holders.clear()
	energetic_wait = 0.0
	stopping = false
	fade_pos = 0.0 if fade_in > 0.0 else 1.0
	fade_rate = 1.0 / maxf(fade_in, 0.01)
	_apply()

# THE CALM TRACK
# Something wants the quieter tutorial track (a dream, the stop between encounters); the encounter track returns when nothing does
func set_calm(holder: String, on: bool) -> void:
	if on:
		calm_holders[holder] = true
	else:
		calm_holders.erase(holder)
	if mode != Mode.ENCOUNTER:
		return
	if not calm_holders.is_empty():
		energetic_wait = 0.0
		blend_rate = 1.0 / CALM_FADE
	elif energetic_wait <= 0.0:
		energetic_wait = ENERGETIC_DELAY

# PAUSE AND DUCKING
# The pause menu softens and muffles the music (the Music slider can still be heard from the pause options)
func set_paused_dim(on: bool) -> void:
	pause_on = on

# A big sound effect dips the music for a moment
func duck() -> void:
	duck_level = 1.0

# UPDATE
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - last_usec) / 1000000.0, 0.1) # Real time, so the pause (time scale 0) and hit-stops do not freeze the fades
	last_usec = now

	# The pause muffle is kept up to date even while nothing plays, so it can never stay stuck on
	pause_amount = move_toward(pause_amount, 1.0 if pause_on else 0.0, dt / PAUSE_TIME)
	_apply_pause_filter()

	if mode == Mode.NONE:
		return

	fade_pos = clampf(fade_pos + fade_rate * dt, 0.0, 1.0)
	if stopping and fade_pos <= 0.0:
		stop_now()
		return

	if energetic_wait > 0.0:
		energetic_wait -= dt
		if energetic_wait <= 0.0 and calm_holders.is_empty():
			blend_rate = -1.0 / ENERGETIC_FADE
	if mode == Mode.ENCOUNTER:
		blend = clampf(blend + blend_rate * dt, 0.0, 1.0)
		if (blend_rate > 0.0 and blend >= 1.0) or (blend_rate < 0.0 and blend <= 0.0):
			blend_rate = 0.0

	duck_level = maxf(duck_level - dt / DUCK_RELEASE, 0.0)
	_apply()

# Sets the levels: the fade, the ducking and the pause on the player, the blend on the two tracks
func _apply() -> void:
	var smooth := fade_pos * fade_pos * (3.0 - 2.0 * fade_pos) # Eases in and out
	var dynamic_db := linear_to_db(maxf(smooth, 0.0001)) + DUCK_DB * duck_level + PAUSE_DB * pause_amount
	if mode == Mode.TITLE:
		title_player.volume_db = TITLE_GAIN_DB + dynamic_db
	else:
		game_player.volume_db = ENCOUNTER_GAIN_DB + dynamic_db
		game_streams.set_sync_stream_volume(0, linear_to_db(maxf(1.0 - blend, 0.0001)))
		game_streams.set_sync_stream_volume(1, linear_to_db(maxf(blend, 0.0001)))

	_apply_pause_filter()

# The low-pass of the pause: open while the game runs, closing down as the pause menu opens
func _apply_pause_filter() -> void:
	if lowpass_index != -1:
		var index := AudioServer.get_bus_index(MUSIC_BUS)
		AudioServer.set_bus_effect_enabled(index, lowpass_index, pause_amount > 0.001)
		lowpass.cutoff_hz = 20000.0 * pow(PAUSE_CUTOFF / 20000.0, pause_amount)
