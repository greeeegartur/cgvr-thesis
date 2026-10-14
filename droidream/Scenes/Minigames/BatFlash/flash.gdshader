shader_type canvas_item;

uniform vec2 light_pos = vec2(0.5, 0.45); // normalized (0..1)
uniform float radius = 0.25;              // normalized (0..1, fraction of rect width)
uniform float softness = 0.1;           // fraction
uniform float darkness = 0.94;

void fragment() {
    float dist = distance(UV, light_pos);
    
    // Invert the mask
    float mask = smoothstep(radius - softness, radius, dist);
    
    // ColorRect color is applied outside the radius
    COLOR = vec4(0.0, 0.0, 0.0, darkness * mask);
}
