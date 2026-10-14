extends Node2D

# Base ShopItem class

class_name ShopItem

var item_data: ShopEntry
var quantity := 1
var pop_tween: Tween

@onready var icon : Sprite2D = $Visual/Icon
@onready var root := $Visual
@onready var arrow := $Visual/Arrow
@onready var count_label := $Visual/CountLabel
@onready var anim := $Visual/AnimationPlayer

func setup(data: ShopEntry):
	item_data = data
	
	icon.texture = data.icon
	count_label.text = ""
	
	arrow.visible = false
	scale = Vector2.ONE

func set_selected(value: bool):
	arrow.visible = value
	
	if value:
		count_label.text = "x%d" % quantity
		_animate_select()
	else:
		count_label.text = ""
		scale = Vector2.ONE

func _animate_select():
	anim.play("idle")
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector2(1.1,1.1), 0.12)
	tween.tween_property(root, "scale", Vector2.ONE, 0.12)


func start_pop():
	stop_pop()
	pop_tween = create_tween()
	pop_tween.set_loops()
	pop_tween.tween_property(root, "scale", Vector2(1.1,1.1), 0.6)
	pop_tween.tween_property(root, "scale", Vector2.ONE, 0.6)
	pop_tween.set_trans(Tween.TRANS_LINEAR)

func stop_pop():
	if pop_tween:
		pop_tween.kill()
		pop_tween = null
	scale = Vector2.ONE

func shake():
	var orig_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position:x", orig_pos.x + 10, 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:x", orig_pos.x, 0.05)

func confirm_purchase():
	stop_pop()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2,1.2), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(self, "modulate", Color(1,1,1,2), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
