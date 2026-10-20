shader_type canvas_item;
render_mode blend_add;

// Slowly rotating purple-pink paint swirl, masked by the sprite's alpha so the light seems to come from inside the creature
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float swirl_speed = 0.6;
uniform float swirl_scale = 40.0; // Local pixels per swirl unit
uniform vec4 purple : source_color = vec4(0.45, 0.1, 0.9, 1.0);
uniform vec4 pink : source_color = vec4(1.0, 0.2, 0.75, 1.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = local_pos / swirl_scale;
	float t = TIME * swirl_speed;
	float r = length(p);
	float a = atan(p.y, p.x) + r * 2.2 - t;
	vec2 q = vec2(cos(a), sin(a)) * r;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		q += 0.6 * vec2(sin(q.y * 2.0 + t + fi), cos(q.x * 2.0 - t + fi * 1.7));
	}
	float m = 0.5 + 0.5 * sin(q.x * 2.4 + q.y * 1.7 + t);
	vec3 col = mix(purple.rgb, pink.rgb, m);
	col += vec3(1.0) * smoothstep(0.82, 1.0, m) * 0.6; // White hot spots
	COLOR = vec4(col, tex.a * intensity);
}
