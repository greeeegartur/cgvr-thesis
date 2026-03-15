extends Control
class_name BoonSelectionScreen

signal boon_selected

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

var boons: Array
var selected := 0

var input_locked := true

func _ready():
	gear_tweens.resize(3)
	pulse_tweens.resize(3)

func show_boons(rolled_boons):
	visible = true
	boons = rolled_boons
	selected = 0
	
	# Resetting from possible previous instances
	for c in containers:
		c.visible = false
		c.modulate.a = 1.0
	for g in gears:
		g.visible = false
		g.modulate = Color(0.7,0.7,0.7)
		g.rotation = 0
	
	# Gears 
	for gear in gears:
		gear.scale = Vector2(1.6,1.6)
		gear.visible = true
		var tween = create_tween()
		tween.tween_property(
			gear,
			"scale",
			Vector2.ONE,
			0.35
		).set_trans(Tween.TRANS_BACK)
	
	_start_gear_spin()
	await get_tree().create_timer(0.4).timeout
	
	# Containers
	for i in range(3):
		await get_tree().create_timer(0.2).timeout
		containers[i].set_boon(boons[i])
		containers[i].scale = Vector2.ZERO
		containers[i].visible = true
		var tween = create_tween()
		tween.tween_property(
			containers[i],
			"scale",
			Vector2.ONE,
			0.25
		).set_trans(Tween.TRANS_BACK)
	
	input_locked = false
	_update_selection()

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_down"):
		selected = (selected + 1) % 3
		_update_selection()
	if event.is_action_pressed("ui_up"):
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
			
			# Container scale pulsing
			var pulse := create_tween()
			pulse.set_loops()
			pulse.tween_property(container,"scale",Vector2(1.1,1.1),0.4)
			pulse.tween_property(container,"scale",Vector2.ONE,0.4)
			pulse_tweens[i] = pulse
		else:
			gear.modulate = Color(0.7,0.7,0.7)
			container.scale = Vector2.ONE
			
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
	# Hiding other containers slightly
	for i in range(3):
		if i != index:
			var fade := create_tween()
			fade.tween_property(containers[i], "modulate:a", 0.0, 0.15)
			fade.parallel().tween_property(gears[i], "modulate:a", 0.0, 0.15)

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
		pulse_tweens[i].kill()
		pulse_tweens[i] = null
