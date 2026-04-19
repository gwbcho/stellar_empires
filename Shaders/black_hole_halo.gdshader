shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
			   mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) { float f = 0.0; float w = 0.5; for (int i=0; i<3; i++) { f += w * noise(p); p *= 2.0; w *= 0.5; } return f; }

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center) * 2.0; 
	float fade = 1.0 - smoothstep(0.1, 1.0, dist);
	
	vec2 polar = vec2(atan(UV.y - 0.5, UV.x - 0.5), dist);
	float radial_noise = fbm(vec2(polar.x * 5.0, polar.y * 10.0 - TIME * 5.0)); // Inward falling plasma
	
	ALBEDO = vec3(0.5, 0.1, 1.0) * fade * (1.0 + radial_noise * 2.0); // Violet halo
	ALPHA = fade * 0.8 * clamp(radial_noise, 0.2, 1.0);
}
