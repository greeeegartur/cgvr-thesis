shader_type canvas_item;

// White outline for the creatures affected by the action being targeted.
// outline_width: 0 = off, 1 = one texel (secondary targets), 1.5 = one texel plus a half-strength second ring (main target)
// frame_rect: the current sprite sheet frame in UV (min x, min y, max x, max y); neighbors outside it are ignored,
// so the outline never picks up pixels from the next frame of the sheet
uniform float outline_width : hint_range(0.0, 2.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0);

const vec2 DIRECTIONS[8] = vec2[](
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0)
);

bool inside_frame(vec2 uv) {
	return uv.x >= frame_rect.x && uv.y >= frame_rect.y && uv.x <= frame_rect.z && uv.y <= frame_rect.w;
}

// The inherited modulate (tint and fade from the pulse and the defeat animations); in fragment() COLOR is already multiplied by the texture
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	COLOR = base * tint;
	if (outline_width > 0.0 && base.a < 0.5) {
		float ring1 = 0.0;
		float ring2 = 0.0;
		for (int i = 1; i <= 2; i++) {
			float a = 0.0;
			for (int j = 0; j < 8; j++) {
				vec2 neighbor = UV + DIRECTIONS[j] * TEXTURE_PIXEL_SIZE * float(i);
				if (inside_frame(neighbor)) {
					a = max(a, texture(TEXTURE, neighbor).a);
				}
			}
			if (i == 1) {
				ring1 = a;
			} else {
				ring2 = a;
			}
		}
		if (ring1 > 0.5) {
			COLOR = vec4(outline_color.rgb, outline_color.a * tint.a);
		} else if (outline_width > 1.0 && ring2 > 0.5) {
			COLOR = vec4(outline_color.rgb, outline_color.a * (outline_width - 1.0) * tint.a);
		}
	}
}
