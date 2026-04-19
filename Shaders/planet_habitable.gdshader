shader_type spatial;
uniform vec3 water_color : source_color;
uniform vec3 land_color : source_color;
uniform vec3 cloud_color : source_color;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
			   mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) { float f = 0.0; float w = 0.5; for (int i=0; i<5; i++) { f += w * noise(p); p *= 2.0; w *= 0.5; } return f; }
void fragment() {
	vec2 uv = UV * 6.0;
	// Base continent/ocean generation
	float elevation = fbm(uv + vec2(3.14, 0.0));
	vec3 surface = mix(water_color, land_color, smoothstep(0.48, 0.53, elevation));
	
	// Separate sweeping cloud atmospheric layer natively decoupled visually!
	vec2 cloud_uv = uv * 1.5 + vec2(TIME * 0.02, TIME * -0.01);
	float clouds = fbm(cloud_uv); 
	float cloud_alpha = smoothstep(0.55, 0.70, clouds);
	
	ALBEDO = mix(surface, cloud_color, cloud_alpha);
	ROUGHNESS = mix(mix(0.1, 0.9, smoothstep(0.48, 0.53, elevation)), 1.0, cloud_alpha);
}
