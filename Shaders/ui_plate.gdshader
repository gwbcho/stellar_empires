shader_type spatial;
render_mode blend_mix, depth_draw_opaque, unshaded, cull_disabled;
uniform vec4 border_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 0.85);
uniform vec2 rect_size = vec2(30.0, 8.0); 
uniform float line_thickness = 0.5;

void vertex() {
	// Native GPU Billboarding Matrix enforcing local tracking globally 
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 pixel_coord = UV * rect_size;
	float bx = step(pixel_coord.x, line_thickness) + step(rect_size.x - line_thickness, pixel_coord.x);
	float by = step(pixel_coord.y, line_thickness) + step(rect_size.y - line_thickness, pixel_coord.y);
	float is_border = clamp(bx + by, 0.0, 1.0);
	ALBEDO = mix(bg_color.rgb, border_color.rgb, is_border);
	ALPHA = mix(bg_color.a, border_color.a, is_border);
}
