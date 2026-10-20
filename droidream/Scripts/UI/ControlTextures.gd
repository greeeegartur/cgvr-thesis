extends RefCounted
class_name ControlTextures

# The key pictures for the control scheme in use: the arrows, Z, X and C by default; with the WASD scheme the W A S D cluster and U, I and O,
# built from the keyboard sheet and lined up exactly like the original pictures (no new art files). The custom scheme shows the defaults.

const KEYBOARD := preload("res://Graphics/Sprites/UI/keyboard_letters_and_symbols.png")
const DEFAULTS := {
	"Z": preload("res://Graphics/Sprites/UI/Z.png"),
	"X": preload("res://Graphics/Sprites/UI/X.png"),
	"C": preload("res://Graphics/Sprites/UI/C.png"),
	"ARROWS": preload("res://Graphics/Sprites/UI/WASD.png"), # The file is called WASD but it holds the arrow keys
}
const PATHS := {
	"res://Graphics/Sprites/UI/Z.png": "Z",
	"res://Graphics/Sprites/UI/X.png": "X",
	"res://Graphics/Sprites/UI/C.png": "C",
	"res://Graphics/Sprites/UI/WASD.png": "ARROWS",
}
const WASD_LETTER := { "Z": "U", "X": "I", "C": "O" } # Confirm, Cancel and Turn order in the WASD scheme
const CELL := 16 # Size of one key cell on the keyboard sheet
const PRESSED_ROW_OFFSET := 7 # The pressed keys are the same rows lower on the sheet
const KEY_SIZE := Vector2i(13, 12)
const SHEET_LAYOUT := { # frame size, where the key sits in a frame, for the single keys
	"Z": { "frame": Vector2i(32, 32), "origin": Vector2i(9, 10) },
	"X": { "frame": Vector2i(13, 12), "origin": Vector2i(0, 0) },
	"C": { "frame": Vector2i(13, 12), "origin": Vector2i(0, 0) },
}
const CLUSTER_FRAME := Vector2i(39, 26)
const CLUSTER_KEYS := { "W": Vector2i(13, 0), "A": Vector2i(0, 12), "S": Vector2i(13, 12), "D": Vector2i(26, 12) } # Same places as the arrow keys

static var cache := {}

# The two-frame sheet (up, pressed) of a key (Z, X, C or ARROWS) for the scheme in use
static func sheet(key: String) -> Texture2D:
	if Settings.controls_scheme != "wasd":
		return DEFAULTS[key]
	if not cache.has(key):
		cache[key] = _build(key)
	return cache[key]

# Swaps the control pictures of every sprite under a node to the scheme in use (also back to the defaults)
static func swap_in(node: Node) -> void:
	for child in node.get_children():
		swap_in(child)
	if not ("texture" in node):
		return
	var current = node.get("texture")
	if not (current is Texture2D):
		return
	var key: String = node.get_meta("control_key") if node.has_meta("control_key") else PATHS.get(current.resource_path, "")
	if key == "":
		return
	node.set_meta("control_key", key)
	node.set("texture", sheet(key))

# BUILDING THE WASD SHEETS
static func _build(key: String) -> Texture2D:
	if key == "ARROWS":
		return _build_cluster()
	var layout: Dictionary = SHEET_LAYOUT[key]
	var frame: Vector2i = layout["frame"]
	var origin: Vector2i = layout["origin"]
	var image := Image.create(frame.x, frame.y * 2, false, Image.FORMAT_RGBA8)
	var letter: String = WASD_LETTER[key]
	image.blit_rect(_tile(letter, false), Rect2i(Vector2i.ZERO, KEY_SIZE), origin)
	image.blit_rect(_tile(letter, true), Rect2i(Vector2i.ZERO, KEY_SIZE), origin + Vector2i(0, frame.y + 1)) # Pressed: one pixel lower
	return ImageTexture.create_from_image(image)

static func _build_cluster() -> Texture2D:
	var image := Image.create(CLUSTER_FRAME.x, CLUSTER_FRAME.y * 2, false, Image.FORMAT_RGBA8)
	for letter in CLUSTER_KEYS:
		var at: Vector2i = CLUSTER_KEYS[letter]
		image.blit_rect(_tile(letter, false), Rect2i(Vector2i.ZERO, KEY_SIZE), at)
		image.blit_rect(_tile(letter, true), Rect2i(Vector2i.ZERO, KEY_SIZE), at + Vector2i(0, CLUSTER_FRAME.y + 1))
	return ImageTexture.create_from_image(image)

# One key picture from the keyboard sheet (cropped to its art, padded to the common key size so pressed keys, which are a pixel lower, keep their place)
static func _tile(letter: String, pressed: bool) -> Image:
	var index := letter.unicode_at(0) - "A".unicode_at(0)
	var row := 2 + index / 8 + (PRESSED_ROW_OFFSET if pressed else 0)
	var cell := KEYBOARD.get_image().get_region(Rect2i((index % 8) * CELL, row * CELL, CELL, CELL))
	var used := cell.get_used_rect()
	var tile := Image.create(KEY_SIZE.x, KEY_SIZE.y, false, Image.FORMAT_RGBA8)
	tile.blit_rect(cell, used, Vector2i.ZERO)
	if pressed: # The sheet's pressed keys have blue letters; the arrows, Z, X and C keep white ones when pressed
		for y in tile.get_height():
			for x in tile.get_width():
				var c := tile.get_pixel(x, y)
				if c.a > 0.5 and c.b > 0.8 and c.r < 0.8:
					tile.set_pixel(x, y, Color.WHITE)
	return tile
