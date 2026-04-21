shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;
uniform vec4 color : source_color = vec4(0.2, 1.0, 0.5, 1.0);
uniform float speed = 2.0;
uniform float scale_y = 5.0; 
void fragment() {
	vec2 uv = UV;
	uv.y *= scale_y;
	uv.y += TIME * speed;
	vec2 local_uv = fract(uv);
	float distFromCenter = abs(local_uv.x - 0.5);
	float arrow_shape = step(distFromCenter * 2.0, local_uv.y) * step(local_uv.y, distFromCenter * 2.0 + 0.3);
	float line_shape = step(distFromCenter, 0.05);	
	ALPHA = color.a * max(arrow_shape, line_shape);
	ALBEDO = color.rgb;
}
