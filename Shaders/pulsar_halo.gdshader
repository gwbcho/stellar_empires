shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center) * 2.0; 
	float fade = 1.0 - smoothstep(0.1, 1.0, dist);
	
	ALBEDO = vec3(0.2, 0.5, 1.0) * fade * 1.5; 
	ALPHA = fade * 0.4;
}
