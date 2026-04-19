shader_type spatial;
render_mode unshaded;

uniform vec3 base_color : source_color;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
			   mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) { float f = 0.0; float w = 0.5; for (int i=0; i<4; i++) { f += w * noise(p); p *= 2.0; w *= 0.5; } return f; }

void fragment() {
	vec2 uv = UV * 10.0;
	// Slower procedural boiling
	float n = fbm(uv + vec2(TIME * 0.1, TIME * -0.15));
	// Star spots
	float spots = smoothstep(0.6, 0.8, n);
	
	// Radiate logic organically mixing darker spots
	vec3 emit = mix(base_color, base_color * 0.3, spots);
	ALBEDO = emit * 2.0; // Standard organic spherical emission 
}
