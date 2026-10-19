extends NinePatchRect
class_name UIPanel

# Reusable panel: one 9-slice template recolored by a style, so it can be any size and any color; the optional tail adds a pointer on the left

enum Preset { DEFAULT, ABILITY, ITEM, TAME }

const TEMPLATE := preload("res://Graphics/Sprites/UI/defaultMenuStyleBox.png")
const TAIL_TEMPLATE := preload("res://Graphics/Sprites/UI/listInfoContainer.png")
const SHADER := preload("res://Scenes/UI/UIPanel.gdshader")
const OUTLINE_SHADER := preload("res://Scenes/UI/UIPanelOutline.gdshader")
const NO_COLOR := Color(0, 0, 0, 0) # A source color the template does not have

# Source colors of each template (the art itself is never edited)
const TEMPLATE_COLORS := [Color8(85, 85, 85), Color8(129, 129, 129), Color8(58, 58, 58), Color8(115, 115, 115)]
const TAIL_TEMPLATE_COLORS := [Color8(141, 141, 141), Color8(104, 104, 104), NO_COLOR, NO_COLOR]

@export var preset := Preset.DEFAULT:
	set(value):
		preset = value
		_apply()
@export var style: UIPanelStyle: # Overrides the preset when set
	set(value):
		style = value
		_apply()
@export var with_tail := false: # Pointer on the left edge, 16 px below the top
	set(value):
		with_tail = value
		_apply()

# Space between the panel edge and its content (the 9-slice margins plus a little breathing room)
var content_padding := Vector4(12, 12, 12, 12) # left, top, right, bottom

var highlight: NinePatchRect # Solid copy drawn slightly larger behind the panel
var highlight_width := 2.0

func _ready() -> void:
	resized.connect(_sync_highlight)
	_apply()

# Applies template, margins and recolor material
func _apply() -> void:
	if not is_inside_tree():
		return
	texture = TAIL_TEMPLATE if with_tail else TEMPLATE
	if with_tail:
		patch_margin_left = 10
		patch_margin_top = 15
		patch_margin_right = 3
		patch_margin_bottom = 15
		content_padding = Vector4(14, 12, 8, 12)
	else:
		patch_margin_left = 12
		patch_margin_top = 12
		patch_margin_right = 12
		patch_margin_bottom = 12
		content_padding = Vector4(12, 12, 12, 12)
	
	var colors := get_style()
	var source: Array = TAIL_TEMPLATE_COLORS if with_tail else TEMPLATE_COLORS
	var mat := material as ShaderMaterial
	if mat == null or mat.shader != SHADER:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		material = mat
	mat.set_shader_parameter("src_fill", source[0])
	mat.set_shader_parameter("src_ring", source[1])
	mat.set_shader_parameter("src_dark", source[2])
	mat.set_shader_parameter("src_light", source[3])
	mat.set_shader_parameter("dst_fill", colors.fill)
	mat.set_shader_parameter("dst_ring", colors.ring)
	mat.set_shader_parameter("dst_dark", colors.mark_dark)
	mat.set_shader_parameter("dst_light", colors.mark_light)
	_sync_highlight()

# The style in use: the custom style if set, otherwise the preset
func get_style() -> UIPanelStyle:
	if style:
		return style
	match preset:
		Preset.ABILITY:
			return UIPanelStyle.ability_style()
		Preset.ITEM:
			return UIPanelStyle.item_style()
		Preset.TAME:
			return UIPanelStyle.tame_style()
	return UIPanelStyle.default_style()

# Top-left corner where content starts, relative to the panel
func content_origin() -> Vector2:
	return Vector2(content_padding.x, content_padding.y)

# Resizes the panel so that content of the given size fits inside it
func fit_to(content_size: Vector2) -> void:
	size = content_size + Vector2(content_padding.x + content_padding.z, content_padding.y + content_padding.w)

# Shows or hides a highlight outline around the whole panel (used for the selected card)
func set_highlight(on: bool, color := Color("#fff27a"), width := 2.0) -> void:
	highlight_width = width
	if on and highlight == null:
		highlight = NinePatchRect.new()
		highlight.show_behind_parent = true
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		highlight.material = mat
		add_child(highlight)
	if highlight:
		highlight.visible = on
		(highlight.material as ShaderMaterial).set_shader_parameter("outline_color", color)
		_sync_highlight()

# Keeps the highlight copy the same art and margins as the panel, a few pixels larger
func _sync_highlight() -> void:
	if highlight == null:
		return
	highlight.texture = texture
	highlight.patch_margin_left = patch_margin_left
	highlight.patch_margin_top = patch_margin_top
	highlight.patch_margin_right = patch_margin_right
	highlight.patch_margin_bottom = patch_margin_bottom
	highlight.position = Vector2(-highlight_width, -highlight_width)
	highlight.size = size + Vector2(highlight_width, highlight_width) * 2.0

# Flashes the panel's bright parts and every child that uses its material toward white (0..1)
func set_flash(amount: float) -> void:
	if material:
		(material as ShaderMaterial).set_shader_parameter("flash", amount)
