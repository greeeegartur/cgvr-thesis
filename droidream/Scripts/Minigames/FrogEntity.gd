extends Node2D
class_name FrogGuessEntity

@onready var sprite: Sprite2D = $Sprite2D
@onready var count_label: Label = $CountLabel

var is_real := true

const CROAK_GAP := 700 # Msec; the frogs croak together, but only one croak is heard at a time (no stacking)
static var last_croak := 0

func setup(texture: Texture2D, real: bool, tint: Color, entity_scale: float) -> void:
	is_real = real
	sprite.texture = texture
	sprite.modulate = tint
	scale = Vector2.ONE * entity_scale
	count_label.visible = false

# The croak's mouth opening (a method key in the croak animation)
func croak_sfx() -> void:
	var now := Time.get_ticks_msec()
	if now - last_croak < CROAK_GAP:
		return
	last_croak = now
	Sfx.play_ui("frog_attack", { "volume": -6.0 })

func show_count(number: int) -> void:
	count_label.text = str(number)
	count_label.visible = true
