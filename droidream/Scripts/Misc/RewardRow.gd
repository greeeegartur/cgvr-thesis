extends HBoxContainer
class_name RewardRow

@onready var icon := $Icon
@onready var name_label := $Name
@onready var amount_label := $Amount

var target_amount := 0
var skipped := false
var name_text := ""

var animating := false

func setup(texture:Texture2D, name:String, amount:int):
	icon.texture = texture
	name_text = name
	target_amount = amount
	name_label.text = name
	amount_label.text = "x0"
	
	scale = Vector2(1.35,0.65)
	modulate.a = 0.0

func play_count():
	for i in range(target_amount + 1):
		if skipped:
			amount_label.text = "x%d" % target_amount
			animating = false
			return
		
		amount_label.text = "x%d" % i
		await get_tree().create_timer(0.035).timeout
	
	animating = false
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.55, 0.06)
	tween.tween_property(self, "scale", Vector2.ONE * 1.4, 0.1)

func animate_in():
	animating = true
	
	var tween := create_tween()
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(
		self,
		"scale",
		Vector2(0.75, 1.25),
		0.22
	)
	tween.tween_property(
		self,
		"scale",
		Vector2.ONE * 1.4,
		0.25
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished
