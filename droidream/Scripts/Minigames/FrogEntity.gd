extends Node2D
class_name FrogGuessEntity

@onready var sprite: Sprite2D = $Sprite2D
@onready var count_label: Label = $CountLabel

var is_real := true

func setup(texture: Texture2D, real: bool, tint: Color, entity_scale: float) -> void:
	is_real = real
	sprite.texture = texture
	sprite.modulate = tint
	scale = Vector2.ONE * entity_scale
	count_label.visible = false

func show_count(number: int) -> void:
	count_label.text = str(number)
	count_label.visible = true
