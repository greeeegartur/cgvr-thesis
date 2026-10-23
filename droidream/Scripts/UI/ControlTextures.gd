extends RefCounted
class_name ControlTextures

# The key pictures for the control family pressed last (Settings.input_family): the arrows, Z, X and C; the W A S D cluster, the mouse buttons and E;
# or the custom keys (letters, built from the keyboard sheet). Every sheet keeps the exact layout of the original picture, so sprites with frames keep working

const KEYBOARD := preload("res://Graphics/Sprites/UI/keyboard_letters_and_symbols.png")
const DEFAULTS := {
	"Z": preload("res://Graphics/Sprites/UI/Z.png"),
	"X": preload("res://Graphics/Sprites/UI/X.png"),
	"C": preload("res://Graphics/Sprites/UI/C.png"),
	"ARROWS": preload("res://Graphics/Sprites/UI/Arrows.png"),
}
const WASD_CLUSTER := preload("res://Graphics/Sprites/UI/WASD.png")
const MOUSE_LEFT := preload("res://Graphics/Sprites/UI/MouseLeft.png")
const MOUSE_RIGHT := preload("res://Graphics/Sprites/UI/MouseRight.png")
const PATHS := {
	"res://Graphics/Sprites/UI/Z.png": "Z",
	"res://Graphics/Sprites/UI/X.png": "X",
	"res://Graphics/Sprites/UI/C.png": "C",
	"res://Graphics/Sprites/UI/Arrows.png": "ARROWS",
}
# Minigame hints drawn from the arrow keys (two frames, up and pressed): the arrow keys in them are swapped for the family's keys in place
const HINT_PATHS := [
	"res://Graphics/Sprites/Minigames/FrogGuess/arrows.png",
	"res://Scenes/Minigames/BeetleRush/LEFT.png",
	"res://Scenes/Minigames/BeetleRush/RIGHT.png",
]
const KEY_ACTION := { "Z": "ui_accept", "X": "ui_cancel", "C": "toggle_turn_order" }
const DIRECTION_ACTIONS := { "ui_up": "W", "ui_left": "A", "ui_down": "S", "ui_right": "D" } # Each direction and its key's place in the cluster
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

const SPACE_WIDTH := 28 # The Space bar: a letter key without its letter, widened

static var cache := {}

# The two-frame sheet (up, pressed) of a key (Z, X, C or ARROWS) for the family in use
static func sheet(key: String) -> Texture2D:
	if key == "SPACE": # The same in every family
		if not cache.has(key):
			cache[key] = _build_space()
		return cache[key]
	if key.length() == 1 and not DEFAULTS.has(key): # Any other letter key (T skips the tutorial), the same in every family
		if not cache.has(key):
			cache[key] = _build_letter(key)
		return cache[key]
	if key.begins_with("res://"): # A minigame hint
		var cluster := sheet("ARROWS")
		if cluster == DEFAULTS["ARROWS"]:
			return load(key)
		var hint_key := key + str(cluster.get_instance_id())
		if not cache.has(hint_key):
			cache[hint_key] = _build_hint(key, cluster)
		return cache[hint_key]
	var family := Settings.input_family
	if family == "arrows" or (family == "custom" and not _has_custom_letter(key)):
		return DEFAULTS[key]
	var cache_key := family + key
	if not cache.has(cache_key):
		cache[cache_key] = _build_wasd(key) if family == "wasd" else _build_custom(key)
	return cache[cache_key]

# A single direction key picture (13 x 12, the size of the Harden keys) for the family in use; null keeps the arrow art
static func direction(action: String) -> Texture2D:
	var letter := _direction_letter(action)
	if letter == "":
		return null
	var cache_key := "dir" + Settings.input_family + letter
	if not cache.has(cache_key):
		cache[cache_key] = ImageTexture.create_from_image(_tile(letter, false))
	return cache[cache_key]

# The custom pictures are rebuilt after a key changes
static func clear_custom() -> void:
	for cache_key in cache.keys():
		if cache_key.begins_with("custom") or cache_key.begins_with("dircustom"):
			cache.erase(cache_key)

# Swaps the control pictures of every sprite under a node to the family in use (also back to the defaults)
static func swap_in(node: Node) -> void:
	for child in node.get_children():
		swap_in(child)
	if not ("texture" in node):
		return
	var current = node.get("texture")
	if not (current is Texture2D):
		return
	var key: String = node.get_meta("control_key") if node.has_meta("control_key") else PATHS.get(current.resource_path, current.resource_path if current.resource_path in HINT_PATHS else "")
	if key == "":
		return
	node.set_meta("control_key", key)
	node.set("texture", sheet(key))

# The letter a custom key gives a picture, or "" (only letters can be drawn from the keyboard sheet)
static func _custom_letter(action: String) -> String:
	var keycode: int = Settings.custom_keys.get(action, 0)
	if keycode >= KEY_A and keycode <= KEY_Z:
		return char(keycode)
	return "" # shortcut: a custom key that is not a letter shows the default picture, draw more keys if players bind them

static func _has_custom_letter(key: String) -> bool:
	if key == "ARROWS":
		for action in DIRECTION_ACTIONS:
			if _custom_letter(action) != "":
				return true
		return false
	return _custom_letter(KEY_ACTION[key]) != ""

static func _direction_letter(action: String) -> String:
	match Settings.input_family:
		"wasd":
			return DIRECTION_ACTIONS[action]
		"custom":
			return _custom_letter(action)
	return ""

# BUILDING THE SHEETS
# WASD: the cluster art, the mouse buttons for Confirm and Cancel, E for Turn order
static func _build_wasd(key: String) -> Texture2D:
	match key:
		"ARROWS":
			return WASD_CLUSTER
		"Z":
			return _build_single(key, _frames_of(MOUSE_LEFT), 0)
		"X":
			return MOUSE_RIGHT
	return _build_single(key, [_tile("E", false), _tile("E", true)], 1)

# Custom: the letters of the custom keys; the cluster mixes custom letters with the arrows the player did not change
static func _build_custom(key: String) -> Texture2D:
	if key != "ARROWS":
		var letter := _custom_letter(KEY_ACTION[key])
		return _build_single(key, [_tile(letter, false), _tile(letter, true)], 1)
	var arrows := DEFAULTS["ARROWS"].get_image()
	arrows.convert(Image.FORMAT_RGBA8)
	var image := Image.create(CLUSTER_FRAME.x, CLUSTER_FRAME.y * 2, false, Image.FORMAT_RGBA8)
	for action in DIRECTION_ACTIONS:
		var at: Vector2i = CLUSTER_KEYS[DIRECTION_ACTIONS[action]]
		var letter := _custom_letter(action)
		for pressed in 2:
			var row := at + Vector2i(0, CLUSTER_FRAME.y * pressed)
			if letter == "":
				image.blit_rect(arrows, Rect2i(row, KEY_SIZE + Vector2i(0, 1)), row)
			else:
				image.blit_rect(_tile(letter, pressed == 1), Rect2i(Vector2i.ZERO, KEY_SIZE), row + Vector2i(0, pressed))
	return ImageTexture.create_from_image(image)

# A single key sheet in the layout of Z, X or C: the up frame, then the pressed frame drop pixels lower
static func _build_single(key: String, frames: Array, drop: int) -> Texture2D:
	var layout: Dictionary = SHEET_LAYOUT[key]
	var frame: Vector2i = layout["frame"]
	var origin: Vector2i = layout["origin"]
	var image := Image.create(frame.x, frame.y * 2, false, Image.FORMAT_RGBA8)
	image.blit_rect(frames[0], Rect2i(Vector2i.ZERO, KEY_SIZE), origin)
	image.blit_rect(frames[1], Rect2i(Vector2i.ZERO, KEY_SIZE), origin + Vector2i(0, frame.y + drop))
	return ImageTexture.create_from_image(image)

# A minigame hint with its arrow keys swapped: each arrow key found in the up frame gets the family's key, and the same spot one frame lower gets its pressed look
static func _build_hint(path: String, cluster: Texture2D) -> Texture2D:
	var image: Image = load(path).get_image()
	image.convert(Image.FORMAT_RGBA8)
	var arrows: Image = DEFAULTS["ARROWS"].get_image()
	arrows.convert(Image.FORMAT_RGBA8)
	var keys := cluster.get_image()
	keys.convert(Image.FORMAT_RGBA8)
	var frame_height := image.get_height() / 2
	for at in CLUSTER_KEYS.values():
		var cell := arrows.get_region(Rect2i(at, KEY_SIZE))
		for spot in _find(image, cell, frame_height):
			image.blit_rect(keys, Rect2i(at, KEY_SIZE), spot)
			image.blit_rect(keys, Rect2i(at + Vector2i(0, CLUSTER_FRAME.y), KEY_SIZE), spot + Vector2i(0, frame_height))
	return ImageTexture.create_from_image(image)

# Where a key picture appears (pixel for pixel) in the top rows of an image
static func _find(image: Image, cell: Image, rows: int) -> Array:
	var spots := []
	for y in rows - KEY_SIZE.y + 1:
		for x in image.get_width() - KEY_SIZE.x + 1:
			if _matches(image, cell, Vector2i(x, y)):
				spots.append(Vector2i(x, y))
	return spots

static func _matches(image: Image, cell: Image, at: Vector2i) -> bool:
	for y in KEY_SIZE.y:
		for x in KEY_SIZE.x:
			var want := cell.get_pixel(x, y)
			var have := image.get_pixel(at.x + x, at.y + y)
			if (want.a > 0.5) != (have.a > 0.5) or (want.a > 0.5 and not want.is_equal_approx(have)):
				return false
	return true

# The two 13 x 12 frames of a mouse button picture
static func _frames_of(texture: Texture2D) -> Array:
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	return [image.get_region(Rect2i(Vector2i.ZERO, KEY_SIZE)), image.get_region(Rect2i(Vector2i(0, KEY_SIZE.y), KEY_SIZE))]

# A single letter key in both frames (up, then pressed one pixel lower), the size of the X and C pictures
static func _build_letter(letter: String) -> Texture2D:
	var image := Image.create(KEY_SIZE.x, KEY_SIZE.y * 2, false, Image.FORMAT_RGBA8)
	image.blit_rect(_tile(letter, false), Rect2i(Vector2i.ZERO, KEY_SIZE), Vector2i.ZERO)
	image.blit_rect(_tile(letter, true), Rect2i(Vector2i.ZERO, KEY_SIZE), Vector2i(0, KEY_SIZE.y + 1))
	return ImageTexture.create_from_image(image)

# The Space bar from the same keyboard sheet: a letter key with its letter painted over by the inset color, stretched in the middle (both frames, up and pressed)
static func _build_space() -> Texture2D:
	var image := Image.create(SPACE_WIDTH, KEY_SIZE.y * 2, false, Image.FORMAT_RGBA8)
	image.blit_rect(_space_tile(false), Rect2i(0, 0, SPACE_WIDTH, KEY_SIZE.y), Vector2i.ZERO)
	image.blit_rect(_space_tile(true), Rect2i(0, 0, SPACE_WIDTH, KEY_SIZE.y), Vector2i(0, KEY_SIZE.y + 1))
	return ImageTexture.create_from_image(image)

static func _space_tile(pressed: bool) -> Image:
	var tile := _tile("A", pressed)
	var inset := tile.get_pixel(3, 4) # The recessed area the letter sits on
	for y in range(2, 7):
		for x in range(4, 10):
			if tile.get_pixel(x, y).get_luminance() > 0.55: # The letter is the only light thing in there
				tile.set_pixel(x, y, inset)
	var wide := Image.create(SPACE_WIDTH, KEY_SIZE.y, false, Image.FORMAT_RGBA8)
	wide.blit_rect(tile, Rect2i(0, 0, 5, KEY_SIZE.y), Vector2i.ZERO) # The left edge
	for x in range(5, SPACE_WIDTH - 5):
		wide.blit_rect(tile, Rect2i(6, 0, 1, KEY_SIZE.y), Vector2i(x, 0)) # The middle, one column repeated
	wide.blit_rect(tile, Rect2i(8, 0, 5, KEY_SIZE.y), Vector2i(SPACE_WIDTH - 5, 0)) # The right edge
	return wide

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
