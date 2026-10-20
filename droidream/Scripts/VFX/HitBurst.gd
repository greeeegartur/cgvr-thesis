extends Node2D
class_name HitBurst

# The burst for every hit; a thin wrapper that picks the StarBurst preset for the hit strength

enum Strength { NORMAL, BLOCK, CRIT }

static func burst(layer: Node, at: Vector2, burst_color: Color, burst_strength: Strength) -> void:
	var preset := StarBurst.Preset.NORMAL
	match burst_strength:
		Strength.BLOCK:
			preset = StarBurst.Preset.BLOCK
		Strength.CRIT:
			preset = StarBurst.Preset.CRIT
	StarBurst.play(layer, at, preset, burst_color)
