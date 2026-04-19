shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform float emission_energy = 4.0;
uniform vec3 bh_pos;

void fragment() {
	// Natively flip horizontal UV mapping to reverse the chiral geometry 
	// of the plasma streaks so they perfectly trail the reversed -PI animation!
	vec2 flipped_uv = vec2(1.0 - UV.x, UV.y);
	vec4 c = texture(tex_albedo, flipped_uv);
	float lum = max(max(c.r, c.g), c.b);
	float mask = smoothstep(0.02, 0.15, lum);
	
	// Extract explicit World-Space Geometric Intersections mathematically!
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Because the horizontal accretion disk geometry is structurally mapped completely 
	// flat upon the exact absolute Y-axis plane of the singularity (world_pos.y == bh_pos.y), 
	// any Halo fragment sharing that identical Y-coordinate is physically colliding into it!
	float dy = abs(world_pos.y - bh_pos.y);
	
	// Fades out into pure native transparency exactly matching the physical equator line
	// utterly regardless of the viewing pitch or relative rotation sequence limits on the camera lens!
	float angle_fade = smoothstep(0.1, 1.5, dy);
	
	ALBEDO = c.rgb * emission_energy * mask * angle_fade;
}
