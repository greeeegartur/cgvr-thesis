extends Control
class_name KeyIcon

# A keyboard key picture from a two-frame sheet (up, pressed), cropped to its art so it sits well in a line of text

const SHEETS := {
	"Z": preload("res://Graphics/Sprites/UI/Z.png"),
	"X": preload("res://Graphics/Sprites/UI/X.png"),
	"C": preload("res://Graphics/Sprites/UI/C.png"),
	"ARROWS": preload("res://Graphics/Sprites/UI/WASD.png")
}

var key_name := ""
var frames: Array[AtlasTexture] = []
var pressed := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# Loads the sheet of a key (Z, X, C or ARROWS) and crops both frames to the same art rectangle; icon_scale 1 or 2 keeps pixels crisp; other values are only for small icons
func setup(key: String, icon_scale: float = 1.0) -> void:
	key_name = key
	var sheet: Texture2D = SHEETS[key]
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

func set_pressed(value: bool) -> void:
	if value != pressed:
		pressed = value
		queue_redraw()

func _draw() -> void:
	if not frames.is_empty():
		draw_texture_rect(frames[1 if pressed else 0], Rect2(Vector2.ZERO, size), false)
