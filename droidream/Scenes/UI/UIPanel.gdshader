shader_type canvas_item;

// Recolors the UI panel template: each source color of the template art is swapped for the matching style color.
// Source colors that a template does not have are set to a color that never matches (alpha 0).
uniform vec4 src_fill;
uniform vec4 src_ring;
uniform vec4 src_dark;
uniform vec4 src_light;
uniform vec4 dst_fill;
uniform vec4 dst_ring;
uniform vec4 dst_dark;
uniform vec4 dst_light;

uniform float flash : hint_range(0.0, 1.0) = 0.0; // Flashes bright parts (text, art) toward white; children with use_parent_material share it

const float TOLERANCE = 0.004; // About one 8-bit step

bool same(vec3 a, vec4 b) {
	return b.a > 0.0 && distance(a, b.rgb) < TOLERANCE;
}

// The inherited modulate; in fragment() COLOR is already multiplied by the texture
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 rgb = base.rgb;
	if (same(rgb, src_fill)) {
		rgb = dst_fill.rgb;
	} else if (same(rgb, src_ring)) {
		rgb = dst_ring.rgb;
	} else if (same(rgb, src_dark)) {
		rgb = dst_dark.rgb;
	} else if (same(rgb, src_light)) {
		rgb = dst_light.rgb;
	}
	COLOR = vec4(rgb, base.a) * tint;
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash * smoothstep(0.15, 0.5, luma));
}
