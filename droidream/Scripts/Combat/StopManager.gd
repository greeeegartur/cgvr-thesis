extends Node

class_name StopManager

signal stop_finished

# States
enum State {
	INACTIVE,
	ENTERING,
	ACTIVE,
	EXITING
}

# Base selection
var state := State.INACTIVE
var selection_index := 0
var next_pop_tween: Tween
var ufo_idle_tween: Tween

@onready var ui := $StopUI
@onready var ufo := $StopUI/TuhU
@onready var items_container := $StopUI/ItemsContainer
@onready var next_button := $StopUI/NextArrow
@onready var stop_text := $StopUI/StopText
@onready var popup := $StopUI/ShopItemContainer
@onready var item_scene = preload("res://Scenes/ShopItem.tscn")
@onready var HitFeedbackScene = preload("res://Scenes/VFX/HitFeedbackText.tscn")

var popup_tween: Tween
var popup_scale_tween: Tween
# TO-DO: karma based prices

func _ready():
	var base_y = popup.position.y + 2
	var t = create_tween()
	t.set_loops()
	t.tween_property(popup, "position:y", base_y + 3, 1.2)
	t.tween_property(popup, "position:y", base_y, 1.2)

func _unhandled_input(event):
	if state != State.ACTIVE:
		return
	
	if event.is_action_pressed("ui_right"):
		_move_selection(1)
	elif event.is_action_pressed("ui_left"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_accept"):
		_activate_selection()

func _move_selection(direction: int):
	var max_index := items_container.get_child_count()
	selection_index = clamp(selection_index + direction, 0, max_index)
	_update_selection_visuals()

func _update_selection_visuals():
	for i in items_container.get_child_count():
		var item = items_container.get_child(i)
		var selected = (i == selection_index)
		item.set_selected(selected)
		if selected:
			item.start_pop()
			_move_popup_to(item)
		else:
			item.stop_pop()
	
	# Next button logic
	var is_next := selection_index == items_container.get_child_count()
	if is_next:
		_hide_popup()
	else:
		_show_popup()
	_set_next_button_selected(is_next)

func _move_popup_to(item: ShopItem):
	popup.visible = true
	popup.setup(item.item_data, item.quantity, _get_modified_price(item.item_data.cost))
	var target_x = item.global_position.x -55
	
	if popup_tween:
		popup_tween.kill()
	popup_tween = create_tween()
	popup_tween.set_trans(Tween.TRANS_CUBIC)
	popup_tween.set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(
		popup,
		"global_position:x",
		target_x + 5,
		0.18
	)
	popup_tween.tween_property(popup, "global_position:x", target_x, 0.08)

func _activate_selection():
	if selection_index < items_container.get_child_count():
		var item_node = items_container.get_child(selection_index)
		_attempt_purchase(item_node)
	else:
		await _exit_stop()

func _attempt_purchase(shop_item: ShopItem):
	var data := shop_item.item_data
	var actual_cost := _get_modified_price(data.cost)
	
	# Does not allow purchase
	if PlayerData.currency < actual_cost or shop_item.quantity <= 0:
		shop_item.shake()
		return
	
	# Purchase accepted
	PlayerData.currency -= actual_cost
	shop_item.confirm_purchase()
	_play_purchase_feedback(shop_item)
	_spawn_purchase_feedback(shop_item)
	
	# Item's attributes inherited by player
	match data.id:
		"earth_chip":
			PlayerData.add_guesses(CombatTypes.EntityType.EARTH, 1)
		"sky_chip":
			PlayerData.add_guesses(CombatTypes.EntityType.SKY, 1)
		"water_chip":
			PlayerData.add_guesses(CombatTypes.EntityType.WATER, 1)
	
	shop_item.quantity -= 1
	_update_selection_visuals()

func enter_stop():
	state = State.ENTERING
	ui.visible = true
	popup.scale = Vector2.ZERO
	popup.visible = true
	
	await _animate_ufo_entry()
	await _spawn_items()
	await _show_next_button()
	selection_index = 0
	_update_selection_visuals()
	
	state = State.ACTIVE
	set_process_input(true)

func _exit_stop():
	state = State.EXITING
	set_process_input(false)
	
	await _animate_items_out()
	await _next_button_out()
	await _animate_ufo_exit()
	_stop_ufo_idle()
	
	# Resetting selection and UI for next stage
	selection_index = 0
	for child in items_container.get_children():
		child.stop_pop()
	next_button.scale = Vector2.ONE
	
	state = State.INACTIVE
	ui.visible = false
	
	stop_finished.emit()

func _animate_ufo_entry():
	ufo.position.y = -20
	var tween := create_tween()
	tween.tween_property(ufo, "position:y", 210, 1.2)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	await tween.finished
	_start_ufo_idle()

func _start_ufo_idle():
	_stop_ufo_idle()

	ufo_idle_tween = create_tween()
	ufo_idle_tween.set_loops()

	ufo_idle_tween.tween_property(
		ufo,
		"position:y",
		ufo.position.y + 10,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	ufo_idle_tween.tween_property(
		ufo,
		"position:y",
		ufo.position.y,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_ufo_idle():
	if ufo_idle_tween:
		ufo_idle_tween.kill()
		ufo_idle_tween = null

func _animate_ufo_exit():
	var tween := create_tween()
	tween.tween_property(ufo, "position:y", -20, 0.8)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	await tween.finished

func _play_purchase_feedback(shop_item: ShopItem):
	var tween := create_tween()
	# Popup slamming
	tween.tween_property(
		popup,
		"scale",
		Vector2(0.85, 1.25),
		0.08
	)

	# Flash
	tween.parallel().tween_property(popup, "modulate", Color(1,1,1,2), 0.05)
	tween.tween_property(popup, "modulate", Color.WHITE, 0.1)
	
	# Bouncing
	tween.tween_property(
		popup,
		"scale",
		Vector2.ONE * 1.2,
		0.18
	).set_trans(Tween.TRANS_BACK)

	# Item pop confirmation
	tween.parallel().tween_property(
		shop_item,
		"scale",
		Vector2(1.55,1.55),
		0.12
	)
	tween.tween_property(
		shop_item,
		"scale",
		Vector2.ONE * 1.2,
		0.12
	)

	await tween.finished

func _spawn_items():
	items_container.visible = true
	
	var rolled_items = _roll_shop_items()
	
	for i in rolled_items.size():
		var item_instance = item_scene.instantiate()
		item_instance.position = Vector2(410 + (i * 53), 283)
		items_container.add_child(item_instance)
		
		var data = rolled_items[i]
		item_instance.setup(data)

		# Generate stack size depending on given item (necessary for chips and maybe other items)
		if data.max_stack > 1:
			item_instance.quantity = randi_range(1, data.max_stack)
		else:
			item_instance.quantity = 1
		
		item_instance.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(item_instance, "scale", Vector2.ONE, 0.2)

func _animate_items_out() -> void:
	var children := items_container.get_children()
	
	for i in children.size():
		var item = children[i]
		var tween := create_tween()
		tween.tween_property(item, "scale", Vector2.ZERO, 0.2)
		tween.parallel().tween_property(item, "modulate:a", 0.0, 0.2)
	
	await get_tree().create_timer(0.25).timeout
	
	for child in children:
		child.queue_free()

# Also shows stop text
func _show_next_button():
	next_button.visible = true
	next_button.scale = Vector2.ZERO
	stop_text.visible = true
	stop_text.scale = Vector2.ZERO
	
	var tween := create_tween()
	tween.tween_property(next_button, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(stop_text, "scale", Vector2.ONE, 0.2)
	await tween.finished

func _next_button_out():
	var tween := create_tween()
	tween.tween_property(next_button, "scale", Vector2.ZERO, 0.2)
	tween.parallel().tween_property(stop_text, "scale", Vector2.ZERO, 0.2)
	await tween.finished
	
	next_button.visible = false
	stop_text.visible = false

func _set_next_button_selected(selected: bool):
	if selected:
		_start_next_pop()
	else:
		_stop_next_pop()

func _start_next_pop():
	if next_pop_tween:
		next_pop_tween.kill()
	
	next_pop_tween = create_tween()
	next_pop_tween.set_loops()
	next_pop_tween.tween_property(next_button, "scale", Vector2(1.2,1.2), 0.4)
	next_pop_tween.tween_property(next_button, "scale", Vector2.ONE, 0.4)
	next_pop_tween.set_trans(Tween.TRANS_LINEAR)
	next_pop_tween.set_ease(Tween.EASE_IN)

func _stop_next_pop():
	if next_pop_tween:
		next_pop_tween.kill()
	next_button.scale = Vector2.ONE

# Randomly picks 3 items to display in the shop from current unlocked items
func _roll_shop_items():
	var pool = ItemDb.get_unlocked_items().duplicate()
	var chosen: Array[ShopEntry] = []
	
	while chosen.size() < 3 and pool.size() > 0:
		var item = pool.pick_random()
		pool.erase(item)
		
		# Duplicate check for abilities
		if item.type == ShopEntry.ItemType.ABILITY and item.ability_data:
			if PlayerData.has_ability(item.ability_data.id):
				continue
		
		# And same for passives
		if item.type == ShopEntry.ItemType.PASSIVE and item.passive_data:
			if PlayerData.has_ability(item.passive_data.id):
				continue
		
		# Does not allow the same item to be in the shop twice, i.e "Repair" ability and "Repair" ability
		if chosen.any(func(i): return i.id == item.id):
			continue
		
		chosen.append(item)
	
	return chosen

func _hide_popup():
	if popup_scale_tween:
		popup_scale_tween.kill()
	popup_scale_tween = create_tween()
	popup_scale_tween.tween_property(
		popup,
		"scale",
		Vector2.ZERO,
		0.15
	)

func _show_popup():
	if popup_scale_tween:
		popup_scale_tween.kill()
	popup_scale_tween = create_tween()
	popup_scale_tween.tween_property(
		popup,
		"scale",
		Vector2.ONE * 1.2,
		0.15
	)

func _spawn_purchase_feedback(shop_item: ShopItem):
	var texts = [
		"[color=#17e84f][wave freq=12]Bought![/wave][/color]",
		"[color=#eff238][wave freq=12]Acquired![/wave][/color]",
		"[color=#3d9feb][shake rate=14]Got it![/shake][/color]"
	]
	var feedback := HitFeedbackScene.instantiate()
	ui.add_child(feedback)
	
	feedback.rotation_degrees = randf_range(-3,3)
	feedback.global_position = shop_item.global_position + Vector2(0,-20)
	feedback.play(texts.pick_random())

func _get_modified_price(base_cost: int) -> int:
	return base_cost + PlayerData.get_shop_price_increase()
