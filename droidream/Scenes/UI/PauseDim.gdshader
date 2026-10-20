shader_type canvas_item;

// Dims and slightly desaturates everything behind it (the world while the pause menu is open); amount fades the effect in and out
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float dim = 0.5; // How much darker the world gets
uniform float desaturate = 0.45; // How much of the color is taken away

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray), desaturate * amount);
	color *= 1.0 - dim * amount;
	COLOR = vec4(color, 1.0);
}
