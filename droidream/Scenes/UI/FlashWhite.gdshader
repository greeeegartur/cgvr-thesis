shader_type canvas_item;

// Flashes bright parts of text and icons toward white; dark parts (outlines) stay dark.
// Children with use_parent_material share it, so one parameter flashes a whole row or card.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// COLOR is already texture * modulate here
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	float amount = flash * smoothstep(0.15, 0.5, luma);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), amount);
}
