extends RefCounted
class_name TargetArrowArt

# The target arrow's picture, drawn in code (no art file): a white downward triangle with a black outline and a faint shade on its lower right (like the old arrow, a little crisper)

const WIDTH := 19
const HEIGHT := 14
const HEAD_TOP := 1 # First row of the triangle
const HEAD_ROWS := 11
const COLOR_LIGHT := Color("#ffffff")
const COLOR_SHADE := Color("#d6d6d6") # A faint shade on the lower right edge

static var cached: ImageTexture

static func texture() -> ImageTexture:
	if cached:
		return cached
	var inside := PackedByteArray()
	inside.resize(WIDTH * HEIGHT)
	for y in HEIGHT:
		for x in WIDTH:
			inside[y * WIDTH + x] = 1 if _in_arrow(x, y) else 0
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in HEIGHT:
		for x in WIDTH:
			if inside[y * WIDTH + x] == 1:
				var shade := clampf(((x - 9.0) / 9.0) * 0.4 + (float(y) / HEIGHT - 0.5) * 0.9, 0.0, 1.0)
				var color := COLOR_LIGHT.lerp(COLOR_SHADE, shade)
				image.set_pixel(x, y, color)
			elif _touches(inside, x, y):
				image.set_pixel(x, y, Color.BLACK)
	cached = ImageTexture.create_from_image(image)
	return cached

static func _in_arrow(x: int, y: int) -> bool:
	var row := y - HEAD_TOP
	if row < 0 or row >= HEAD_ROWS:
		return false
	var half := 8.0 - row * 0.74 # Narrows to a point
	return absf(x - 9.0) <= half

static func _touches(inside: PackedByteArray, x: int, y: int) -> bool:
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if nx >= 0 and ny >= 0 and nx < WIDTH and ny < HEIGHT and inside[ny * WIDTH + nx] == 1:
			return true
	return false
