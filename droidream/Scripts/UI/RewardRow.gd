extends HBoxContainer
class_name RewardRow

@onready var icon := $Icon
@onready var name_label := $Name
@onready var amount_label := $Amount

var target_amount := 0
var skipped := false
var name_text := ""

var animating := false

# Scale the row keeps after its pop animations (set by RewardsScreen so rows always fit in the container)
var final_scale := 1.4
var active_tween: Tween

const COUNT_TICK_LENGTH := 0.085 # Only the first syllable of the blip

func setup(texture:Texture2D, name:String, amount:int, p_final_scale := 1.4):
	icon.texture = texture
	name_text = name
	target_amount = amount
	final_scale = p_final_scale
	name_label.text = name
	amount_label.text = "x0"
	
	scale = Vector2(1.35,0.65)
	modulate.a = 0.0

func play_count():
	for i in range(target_amount + 1):
		if skipped:
			_show_final()
			return
		
		amount_label.text = "x%d" % i
		if i % 2 == 1:
			Sfx.play_ui("text_speech", { "pitch": 1.0 + minf(i * 0.02, 0.4), "length": COUNT_TICK_LENGTH, "volume": -3.0 }) # A soft tick that climbs with the count
		await get_tree().create_timer(0.035).timeout
	
	if skipped:
		_show_final()
		return
	
	animating = false
	
	# Pop when the count lands, settles on the final scale
	active_tween = create_tween()
	active_tween.tween_property(self, "scale", Vector2.ONE * (final_scale + 0.15), 0.06)
	active_tween.tween_property(self, "scale", Vector2.ONE * final_scale, 0.1)
	await active_tween.finished

func animate_in():
	animating = true
	
	# Rows created after a skip appear at their final state right away
	if skipped:
		_show_final()
		return
	
	active_tween = create_tween()
	active_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.16)
	active_tween.parallel().tween_property(
		self,
		"scale",
		Vector2(0.75, 1.25),
		0.22
	)
	active_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * final_scale,
		0.25
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await active_tween.finished

# Fast-forwards the running animation to its end (the awaiting coroutines continue normally)
func finish_instantly():
	skipped = true
	if active_tween and active_tween.is_valid() and active_tween.is_running():
		active_tween.custom_step(100.0)
	_show_final()

# Final look: fully visible, final scale, full count
func _show_final():
	modulate.a = 1.0
	scale = Vector2.ONE * final_scale
	amount_label.text = "x%d" % target_amount
	animating = false
