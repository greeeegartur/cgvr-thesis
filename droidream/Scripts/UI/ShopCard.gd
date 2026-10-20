extends Control
class_name ShopCard

# One item in the shop: icon, type, stack count and price on a recolored panel (the name is in the detail box); the selected card lifts, glows and shows arrows

const CARD_SIZE := Vector2(104, 92)
const FONT := preload("res://Graphics/Fonts/PixelOperator.ttf")
const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const PRICE_SIZE := 18 # The bolt and the price number are this tall
const BOLT := preload("res://Graphics/Sprites/VFX/bolt.png")
const ICON_BOX := 38.0 # The icon is the card's main picture; the name is in the box below
const PLATE_SIZE := Vector2(62, 46)
const PLATE_Y := 20.0
const TYPE_CENTER_Y := 7.0 # Halfway between the top edge of the card and the plate
const PRICE_CENTER_Y := 76.0 # Halfway between the bottom of the plate (66) and the bottom edge of the card (92)
const LIFT := 5.0 # Pixels the selected card rises
const SELECTED_SCALE := 1.06
const DIM := 0.6 # Brightness of the cards that are not selected
const ARROW_BOB := 4.0
const TYPE_COLORS := {
	ShopEntry.ItemType.ABILITY: Color("#a6ffb0"),
	ShopEntry.ItemType.PASSIVE: Color("#ebb0ff"),
	ShopEntry.ItemType.ITEM: Color("#a8f0ff"),
}
const PRICE_COLOR := Color.WHITE
const UNAFFORDABLE_COLOR := Color("#ff5a5a")

var entry: ShopEntry
var quantity := 1
var panel: UIPanel
var icon: TextureRect
var chip_label: Label # The type, as the header
var count_label: Label # The stack count on the icon plate
var plate: ColorRect
var price_label: Label
var bolt: TextureRect
var arrows: Array[UIArrow] = []
var rest_position := Vector2.ZERO
var selected := false
var move_tween: Tween
var arrow_tween: Tween

func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = UIPanel.new()
	panel.size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	
	# A light plate behind the icon makes every icon readable, whatever the panel color
	plate = ColorRect.new()
	plate.color = Color(1, 1, 1, 0.16)
	plate.size = PLATE_SIZE
	plate.position = Vector2((CARD_SIZE.x - PLATE_SIZE.x) * 0.5, PLATE_Y)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	icon = TextureRect.new()
	icon.position = Vector2((CARD_SIZE.x - ICON_BOX) * 0.5, PLATE_Y + (PLATE_SIZE.y - ICON_BOX) * 0.5)
	icon.size = Vector2(ICON_BOX, ICON_BOX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(icon)
	
	# The type is the header, centered above the plate (the price below it is centered the same way)
	chip_label = _make_label(FONT_BOLD, 12, 3)
	chip_label.size = Vector2(CARD_SIZE.x - 8, 16)
	chip_label.position = Vector2(4, TYPE_CENTER_Y - 8)
	chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(chip_label)
	# The stack count sits on the plate's bottom-right corner; a sold out card gets it centered on the plate
	count_label = _make_label(FONT_BOLD, 12, 4)
	add_child(count_label)
	
	# The bolt and the price sit on one line under the name, the same height and on the same axis
	bolt = TextureRect.new()
	bolt.texture = BOLT
	bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bolt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bolt.size = Vector2(PRICE_SIZE, PRICE_SIZE)
	bolt.position.y = PRICE_CENTER_Y - PRICE_SIZE * 0.5
	add_child(bolt)
	price_label = _make_label(FONT_BOLD, PRICE_SIZE, 4)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.size = Vector2(40, PRICE_SIZE + 6)
	price_label.position.y = PRICE_CENTER_Y - (PRICE_SIZE + 6) * 0.5
	add_child(price_label)
	
	for facing in [1, -1]: # Left arrow points right (at the card), right arrow points left
		var arrow := UIArrow.new()
		arrow.facing = facing
		arrow.visible = false
		add_child(arrow)
		arrows.append(arrow)
	_place_arrows(0.0)

func _make_label(font: Font, font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func setup(data: ShopEntry, stack: int, price: int, affordable: bool) -> void:
	entry = data
	panel.style = style_for(data)
	icon.texture = data.icon
	set_quantity(stack)
	set_price(price, affordable)

# Panel colors by what the entry is
static func style_for(data: ShopEntry) -> UIPanelStyle:
	match data.type:
		ShopEntry.ItemType.ABILITY:
			return UIPanelStyle.ability_style()
		ShopEntry.ItemType.PASSIVE:
			return UIPanelStyle.from_base(Color("#7a3a9a"))
	return UIPanelStyle.item_style()

# The word for the type: Ability, Passive or Item (chips are items)
static func type_name(data: ShopEntry) -> String:
	match data.type:
		ShopEntry.ItemType.ABILITY:
			return "Ability"
		ShopEntry.ItemType.PASSIVE:
			return "Passive"
	return "Item" # Chips are items too

func set_quantity(stack: int) -> void:
	quantity = stack
	chip_label.text = type_name(entry).to_upper()
	chip_label.add_theme_color_override("font_color", TYPE_COLORS[entry.type])
	var plate_pos := plate.position
	if stack <= 0:
		count_label.text = "SOLD OUT"
		count_label.add_theme_color_override("font_color", UNAFFORDABLE_COLOR)
		count_label.position = Vector2(plate_pos.x, plate_pos.y + (PLATE_SIZE.y - 16.0) * 0.5)
		count_label.size = Vector2(PLATE_SIZE.x, 16)
		icon.modulate.a = 0.35
		return
	icon.modulate.a = 1.0
	count_label.text = "x%d" % stack if entry.max_stack > 1 else ""
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.position = Vector2(plate_pos.x + PLATE_SIZE.x - 36.0, plate_pos.y + PLATE_SIZE.y - 15.0)
	count_label.size = Vector2(34, 14)

func set_price(price: int, affordable: bool) -> void:
	price_label.text = str(price)
	# Center bolt + number as one group under the name
	var text_width := price_label.get_minimum_size().x
	var group := PRICE_SIZE + 2.0 + text_width
	bolt.position.x = (CARD_SIZE.x - group) * 0.5
	price_label.position.x = bolt.position.x + PRICE_SIZE + 2.0
	price_label.add_theme_color_override("font_color", PRICE_COLOR if affordable else UNAFFORDABLE_COLOR)

# Selected: rises, grows, gets a bright frame and bobbing arrows; the others dim
func set_selected(on: bool) -> void:
	selected = on
	if move_tween:
		move_tween.kill()
	move_tween = create_tween().set_parallel(true)
	move_tween.tween_property(self, "position:y", rest_position.y - (LIFT if on else 0.0), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "scale", Vector2.ONE * (SELECTED_SCALE if on else 1.0), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shade := 1.0 if on else DIM
	move_tween.tween_property(self, "modulate", Color(shade, shade, shade, 1.0), 0.12)
	panel.set_highlight(on, Color.WHITE, 2.0)
	z_index = 1 if on else 0
	for arrow in arrows:
		arrow.visible = on
	if arrow_tween:
		arrow_tween.kill()
		arrow_tween = null
	if on:
		arrow_tween = create_tween().set_loops()
		arrow_tween.tween_method(_place_arrows, 0.0, 1.0, SelectionPulse.BEAT * 0.5)
		arrow_tween.tween_method(_place_arrows, 1.0, 0.0, SelectionPulse.BEAT * 0.5)

# The arrows sit beside the card and nudge toward it on the beat (whole pixels)
func _place_arrows(amount: float) -> void:
	var nudge := roundf(amount * ARROW_BOB)
	arrows[0].position = Vector2(-11 + nudge, CARD_SIZE.y * 0.5 - 5)
	arrows[1].position = Vector2(CARD_SIZE.x + 4 - nudge, CARD_SIZE.y * 0.5 - 5)

func shake() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:x", rest_position.x + 6, 0.05)
	tween.tween_property(self, "position:x", rest_position.x - 6, 0.05)
	tween.tween_property(self, "position:x", rest_position.x, 0.05)

# A quick squash, a white flash and a settle back to the selected size
func confirm_purchase() -> void:
	panel.set_flash(1.0)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE * SELECTED_SCALE, 0.14).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_method(panel.set_flash, 1.0, 0.0, 0.2)

func pop_in(delay: float) -> void:
	scale = Vector2.ZERO
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_delay(delay)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.12).set_delay(delay)

func pop_out(delay: float) -> void:
	if move_tween:
		move_tween.kill()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_delay(delay)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(delay)
