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

uniform vec3 base_color;

void fragment() {
	vec2 uv = UV * 12.0;
	// Boiling time vector for natively animated solar flares and plasma crust
	float n = fbm(uv + vec2(TIME * 1.5, TIME * 1.0));
	
	// Fluid, natural solar surface rolling
	n = smoothstep(0.3, 0.7, n);
	
	// Natively over-emit utilizing the strictly injected base_color directly!
	// This forces the crackling energy to structurally remain the exact same hue rather than washing into generic white limits
	ALBEDO = base_color * mix(1.0, 5.0, n); 
}
