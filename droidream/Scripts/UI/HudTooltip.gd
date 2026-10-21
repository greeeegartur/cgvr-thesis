extends CanvasLayer
class_name HudTooltip

# The description box that follows the mouse cursor while it rests on a HUD element (ability, item, stat or the heart); the element hands in a function that returns its
# current texts, so the box also updates while it is open

const FONT := preload("res://Graphics/Fonts/PixelOperator.ttf")
const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const MIN_WIDTH := 70.0
const MAX_WIDTH := 150.0 # Longer descriptions wrap at this width
const OFFSET := Vector2(14.0, 14.0) # From the cursor to the box's corner
const SHOW_DELAY := 0.12 # Seconds the cursor rests before the box appears
const TITLE_HEIGHT := 16.0
const PADDING := Vector2(11.0, 9.0) # Space between the border and the text
const DESC_SIZE := 14
const DETAIL_HEIGHT := 13.0

static var instance: HudTooltip
static var gate: Callable # Returns whether tooltips may show right now (only during the player turn and the shop)

var source: CanvasItem # The element the box belongs to (null while closed)
var preset := UIPanel.Preset.DEFAULT # The panel color: abilities and items use the colors of their combat menu panels
var provider: Callable # Returns [title, description, detail] (an empty array means nothing to show)
var hover_time := 0.0
var shown_texts := []
var panel: UIPanel
var title_label: Label
var desc: RichTextLabel
var detail_label: Label

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self
	
	panel = UIPanel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	add_child(panel)
	
	title_label = Label.new()
	title_label.add_theme_font_override("font", FONT_BOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_label)
	
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
	panel.add_child(desc)
	
	detail_label = Label.new()
	detail_label.add_theme_font_override("font", FONT)
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_constant_override("outline_size", 3)
	detail_label.add_theme_color_override("font_outline_color", Color.BLACK)
	detail_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(detail_label)

func _exit_tree() -> void:
	if instance == self:
		instance = null

# The cursor entered an element: the box opens for it after a short rest
static func show_tip(from: CanvasItem, tip_provider: Callable, panel_preset := UIPanel.Preset.DEFAULT) -> void:
	if instance == null:
		return
	instance.source = from
	instance.provider = tip_provider
	instance.preset = panel_preset
	instance.panel.preset = panel_preset
	instance.hover_time = 0.0
	instance.shown_texts = []

# The cursor left the element (ignored if another element already took over)
static func hide_tip(from: CanvasItem) -> void:
	if instance != null and instance.source == from:
		instance._close()

func _close() -> void:
	source = null
	panel.visible = false
	shown_texts = []

func _process(delta: float) -> void:
	if source == null:
		return
	if not is_instance_valid(source) or not source.is_visible_in_tree() or PauseMenu.active or _is_faded(source) or (gate.is_valid() and not gate.call()):
		_close()
		return
	
	var texts: Array = provider.call()
	if texts.is_empty():
		_close()
		return
	
	hover_time += delta
	if hover_time < SHOW_DELAY:
		return
	if texts != shown_texts:
		shown_texts = texts
		_fill(texts)
	panel.visible = true
	_follow_cursor()

# True while the element (or something above it) is faded out, like the HUD between screens
func _is_faded(node: CanvasItem) -> bool:
	var current: Node = node
	while current != null:
		if current is CanvasItem and current.modulate.a < 0.5:
			return true
		current = current.get_parent()
	return false

# Fills the labels and sizes the panel tightly around its text
func _fill(texts: Array) -> void:
	title_label.text = texts[0]
	desc.text = texts[1]
	detail_label.text = texts[2] if texts.size() > 2 else ""
	detail_label.visible = detail_label.text != ""
	
	# As wide as its longest line, up to a maximum (longer descriptions wrap)
	var longest := maxf(title_label.get_minimum_size().x, detail_label.get_minimum_size().x if detail_label.visible else 0.0)
	var desc_width := FONT.get_string_size(desc.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, DESC_SIZE).x + 2.0
	var inner := ceilf(clampf(maxf(longest, desc_width), MIN_WIDTH, MAX_WIDTH))
	
	var origin := PADDING
	title_label.position = origin
	title_label.size = Vector2(inner, TITLE_HEIGHT)
	var y := TITLE_HEIGHT
	desc.position = origin + Vector2(0.0, y)
	desc.size = Vector2(inner, 0.0)
	if desc.text != "":
		y += maxf(desc.get_content_height(), DESC_SIZE + 2.0)
	if detail_label.visible:
		detail_label.position = origin + Vector2(0.0, y)
		detail_label.size = Vector2(inner, DETAIL_HEIGHT)
		y += DETAIL_HEIGHT
	panel.size = Vector2(inner, y) + PADDING * 2.0

# Puts the box beside the cursor, flipped and clamped so it stays fully on the screen
func _follow_cursor() -> void:
	var screen := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var spot := mouse + OFFSET
	if spot.x + panel.size.x > screen.x:
		spot.x = mouse.x - OFFSET.x - panel.size.x
	if spot.y + panel.size.y > screen.y:
		spot.y = mouse.y - OFFSET.y - panel.size.y
	panel.position = Vector2(clampf(spot.x, 0.0, maxf(screen.x - panel.size.x, 0.0)), clampf(spot.y, 0.0, maxf(screen.y - panel.size.y, 0.0))).round()
