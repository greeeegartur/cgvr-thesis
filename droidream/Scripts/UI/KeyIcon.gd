extends Control
class_name KeyIcon

# A keyboard key picture from a two-frame sheet (up, pressed), cropped to its art so it sits well in a line of text

var key_name := ""
var frames: Array[AtlasTexture] = []
var pressed := false
var icon_scale_value := 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# Loads the sheet of a key (Z, X, C or ARROWS) and crops both frames to the same art rectangle; icon_scale 1 or 2 keeps pixels crisp; other values are only for small icons
func setup(key: String, icon_scale: float = 1.0) -> void:
	key_name = key
	icon_scale_value = icon_scale
	if not Settings.controls_changed.is_connected(_refresh):
		Settings.controls_changed.connect(_refresh) # The picture follows the control scheme
	var sheet: Texture2D = ControlTextures.sheet(key)
	var frame_height := sheet.get_height() / 2
	var image := sheet.get_image()
	var used := Rect2i()
	for i in 2:
		var frame_rect := Rect2i(0, i * frame_height, sheet.get_width(), frame_height)
		var frame_used := image.get_region(frame_rect).get_used_rect() # Relative to the frame
		used = frame_used if i == 0 else used.merge(frame_used)
	
	# The same crop on both frames, so pressing does not move the key
	frames.clear()
	for i in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(used.position.x, used.position.y + i * frame_height, used.size.x, used.size.y)
		frames.append(atlas)
	custom_minimum_size = Vector2(used.size) * icon_scale
	size = custom_minimum_size
	queue_redraw()

func _refresh() -> void:
	if key_name != "":
		setup(key_name, icon_scale_value)

func set_pressed(value: bool) -> void:
	if value != pressed:
		pressed = value
		queue_redraw()

func _draw() -> void:
	if not frames.is_empty():
		draw_texture_rect(frames[1 if pressed else 0], Rect2(Vector2.ZERO, size), false)
