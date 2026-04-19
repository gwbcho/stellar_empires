shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
uniform float explosion_alpha = 1.0;
void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center) * 2.0; 
	float fade = 1.0 - smoothstep(0.0, 1.0, dist); // Beautiful gradient bloom
	
	// Cherenkov intense neon blue flash burst over-emitting strictly natively!
	vec3 base_color = vec3(0.1, 0.5, 1.0);
	ALBEDO = base_color * fade * 15.0; 
	ALPHA = fade * explosion_alpha;
}
