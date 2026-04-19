shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
			   mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float f = 0.0; float w = 0.5;
	for (int i=0; i<4; i++) { f += w * noise(p); p *= 2.0; w *= 0.5; }
	return f;
}

void fragment() {
	vec2 uv = UV * 15.0;
	// Boiling time vector for extremely volatile energetic plasma crust
	float n = fbm(uv + vec2(TIME * 3.0, TIME * 2.5));
	// Crackling contrast
	n = smoothstep(0.4, 0.8, n);
	
	vec3 base_col = vec3(0.1, 0.6, 1.0);
	vec3 crackle_col = vec3(1.0, 1.0, 1.0);
	
	// Natively over-emit the core logic directly!
	ALBEDO = mix(base_col, crackle_col, n) * 4.0; 
}
