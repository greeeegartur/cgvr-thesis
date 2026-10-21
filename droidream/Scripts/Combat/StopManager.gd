extends Node

class_name StopManager

# The shop between stages: Tuh-U drops in, three items are rolled onto big centered cards, the selected one is described in a box under them

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
var selection_index := 0 # The cards first, then the "Next" button

@onready var ui := $StopUI
@onready var ufo := $StopUI/TuhU
@onready var combat_manager := $"../CombatManager"
@onready var combat_ui := $"../UI/CombatUI"
@onready var player_visual := $"../World/PlayerVisual"
@onready var camera := $"../Camera2D"
@onready var speech_bubble := $"../UI/SpeechBubble"
@onready var HitFeedbackScene = preload("res://Scenes/VFX/HitFeedbackText.tscn")

const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const UFO_STOP_POS := Vector2(390, 210)
const UFO_ENDING_POS := Vector2(170, 210)
const UFO_SHOP_POS := Vector2(556, 164) # Right of the items, looking at the Droid on the left
const UFO_HOME_POS := Vector2(463, -20) # Where Tuh-U waits above the screen
const CARD_GAP := 8.0
const SHOP_LEFT := 160.0 # Left edge of the items: away from the top HUD and the Droid, and Tuh-U sits about as far from the right edge as the Droid is from the left
const DETAIL_WIDTH := 300.0 # Slim, so Tuh-U and his bubble fit beside it
const CARDS_TOP := 104.0
const DETAIL_TOP := 206.0
const NEXT_SIZE := Vector2(62, 32)
const NEXT_ARROW_SPACE := 14.0 # The arrow takes the right side, so the text is nudged left to look centered
const ENDING_WIDTHS := [120.0, 150.0, 190.0, 230.0] # The ending's lines are longer than the shop's
const LINE_TIME := 2.4 # Seconds a line of Tuh-U stays up

var shop_layer: CanvasLayer # Screen-fixed layer above the dimmed world
var card_row: Control
var cards: Array[ShopCard] = []
var detail: ShopDetailPanel
var shop_bubble: ShopBubble
var next_button: UIPanel
var next_arrow: UIArrow
var next_label: Label
var next_tween: Tween
var line_id := 0
var ufo_scale := Vector2.ONE

func _ready():
	_build_shop_ui()

func _build_shop_ui():
	shop_layer = CanvasLayer.new()
	shop_layer.layer = 2 # Above the HUD and the world dim, below the pause menu
	shop_layer.visible = false
	add_child(shop_layer)
	card_row = Control.new()
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_layer.add_child(card_row)
	shop_bubble = ShopBubble.new()
	detail = ShopDetailPanel.new()
	detail.top_y = DETAIL_TOP
	shop_layer.add_child(detail)
	
	next_button = UIPanel.new()
	next_button.size = NEXT_SIZE
	next_button.pivot_offset = NEXT_SIZE * 0.5
	next_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_button.visible = false
	shop_layer.add_child(next_button)
	next_label = Label.new()
	next_label.text = "Next"
	next_label.add_theme_font_override("font", FONT_BOLD)
	next_label.add_theme_font_size_override("font_size", 14)
	next_label.add_theme_constant_override("outline_size", 4)
	next_label.add_theme_color_override("font_outline_color", Color.BLACK)
	next_label.position = Vector2(-NEXT_ARROW_SPACE * 0.5, 0) # Centered between the left edge and the arrow
	next_label.size = NEXT_SIZE
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_button.add_child(next_label)
	next_arrow = UIArrow.new()
	next_arrow.facing = 1
	next_arrow.position = Vector2(NEXT_SIZE.x - 16, NEXT_SIZE.y * 0.5 - 5.5)
	next_button.add_child(next_arrow)
	shop_layer.add_child(shop_bubble) # Last, so it is drawn above the rest

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
	selection_index = clampi(selection_index + direction, 0, cards.size())
	_update_selection_visuals()

func _update_selection_visuals():
	for i in cards.size():
		cards[i].set_selected(i == selection_index)
	
	var is_next := selection_index == cards.size()
	_set_next_selected(is_next)
	if is_next:
		detail.show_next()
	else:
		var card := cards[selection_index]
		detail.show_entry(card.entry, card.quantity)

func _set_next_selected(selected: bool):
	if next_tween:
		next_tween.kill()
	next_tween = create_tween().set_parallel(true)
	var shade := 1.0 if selected else 0.7
	next_tween.tween_property(next_button, "scale", Vector2.ONE * (1.08 if selected else 1.0), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	next_tween.tween_property(next_button, "modulate", Color(shade, shade, shade, 1.0), 0.12)
	next_button.set_highlight(selected, Color.WHITE, 2.0) # Selected containers get a white outline

func _activate_selection():
	if selection_index < cards.size():
		_attempt_purchase(cards[selection_index])
	else:
		await _exit_stop()

func _attempt_purchase(shop_item: ShopCard):
	var data := shop_item.entry
	var actual_cost := _get_modified_price(data.cost)
	
	# Sold out
	if shop_item.quantity <= 0:
		shop_item.shake()
		return
	
	# Cannot afford it
	if PlayerData.currency < actual_cost:
		shop_item.shake()
		_tuhu_says(ShopDialogue.deny())
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
	_spawn_purchase_feedback(shop_item)
	_tuhu_says(ShopDialogue.buy())
	
	shop_item.set_quantity(shop_item.quantity - 1)
	combat_ui.refresh_player_hud()
	_refresh_prices()
	_update_selection_visuals()

# Prices turn red on the cards the player cannot afford (anymore)
func _refresh_prices():
	for card in cards:
		var price := _get_modified_price(card.entry.cost)
		card.set_price(price, PlayerData.currency >= price)

func enter_stop():
	state = State.ENTERING
	ui.visible = true
	shop_layer.visible = true
	_take_ufo()
	combat_manager._world_gray_out(true, true) # The Droid stays undimmed
	
	await _animate_ufo_entry(UFO_SHOP_POS.y)
	await _spawn_cards()
	await _show_next_button()
	selection_index = 0
	_update_selection_visuals()
	
	state = State.ACTIVE
	set_process_input(true)
	_tuhu_says(ShopDialogue.arrival())

func _exit_stop():
	state = State.EXITING
	set_process_input(false)
	line_id += 1
	combat_manager._world_gray_out(false, true) # The world lights up again while the shop leaves
	_hide_line() # Tuh-U's bubble goes away
	_animate_items_out()
	detail.pop_out()
	await _next_button_out()
	await _animate_ufo_exit()
	_stop_ufo_idle()
	_return_ufo()
	
	# Resetting selection and UI for next stage
	selection_index = 0
	shop_layer.visible = false
	
	state = State.INACTIVE
	ui.visible = false
	
	stop_finished.emit()

# Tuh-U moves to the screen-fixed layer for the shop (the world is dimmed behind it), facing the Droid on the left
func _take_ufo():
	ufo_scale = ufo.scale
	ufo.reparent(shop_layer, false)
	ufo.position = Vector2(UFO_SHOP_POS.x, -20)
	ufo.flip_toward_right() # Faces the Droid on the left

# ...and goes back to the stop UI where the demo ending expects him
func _return_ufo():
	ufo.reparent(ui, false)
	ufo.scale = ufo_scale
	ufo.reset_pose()
	ufo.position = UFO_HOME_POS

func _animate_ufo_entry(target_y := 210.0):
	await ufo.glide_in(target_y) # Swoops in, then floats

func _start_ufo_idle():
	ufo.set_hovering(true)

func _stop_ufo_idle():
	ufo.set_hovering(false)

func _animate_ufo_exit():
	await ufo.glide_out()

# Rolls the items and lays the cards out in a centered row
func _spawn_cards():
	var rolled_items: Array = _roll_shop_items()
	var count: int = rolled_items.size()
	if count < 3:
		push_warning("The shop rolled only %d cards." % count) # Should not happen: chips fill missing cards
	var total: float = count * ShopCard.CARD_SIZE.x + maxi(count - 1, 0) * CARD_GAP
	
	# The detail box lines up with a full row of three cards, the Next button sits beside the row
	var row_width: float = 3.0 * ShopCard.CARD_SIZE.x + 2.0 * CARD_GAP
	var row_left: float = SHOP_LEFT
	var start_x: float = row_left + (row_width - total) * 0.5 # A shorter row stays centered
	detail.size = Vector2(DETAIL_WIDTH, ShopDetailPanel.MIN_HEIGHT)
	detail.position.x = row_left + (row_width - DETAIL_WIDTH) * 0.5
	next_button.position = Vector2(detail.position.x + DETAIL_WIDTH + 12.0, DETAIL_TOP + 6.0) # Beside the detail box
	
	for i in count:
		var data: ShopEntry = rolled_items[i]
		var card := ShopCard.new()
		card_row.add_child(card)
		card.position = Vector2(start_x + i * (ShopCard.CARD_SIZE.x + CARD_GAP), CARDS_TOP)
		card.rest_position = card.position
		
		# Generate stack size depending on given item (necessary for chips and maybe other items)
		var stack := randi_range(1, data.max_stack) if data.max_stack > 1 else 1
		var price := _get_modified_price(data.cost)
		card.setup(data, stack, price, PlayerData.currency >= price)
		card.set_selected(false)
		card.pop_in(i * 0.08)
		cards.append(card)
	
	await get_tree().create_timer(0.3 + count * 0.08).timeout

func _animate_items_out():
	for i in cards.size():
		cards[i].pop_out(i * 0.05)
	await get_tree().create_timer(0.3).timeout
	for card in cards:
		card.queue_free()
	cards.clear()

func _show_next_button():
	next_button.visible = true
	next_button.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(next_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

func _next_button_out():
	var tween := create_tween()
	tween.tween_property(next_button, "scale", Vector2.ZERO, 0.2)
	await tween.finished
	next_button.visible = false

# Picks 3 different cards by rarity from the entries the player can actually take; chips fill in if fewer are valid
func _roll_shop_items():
	var valid: Array = ItemDb.get_unlocked_items().filter(_can_take)
	var chosen: Array[ShopEntry] = ItemDb.pick_weighted(valid, 3)
	
	for id in ItemDb.FILLER_IDS:
		if chosen.size() >= 3:
			break
		var filler: ShopEntry = ItemDb.get_item(id)
		if not chosen.has(filler):
			chosen.append(filler)
	
	return chosen

# Whether the player can take a shop entry right now (no owned abilities, no full slots or stacks)
func _can_take(item: ShopEntry) -> bool:
	if item.type == ShopEntry.ItemType.ABILITY and item.ability_data:
		return not PlayerData.has_ability(item.ability_data.id) and not PlayerData.has_max_abilities()
	if item.type == ShopEntry.ItemType.PASSIVE and item.passive_data:
		return not PlayerData.has_ability(item.passive_data.id) and not PlayerData.has_max_abilities()
	if item.type == ShopEntry.ItemType.ITEM and item.item_data:
		return PlayerData.can_add_item(item.item_data, 1)
	return true

# Tuh-U says a short line in his bubble without blocking the shop; a new line replaces the old one
func _tuhu_says(line: Dictionary):
	line_id += 1
	var id := line_id
	match line["mood"]:
		"happy":
			ufo.play_happy()
		"sad":
			ufo.play_sad()
		_:
			ufo.play_normal()
	shop_bubble.say(line["text"], ufo.global_position + Vector2(0, -22))
	await get_tree().create_timer(LINE_TIME + line["text"].length() * 0.02).timeout
	if id == line_id and state == State.ACTIVE:
		_hide_line()

func _hide_line():
	shop_bubble.hide_bubble()

func _spawn_purchase_feedback(shop_item: ShopCard):
	var at := shop_item.global_position + Vector2(ShopCard.CARD_SIZE.x * 0.5 - 20, -8)
	ActionFeedback.show(HitFeedbackScene, shop_layer, at, ActionFeedback.Tier.PURCHASE, false)

func _get_modified_price(base_cost: int) -> int:
	return base_cost + PlayerData.get_shop_price_increase()

func _spawn_inventory_full_feedback(shop_item: ShopCard, message: String):
	var feedback := HitFeedbackScene.instantiate()
	shop_layer.add_child(feedback)
	feedback.rotation_degrees = randf_range(-3, 3)
	feedback.global_position = shop_item.global_position + Vector2(ShopCard.CARD_SIZE.x * 0.5 - 30, -8)
	feedback.play(message)

# ENDING METHODS
# Tuh-U's ending dialogue uses the same pixel bubble as the shop, above him and growing to the right, waiting for Confirm after each line
func say(text: String, mood := "normal"):
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
	
	var ufo_screen: Vector2 = ufo.get_global_transform_with_canvas().origin
	shop_bubble.configure(ufo_screen + Vector2(-16, -36), true, ENDING_WIDTHS)
	await shop_bubble.say_and_wait(text, ufo_screen + Vector2(0, -20))


func end_say():
	shop_bubble.hide_bubble()
	shop_bubble.configure(ShopBubble.ANCHOR) # Back to the shop's place


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
	
	# Only the speech bubble of the shop layer is used (no cards, box or Next button)
	shop_layer.visible = true
	detail.visible = false
	next_button.visible = false
	
	await _animate_ufo_entry()
	await move_ufo_to(UFO_ENDING_POS, 0.8)
	
	await _play_demo_ending_dialogue()
	
	set_process_input(false)
	
	end_say()
	await get_tree().create_timer(0.25).timeout
	await move_ufo_to(UFO_STOP_POS, 0.5)
	
	state = State.INACTIVE
	ui.visible = false
	shop_layer.visible = false
	detail.visible = true
	
	demo_ending_finished.emit()

func _play_demo_ending_dialogue():
	camera.follow(player_visual)
	player_visual.hide_hp()
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
