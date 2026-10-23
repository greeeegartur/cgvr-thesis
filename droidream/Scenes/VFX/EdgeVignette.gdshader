shader_type canvas_item;

// A soft dark frame: clear in the middle, darker toward the edges and corners (the block window cue)
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 0.75) * 2.0;
	float edge = smoothstep(0.45, 1.35, length(p));
	COLOR = vec4(0.0, 0.0, 0.0, edge * COLOR.a);
}
