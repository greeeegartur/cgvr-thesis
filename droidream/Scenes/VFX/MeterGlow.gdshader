shader_type canvas_item;
render_mode blend_add;

// Fill glow on the intent meter: lights the bar from the center to the pointer (the bar texture itself is not changed)
uniform float pointer_x : hint_range(0.0, 1.0) = 0.5; // Pointer center in UV space
uniform vec4 glow_color : source_color = vec4(1.0, 0.3, 0.75, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.0; // Stepped flicker value from the script
uniform float hit : hint_range(0.0, 1.0) = 0.0; // White flash on a shift

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	float lo = min(0.5, pointer_x);
	float hi = max(0.5, pointer_x);
	float inside = smoothstep(lo - 0.01, lo + 0.01, UV.x) * (1.0 - smoothstep(hi - 0.01, hi + 0.01, UV.x));
	float reach = max(abs(pointer_x - 0.5), 0.001);
	float grade = mix(0.3, 1.0, clamp(abs(UV.x - 0.5) / reach, 0.0, 1.0)); // Brighter toward the pointer
	float shimmer = 0.92 + 0.08 * sin(UV.x * 22.0 - TIME * 6.0);
	float a = alpha * inside * grade * shimmer * strength;
	vec3 col = mix(glow_color.rgb, vec3(1.0), hit); // The flash turns the glow white
	a = max(a, alpha * hit);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
