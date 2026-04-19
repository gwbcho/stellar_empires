shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always;

uniform vec4 ring_color : source_color;
uniform float inner_radius_rel;

float hash(float x) { return fract(sin(x * 123.456) * 789.123); }

void fragment() {
	vec2 center = UV * 2.0 - 1.0;
	float r = length(center);
	
	if (r < inner_radius_rel || r > 1.0) {
		discard;
	}
	
	// Procedural banding based strictly on mathematical radius limits natively!
	float band = hash(floor(r * 30.0)) * 0.4 + hash(floor(r * 120.0)) * 0.6;
	
	// Smooth edges internally avoiding antialiasing jitter natively
	float edge_in = smoothstep(inner_radius_rel, inner_radius_rel + 0.02, r);
	float edge_out = smoothstep(1.0, 0.98, r);
	
	ALBEDO = ring_color.rgb;
	ALPHA = ring_color.a * band * edge_in * edge_out;
}
