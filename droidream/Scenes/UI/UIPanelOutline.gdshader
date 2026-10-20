shader_type canvas_item;

// Solid silhouette of a UI panel template; UIPanel draws it slightly larger behind the panel as a highlight outline
uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.48, 1.0);

void fragment() {
	// COLOR is already texture * modulate here, so its alpha is the silhouette (and the inherited fade)
	COLOR = vec4(outline_color.rgb, COLOR.a * outline_color.a);
}
