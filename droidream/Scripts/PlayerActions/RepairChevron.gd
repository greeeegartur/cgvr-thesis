extends Node2D
class_name RepairChevron

# Pixel arrow beside a repair part that points at the Droid, so the player sees which way to press (it pulses on the shared selection beat)

const SIZE := 2 # Pixels per block
var inward := Vector2.RIGHT # Direction the arrow points (toward the Droid)
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	# Three nested V shapes pointing along `inward`, the last one drawn in white with a dark outline
	var pulse := SelectionPulse.beat_envelope(fmod(age, SelectionPulse.BEAT) / SelectionPulse.BEAT)
	var push := roundf(pulse * 4.0)
	var side := Vector2(-inward.y, inward.x)
	for layer in 2:
		var color := Color.BLACK if layer == 0 else Color.WHITE
		var grow := 1 if layer == 0 else 0
		for i in 4:
			var spread := 3 - i # The V is widest at its back
			for s in range(-spread, spread + 1):
				var cell: Vector2 = (inward * (i + push / SIZE) + side * s) * SIZE
				draw_rect(Rect2(cell - Vector2(grow, grow) - Vector2(SIZE, SIZE) / 2.0, Vector2(SIZE + grow * 2, SIZE + grow * 2)), color)
