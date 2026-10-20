extends Control
class_name ShopDetailPanel

# The box under the shop cards: the name (with an ability's cooldown next to it), then the description at a readable size (the type and the price are on the cards); it grows downward to fit long text

const FONT := preload("res://Graphics/Fonts/PixelOperator.ttf")
const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const MIN_HEIGHT := 44.0
const DESC_SIZE := 14 # Large like the boon selection; the panel gets taller instead of shrinking the text
const PADDING := 8.0
const HEADER_HEIGHT := 24.0
const UNAFFORDABLE_COLOR := Color("#ff5a5a")

var panel: UIPanel
var name_label: Label
var type_label: Label
var desc: RichTextLabel
var top_y := 190.0 # The panel's top edge stays here
var tween: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = UIPanel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	name_label = _label(FONT_BOLD, 20, 4, HORIZONTAL_ALIGNMENT_LEFT)
	type_label = _label(FONT_BOLD, 10, 3, HORIZONTAL_ALIGNMENT_LEFT)
	desc = RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.scroll_active = false
	desc.fit_content = true
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_font_override("normal_font", FONT)
	desc.add_theme_font_size_override("normal_font_size", DESC_SIZE)
	desc.add_theme_constant_override("outline_size", 3)
	desc.add_theme_constant_override("line_separation", -2)
	desc.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(desc)

func _label(font: Font, font_size: int, outline: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

# Shows the selected entry
func show_entry(entry: ShopEntry, quantity: int) -> void:
	panel.style = ShopCard.style_for(entry)
	name_label.text = entry.display_name
	var type_text := ""
	var type_color := Color(0.9, 0.9, 0.9)
	if entry.type == ShopEntry.ItemType.ABILITY and entry.ability_data:
		type_text = "COOLDOWN %d" % entry.ability_data.cooldown_max
	if quantity <= 0:
		type_text = "SOLD OUT"
		type_color = UNAFFORDABLE_COLOR
	type_label.text = type_text
	type_label.add_theme_color_override("font_color", type_color)
	desc.text = entry.description
	_layout()
	_pop()

# "Next" is selected: leave for the next stage
func show_next() -> void:
	panel.style = UIPanelStyle.default_style()
	name_label.text = "Next encounter"
	type_label.text = ""
	desc.text = "Leave the shop and head to the next encounter."
	_layout()
	_pop()

# Sizes the panel to its text and keeps its top edge in place
func _layout(width := -1.0) -> void:
	if width > 0.0:
		size.x = width
	var inner := size.x - PADDING * 2.0
	desc.position = Vector2(PADDING, PADDING + HEADER_HEIGHT)
	desc.size = Vector2(inner, 0)
	var desc_height := maxf(desc.get_content_height(), DESC_SIZE + 2.0)
	var height := maxf(MIN_HEIGHT, desc.position.y + desc_height + PADDING)
	panel.size = Vector2(size.x, height)
	size.y = height
	position.y = top_y
	# The name, with the small note (cooldown or sold out) right next to it, on the same row
	name_label.position = Vector2(PADDING, PADDING - 2)
	var name_width := name_label.get_minimum_size().x
	name_label.size = Vector2(name_width, HEADER_HEIGHT)
	type_label.position = Vector2(PADDING + name_width + 8.0, PADDING - 2)
	type_label.size = Vector2(inner - name_width - 8.0, HEADER_HEIGHT)

# Shrinks away when the shop closes
func pop_out() -> void:
	if tween:
		tween.kill()
	pivot_offset = size * 0.5
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 0.0), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)

func _pop() -> void:
	if tween:
		tween.kill()
	modulate.a = 1.0
	pivot_offset = size * 0.5
	scale = Vector2(1.0, 0.94)
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
