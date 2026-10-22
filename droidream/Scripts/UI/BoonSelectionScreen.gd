extends Control
class_name BoonSelectionScreen

signal boon_selected

const CARD_TICK_LENGTH := 0.085 # Only the first syllable of the blip
const CARD_TICK_PITCH_STEP := 0.1 # Each card's tick is this much higher than the one before
const HOP_PIXELS := 3.0 # Height of the selected card's hop
const PULSE_STRENGTH := 0.5 # Selection effect strength for a card (1.0 is a main creature target)

@onready var containers = [
	$BoonContainer1,
	$BoonContainer2,
	$BoonContainer3
]

@onready var gears := [
	$Gear1,
	$Gear2,
	$Gear3
]
var gear_tweens := []
var pulse_tweens := []
var gear_rest_y := []

var boons: Array
var selected := 0

var input_locked := true

func _ready():
	gear_tweens.resize(3)
	pulse_tweens.resize(3)
	for gear in gears:
		gear_rest_y.append(gear.position.y)

func show_boons(rolled_boons):
	visible = true
	boons = rolled_boons
	selected = 0
	input_locked = true
	
	# Resetting from possible previous instances
	for i in range(3):
		containers[i].visible = false
		containers[i].modulate = Color.WHITE
		gears[i].modulate = Color(0.7, 0.7, 0.7, 0.0)
		gears[i].rotation = 0
		gears[i].position.y = gear_rest_y[i]
		gears[i].scale = Vector2(1.5, 1.5)
		gears[i].visible = true
	_start_gear_spin()
	
	# Each gear pops in first, its card follows right after; everything is one staggered tween so nothing waits on timers
	for i in range(3):
		var delay: float = i * ScreenMotion.STAGGER
		var gear_tween := create_tween().set_parallel(true)
		gear_tween.tween_property(gears[i], "scale", Vector2.ONE, ScreenMotion.ENTER_TIME).set_delay(delay)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		gear_tween.tween_property(gears[i], "modulate:a", 1.0, ScreenMotion.ENTER_TIME * 0.6).set_delay(delay)
		
		containers[i].slot_center_y = gears[i].position.y
		containers[i].set_boon(boons[i])
		containers[i].scale = Vector2.ZERO
		containers[i].modulate.a = 0.0
		var card_delay: float = delay + ScreenMotion.STAGGER * 1.5
		get_tree().create_timer(card_delay).timeout.connect(func():
			containers[i].visible = true
			Sfx.play_ui("text_speech", { "pitch": 1.0 + i * CARD_TICK_PITCH_STEP, "length": CARD_TICK_LENGTH, "volume": -3.0 }) # The same soft tick as the reward count, a little higher with each card
		)
		var card_tween := create_tween().set_parallel(true)
		card_tween.tween_property(containers[i], "scale", Vector2.ONE, ScreenMotion.ENTER_TIME).set_delay(card_delay)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card_tween.tween_property(containers[i], "modulate:a", 1.0, ScreenMotion.ENTER_TIME * 0.5).set_delay(card_delay)
	
	await get_tree().create_timer(ScreenMotion.STAGGER * 3.5 + ScreenMotion.ENTER_TIME).timeout # Lets the last card finish popping in before it starts pulsing
	input_locked = false
	_update_selection()

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_down"):
		if not input_locked:
			Sfx.play_ui("option_move")
		selected = (selected + 1) % 3
		_update_selection()
	if event.is_action_pressed("ui_up"):
		if not input_locked:
			Sfx.play_ui("option_move")
		selected = (selected - 1 + 3) % 3
		_update_selection()
	if event.is_action_pressed("ui_accept"):
		_confirm_selection()

func _update_selection():
	for i in range(3):
		var gear = gears[i]
		var container = containers[i]
		_kill_gear_tween(i)
		_kill_pulse_tween(i)
		if i == selected:
			gear.modulate = Color.WHITE
			
			# Faster spin when selected
			var spin := create_tween()
			spin.set_loops()
			spin.tween_property(
				gear,
				"rotation",
				TAU,
				2.0
			).set_trans(Tween.TRANS_LINEAR).as_relative()
			gear_tweens[i] = spin
			
			# Same selection effect as the creatures: bounce, tint flash and an outline around the card
			container.set_highlight(true, Color.WHITE)
			var pulse := SelectionPulse.new(self, container)
			pulse.use_scale = false # Scaling blurs the art and text; the card hops in whole pixels instead
			pulse.hop_pixels = HOP_PIXELS
			pulse.tint_amount = 0.0 # No color change and no dimming: the card flashes toward white instead
			pulse.dip = 0.0
			pulse.flash_target = container
			pulse.start(PULSE_STRENGTH, 0.0)
			pulse_tweens[i] = pulse
		else:
			gear.modulate = Color(0.7,0.7,0.7)
			container.scale = Vector2.ONE
			container.set_highlight(false)
			
			# Return gear to slow spin
			var slow := create_tween()
			slow.set_loops()
			slow.tween_property(
				gear,
				"rotation",
				TAU,
				6.0
			).set_trans(Tween.TRANS_LINEAR).as_relative()
			gear_tweens[i] = slow

func _confirm_selection():
	if input_locked:
		return
	input_locked = true
	Sfx.play_ui("shop_buy") # The boon is taken
	
	# Player acquires boon with effect call
	var boon: BoonData = boons[selected]
	if boon.effect:
		boon.effect.call()
		
	await _play_selection_animation(selected)
	boon_selected.emit()

func _play_selection_animation(index):
	for i in range(3):
		_kill_gear_tween(i)
		_kill_pulse_tween(i)
	var chosen_container = containers[index]
	var chosen_gear = gears[index]
	# The other cards sink and fade, one after the other
	var order := 0
	for i in range(3):
		if i != index:
			var fade := create_tween().set_parallel(true)
			var delay: float = order * ScreenMotion.EXIT_STAGGER
			fade.tween_property(containers[i], "modulate:a", 0.0, ScreenMotion.EXIT_TIME).set_delay(delay)
			fade.tween_property(containers[i], "position:y", ScreenMotion.DROP_PIXELS, ScreenMotion.EXIT_TIME).set_delay(delay).as_relative()\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			fade.tween_property(gears[i], "modulate:a", 0.0, ScreenMotion.EXIT_TIME).set_delay(delay)
			fade.tween_property(gears[i], "position:y", ScreenMotion.DROP_PIXELS, ScreenMotion.EXIT_TIME).set_delay(delay).as_relative()\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			order += 1

	# Confirmation animation
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	# Scaling
	tween.tween_property(
		chosen_container,
		"scale",
		Vector2(1.2, 1.2),
		0.22
	)
	# Gear spinning
	tween.parallel().tween_property(
		chosen_gear,
		"rotation",
		chosen_gear.rotation + TAU * 1.5,
		0.25
	)
	# Flashing
	tween.parallel().tween_property(
		chosen_container,
		"modulate",
		Color(2,2,2),
		0.08
	)
	tween.tween_property(
		chosen_container,
		"modulate",
		Color.WHITE,
		0.1
	)

	# Stretch exit with scaling
	tween.tween_property(
		chosen_container,
		"scale",
		Vector2(0.0, 1.2),
		0.35
	)
	tween.parallel().tween_property(
		chosen_container,
		"modulate:a",
		0.0,
		0.35
	)
	tween.parallel().tween_property(
		chosen_gear,
		"scale",
		Vector2(0.0, 1.2),
		0.35
	)
	tween.parallel().tween_property(
		chosen_gear,
		"modulate:a",
		0.0,
		0.35
	)
	await tween.finished
	visible = false

# Slower spin (default)
func _start_gear_spin():
	for i in range(3):
		_kill_gear_tween(i)
		var gear = gears[i]
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(
			gear,
			"rotation",
			TAU,
			6.0
		).set_trans(Tween.TRANS_LINEAR).as_relative()

		gear_tweens[i] = tween

func _kill_gear_tween(i):
	if gear_tweens[i]:
		gear_tweens[i].kill()
		gear_tweens[i] = null

func _kill_pulse_tween(i):
	if pulse_tweens[i]:
		pulse_tweens[i].stop()
		pulse_tweens[i] = null

