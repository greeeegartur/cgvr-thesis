extends RefCounted

# The shared "selected" effect for the player and creatures: scale pop, tint flash, outline and arrow bob on one beat

class_name SelectionPulse

const BEAT := 0.8 # One pulse; the arrow bob uses the same length, so everything stays in rhythm
const ATTACK_RATIO := 0.15 # Share of the beat spent snapping to the peak
const POP_SCALE := 0.10 # How much a main target grows at the peak
const TINT_COLOR := Color(1.0, 0.9, 0.4)
const TINT_AMOUNT := 0.5 # How far a main target is tinted at the peak
const FLASH_DIP := 0.45 # How far a main target's opacity dips mid-beat (the selection flash)
const ARROW_LOW := 5.0 # Arrow offset from its rest position at the start of the beat
const ARROW_HIGH := -10.0 # ...and at the middle of the beat
const ARROW_SCALE_LOW := 1.0
const ARROW_SCALE_HIGH := 1.2
const OUTLINE_SHADER := preload("res://Scenes/VFX/TargetOutline.gdshader")

var owner: Node
var visual # Node2D or Control that pops and is tinted (untyped: both have scale and modulate)
var arrow: Sprite2D # Arrow that bobs in rhythm (can be null)
var arrow_rest := Vector2.ZERO # Where the arrow sits when not pulsing
var body: Sprite2D # Sprite that receives the outline
var material: ShaderMaterial
var tween: Tween
var strength := 1.0
var arrow_factor := 1.0
var base_scale := Vector2.ONE
var base_position := Vector2.ZERO
var dip := FLASH_DIP # How far the opacity dips on the beat (0 = never dims)
var flash_target # Optional node with set_flash(amount): flashes toward white on the beat instead of dimming
var tint_amount := TINT_AMOUNT # 0 = no color change, only the opacity flash (menus and cards)
var use_scale := true # False for text and art that must stay crisp: they hop in whole pixels instead
var hop_pixels := 0.0 # Height of the whole-pixel hop at the peak of the beat (0 = no hop)
var base_modulate := Color.WHITE

# body gets the outline material (only if it has no material of its own)
func _init(p_owner: Node, p_visual, p_body: Sprite2D = null):
	owner = p_owner
	visual = p_visual
	body = p_body
	if p_body and p_body.material == null:
		material = ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		p_body.material = material

# Starts pulsing: strength 1.0 for the main target, lower for the others; outline_width in texels (1.0 = thin, 1.5 = a bit thicker)
# outline_alpha and arrow_alpha fade the outline and the arrow, so the creatures that are not the focus read as weaker
func start(p_strength: float, outline_width: float, p_arrow: Sprite2D = null, p_arrow_factor := 1.0, outline_alpha := 1.0, arrow_alpha := 1.0):
	stop()
	strength = p_strength
	arrow = p_arrow
	arrow_factor = p_arrow_factor
	if arrow:
		arrow_rest = arrow.position
	base_scale = visual.scale
	base_position = visual.position
	base_modulate = visual.modulate
	if material:
		material.set_shader_parameter("outline_width", outline_width)
		material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, outline_alpha))
		_update_frame_rect()
	if arrow:
		arrow.modulate.a = arrow_alpha
	
	tween = owner.create_tween().set_loops()
	tween.tween_method(_apply, 0.0, 1.0, BEAT)

# Stops pulsing and restores scale, tint, outline and the arrow
func stop():
	# Only restores when it was pulsing, so a late stop() cannot undo a defeat animation
	var was_pulsing := tween != null
	if tween:
		tween.kill()
		tween = null
	if was_pulsing and is_instance_valid(visual):
		visual.scale = base_scale
		visual.position = base_position
		visual.modulate = base_modulate
	if flash_target:
		flash_target.set_flash(0.0)
	if material:
		material.set_shader_parameter("outline_width", 0.0)
	if is_instance_valid(arrow):
		arrow.modulate.a = 1.0
		arrow.position = arrow_rest
	arrow = null

# Tells the outline shader which part of the sprite sheet is the current frame, so it cannot read neighboring frames
func _update_frame_rect():
	if material == null or body == null or body.texture == null:
		return
	var frame_width := 1.0 / float(maxi(body.hframes, 1))
	var frame_height := 1.0 / float(maxi(body.vframes, 1))
	var coords := body.frame_coords
	material.set_shader_parameter("frame_rect", Vector4(
		coords.x * frame_width, coords.y * frame_height,
		(coords.x + 1) * frame_width, (coords.y + 1) * frame_height))

# Envelope of one beat (phase 0..1): snaps up quickly, then eases back down; shared by every selection effect
static func beat_envelope(phase: float) -> float:
	if phase < ATTACK_RATIO:
		return sin(phase / ATTACK_RATIO * PI * 0.5)
	return cos((phase - ATTACK_RATIO) / (1.0 - ATTACK_RATIO) * PI * 0.5)

# Applies one point of the beat (phase 0..1)
func _apply(phase: float):
	if not is_instance_valid(visual):
		return
	
	# Snap up quickly, then ease back down before the next beat
	var envelope := beat_envelope(phase)
	
	_update_frame_rect() # The sheet frame can change while pulsing (idle animation)
	# Mid-beat wave: 0 at the start of the beat, 1 in the middle (same curve as the arrow bob)
	var wave := 0.5 - 0.5 * cos(phase * TAU)
	
	if use_scale:
		visual.scale = base_scale * (1.0 + POP_SCALE * strength * envelope)
	if hop_pixels > 0.0:
		visual.position.y = base_position.y - roundf(hop_pixels * envelope)
	var tinted := base_modulate.lerp(TINT_COLOR, tint_amount * strength * envelope)
	tinted.a = base_modulate.a * (1.0 - dip * strength * wave) # Opacity flash, weaker for the other targets
	visual.modulate = tinted
	if flash_target:
		flash_target.set_flash(envelope)
	
	# Arrow bob: low at the start of the beat, highest in the middle
	if arrow and is_instance_valid(arrow):
		arrow.position = arrow_rest + Vector2(0.0, lerpf(ARROW_LOW, ARROW_HIGH, wave))
		arrow.scale = Vector2.ONE * lerpf(ARROW_SCALE_HIGH, ARROW_SCALE_LOW, wave) * arrow_factor
