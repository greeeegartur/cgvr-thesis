extends Node2D

# Base ShopItem class

class_name ShopItem

var item_data: ItemData
var quantity := 1
var pop_tween: Tween

@onready var icon : Sprite2D = $Icon
@onready var arrow := $Arrow
@onready var name_label := $NameLabel
@onready var count_label := $CountLabel
@onready var anim := $AnimationPlayer

func setup(data: ItemData):
	item_data = data
	
	icon.texture = data.icon
	name_label.text = data.display_name
	count_label.text = ""
	
	name_label.visible = false
	arrow.visible = false
	scale = Vector2.ONE

func set_selected(value: bool):
	arrow.visible = value
	
	if value:
		name_label.visible = true
		count_label.text = "x%d" % quantity
		_animate_select()
	else:
		count_label.text = ""
		name_label.visible = false
		scale = Vector2.ONE

func _animate_select():
	anim.play("idle")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.1,1.1), 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func start_pop():
	stop_pop()
	pop_tween = create_tween()
	pop_tween.set_loops()
	pop_tween.tween_property(self, "scale", Vector2(1.1,1.1), 0.6)
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.6)
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
