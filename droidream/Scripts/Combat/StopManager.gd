extends Node

class_name StopManager

signal stop_finished
signal demo_ending_finished

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
@onready var combat_ui := $"../UI/CombatUI"
@onready var player_visual := $"../World/PlayerVisual"
@onready var camera := $"../Camera2D"
@onready var speech_bubble := $"../UI/SpeechBubble"
@onready var item_scene = preload("res://Scenes/ShopItem.tscn")
@onready var HitFeedbackScene = preload("res://Scenes/VFX/HitFeedbackText.tscn")

var popup_tween: Tween
var popup_scale_tween: Tween
const UFO_STOP_POS := Vector2(390, 210)
const UFO_ENDING_POS := Vector2(170, 210)

func _ready():
	var base_y = popup.position.y + 5
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
	
	var added := false
	var fail_message := ""
	
	# Non-usable item attributes inherited by player
	match data.id:
		"earth_chip":
			PlayerData.add_guesses(CombatTypes.EntityType.EARTH, 1)
			added = true
		"sky_chip":
			PlayerData.add_guesses(CombatTypes.EntityType.SKY, 1)
			added = true
		"water_chip":
			PlayerData.add_guesses(CombatTypes.EntityType.WATER, 1)
			added = true
	
	# Every other item attributes inherited by player
	match data.type:
		ShopEntry.ItemType.ITEM:
			if data.item_data:
				added = PlayerData.add_item(data.item_data, 1)
				if not added:
					if PlayerData.is_item_stack_full(data.item_data):
						fail_message = "[color=#e72237ff][wave freq=12]Can't carry more![/wave][/color]"
					elif PlayerData.has_max_item_types():
						fail_message = "[color=#e72237ff][wave freq=12]Bag full![/wave][/color]"
		
		ShopEntry.ItemType.ABILITY:
			if data.ability_data:
				added = PlayerData.add_ability(data.ability_data)
				if not added:
					if PlayerData.has_ability(data.ability_data.id):
						fail_message = "[color=#e72237ff][wave freq=12]Already owned![/wave][/color]" # Should not be possible but just in case
					elif PlayerData.has_max_abilities():
						fail_message = "[color=#e72237ff][wave freq=12]Can't learn more![/wave][/color]"
		
		ShopEntry.ItemType.PASSIVE:
			if data.passive_data:
				added = PlayerData.add_ability(data.passive_data)
				if not added:
					if PlayerData.has_ability(data.passive_data.id):
						fail_message = "[color=#e72237ff][wave freq=12]Already owned![/wave][/color]" # Should not be possible but just in case
					elif PlayerData.has_max_abilities():
						fail_message = "[color=#e72237ff][wave freq=12]Can't learn more![/wave][/color]"
	
	if not added and data.type in [
		ShopEntry.ItemType.ITEM,
		ShopEntry.ItemType.ABILITY,
		ShopEntry.ItemType.PASSIVE
	]:
		shop_item.shake()
		_spawn_inventory_full_feedback(shop_item, fail_message)
		return
	
	# Purchase accepted
	PlayerData.currency -= actual_cost
	shop_item.confirm_purchase()
	_play_purchase_feedback(shop_item)
	_spawn_purchase_feedback(shop_item)
	
	shop_item.quantity -= 1
	combat_ui.refresh_player_hud()
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
			if PlayerData.has_max_abilities():
				continue
		
		# And same for passives
		if item.type == ShopEntry.ItemType.PASSIVE and item.passive_data:
			if PlayerData.has_ability(item.passive_data.id):
				continue
			if PlayerData.has_max_abilities():
				continue
		
		# Also same check for items
		if item.type == ShopEntry.ItemType.ITEM and item.item_data:
			# Skip if player cannot add one
			if not PlayerData.can_add_item(item.item_data, 1):
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

func _spawn_inventory_full_feedback(shop_item: ShopItem, message: String):
	var feedback := HitFeedbackScene.instantiate()
	ui.add_child(feedback)
	feedback.rotation_degrees = randf_range(-3, 3)
	feedback.global_position = shop_item.global_position + Vector2(0, -20)
	feedback.play(message)

# ENDING METHODS
func say(text: String, mood := "normal"):
	speech_bubble.set_target(ufo)
	
	match mood:
		"happy":
			ufo.play_happy()
		"sad":
			ufo.play_sad()
		"right":
			ufo.play_look_right()
		"down":
			ufo.play_look_down()
		"up":
			ufo.play_look_up()
		_:
			ufo.play_normal()
	
	speech_bubble.show_bubble()
	await speech_bubble.say_line(text)


func end_say():
	speech_bubble.hide_bubble()


func move_ufo_to(pos: Vector2, duration := 0.75, restart_idle := true):
	_stop_ufo_idle()
	
	if ufo.has_method("move_to"):
		await ufo.move_to(pos, duration)
	else:
		var tween := create_tween()
		tween.tween_property(ufo, "position", pos, duration)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)
		await tween.finished
	
	if restart_idle:
		_start_ufo_idle()

func enter_demo_ending_stop():
	state = State.ENTERING
	set_process_input(false)
	
	ui.visible = true
	
	# Hide normal shop UI.
	popup.visible = false
	items_container.visible = false
	next_button.visible = false
	stop_text.visible = false
	
	# Clear any leftover shop items.
	for child in items_container.get_children():
		child.queue_free()
	
	if not speech_bubble.is_node_ready():
		await speech_bubble.ready
	
	speech_bubble.set_target(ufo)
	speech_bubble.show_tail()
	
	await _animate_ufo_entry()
	await move_ufo_to(UFO_ENDING_POS, 0.8)
	
	await _play_demo_ending_dialogue()
	
	set_process_input(false)
	
	end_say()
	await get_tree().create_timer(0.25).timeout
	await move_ufo_to(UFO_STOP_POS, 0.5)
	
	state = State.INACTIVE
	ui.visible = false
	
	demo_ending_finished.emit()

func _play_demo_ending_dialogue():
	camera.follow(player_visual)
	await get_tree().create_timer(0.35).timeout
	
	await say("Hey, we made it to the end of the jungle!", "happy")
	await say("You're sure to become an excellent caretaker! There's no doubt in my mind!", "happy")
	await say("Unfortunately I have to break the fourth wall with some bad news.", "sad")
	await say("You've reached the end of the demo made for this thesis.", "normal")
	await say("There's kinda nothing beyond this point other than unfinished assets.", "right")
	await say("Feel free to try playing through the jungle again though! The experience is different each time!", "happy")
	
	await player_visual.bubble_emote("worry")
	await get_tree().create_timer(0.25).timeout
	
	await say("Oh right, about your progress..", "normal")
	
	match PlayerData.get_ending_type():
		"pacifist":
			await _play_pacifist_demo_dialogue()
		"neutral":
			await _play_neutral_demo_dialogue()
		"genocide":
			await _play_genocide_demo_dialogue()
		_:
			await say("Honestly, I'm not sure how to evaluate you.", "normal") # Should not happen
	
	await say("I'm sending you back to the title screen now.", "normal")
	end_say()

func _play_pacifist_demo_dialogue():
	await say("You managed to tame every creature in the jungle! You've done incredibly well!", "happy")
	await say("I'm sure it must've been difficult, managing so many resources and whatnot.", "normal")
	await say("You really are a true creature caretaker! I'm so proud!", "happy")


func _play_neutral_demo_dialogue():
	await say("You tamed some creatures, but had to resort to killing too.", "down")
	await say("It must have been tough with all those wild creatures trying to attack you.", "normal")
	await say("Not to say you did bad, in fact you did very well coming all this way!", "happy")
	await say("The developer definitely did not expect anyone to come this far, so you've done superbly!", "happy")


func _play_genocide_demo_dialogue():
	await say("...", "down")
	await say("..I, uh.. I'm truly at a loss for words..", "down")
	await say("..Does it feel good? Having killed all those creatures?", "normal")
	await say("You somehow managed to do the exact opposite of what I taught you. I hope you're proud.", "normal")
	await say("Those creatures were only trying to protect themselves, thinking you were a threat.", "normal")
	await say("And I guess they were right, you're a murderer through and through.", "normal")
	await say("Was that your dream? To stain this world red? To become human?", "normal")
	await say("Either way, I'm ashamed.", "sad")
