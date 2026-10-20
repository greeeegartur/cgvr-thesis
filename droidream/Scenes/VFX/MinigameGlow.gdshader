shader_type canvas_item;
render_mode blend_add;

// A slow, ominous blob of purple-pink light that swirls behind the minigame box (the box itself is drawn on top)
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(480.0, 480.0);
uniform vec4 purple : source_color = vec4(0.45, 0.1, 0.9, 1.0);
uniform vec4 pink : source_color = vec4(1.0, 0.2, 0.75, 1.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0; // -1..1 on both axes, so the blob is an ellipse that never touches the rect edge
	float t = TIME * 0.35;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// Lumpy outline: slow lobes that crawl around the blob
	float edge = 0.8 + 0.06 * sin(ang * 3.0 + t * 1.2) + 0.04 * sin(ang * 5.0 - t * 1.7) + 0.025 * sin(ang * 8.0 + t * 2.3);
	float density = smoothstep(edge + 0.1, edge - 0.3, r);
	// Swirling, warped texture inside
	float a = ang + r * 1.8 - t * 1.3;
	vec2 q = vec2(cos(a), sin(a)) * r;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		q += 0.45 * vec2(sin(q.y * 2.6 + t * 1.7 + fi * 2.0), cos(q.x * 2.6 - t * 1.3 + fi));
	}
	float streaks = pow(0.5 + 0.5 * sin(q.x * 5.0 + q.y * 3.2 + t * 3.0), 2.0); // Wispy bands
	float m = 0.5 + 0.5 * sin(q.x * 2.6 - q.y * 1.9 + t * 2.0);
	vec3 col = mix(purple.rgb, pink.rgb, m);
	float rim = smoothstep(edge - 0.3, edge, r) * density; // Brighter, paler edge like a glowing membrane
	col = mix(col * (0.6 + 0.6 * streaks), vec3(1.0, 0.7, 0.95), rim * 0.55);
	float alpha = density * (0.35 + 0.65 * streaks) + rim * 0.4;
	alpha *= 1.0 - smoothstep(0.93, 1.0, max(abs(p.x), abs(p.y))); // Hard guarantee that nothing is cut off at the rect edge
	COLOR = vec4(col, alpha * 0.7 * intensity);
}
