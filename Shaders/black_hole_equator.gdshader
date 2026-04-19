shader_type spatial;
render_mode unshaded, cull_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
			   mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) { float f = 0.0; float w = 0.5; for (int i=0; i<4; i++) { f += w * noise(p); p *= 2.0; w *= 0.5; } return f; }
void fragment() {
	vec2 uv = vec2(UV.x * 20.0 - TIME * 4.0, UV.y * 3.0);
	float n = fbm(uv) * fbm(uv + vec2(TIME, 0.0));
	float fade = sin(UV.y * 3.14159);
	fade = smoothstep(0.0, 0.5, fade) * smoothstep(1.0, 0.5, fade);
	ALBEDO = vec3(1.0, 0.5, 0.1) * max(0.2, n) * 3.0; // Overbright plasma
	ALPHA = n * fade * clamp(1.0 - (abs(UV.x - 0.5) * 2.0), 0.0, 1.0); 
}
