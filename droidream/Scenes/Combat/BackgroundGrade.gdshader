shader_type canvas_item;

// Calms the background so characters stand out: contrast is pulled toward mid-gray (darks get lighter, brights slightly darker),
// so the scene is not made darker overall. contrast is how much of the original contrast is kept (1.0 = unchanged).
uniform float contrast : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// COLOR is already texture * modulate here
	COLOR.rgb = mix(vec3(0.5), COLOR.rgb, contrast);
}
