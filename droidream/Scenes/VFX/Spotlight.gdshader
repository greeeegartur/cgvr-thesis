shader_type canvas_item;

// Dims the whole screen except a soft round light (used on the game over screen: the only light is around the Droid).
// center is in screen UV (0..1); radius and feather are in screen heights, so the light stays round.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 2.0;
uniform float feather = 0.18;
uniform float aspect = 1.7778; // Screen width divided by height
uniform float outside = 0.12; // Brightness left outside the light
uniform vec3 tint = vec3(0.55, 0.7, 1.0); // Cool tone of the dark part

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float distance_to_center = length((SCREEN_UV - center) * vec2(aspect, 1.0));
	float shade = smoothstep(radius, radius + feather, distance_to_center);
	vec3 dark = color * outside * tint * 1.6;
	COLOR = vec4(mix(color, dark, shade), 1.0);
}
