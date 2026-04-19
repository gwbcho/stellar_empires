shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 base_color : source_color;
uniform vec3 rock_color : source_color;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
			   mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) { float f = 0.0; float w = 0.5; for (int i=0; i<5; i++) { f += w * noise(p); p *= 2.0; w *= 0.5; } return f; }

void fragment() {
	vec2 uv = UV * 12.0;
	float n = fbm(uv);
	ALBEDO = mix(base_color, rock_color, smoothstep(0.3, 0.7, n));
	ROUGHNESS = mix(0.7, 1.0, n);
}
