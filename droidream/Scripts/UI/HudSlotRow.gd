extends Control
class_name HudSlotRow

# One row of the top-left HUD: a small header icon and framed slots (filled slots show what the player owns, empty slots show what is left up to the cap)

const SLOT_SIZE := 24 # Smallest size the UIPanel template can be
const ICON_SIZE := 16
const HEADER_ICON_SIZE := 32 # Row icon, as big as the gear menu icons
const ROW_HEIGHT := 32
const SLOT_GAP := 2
const HEADER_WIDTH := 36
const POPUP_HOLD := 1.2
const COUNT_FONT_SIZE := 12 # Stack counts are smaller than the 16 px text
const HOP_PIXELS := 3.0
const EMPTY_STYLE_BASE := Color(0.16, 0.16, 0.16)

@export var preset := UIPanel.Preset.ABILITY
@export var header_icon: Texture2D
@export var cap := 6
@export var popup_color := Color("#d7ffd0")

var slots: Array[UIPanel] = []
var icons: Array[TextureRect] = []
var counts: Array[Label] = []
var popup: Label
var popup_tween: Tween
var known := {} # id -> count from the last update, to find what changed
var has_baseline := false

func _ready() -> void:
	var header := TextureRect.new()
	header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # Before the texture, so its own size does not set the minimum
	header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.texture = header_icon
	header.custom_minimum_size = Vector2(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
	header.size = Vector2(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
	header.position = Vector2.ZERO
	add_child(header)
	
	for i in cap:
		var slot := UIPanel.new()
		slot.preset = preset
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.position = Vector2(HEADER_WIDTH + i * (SLOT_SIZE + SLOT_GAP), (ROW_HEIGHT - SLOT_SIZE) / 2)
		add_child(slot)
		slots.append(slot)
		
		var icon := TextureRect.new()
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.position = Vector2((SLOT_SIZE - ICON_SIZE) / 2, (SLOT_SIZE - ICON_SIZE) / 2)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)
		icons.append(icon)
		
		var count := Label.new()
		count.size = Vector2(SLOT_SIZE, 13)
		count.position = Vector2(1, SLOT_SIZE - 13)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_override("font", UIRow.FONT)
		count.add_theme_font_size_override("font_size", COUNT_FONT_SIZE)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 3)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)
		counts.append(count)
	
	var row_width := HEADER_WIDTH + cap * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	custom_minimum_size = Vector2(row_width, ROW_HEIGHT)
	size = custom_minimum_size
	
	popup = Label.new()
	popup.position = Vector2(row_width + 8, (ROW_HEIGHT - 16) / 2)
	popup.add_theme_font_override("font", UIRow.FONT)
	popup.add_theme_font_size_override("font_size", UIRow.FONT_SIZE)
	popup.add_theme_color_override("font_color", popup_color)
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_constant_override("outline_size", 4)
	popup.modulate.a = 0.0
	add_child(popup)
	
	_show_entries([])

# Shows the given entries (Dictionaries with id, name, icon and count); changes since the last call pop and show a name popup
func set_entries(entries: Array, announce := true) -> void:
	if slots.is_empty():
		await ready
	var changes: Array[String] = []
	var changed_slots: Array[int] = []
	var now := {}
	for i in entries.size():
		var entry: Dictionary = entries[i]
		now[entry.id] = entry.count
		var before: int = known.get(entry.id, 0)
		if has_baseline and entry.count != before:
			changed_slots.append(i)
			changes.append(("+ " if entry.count > before else "- ") + entry.name)
	if has_baseline:
		for id in known:
			if not now.has(id):
				changes.append("- " + str(id).capitalize())
	known = now
	has_baseline = true
	
	_show_entries(entries)
	if announce and visible and is_visible_in_tree():
		for i in changed_slots:
			_hop(icons[i])
		if not changes.is_empty():
			_show_popup(changes[0])

func _show_entries(entries: Array) -> void:
	for i in cap:
		var filled := i < entries.size()
		slots[i].style = null if filled else UIPanelStyle.from_base(EMPTY_STYLE_BASE)
		slots[i].modulate.a = 1.0 if filled else 0.55
		icons[i].texture = entries[i].icon if filled else null
		var amount: int = entries[i].count if filled else 0
		counts[i].text = "x%d" % amount
		counts[i].visible = amount > 1 # Only stackable entries show a count

# A short whole-pixel hop of an icon (no scaling, so pixels stay crisp)
func _hop(icon: TextureRect) -> void:
	var rest := (SLOT_SIZE - ICON_SIZE) / 2.0
	var tween := create_tween()
	tween.tween_method(func(t: float): icon.position.y = rest - roundf(HOP_PIXELS * sin(t * PI)), 0.0, 1.0, 0.25)

# Slides a name out beside the row, holds, then fades
func _show_popup(text: String) -> void:
	if popup_tween:
		popup_tween.kill()
	popup.text = text
	var rest_x := popup.position.x
	popup.position.x = rest_x - 8
	popup.modulate.a = 0.0
	popup_tween = create_tween()
	popup_tween.tween_property(popup, "position:x", rest_x, 0.15)
	popup_tween.parallel().tween_property(popup, "modulate:a", 1.0, 0.15)
	popup_tween.tween_interval(POPUP_HOLD)
	popup_tween.tween_property(popup, "modulate:a", 0.0, 0.3)
