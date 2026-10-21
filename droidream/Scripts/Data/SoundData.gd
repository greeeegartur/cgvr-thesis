extends Resource
class_name SoundData

# One sound effect: its file and how it is played (level, pitch variation, how many may overlap)

@export var id: String
@export var stream: AudioStream
@export var volume_db := 0.0 # Level-matched to its mix tier (the measured loudness of the file is evened out here)
@export var pitch_variation := 0.0 # Random pitch range around 1.0 per play, e.g. 0.05 = 0.95 to 1.05
@export var max_voices := 3 # How many may play at once; a new play replaces the oldest
@export var restart := false # Restarts its playing voice instead of stacking
@export var cooldown := 0.0 # Seconds a new play is ignored after the last one (two creatures stepping together do not double up)
@export var ui := false # Centered and keeps playing while the game is paused
