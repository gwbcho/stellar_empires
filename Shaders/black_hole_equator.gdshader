shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform float emission_energy = 4.0;

void fragment() {
	vec4 c = texture(tex_albedo, UV);
	float lum = max(max(c.r, c.g), c.b);
	float mask = smoothstep(0.02, 0.15, lum);
	
	// Math completely forces pseudo-black texture bounding box to true zero!
	// Additive rendering flawlessly merges light with no occlusion lines!
	ALBEDO = c.rgb * emission_energy * mask;
}
