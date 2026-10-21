extends RefCounted
class_name ActionFeedback

# The reusable feedback texts (Perfect, Good, Try, Miss, blocks, purchases, quick tame) with a tier style each, and the placement rule shared with the damage numbers:
# inside the camera's visible rect (away from the HUD strips) and never on top of another live text

enum Tier { PERFECT, GOOD, TRY, MISS, BLOCK, PURCHASE, TAME }

const POOLS := { # Text, color and bbcode effect of each variation
	Tier.PERFECT: [["Perfect!", "#fff27a", "wave freq=14"], ["Awesome!", "#c24dd0", "wave freq=14"], ["Great!", "#3d9feb", "shake rate=18"]],
	Tier.GOOD: [["Nice!", "#ffffff", "wave freq=10"], ["Good!", "#ffffff", ""], ["Sweet!", "#ffffff", ""]],
	Tier.TRY: [["Close!", "#b8b8c4", ""], ["Almost!", "#b8b8c4", ""]],
	Tier.MISS: [["Miss...", "#8a93a3", ""]],
	Tier.BLOCK: [["Blocked!", "#17e84f", "wave freq=14"], ["Thwarted!", "#06d63e", "shake rate=18"]],
	Tier.PURCHASE: [["Bought!", "#17e84f", "wave freq=12"], ["Acquired!", "#eff238", "wave freq=12"], ["Got it!", "#3d9feb", "shake rate=14"], ["Obtained!", "#3d9feb", "shake rate=14"]],
	Tier.TAME: [["Superb!", "#ff7ae0", "wave freq=12"], ["Excellent!", "#ff7ae0", "wave freq=12"]],
}
const FEEDBACK_BOX := Rect2(28, 6, 80, 26) # Where the text sits relative to the node's position (the label is 135 wide, the text centered)
const SIDE_MARGIN := 24.0 # Screen pixels kept free at the sides and the HUD strips
const TOP_MARGIN := 56.0
const BOTTOM_MARGIN := 36.0
const SLOT_TIME := 900 # Milliseconds a placed text blocks its spot for others

static var slots: Array[Dictionary] = []
static var last_text := {} # The last variation of each tier, so the same word does not repeat

# Shows a feedback text of a tier at a position in the layer; keep_visible clamps it inside the camera (screen-fixed layers like the shop pass false)
static func show(scene: PackedScene, layer: Node, at: Vector2, tier: Tier, keep_visible := true) -> void:
	if not scene:
		return
	var entry := _pick(tier)
	var effect: String = entry[2]
	var text := "[color=%s]%s[/color]" % [entry[1], entry[0]]
	if effect != "":
		text = "[%s]%s[/%s]" % [effect, text, effect.split(" ")[0]]
	
	var feedback := scene.instantiate()
	layer.add_child(feedback)
	feedback.position = place(layer, at, FEEDBACK_BOX, 40.0, 14.0) if keep_visible else at
	match tier:
		Tier.PERFECT:
			feedback.play_flair(text, Color("#e8e8f0")) # A neutral glow, so the fade-out is not yellow
		Tier.TAME:
			feedback.play_flair(text, Color("#ff7ae0"))
		Tier.TRY:
			feedback.play(text, 0.8)
		Tier.MISS:
			feedback.play_miss(text)
		_:
			feedback.play(text)

# A random variation of the tier that is not the one shown last
static func _pick(tier: Tier) -> Array:
	var pool: Array = POOLS[tier]
	var choices := pool.filter(func(entry): return entry[0] != last_text.get(tier, ""))
	if choices.is_empty():
		choices = pool # A tier with one text repeats it
	var entry: Array = choices.pick_random()
	last_text[tier] = entry[0]
	return entry

# PLACEMENT
# Returns the position for something whose footprint is box (relative to the position): clamped inside the camera's visible rect with the text's rise and sideways drift
# kept inside too, and moved up or down away from live texts placed before it
static func place(layer: Node, at: Vector2, box: Rect2, rise: float, drift: float) -> Vector2:
	var viewport := layer.get_viewport()
	var canvas := viewport.get_canvas_transform()
	var zoom := canvas.get_scale().x
	var view: Rect2 = canvas.affine_inverse() * viewport.get_visible_rect()
	var inner := view.grow_individual(-SIDE_MARGIN / zoom, -TOP_MARGIN / zoom, -SIDE_MARGIN / zoom, -BOTTOM_MARGIN / zoom)
	var pos := at
	var now := Time.get_ticks_msec()
	slots = slots.filter(func(slot): return slot.until > now)
	for attempt in 4:
		pos = _clamp(pos, box, inner, rise, drift)
		var footprint := Rect2(pos + box.position, box.size)
		var overlap := false
		for slot in slots:
			var other: Rect2 = slot.rect
			if footprint.intersects(other):
				overlap = true
				var above := other.position.y - box.size.y - 2.0 - box.position.y
				pos.y = above if above - rise > inner.position.y else other.end.y + 2.0 - box.position.y
				break
		if not overlap:
			break
	pos = _clamp(pos, box, inner, rise, drift)
	slots.append({ "rect": Rect2(pos + box.position, box.size), "until": now + SLOT_TIME })
	return pos

static func _clamp(pos: Vector2, box: Rect2, inner: Rect2, rise: float, drift: float) -> Vector2:
	var low := inner.position - box.position + Vector2(drift, rise)
	var high := inner.end - box.position - box.size - Vector2(drift, 0.0)
	return Vector2(clampf(pos.x, low.x, maxf(low.x, high.x)), clampf(pos.y, low.y, maxf(low.y, high.y)))
