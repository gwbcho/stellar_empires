extends Node3D
class_name GalaxyGenerator

@export var num_stars: int = 400
@export var galaxy_radius: float = 500.0
@export var core_radius: float = 90.0 
@export var hyperlane_connectivity: float = 0.15 

var star_data: Array[Dictionary] = [] # Stores { "pos": Vector3, "type": String, "color": Color, "size": float, "name": String, "node": Area3D }
var hyperlanes: Array[Vector2i] = [] 
var adjacency_list: Dictionary = {} # Maps star integer index to an array of neighboring integer indices

# Visual references
var hyperlane_mesh_instance: MeshInstance3D
var backdrop_sprite: Sprite3D
var system_view_nodes: Array[Node3D] = []
var black_hole_billboards: Array[Dictionary] = []

var last_visited_system_index: int = -1
var galaxy_return_marker: Node3D = null
var focused_planet_ring: MeshInstance3D = null
var focused_planet_marker: Node3D = null
var system_name_canvas: CanvasLayer = null
var fleet_manager: Node3D = null

# Naming Database
var greek_letters = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Sigma", "Omega"]
var designations = ["Centauri", "Cygni", "Lupi", "Draconis", "Lyrae", "Orionis", "Pegasi", "Eridani", "Ceti", "Majoris"]
var generic_names = ["Sirius", "Betelgeuse", "Rigel", "Vega", "Altair", "Antares", "Polaris", "Arcturus", "Aldebaran", "Capella", "Trappist"]

var preset_systems = {
	"Sol": { "pos": Vector3(250.0, 0, 150.0), "type": "Yellow Dwarf (G)", "color": Color(1.0, 0.9, 0.7), "size": 1.0, "mass": 1.0 },
	"Alpha Centauri": { "pos": Vector3(258.0, 2.0, 145.0), "type": "Yellow Dwarf (G)", "color": Color(1.0, 0.9, 0.7), "size": 1.0, "mass": 1.1 }
}

var star_classifications = [
	{ "type": "Red Dwarf (M)", "weight": 76.45, "color": Color(1.0, 0.3, 0.1), "size": 0.8 },
	{ "type": "Orange Dwarf (K)", "weight": 12.1, "color": Color(1.0, 0.6, 0.2), "size": 0.9 },
	{ "type": "Yellow Dwarf (G)", "weight": 7.6, "color": Color(1.0, 0.9, 0.7), "size": 1.0 },
	{ "type": "White Main Seq (F/A)", "weight": 3.0, "color": Color(0.8, 0.9, 1.0), "size": 1.1 },
	{ "type": "Blue Giant (O/B)", "weight": 0.2, "color": Color(0.4, 0.6, 1.0), "size": 1.3 },
	{ "type": "Red Giant", "weight": 0.4, "color": Color(1.0, 0.1, 0.05), "size": 1.5 },
	{ "type": "White Dwarf", "weight": 0.2, "color": Color(0.9, 0.9, 0.9), "size": 0.6 },
	{ "type": "Neutron Star", "weight": 2.5, "color": Color(0.2, 0.8, 1.0), "size": 0.5 }, 
	{ "type": "Black Hole", "weight": 2.5, "color": Color(0.05, 0.0, 0.1), "size": 0.6 }
]

var cached_ui_shader: Shader = null

func get_ui_plate_material(plate_size: Vector2) -> ShaderMaterial:
	if cached_ui_shader == null:
		cached_ui_shader = Shader.new()
		cached_ui_shader.code = """
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
"""
	var mat = ShaderMaterial.new()
	mat.shader = cached_ui_shader
	mat.set_shader_parameter("rect_size", plate_size)
	mat.set_shader_parameter("line_thickness", 0.1) 
	return mat

var cached_planet_shaders: Dictionary = {}

func get_planet_material(p_type: String) -> ShaderMaterial:
	if not cached_planet_shaders.has(p_type):
		var s = Shader.new()
		if p_type == "Rocky":
			s.code = """
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
"""
		elif p_type == "Gas":
			s.code = """
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
"""
		elif p_type == "Habitable":
			s.code = """
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
"""
		cached_planet_shaders[p_type] = s
		
	var m = ShaderMaterial.new()
	m.shader = cached_planet_shaders[p_type]
	return m

var cached_ring_shader: Shader = null

func get_ring_material(ring_color: Color, inner_rel: float) -> ShaderMaterial:
	if not cached_ring_shader:
		cached_ring_shader = Shader.new()
		cached_ring_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always;

uniform vec4 ring_color : source_color;
uniform float inner_radius_rel;

float hash(float x) { return fract(sin(x * 123.456) * 789.123); }

void fragment() {
	vec2 center = UV * 2.0 - 1.0;
	float r = length(center);
	
	if (r < inner_radius_rel || r > 1.0) {
		discard;
	}
	
	// Procedural banding based strictly on mathematical radius limits natively!
	float band = hash(floor(r * 30.0)) * 0.4 + hash(floor(r * 120.0)) * 0.6;
	
	// Smooth edges internally avoiding antialiasing jitter natively
	float edge_in = smoothstep(inner_radius_rel, inner_radius_rel + 0.02, r);
	float edge_out = smoothstep(1.0, 0.98, r);
	
	ALBEDO = ring_color.rgb;
	ALPHA = ring_color.a * band * edge_in * edge_out;
}
"""
	var m = ShaderMaterial.new()
	m.shader = cached_ring_shader
	m.set_shader_parameter("ring_color", ring_color)
	m.set_shader_parameter("inner_radius_rel", inner_rel)
	return m

func _ready():
	randomize()
	fleet_manager = preload("res://Scripts/FleetManager.gd").new()
	fleet_manager.name = "FleetManager"
	add_child(fleet_manager)
	generate_galaxy()
	visualize_galaxy()
	
	# Instantiate global 2D HUD exactly for Solar System context
	system_name_canvas = CanvasLayer.new()
	var control = Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	system_name_canvas.add_child(control)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hbox.grow_vertical = Control.GROW_DIRECTION_END
	hbox.position.y -= 70
	hbox.add_theme_constant_override("separation", 20)
	control.add_child(hbox)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	style.border_color = Color(0.2, 1.0, 0.5, 0.9) 
	style.set_border_width_all(3)
	style.content_margin_left = 35
	style.content_margin_right = 35
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	hbox.add_child(panel)
	
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	label.add_theme_constant_override("outline_size", 6)
	panel.add_child(label)
	
	var btn = Button.new()
	btn.text = "🌌" 
	btn.custom_minimum_size = Vector2(75, 75)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	btn_style.border_color = Color(0.2, 1.0, 0.5, 0.9) # Identical neon matrix linking the UI organically
	btn_style.set_border_width_all(3)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	btn.add_theme_font_size_override("font_size", 42)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func():
		# Destroy old map button organically and execute native transition logic!
		var cam = get_viewport().get_camera_3d()
		if cam and cam.has_method("return_to_galaxy"): cam.return_to_galaxy()
	)
	hbox.add_child(btn)
	
	system_name_canvas.hide()
	add_child(system_name_canvas)

func _process(_delta):
	# Forces all 3D Orthogonal Lensed Halos to perfectly track the camera conditionally 
	var cam = get_viewport().get_camera_3d()
	if cam:
		for data in black_hole_billboards:
			var b = data["node"]
			if is_instance_valid(b):
				var star_pos = data["pos"]
				# The halo perfectly centers on the singularity, flawlessly intersecting 
				# through the equatorial accretion plane to natively match gravitational formulas!
				b.global_position = star_pos
				b.look_at(cam.global_position, Vector3.UP)
				
	# Sync Galaxy Map Fleet Indicators Dynamically exactly explicitly tracking logical arrays universally!
	if is_instance_valid(fleet_manager):
		for i in range(star_data.size()):
			if star_data[i].has("fleet_icon"):
				var icon = star_data[i]["fleet_icon"]
				if is_instance_valid(icon):
					var has_fleets = false
					var is_moving = false
					for f in fleet_manager.global_fleets:
						if f["system_index"] == i:
							has_fleets = true
							if f["is_moving"]: is_moving = true
					
					var should_show = has_fleets
					
					# Physically enforce native system view constraints explicitly preventing tracking bounds rendering internally strictly!
					if i == fleet_manager.current_rendered_system:
						should_show = false
					
					icon.visible = should_show
					if is_moving:
						icon.rotation.z = -PI/2
					else:
						icon.rotation.z = 0

# --- Procedural Data Generation ---

func get_random_star_type() -> Dictionary:
	var total_weight = 0.0
	for sc in star_classifications: total_weight += sc["weight"]
	var roll = randf() * total_weight
	var current_weight = 0.0
	var chosen_class = star_classifications[0]
	
	for sc in star_classifications:
		current_weight += sc["weight"]
		if roll <= current_weight: 
			chosen_class = sc
			break
			
	var mass = 1.0 # Default Sol Baseline
	match chosen_class["type"]:
		"Red Dwarf (M)": mass = randf_range(0.08, 0.45)
		"Orange Dwarf (K)": mass = randf_range(0.45, 0.8)
		"Yellow Dwarf (G)": mass = randf_range(0.8, 1.04)
		"White Main Seq (F/A)": mass = randf_range(1.04, 2.1)
		"Blue Giant (O/B)": mass = randf_range(2.1, 16.0)
		"Red Giant": mass = randf_range(0.3, 8.0) # High volume, moderate/low mass
		"White Dwarf": mass = randf_range(0.5, 1.4)
		"Neutron Star": mass = randf_range(1.4, 3.0) 
		"Black Hole": mass = randf_range(10.0, 36.0) # Maximum boundary radius tightly constrained to ~300.0
		
	var result = chosen_class.duplicate()
	result["mass"] = mass
	return result

func get_random_star_name() -> String:
	var roll = randf()
	if roll < 0.2 and generic_names.size() > 0:
		var n = generic_names[randi() % generic_names.size()]
		generic_names.erase(n)
		return n
	elif roll < 0.6:
		return greek_letters[randi() % greek_letters.size()] + " " + designations[randi() % designations.size()]
	else:
		return "Kepler-" + str(randi() % 900 + 10) + String.chr(randi() % 5 + 97)

func generate_galaxy():
	print("Generating Galaxy...")
	generate_stars()
	generate_hyperlanes()
	initialize_starting_fleets()

func initialize_starting_fleets():
	var sol_index = -1
	for i in range(star_data.size()):
		if star_data[i]["name"] == "Sol":
			sol_index = i
			break
	if sol_index == -1: return
	
	var planet_data = get_system_planets(sol_index)
	var prng = RandomNumberGenerator.new()
	prng.seed = hash(str(sol_index) + "_system_seed") 
	for i in range(100): prng.randf()
	
	var earth_orbit_pos = Vector3.ZERO
	for i in range(planet_data.size()):
		var angle = prng.randf_range(-PI, PI)
		if planet_data[i]["name"] == "Earth":
			earth_orbit_pos = star_data[sol_index]["pos"] + Vector3(cos(angle), 0, -sin(angle)) * planet_data[i]["orbit"]
			break
			
	if is_instance_valid(fleet_manager):
		fleet_manager.create_fleet(sol_index, earth_orbit_pos)

func generate_stars():
	star_data.clear()
	
	for system_name in preset_systems.keys():
		var sys = preset_systems[system_name].duplicate()
		sys["name"] = system_name
		star_data.append(sys)
		
	var generated = preset_systems.size()
	while generated < num_stars:
		var angle = randf() * PI * 2.0
		var distance = core_radius + sqrt(randf()) * (galaxy_radius - core_radius)
		var height_variance = (1.0 - (distance / galaxy_radius)) * 20.0
		var y = randf_range(-height_variance, height_variance)
		var x = cos(angle) * distance
		var z = sin(angle) * distance
		var pos = Vector3(x, y, z)
		
		var too_close = false
		for existing_star in star_data:
			if pos.distance_to(existing_star["pos"]) < 15.0:
				too_close = true
				break
				
		if not too_close:
			var random_star_type = get_random_star_type()
			star_data.append({
				"pos": pos,
				"name": get_random_star_name(),
				"type": random_star_type["type"],
				"color": random_star_type["color"],
				"size": random_star_type["size"],
				"mass": random_star_type["mass"]
			})
			generated += 1

func generate_hyperlanes():
	hyperlanes.clear()
	adjacency_list.clear()
	for i in range(star_data.size()): adjacency_list[i] = []
	
	var navigable_stars = [] 
	var points_2d = PackedVector2Array()
	
	for i in range(star_data.size()):
		var star = star_data[i]
		var pos2d = Vector2(star["pos"].x, star["pos"].z)
		if pos2d.length() >= (core_radius - 5.0): 
			points_2d.append(pos2d)
			navigable_stars.append(i)
			
	var delaunay_triangles = Geometry2D.triangulate_delaunay(points_2d)
	var all_edges = []
	var edge_set = {} 
	
	for i in range(0, delaunay_triangles.size(), 3):
		var p1_idx = navigable_stars[delaunay_triangles[i]]
		var p2_idx = navigable_stars[delaunay_triangles[i+1]]
		var p3_idx = navigable_stars[delaunay_triangles[i+2]]
		_add_edge(p1_idx, p2_idx, edge_set, all_edges)
		_add_edge(p2_idx, p3_idx, edge_set, all_edges)
		_add_edge(p3_idx, p1_idx, edge_set, all_edges)
		
	for edge in all_edges:
		var dist = star_data[edge.x]["pos"].distance_to(star_data[edge.y]["pos"])
		edge.weight = dist
		
	all_edges.sort_custom(func(a, b): return a.weight < b.weight)
	
	var parent_set = []
	for i in range(star_data.size()): parent_set.append(i)
		
	var mst_edges = []
	var remaining_edges = []
	
	for edge in all_edges:
		var root1 = _find(parent_set, edge.x)
		var root2 = _find(parent_set, edge.y)
		if root1 != root2:
			mst_edges.append(Vector2i(edge.x, edge.y))
			_union(parent_set, root1, root2)
		else:
			remaining_edges.append(Vector2i(edge.x, edge.y))
			
	hyperlanes.append_array(mst_edges)
	remaining_edges.shuffle()
	var extra_lanes_count = int(mst_edges.size() * hyperlane_connectivity)
	for i in range(min(extra_lanes_count, remaining_edges.size())):
		hyperlanes.append(remaining_edges[i])
		
	# Build adjacency list map for the System View arrows
	for lane in hyperlanes:
		adjacency_list[lane.x].append(lane.y)
		adjacency_list[lane.y].append(lane.x)

# --- Visualization & Interactions ---

func get_system_planets(star_idx: int) -> Array:
	var center_star = star_data[star_idx]
	var planet_data = []
	if center_star["name"] == "Sol":
		return [
			{"name": "Mercury", "type": "Rocky", "radius": 0.6, "orbit": 25.0, "c1": Color(0.4, 0.4, 0.45), "c2": Color(0.2, 0.2, 0.25)},
			{"name": "Venus", "type": "Gas", "radius": 1.2, "orbit": 40.0, "c1": Color(0.9, 0.8, 0.5), "c2": Color(0.8, 0.6, 0.3)}, 
			{"name": "Earth", "type": "Habitable", "radius": 1.3, "orbit": 55.0, "c1": Color(0.05, 0.2, 0.6), "c2": Color(0.1, 0.5, 0.2), "c3": Color(1.0, 1.0, 1.0)},
			{"name": "Mars", "type": "Rocky", "radius": 0.8, "orbit": 70.0, "c1": Color(0.8, 0.3, 0.1), "c2": Color(0.5, 0.15, 0.05)},
			{"name": "Jupiter", "type": "Gas", "radius": 4.5, "orbit": 110.0, "c1": Color(0.8, 0.7, 0.6), "c2": Color(0.6, 0.4, 0.2)},
			{"name": "Saturn", "type": "Gas", "radius": 3.8, "orbit": 150.0, "c1": Color(0.9, 0.8, 0.6), "c2": Color(0.7, 0.6, 0.4), "has_rings": true, "ring_inner": 1.3, "ring_outer": 2.4, "ring_color": Color(0.85, 0.8, 0.65, 0.85)},
			{"name": "Uranus", "type": "Gas", "radius": 2.2, "orbit": 190.0, "c1": Color(0.6, 0.8, 0.9), "c2": Color(0.4, 0.7, 0.8), "has_rings": true, "ring_inner": 1.4, "ring_outer": 1.8, "ring_color": Color(0.6, 0.8, 0.9, 0.35)},
			{"name": "Neptune", "type": "Gas", "radius": 2.1, "orbit": 230.0, "c1": Color(0.2, 0.3, 0.8), "c2": Color(0.1, 0.2, 0.6)}
		]
	
	var prng = RandomNumberGenerator.new()
	prng.seed = hash(str(star_idx) + "_system_seed")
	var planet_count = clampi(round(center_star["mass"] * 7.0), 0, 12)
	var orbit_start = 15.0
	var core_visual_radius = 5.0
	if center_star["type"] == "Black Hole":
		core_visual_radius = center_star["mass"] * 1.5
		orbit_start = max(core_visual_radius * 4.5, center_star["mass"] * 25.0) 
	elif center_star["type"] == "Neutron Star":
		core_visual_radius = center_star["size"] * 4.0
		orbit_start = max(core_visual_radius * 2.5, center_star["mass"] * 25.0)
	else:
		match center_star["type"]:
			"Red Dwarf (M)": core_visual_radius = 2.0
			"Orange Dwarf (K)": core_visual_radius = 3.5
			"Yellow Dwarf (G)": core_visual_radius = 5.0
			"White Main Seq (F/A)": core_visual_radius = 7.5
			"White Dwarf": core_visual_radius = 1.0
			"Blue Giant (O/B)": core_visual_radius = 25.0
			"Red Giant": core_visual_radius = 45.0
		orbit_start = max(core_visual_radius + 20.0, center_star["mass"] * 18.0 + 10.0)
		
	var scale_factor = sqrt(center_star["mass"]) * 275.0
	var ring_radius = max(275.0, scale_factor)
	var available_space = ring_radius - orbit_start
	if available_space < ring_radius * 0.4:
		planet_count = int(planet_count * (available_space / (ring_radius * 0.5)))
		planet_count = maxi(0, planet_count)
		
	var orbit_end = ring_radius - 20.0
	var step = 0.0
	if planet_count > 0: step = (orbit_end - orbit_start) / float(planet_count)
	
	for i in range(planet_count):
		var current_orbit_radius = orbit_start + (i * step) + prng.randf_range(-step * 0.2, step * 0.2)
		var progress = float(i) / float(max(1, planet_count - 1))
		var thermal_index = (center_star["mass"] * 300.0) / max(1.0, current_orbit_radius)
		
		var p_type = "Rocky"
		var r_min = 0.8
		var r_max = 1.8
		
		if progress > 0.5 or current_orbit_radius > 120.0:
			p_type = "Gas"
			r_min = 2.0
			r_max = 4.5
		else:
			if thermal_index > 1.2 and thermal_index < 3.5:
				if prng.randf() < 0.35: 
					p_type = "Habitable"
		
		var p_name = center_star["name"] + " - " + str(i + 1)
		var p_radius = prng.randf_range(r_min, r_max)
		var p = {"name": p_name, "type": p_type, "orbit": current_orbit_radius, "radius": p_radius}
		
		if p_type == "Gas":
			p["c1"] = Color.from_hsv(prng.randf(), prng.randf_range(0.4, 1.0), prng.randf_range(0.5, 0.9))
			p["c2"] = Color.from_hsv(prng.randf(), prng.randf_range(0.4, 1.0), prng.randf_range(0.2, 0.6))
		elif p_type == "Habitable":
			p["c1"] = Color(prng.randf_range(0.05, 0.15), prng.randf_range(0.2, 0.4), prng.randf_range(0.6, 0.8))
			p["c2"] = Color(prng.randf_range(0.1, 0.3), prng.randf_range(0.4, 0.7), prng.randf_range(0.1, 0.3))
			p["c3"] = Color(1.0, 1.0, 1.0)
		else:
			if thermal_index >= 3.5: 
				p["c1"] = Color(prng.randf_range(0.8, 1.0), prng.randf_range(0.1, 0.3), prng.randf_range(0.0, 0.1))
			else: 
				p["c1"] = Color(prng.randf_range(0.4, 0.7), prng.randf_range(0.4, 0.7), prng.randf_range(0.4, 0.7))
			p["c2"] = p["c1"].darkened(0.5)
		
		# Procedural Rings dynamically applied accurately
		var ring_chance = 0.0
		if p_type == "Gas": ring_chance = 0.45
		elif p_type == "Rocky": ring_chance = 0.08
		elif p_type == "Habitable": ring_chance = 0.12
		
		if prng.randf() < ring_chance:
			p["has_rings"] = true
			p["ring_inner"] = prng.randf_range(1.2, 1.6)
			p["ring_outer"] = p["ring_inner"] + prng.randf_range(0.3, 1.4)
			var rc = p["c1"].darkened(prng.randf_range(0.1, 0.4))
			rc.a = prng.randf_range(0.4, 0.85)
			p["ring_color"] = rc
		else:
			p["has_rings"] = false
		
		planet_data.append(p)
		
	return planet_data

func does_system_have_habitable(star_idx: int) -> bool:
	var planets = get_system_planets(star_idx)
	for p in planets:
		if p["type"] == "Habitable": return true
	return false

func visualize_galaxy():
	for i in range(star_data.size()):
		var star = star_data[i]
		
		var star_material = StandardMaterial3D.new()
		star_material.albedo_color = star["color"]
		star_material.emission_enabled = true
		star_material.emission = star["color"]
		
		if star["type"] == "Black Hole":
			star_material.emission_energy_multiplier = 0.1 
			star_material.albedo_color = Color(0, 0, 0)
			star_material.rim_enabled = true
			star_material.rim_tint = 1.0
			star_material.rim = 1.0
		elif star["type"] == "Neutron Star":
			star_material.emission_energy_multiplier = 4.0 
		else:
			star_material.emission_energy_multiplier = 1.5
		
		var sphere = SphereMesh.new()
		var final_size = star["size"] * randf_range(0.95, 1.05) * 1.5 
		sphere.radius = final_size
		sphere.height = final_size * 2.0
		
		var area = Area3D.new()
		add_child(area)
		area.position = star["pos"]
		star["node"] = area # Cache reference
		
		if star["type"] == "Black Hole":
			# Fake Gravitational Lensing via Godot's built-in Refraction
			var lensing_mesh = SphereMesh.new()
			lensing_mesh.radius = final_size * 2.5
			lensing_mesh.height = final_size * 5.0
			
			var lensing_mat = StandardMaterial3D.new()
			lensing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lensing_mat.albedo_color = Color(1, 1, 1, 0.0)
			lensing_mat.refraction_enabled = true
			lensing_mat.refraction_scale = 1.0 # Maximum visual distortion around the dark core
			
			var lensing_node = MeshInstance3D.new()
			lensing_node.mesh = lensing_mesh
			lensing_node.material_override = lensing_mat
			area.add_child(lensing_node)
		
		var mi = MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = star_material
		area.add_child(mi)
		
		var col = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = final_size * 3.0  # Slightly larger for easier hover/click
		col.shape = shape
		area.add_child(col)
		
		# 3. Modular UI Data Plate Pipeline
		var ui_nodes = []
		var exact_text = star["name"]
		var has_life = does_system_have_habitable(i)
		
		var display_text = exact_text
		
		# Expand box to fit name elegantly and strictly inject 12.0 raw physical padding explicitly preserving right-aligned tracking space statically!
		var p_width = max(20.0, display_text.length() * 2.5) + 12.0 
		var p_height = 8.0
		
		var plate_mesh = QuadMesh.new()
		plate_mesh.size = Vector2(p_width, p_height)
		var plate_node = MeshInstance3D.new()
		plate_node.mesh = plate_mesh
		plate_node.material_override = get_ui_plate_material(Vector2(p_width, p_height))
		plate_node.position = Vector3(0, -final_size * 4.0 - 5.0, 0)
		plate_node.visibility_range_end = 250.0 
		plate_node.visibility_range_end_margin = 10.0
		plate_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		area.add_child(plate_node)
		ui_nodes.append(plate_node)
		
		var label = Label3D.new()
		label.text = display_text
		label.font_size = 400
		label.position = Vector3(0, -final_size * 4.0 - 5.0, 0.1) # Pushed explicitly forward by 0.1 to avoid Plate Z-fighting!
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visibility_range_end = 250.0 
		label.visibility_range_end_margin = 10.0
		label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		label.extra_cull_margin = 16000.0 # Aggressively protects horizontal offset culling limits!
		area.add_child(label)
		ui_nodes.append(label)
		
		if has_life:
			var icon = Label3D.new()
			icon.text = "🌐"
			icon.font_size = 400
			icon.modulate = Color(0.2, 1.0, 0.5)
			
			# Flawlessly globally calculate exact 3D geometric edge explicitly bounding strictly mathematically explicitly symmetrically!
			var l_offset_x = -(exact_text.length() * 1.1) - 2.5
			icon.position = Vector3(l_offset_x, -final_size * 4.0 - 5.0, 0.12)
			icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			icon.visibility_range_end = 250.0 
			icon.visibility_range_end_margin = 10.0
			icon.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			icon.extra_cull_margin = 16000.0 
			icon.offset = Vector2.ZERO # Absolute purge of chaotic pixel offsets mathematically explicitly universally!
			
			area.add_child(icon)
			ui_nodes.append(icon)
			
		var ship_sprite = Sprite3D.new()
		var img = Image.new()
		if img.load("res://Resources/fleet_icon.png") == OK:
			ship_sprite.texture = ImageTexture.create_from_image(img)
			
		# Perfectly scale 3D bounds exactly anchoring logically natively against the dynamic plate boundaries organically!
		var s_offset_x = (exact_text.length() * 1.1) + 2.5 # Exactly identically physically mirrored against the Habitable icon symmetrically natively!
		ship_sprite.position = Vector3(s_offset_x, -final_size * 4.0 - 5.0, 0.12)
		ship_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ship_sprite.visibility_range_end = 250.0 
		ship_sprite.visibility_range_end_margin = 10.0
		ship_sprite.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		ship_sprite.extra_cull_margin = 16000.0
		
		# Tightly scale native 1024 resolution perfectly gracefully into UI boundaries strictly
		ship_sprite.pixel_size = 0.003 
		ship_sprite.visible = false 
		
		area.add_child(ship_sprite)
		ui_nodes.append(ship_sprite)
		star["fleet_icon"] = ship_sprite
		
		star["ui_plate_nodes"] = ui_nodes
		
		area.input_event.connect(_on_star_input_event.bind(i))
		area.mouse_entered.connect(_on_star_hover_enter.bind(i))
		area.mouse_exited.connect(_on_star_hover_exit.bind(i))
		
	var line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color(0.2, 0.4, 0.8, 0.15)
	line_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var immediate_mesh = ImmediateMesh.new()
	hyperlane_mesh_instance = MeshInstance3D.new()
	hyperlane_mesh_instance.mesh = immediate_mesh
	hyperlane_mesh_instance.material_override = line_material
	add_child(hyperlane_mesh_instance)
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for lane in hyperlanes:
		immediate_mesh.surface_add_vertex(star_data[lane.x]["pos"])
		immediate_mesh.surface_add_vertex(star_data[lane.y]["pos"])
	immediate_mesh.surface_end()
	
	var img = Image.new()
	var err = img.load("res://Resources/milky_way_backdrop.png")
	if err == OK:
		var backdrop_texture = ImageTexture.create_from_image(img)
		backdrop_sprite = Sprite3D.new()
		backdrop_sprite.texture = backdrop_texture
		backdrop_sprite.pixel_size = 1.2 
		backdrop_sprite.axis = Vector3.AXIS_Y 
		backdrop_sprite.position = Vector3(0, -10.0, 0)
		backdrop_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		backdrop_sprite.modulate = Color(1.0, 1.0, 1.0, 0.6) 
		add_child(backdrop_sprite)

# --- State Machine & Zoom Handlers ---

func set_galactic_view():
	# Restore macro view
	if hyperlane_mesh_instance: hyperlane_mesh_instance.show()
	if backdrop_sprite: backdrop_sprite.show()
	if is_instance_valid(system_name_canvas): system_name_canvas.hide()
	if is_instance_valid(fleet_manager) and fleet_manager.has_method("clear_ships"): fleet_manager.clear_ships()
	
	for star in star_data:
		if star.has("node") and star["node"]: star["node"].show()
		# Natively unhide tracking billboards!
		if star.has("ui_plate_nodes"):
			for node in star["ui_plate_nodes"]:
				if is_instance_valid(node): node.show()
		
	for node in system_view_nodes:
		if is_instance_valid(node): node.queue_free()
	system_view_nodes.clear()

	# Dynamically generate the pinpoint targeting marker upon emerging natively from a zoom level!
	if is_instance_valid(galaxy_return_marker):
		galaxy_return_marker.queue_free()
		
	if last_visited_system_index != -1 and last_visited_system_index < star_data.size():
		var target_star = star_data[last_visited_system_index]
		galaxy_return_marker = Node3D.new()
		galaxy_return_marker.position = target_star["pos"]
		add_child(galaxy_return_marker)
		
		# Targeting Reticle Ring
		var ring = MeshInstance3D.new()
		var ring_m = TorusMesh.new()
		ring_m.inner_radius = 6.0
		ring_m.outer_radius = 7.0
		ring.mesh = ring_m
		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.2, 1.0, 0.5)
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(0.2, 1.0, 0.5)
		ring.material_override = ring_mat
		galaxy_return_marker.add_child(ring)
		
		# Natively calculated Inward bounding arrows!
		for i in range(4):
			var angle = i * (PI / 2.0)
			var inward_dir = Vector3(cos(angle), 0, -sin(angle)).normalized()
			var outward_dir = -inward_dir 
			
			var arr = Label3D.new()
			# Re-using literal Arrow geometry mapped inversely toward the center pivot radially
			arr.text = "➤"
			arr.font_size = 1000
			arr.modulate = Color(0.2, 1.0, 0.5)
			arr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			arr.rotation.x = -PI/2
			arr.rotation.y = atan2(-inward_dir.z, inward_dir.x)
			arr.position = outward_dir * 25.0
			galaxy_return_marker.add_child(arr)
			
		# Visually pulsing the tracking matrix explicitly so it can never be mistaken for generic stars
		create_tween().set_loops().tween_property(galaxy_return_marker, "rotation:y", PI * 2.0, 8.0).as_relative()
		
func set_system_view(star_index: int):
	# Hide macro universe UI/paths, but leave background logic running natively if needed
	if hyperlane_mesh_instance: hyperlane_mesh_instance.hide()
	if backdrop_sprite: backdrop_sprite.hide()
	
	# Clear out any previous system rings/arrows if we are jumping natively from system to system!
	for node in system_view_nodes:
		if is_instance_valid(node): node.queue_free()
	system_view_nodes.clear()
	black_hole_billboards.clear()
	
	if is_instance_valid(fleet_manager) and fleet_manager.has_method("clear_ships"):
		fleet_manager.clear_ships()
	
	if is_instance_valid(galaxy_return_marker):
		galaxy_return_marker.hide()
		
	if is_instance_valid(focused_planet_marker):
		focused_planet_marker.queue_free()
	focused_planet_ring = null
		
	# Locks the target to physically remember where we exited into the galaxy space from!
	last_visited_system_index = star_index
	
	var center_star = star_data[star_index]
	
	# Hide every star except the targeted one
	for i in range(star_data.size()):
		if star_data[i].has("node") and star_data[i]["node"]:
			if i == star_index:
				star_data[i]["node"].show()
				# Remove redundant 3D UI label natively within System mode 
				if star_data[i].has("ui_plate_nodes"):
					for n in star_data[i]["ui_plate_nodes"]:
						if is_instance_valid(n): n.hide()
			else:
				star_data[i]["node"].hide()
				
	# Activate global 2D HUD dynamically
	if is_instance_valid(system_name_canvas):
		# Traverse structural UI nodes directly: Canvas -> Control -> HBox -> Panel -> Label
		var sys_lbl = system_name_canvas.get_child(0).get_child(0).get_child(0).get_child(0)
		sys_lbl.text = center_star["name"] + " System"
		system_name_canvas.show()
				
	# --- Procedural 3D Nebula Skybox ---
	var sky_mesh = SphereMesh.new()
	# Explode the systemic boundaries profoundly avoiding mathematical decapitation natively against extended Far planes!
	sky_mesh.radius = 18000.0 
	sky_mesh.height = 36000.0
	
	var sky_mat = StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.cull_mode = BaseMaterial3D.CULL_FRONT # Renders explicitly on the inside bounds
	
	var sky_img = Image.new()
	# Forcibly bypassed strictly to .jpg extension to avoid corrupting strictly-handled Godot magic bytes!
	if sky_img.load("res://Resources/system_skybox.jpg") == OK:
		sky_mat.albedo_texture = ImageTexture.create_from_image(sky_img)
		# Heavily dim the background natively forcing the actual planets and UI vividly into the foreground!
		sky_mat.albedo_color = Color(0.12, 0.12, 0.15, 1.0) 
		
	var sky_node = MeshInstance3D.new()
	sky_node.mesh = sky_mesh
	sky_node.material_override = sky_mat
	sky_node.position = center_star["pos"]
	add_child(sky_node)
	system_view_nodes.append(sky_node)
			
	# Generate the system boundary ring
	var ring_mesh = TorusMesh.new()
	# The size scales natively proportionate to the gravitational reach using square root!
	# Sol is exactly 1 SM -> scale_factor = 275.0 radius natively encompassing Neptune!
	var scale_factor = sqrt(center_star["mass"]) * 275.0
	var ring_radius = max(275.0, scale_factor) # Guaranteed minimum bounds mathematically engulfing outer orbits
	ring_mesh.inner_radius = ring_radius - 1.0
	ring_mesh.outer_radius = ring_radius
	
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.8)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.2, 0.6, 1.0)
	
		# Skybox removed natively per user request to respect the sprawling system boundary scale
	
	# Generate Hyperlane 2D exit arrows pointing towards neighbors
	var ring_instance = MeshInstance3D.new()
	ring_instance.mesh = ring_mesh
	ring_instance.material_override = ring_mat
	ring_instance.position = center_star["pos"]
	add_child(ring_instance)
	system_view_nodes.append(ring_instance)
	
	# Generate Central System Light Source to physically illuminate upcoming procedural planetary assets
	var sys_light = OmniLight3D.new()
	sys_light.position = center_star["pos"]
	sys_light.omni_range = ring_radius * 12.0 # Push physics falloff massively outwards!
	if center_star["type"] == "Black Hole":
		sys_light.light_color = Color(1.0, 1.0, 1.0) # Intense White high-energy radiation
		sys_light.light_energy = 40.0
	else:
		sys_light.light_color = center_star["color"]
		sys_light.light_energy = 20.0
	add_child(sys_light)
	system_view_nodes.append(sys_light)
	
	# Physically Fixed Geometric Simulator for Black Holes
	if center_star["type"] == "Black Hole":
		# 1. Solid Pitch-Black Event Horizon Core
		var core_mesh = SphereMesh.new()
		var bh_rad = center_star["mass"] * 1.5 # Significantly compressed!
		core_mesh.radius = bh_rad
		core_mesh.height = bh_rad * 2.0
		
		var core_mat = StandardMaterial3D.new()
		core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core_mat.albedo_color = Color(0,0,0)
		
		var core_node = MeshInstance3D.new()
		core_node.mesh = core_mesh
		core_node.material_override = core_mat
		core_node.position = center_star["pos"]
		add_child(core_node)
		system_view_nodes.append(core_node)
		
		# 2. Universal Accretion Disk Physics Engine
		var disk_mesh = PlaneMesh.new()
		var disk_rad = bh_rad * 2.2 # Tighter radius so it actually physically disappears behind the void!
		disk_mesh.size = Vector2(disk_rad * 2.0, disk_rad * 2.0)
		
		var tex = null
		var img = Image.new()
		if img.load("res://Resources/accretion_disk.jpg") == OK:
			tex = ImageTexture.create_from_image(img)
			
		var eq_mat = ShaderMaterial.new()
		var eq_shader = Shader.new()
		eq_shader.code = """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform float emission_energy = 4.0;

void fragment() {
	vec4 c = texture(tex_albedo, UV);
	float lum = max(max(c.r, c.g), c.b);
	float mask = smoothstep(0.02, 0.15, lum);
	
	// Math completely forces pseudo-black texture bounding box to true zero!
	// Additive rendering flawlessly merges light with no occlusion lines!
	ALBEDO = c.rgb * emission_energy * mask;
}
"""
		eq_mat.shader = eq_shader
		
		var halo_mat = ShaderMaterial.new()
		var halo_shader = Shader.new()
		halo_shader.code = """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform float emission_energy = 4.0;
uniform vec3 bh_pos;

void fragment() {
	// Natively flip horizontal UV mapping to reverse the chiral geometry 
	// of the plasma streaks so they perfectly trail the reversed -PI animation!
	vec2 flipped_uv = vec2(1.0 - UV.x, UV.y);
	vec4 c = texture(tex_albedo, flipped_uv);
	float lum = max(max(c.r, c.g), c.b);
	float mask = smoothstep(0.02, 0.15, lum);
	
	// Extract explicit World-Space Geometric Intersections mathematically!
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Because the horizontal accretion disk geometry is structurally mapped completely 
	// flat upon the exact absolute Y-axis plane of the singularity (world_pos.y == bh_pos.y), 
	// any Halo fragment sharing that identical Y-coordinate is physically colliding into it!
	float dy = abs(world_pos.y - bh_pos.y);
	
	// Fades out into pure native transparency exactly matching the physical equator line
	// utterly regardless of the viewing pitch or relative rotation sequence limits on the camera lens!
	float angle_fade = smoothstep(0.1, 1.5, dy);
	
	ALBEDO = c.rgb * emission_energy * mask * angle_fade;
}
"""
		halo_mat.shader = halo_shader
		
		if tex:
			eq_mat.set_shader_parameter("tex_albedo", tex)
			halo_mat.set_shader_parameter("tex_albedo", tex)
			
		halo_mat.set_shader_parameter("bh_pos", center_star["pos"])
		
		# A. The Equatorial Disk! 
		var eq_disk = MeshInstance3D.new()
		eq_disk.mesh = disk_mesh
		eq_disk.material_override = eq_mat
		eq_disk.position = center_star["pos"]
		add_child(eq_disk)
		system_view_nodes.append(eq_disk)
		
		create_tween().set_loops().tween_property(eq_disk, "rotation:y", PI * 2.0, 12.0).as_relative()
		
		# B. The Orthogonal Gravitational Lensing Halo (3-Tiered Hierarchy fix)!
		# Tracker Pivot physically looks_at the Camera constantly
		var halo_tracker = Node3D.new()
		halo_tracker.position = center_star["pos"]
		add_child(halo_tracker)
		system_view_nodes.append(halo_tracker)
		
		# Tilt Pivot locks the rigid 90-degree angle without ever tweening (IMMUNE to Gimbal Lock!)
		var tilt_pivot = Node3D.new()
		tilt_pivot.rotation.x = deg_to_rad(90)
		halo_tracker.add_child(tilt_pivot)
		
		# The Mesh geometry naturally spins purely upon its zeroed strictly-local axis
		var halo_disk = MeshInstance3D.new()
		halo_disk.mesh = disk_mesh
		halo_disk.material_override = halo_mat
		# Due to optical lensing refracting light sharply, the projection naturally compacts 
		# tighter inward against the Event Horizon than the true physical Equator disk!
		halo_disk.scale = Vector3(0.70, 0.70, 0.70)
		tilt_pivot.add_child(halo_disk)
		
		# Natively synching the rotational period explicitly with the equatorial disk (-PI matching direction!)
		create_tween().set_loops().tween_property(halo_disk, "rotation:y", -PI * 2.0, 12.0).as_relative()
		
		black_hole_billboards.append({
			"node": halo_tracker,
			"pos": center_star["pos"],
			"radius": bh_rad
		})
		
	elif center_star["type"] == "Neutron Star":
		var ns_rad = center_star["size"] * 4.0 # Scale it up slightly so it physically dominates the void
		
		# 1. Crackling Energy Core
		var core_mesh = SphereMesh.new()
		core_mesh.radius = ns_rad
		core_mesh.height = ns_rad * 2.0
		
		var core_mat = ShaderMaterial.new()
		var core_shader = Shader.new()
		core_shader.code = """
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
"""
		core_mat.shader = core_shader
		var core_node = MeshInstance3D.new()
		core_node.mesh = core_mesh
		core_node.material_override = core_mat
		core_node.position = center_star["pos"]
		add_child(core_node)
		system_view_nodes.append(core_node)
		

		
		# 3. Faint Pulsar Halo Horizon
		var halo_mesh = PlaneMesh.new()
		halo_mesh.size = Vector2(ns_rad * 30.0, ns_rad * 30.0)
		
		var h_mat = ShaderMaterial.new()
		var h_shader = Shader.new()
		h_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center) * 2.0; 
	float fade = 1.0 - smoothstep(0.1, 1.0, dist);
	
	ALBEDO = vec3(0.2, 0.5, 1.0) * fade * 1.5; 
	ALPHA = fade * 0.4;
}
"""
		h_mat.shader = h_shader
		var h_node = MeshInstance3D.new()
		h_node.mesh = halo_mesh
		h_node.material_override = h_mat
		h_node.position = center_star["pos"]
		add_child(h_node)
		system_view_nodes.append(h_node)
		
		# Rotate Halo seamlessly over time
		create_tween().set_loops().tween_property(h_node, "rotation:y", PI * 2.0, 20.0).as_relative()
		
	else:
		# Universal Procedural Generation explicitly overwriting standard base Star Meshes!
		var u_rad = 5.0 # Core Sol Baseline
		match center_star["type"]:
			"Red Dwarf (M)": u_rad = 2.0
			"Orange Dwarf (K)": u_rad = 3.5
			"Yellow Dwarf (G)": u_rad = 5.0
			"White Main Seq (F/A)": u_rad = 7.5
			"White Dwarf": u_rad = 1.0 # Microscopic geometric scaling properly rendered
			"Blue Giant (O/B)": u_rad = 25.0
			"Red Giant": u_rad = 45.0 # Max capped visual limit guaranteeing zero screen disruption naturally!
		
		var u_mesh = SphereMesh.new()
		u_mesh.radius = u_rad
		u_mesh.height = u_rad * 2.0
		
		var u_mat = ShaderMaterial.new()
		var u_shader = Shader.new()
		u_shader.code = """
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
"""
		u_mat.shader = u_shader
		u_mat.set_shader_parameter("base_color", center_star["color"])
		
		var u_node = MeshInstance3D.new()
		u_node.mesh = u_mesh
		u_node.material_override = u_mat
		u_node.position = center_star["pos"]
		add_child(u_node)
		system_view_nodes.append(u_node)
	
	# PHASE 5: Procedural Planetary Generation
	var prng = RandomNumberGenerator.new()
	# Binding hash seed directly to the star_index rigidly guarantees identical system configurations natively 
	prng.seed = hash(str(star_index) + "_system_seed") 
	
	var planet_data = get_system_planets(star_index)
	# Structurally duplicate rng state structurally consuming identical math to guarantee rotation sequence avoids collision!
	for i in range(100): prng.randf()

	for i in range(planet_data.size()):
		var p_info = planet_data[i]
		
		var p_pivot = Node3D.new()
		p_pivot.position = center_star["pos"]
		if center_star["name"] == "Sol":
			# Completely ignore directional constraints and spread real planets totally functionally around the core globally
			p_pivot.rotation.y = prng.randf_range(-PI, PI) 
		else:
			p_pivot.rotation.y = prng.randf_range(-PI * 0.45, PI * 0.45)
		add_child(p_pivot)
		system_view_nodes.append(p_pivot)
		
		var p_mesh = SphereMesh.new()
		p_mesh.radius = p_info["radius"]
		p_mesh.height = p_info["radius"] * 2.0
		
		# Critically .duplicate() materials from the global GPU cache so standard distinct shader maps don't overwrite!
		var p_mat = get_planet_material(p_info["type"]).duplicate()
		if p_info["type"] == "Rocky":
			p_mat.set_shader_parameter("base_color", p_info["c1"])
			p_mat.set_shader_parameter("rock_color", p_info["c2"])
		elif p_info["type"] == "Gas":
			p_mat.set_shader_parameter("band_color1", p_info["c1"])
			p_mat.set_shader_parameter("band_color2", p_info["c2"])
		elif p_info["type"] == "Habitable":
			p_mat.set_shader_parameter("water_color", p_info["c1"])
			p_mat.set_shader_parameter("land_color", p_info["c2"])
			p_mat.set_shader_parameter("cloud_color", p_info["c3"])
			
		var planet_node = MeshInstance3D.new()
		planet_node.mesh = p_mesh
		planet_node.material_override = p_mat
		planet_node.position.x = p_info["orbit"]
		
		var outer_boundary = p_mesh.radius
		if p_info.has("has_rings") and p_info["has_rings"]: 
			outer_boundary = p_mesh.radius * p_info["ring_outer"]
		
		var highlight_ring = MeshInstance3D.new()
		var hr_m = TorusMesh.new()
		hr_m.inner_radius = outer_boundary + 0.8
		hr_m.outer_radius = outer_boundary + 1.2
		highlight_ring.mesh = hr_m
		var hr_mat = StandardMaterial3D.new()
		hr_mat.albedo_color = Color(0.1, 0.7, 1.0, 0.4)
		hr_mat.emission_enabled = true
		hr_mat.emission = Color(0.1, 0.7, 1.0)
		hr_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hr_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		highlight_ring.material_override = hr_mat
		planet_node.add_child(highlight_ring)
		
		# Generative Rings natively aligned logically!
		if p_info.has("has_rings") and p_info["has_rings"]:
			var ring_node = MeshInstance3D.new()
			if p_info["name"] == "Uranus":
				ring_node.rotation.z = PI / 2.0 # Orthogonal axial tilt natively accurate
			var p_ring_mesh = PlaneMesh.new()
			var r_span = p_mesh.radius * p_info["ring_outer"] * 2.0
			p_ring_mesh.size = Vector2(r_span, r_span)
			ring_node.mesh = p_ring_mesh
			var r_inner_rel = p_info["ring_inner"] / p_info["ring_outer"]
			ring_node.material_override = get_ring_material(p_info["ring_color"], r_inner_rel)
			planet_node.add_child(ring_node)
		
		# 2. Planet Physics Hitbox
		var planet_area = Area3D.new()
		var p_col = CollisionShape3D.new()
		var p_shape = SphereShape3D.new()
		p_shape.radius = p_mesh.radius * 2.0 # Comfortable Hover bounds
		p_col.shape = p_shape
		planet_area.add_child(p_col)
		planet_node.add_child(planet_area)
		
		# 3. Modular UI Data Plate Pipeline with rigid zoom culling
		var ui_array = []
		var exact_text = p_info["name"]
		var is_habitable = (p_info["type"] == "Habitable")
		
		var display_text = exact_text
		if is_habitable: display_text = "       " + exact_text
		
		var p_width = max(6.0, display_text.length() * 0.8)
		var p_height = 2.5
		
		var plate_mesh = QuadMesh.new()
		plate_mesh.size = Vector2(p_width, p_height)
		var plate_node = MeshInstance3D.new()
		plate_node.mesh = plate_mesh
		plate_node.material_override = get_ui_plate_material(Vector2(p_width, p_height))
		plate_node.position = Vector3(0, -outer_boundary - 3.5, 0) # Anchored dynamically below extreme edges!
		plate_node.visibility_range_end = 120.0 
		plate_node.visibility_range_end_margin = 10.0
		plate_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		planet_node.add_child(plate_node)
		ui_array.append(plate_node)
		
		var p_label = Label3D.new()
		p_label.text = display_text
		p_label.font_size = 250
		p_label.position = Vector3(0, -outer_boundary - 3.5, 0.1) # 0.1 offset prevents fighting!
		p_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p_label.visibility_range_end = 120.0 # Strict culling when Camera pulls back
		p_label.visibility_range_end_margin = 10.0
		p_label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		p_label.extra_cull_margin = 16000.0 # Aggressively protects horizontal offset culling limits!
		planet_node.add_child(p_label)
		ui_array.append(p_label)
		
		if is_habitable:
			var icon = Label3D.new()
			icon.text = "🌐"
			icon.font_size = 250
			icon.modulate = Color(0.2, 1.0, 0.5) 
			icon.position = Vector3(0, -outer_boundary - 3.5, 0.12)
			icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			icon.visibility_range_end = 120.0 
			icon.visibility_range_end_margin = 10.0
			icon.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			icon.extra_cull_margin = 16000.0 # Binds bounds natively!
			
			var space_width = 7.0 * 55.0
			var text_width = exact_text.length() * 145.0
			var text_start_x = (space_width - text_width) / 2.0
			icon.offset = Vector2(text_start_x - 180.0, 0) # Scales explicit UI positioning perfectly
			
			planet_node.add_child(icon)
			ui_array.append(icon)
		
		# Pass the whole UI array structurally!
		planet_area.mouse_entered.connect(_on_planet_hover_enter.bind(ui_array))
		planet_area.mouse_exited.connect(_on_planet_hover_exit.bind(ui_array))
		
		# Hook up double-click explicit focusing bounding perfectly
		planet_area.input_event.connect(_on_planet_input_event.bind(planet_node, outer_boundary, highlight_ring))
		
		p_pivot.add_child(planet_node)
		
		# Trace thin procedural orbit rings physically mapping the layout!
		var orbit_ring = MeshInstance3D.new()
		var ring_t = TorusMesh.new()
		ring_t.inner_radius = p_info["orbit"] - 0.15
		ring_t.outer_radius = p_info["orbit"] + 0.15
		orbit_ring.mesh = ring_t
		var o_mat = StandardMaterial3D.new()
		o_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.15)
		o_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		o_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		orbit_ring.material_override = o_mat
		p_pivot.add_child(orbit_ring)
		
	var neighbors = adjacency_list[star_index]
	for n_idx in neighbors:
		var neighbor = star_data[n_idx]
		# Zero out the vertical dimension FIRST before normalizing, 
		# otherwise Z-height differences shrink the X/Z magnitude!
		var dir = (neighbor["pos"] - center_star["pos"])
		dir.y = 0 
		dir = dir.normalized()
		
		# Add +15.0 radius buffer to mathematically ensure the massive Label text geometry 
		# rests entirely outside the outer bounds of the TorusMesh ring.
		var marker_pos = center_star["pos"] + (dir * (ring_radius + 15.0))
		
		# Physics Area for arrow clicking
		var area = Area3D.new()
		add_child(area)
		area.position = marker_pos
		system_view_nodes.append(area)
		
		var ui_scale = max(1.0, ring_radius / 150.0)
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(25 * ui_scale, 20 * ui_scale, 25 * ui_scale) # Bigger hitbox for the bigger text
		col.shape = shape
		area.add_child(col)
		area.input_event.connect(_on_arrow_input_event.bind(n_idx))
		
		var arrow = Label3D.new()
		arrow.text = "➤"
		arrow.font_size = int(600 * ui_scale)
		arrow.modulate = Color(0.2, 0.8, 1.0)
		arrow.billboard = BaseMaterial3D.BILLBOARD_DISABLED 
		arrow.rotation.x = -PI/2 # Lay flat
		arrow.rotation.y = atan2(-dir.z, dir.x)
		area.add_child(arrow)
		
		var sys_label = Label3D.new()
		sys_label.text = neighbor["name"]
		sys_label.font_size = int(250 * ui_scale)
		sys_label.modulate = Color(1,1,1)
		sys_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sys_label.position = Vector3(0, 8.0 * ui_scale, 0)
		area.add_child(sys_label)

	if is_instance_valid(fleet_manager):
		fleet_manager.render_system_fleets(star_index)

func _on_arrow_input_event(camera, event, event_position, normal, shape_idx, target_star_index: int):
	# Single click an arrow instantly drops us into the adjacent system!
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cam = get_viewport().get_camera_3d()
		if cam and cam.has_method("focus_on_star"):
			var target_ring = max(275.0, sqrt(star_data[target_star_index]["mass"]) * 275.0)
			cam.focus_on_star(star_data[target_star_index]["pos"], true, target_ring)
			set_system_view(target_star_index)
			
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_instance_valid(fleet_manager) and fleet_manager.selected_fleets.size() > 0:
			for f in fleet_manager.selected_fleets:
				fleet_manager._order_fleet_jump(f, target_star_index)
			get_viewport().set_input_as_handled()

# --- Signals ---

func _on_star_hover_enter(star_index: int):
	if star_data[star_index].has("ui_plate_nodes"):
		for node in star_data[star_index]["ui_plate_nodes"]:
			if is_instance_valid(node): node.visibility_range_end = 0.0

func _on_star_hover_exit(star_index: int):
	if star_data[star_index].has("ui_plate_nodes"):
		for node in star_data[star_index]["ui_plate_nodes"]:
			if is_instance_valid(node): node.visibility_range_end = 250.0

func _on_planet_hover_enter(ui_nodes_array: Array):
	for node in ui_nodes_array:
		if is_instance_valid(node): node.visibility_range_end = 0.0

func _on_planet_hover_exit(ui_nodes_array: Array):
	for node in ui_nodes_array:
		if is_instance_valid(node): node.visibility_range_end = 120.0

var last_clicked_planet: Node3D = null
var last_planet_click_time: float = 0.0

func clear_planet_selection():
	if is_instance_valid(focused_planet_ring):
		var old_mat = focused_planet_ring.material_override
		if old_mat is StandardMaterial3D:
			old_mat.albedo_color = Color(0.1, 0.7, 1.0, 0.4)
			old_mat.emission = Color(0.1, 0.7, 1.0)
	if is_instance_valid(focused_planet_marker):
		focused_planet_marker.queue_free()
	focused_planet_ring = null

func _on_planet_input_event(camera, event, event_position, normal, shape_idx, p_node: Node3D, p_outer_boundary: float, p_ring: MeshInstance3D):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Single click natively confirmed! Reset old ring gracefully
		clear_planet_selection()
			
		focused_planet_ring = p_ring
		var new_mat = focused_planet_ring.material_override
		if new_mat is StandardMaterial3D:
			new_mat.albedo_color = Color(0.2, 1.0, 0.5, 0.4)
			new_mat.emission = Color(0.2, 1.0, 0.5)
			
		focused_planet_marker = Node3D.new()
		# Binds physically bounding limits natively rotating!
		p_node.add_child(focused_planet_marker)
		
		for i in range(4):
			var angle = i * (PI / 2.0)
			var inward_dir = Vector3(cos(angle), 0, -sin(angle)).normalized()
			var outward_dir = -inward_dir 
			
			var arr = Label3D.new()
			arr.text = "➤"
			arr.font_size = 400
			arr.modulate = Color(0.2, 1.0, 0.5)
			arr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			arr.rotation.x = -PI/2
			arr.rotation.y = atan2(-inward_dir.z, inward_dir.x)
			arr.position = outward_dir * (p_outer_boundary + 3.0) 
			focused_planet_marker.add_child(arr)
			
		create_tween().set_loops().tween_property(focused_planet_marker, "rotation:y", PI * 2.0, 8.0).as_relative()
		
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# If a fleet is locally natively selected structurally intercepting planetary right clicks explicitly!
		if is_instance_valid(fleet_manager) and fleet_manager.selected_fleets.size() > 0:
			var dest = Vector3(p_node.global_position.x, 15.0, p_node.global_position.z)
			for f in fleet_manager.selected_fleets:
				fleet_manager._order_fleet_move(f, dest)
			get_viewport().set_input_as_handled()

var last_clicked_star: int = -1
var last_click_time: float = 0.0

func _on_star_input_event(camera, event, event_position, normal, shape_idx, star_index: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_time = Time.get_ticks_msec() / 1000.0
		var cam = get_viewport().get_camera_3d()
		
		if cam and cam.has_method("focus_on_star"):
			# Manual Physics double-click detection
			if last_clicked_star == star_index and (current_time - last_click_time) < 0.4:
				var ring_radius = max(275.0, sqrt(star_data[star_index]["mass"]) * 275.0)
				cam.focus_on_star(star_data[star_index]["pos"], true, ring_radius)
				set_system_view(star_index)
				last_click_time = 0.0 # prevent triple execution
			else:
				# Single click does not pan camera anymore per user request
				last_clicked_star = star_index
				last_click_time = current_time

# --- Math Helpers ---
func _add_edge(u: int, v: int, edge_set: Dictionary, all_edges: Array):
	var edge_id = str(min(u, v)) + "_" + str(max(u, v))
	if not edge_set.has(edge_id):
		edge_set[edge_id] = true
		all_edges.append({"x": u, "y": v, "weight": 0.0})

func _find(parent: Array, i: int) -> int:
	if parent[i] == i: return i
	parent[i] = _find(parent, parent[i])
	return parent[i]

func _union(parent: Array, i: int, j: int):
	parent[_find(parent, i)] = _find(parent, j)
