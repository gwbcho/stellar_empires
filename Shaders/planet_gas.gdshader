shader_type spatial;

uniform vec3 band_color1 : source_color;
uniform vec3 band_color2 : source_color;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
			   mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) { float f = 0.0; float w = 0.5; for (int i=0; i<6; i++) { f += w * noise(p); p *= 2.0; w *= 0.5; } return f; }

void fragment() {
	vec2 uv = UV;
	uv.x -= TIME * 0.015; // Slow atmospheric spin
	// Stretched Y coordinates structurally enforcing fluid fluid bands across the equatorial plane!
	float n = fbm(vec2(uv.x * 6.0, uv.y * 40.0));
	n = smoothstep(0.4, 0.6, n);
	ALBEDO = mix(band_color1, band_color2, n);
	ROUGHNESS = 1.0;
}
