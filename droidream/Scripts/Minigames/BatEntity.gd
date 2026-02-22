extends Area2D

# Bat entity for Bat Flash minigame

signal died(bat)

@onready var sprite := $Sprite2D
@onready var hp_container := $HBoxContainer
@export var flash_texture : Texture2D
var normal_texture : Texture2D

var max_hp := 3
var hp := 2
var hp_label
var revealed := false

func setup(texture: Texture2D, hp_value: int):
	normal_texture = texture
	sprite.texture = normal_texture
	add_to_group("flash_bat")
	set_hp(hp_value)

func set_hp(value: int):
	hp = value
	max_hp = value
	update_hp_ui()
	hp_container.visible = false

func take_damage(amount: int):
	if not revealed:
		revealed = true
		hp_container.visible = true
	
	hp -= amount
	update_hp_ui()
	
	# Swap texture briefly
	sprite.texture = flash_texture
	
	if hp <= 0:
		die()
	else:
		await get_tree().create_timer(0.08).timeout
		sprite.texture = normal_texture

func update_hp_ui():
	for i in hp_container.get_child_count():
		var heart = hp_container.get_child(i)
		heart.visible = i < max_hp
		heart.modulate.a = 1.0 if i < hp else 0.25

func die():
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 80, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	
	died.emit(self)
	queue_free()
