extends Node3D
class_name FleetManager

var drag_start: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_rect: Rect2 = Rect2()

var selection_box: Control

# THE DATA-ORIENTED STATE
var global_fleets: Array[Dictionary] = []
var selected_fleets: Array[Dictionary] = []
var current_rendered_system: int = -1
var player_faction: String = "humans"

@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var galaxy_generator = get_parent()

func _ready():
	selection_box = Control.new()
	selection_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_box.draw.connect(_on_selection_box_draw)
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(selection_box)
	add_child(canvas)

func _process(delta: float):
	# Pure mathematical simulation loop updating tracking limits persistently globally ALWAYS!
	for fleet in global_fleets:
		if fleet["is_moving"]:
			var target = fleet["target_pos"]
			
			# Fallback for old active fleets without cached vectors intrinsically
			if not fleet.has("move_start_time"):
				fleet["move_start_pos"] = fleet["local_pos"]
				fleet["move_start_time"] = Time.get_unix_time_from_system()
				
			var total_dist = fleet["move_start_pos"].distance_to(target)
			var elapsed = float(Time.get_unix_time_from_system()) - fleet["move_start_time"]
			var current_dist = fleet["speed"] * elapsed
			
			if current_dist >= total_dist or total_dist <= 0.01:
				fleet["local_pos"] = target
				fleet["is_moving"] = false
				
				# Automatically trigger hyperspace physics immediately upon cleanly matching the exact edge boundary perfectly!
				if fleet.has("jump_target") and fleet["jump_target"] != -1:
					_execute_jump(fleet)
			else:
				# Interpolate mathematically precisely bridging real-time coordinates universally mapping system states inherently!
				fleet["local_pos"] = fleet["move_start_pos"].lerp(target, current_dist / total_dist)
				
		# Only push visual transforms IF the memory dictionary locally references active Godot primitives!
		if fleet.has("visual_node") and is_instance_valid(fleet["visual_node"]):
			var v_node = fleet["visual_node"]
			v_node.position = fleet["local_pos"]
			
			if fleet["is_moving"] and v_node.has_meta("waypoint_visuals"):
				var wp = v_node.get_meta("waypoint_visuals")
				if is_instance_valid(wp):
					var target = fleet["target_pos"]
					var distance = fleet["local_pos"].distance_to(target)
					wp.position = fleet["local_pos"].lerp(target, 0.5)
					
					var p_mesh = wp.get_node_or_null("LinePlane")
					if p_mesh:
						p_mesh.mesh.size = Vector2(0.8, distance)
						var l_mat = p_mesh.material_override
						if l_mat and l_mat is ShaderMaterial:
							l_mat.set_shader_parameter("scale_y", float(distance) / 1.5)
							
					if fleet["local_pos"].distance_squared_to(target) > 0.001:
						wp.look_at_from_position(wp.position, target, Vector3.UP)
						
					var e_circ = wp.get_node_or_null("EndCircle")
					if e_circ: e_circ.global_position = target
			elif not fleet["is_moving"] and v_node.has_meta("waypoint_visuals"):
				var wp = v_node.get_meta("waypoint_visuals")
				if is_instance_valid(wp): wp.queue_free()
				v_node.set_meta("waypoint_visuals", null)
				
		if fleet.has("is_jumping") and fleet["is_jumping"]:
			var path = fleet["hyperlane_path"]
			if path.size() > 1:
				var target_idx = path[1]
				var t_pos = galaxy_generator.star_data[target_idx]["pos"]
				var start_pos = fleet["map_local_pos"]
				var dist = start_pos.distance_to(t_pos)
				var elapsed = float(Time.get_unix_time_from_system()) - fleet["jump_start_time"]
				var cur_dist = 50.0 * elapsed
				
				fleet["map_render_pos"] = start_pos.lerp(t_pos, min(1.0, cur_dist / max(0.01, dist)))
				
				if cur_dist >= dist:
					fleet["map_local_pos"] = t_pos
					fleet["jump_start_time"] = Time.get_unix_time_from_system()
					var start_idx = fleet["hyperlane_path"].pop_front()
					
					fleet["is_jumping"] = false
					fleet["system_index"] = fleet["hyperlane_path"][0]
					
					var new_star = galaxy_generator.star_data[fleet["hyperlane_path"][0]]
					var old_star = galaxy_generator.star_data[start_idx]
					var travel_dir = (new_star["pos"] - old_star["pos"])
					travel_dir.y = 0
					travel_dir = travel_dir.normalized()
					
					var new_ring_rad = max(275.0, sqrt(new_star["mass"]) * 275.0)
					var entry_pos = new_star["pos"] - (travel_dir * new_ring_rad)
					entry_pos.y = galaxy_generator.get_system_plane_height(fleet["hyperlane_path"][0])
					
					fleet["local_pos"] = entry_pos
					fleet["target_pos"] = entry_pos
					
					if current_rendered_system == fleet["hyperlane_path"][0]:
						_instantiate_fleet_geometry(fleet)
						_play_warp_flash(entry_pos)
						
					if fleet["hyperlane_path"].size() <= 1:
						fleet.erase("target_system")
						if fleet.has("macro_wp") and is_instance_valid(fleet["macro_wp"]):
							fleet["macro_wp"].queue_free()
							fleet.erase("macro_wp")
							
						if fleet.has("final_local_target"):
							if fleet.has("pending_system_wp") and is_instance_valid(fleet["pending_system_wp"]):
								fleet["pending_system_wp"].queue_free()
								fleet.erase("pending_system_wp")
							order_fleet_move(fleet, fleet["final_local_target"])
							fleet.erase("final_local_target")
					else:
						var next_star = galaxy_generator.star_data[fleet["hyperlane_path"][1]]
						var t_dir = (next_star["pos"] - new_star["pos"])
						t_dir.y = 0
						t_dir = t_dir.normalized()
						var edge_pos = new_star["pos"] + (t_dir * new_ring_rad)
						edge_pos.y = galaxy_generator.get_system_plane_height(fleet["system_index"])
						
						order_fleet_move(fleet, edge_pos)
						fleet["jump_target"] = fleet["hyperlane_path"][1]
						if current_rendered_system == fleet["system_index"]:
							render_system_fleets(current_rendered_system)
		if fleet.has("hyperlane_path") and fleet["hyperlane_path"].size() > 1:
			if not fleet.has("macro_wp") or not is_instance_valid(fleet["macro_wp"]):
				var wp = Node3D.new()
				galaxy_generator.add_child(wp)
				fleet["macro_wp"] = wp
				
			var wp = fleet["macro_wp"]
			wp.visible = current_rendered_system == -1 and fleet.get("selected", false)
			if wp.visible:
				var path = fleet["hyperlane_path"]
				var trace_pts = []
				
				if fleet.has("is_jumping") and fleet["is_jumping"]:
					trace_pts.append(fleet.get("map_render_pos", fleet["map_local_pos"]))
				else:
					trace_pts.append(galaxy_generator.star_data[path[0]]["pos"])
					
				for i in range(1, path.size()):
					trace_pts.append(galaxy_generator.star_data[path[i]]["pos"])
					
				var child_count = wp.get_child_count()
				while child_count < trace_pts.size() - 1:
					var l_node = MeshInstance3D.new()
					l_node.mesh = PlaneMesh.new()
					l_node.material_override = _get_waypoint_shader()
					l_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					wp.add_child(l_node)
					child_count += 1
				while child_count > trace_pts.size() - 1:
					wp.get_child(child_count - 1).queue_free()
					child_count -= 1
					
				for i in range(trace_pts.size() - 1):
					var p1 = trace_pts[i]
					var p2 = trace_pts[i+1]
					var seg_dist = p1.distance_to(p2)
					if seg_dist > 0.1:
						var l_node = wp.get_child(i)
						l_node.mesh.size = Vector2(2.5, seg_dist) 
						l_node.position = (p1 + p2) / 2.0
						l_node.look_at_from_position((p1 + p2) / 2.0, p2, Vector3.UP)
						if l_node.material_override is ShaderMaterial:
							l_node.material_override.set_shader_parameter("scale_y", max(1.0, seg_dist / 6.0))

# --- Selection Logic ---
func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_start = event.position
			drag_rect = Rect2(drag_start, Vector2.ZERO)
			selection_box.queue_redraw()
		else:
			if is_dragging:
				is_dragging = false
				selection_box.queue_redraw()
				_execute_selection()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if selected_fleets.size() > 0:
			if current_rendered_system != -1:
				var plane_y = galaxy_generator.star_data[current_rendered_system].get("fleet_plane_height", 15.0)
				var intersection_plane = Plane(Vector3.UP, plane_y)
				var click_hit = intersection_plane.intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
				if click_hit != null:
					var c_star = galaxy_generator.star_data[current_rendered_system]
					var ring_rad = max(275.0, sqrt(c_star["mass"]) * 275.0)
					
					# Mathematical Clamp: Reject fleet movement cleanly if commanded physically outside localized system rings natively!
					if Vector2(click_hit.x, click_hit.z).distance_to(Vector2(c_star["pos"].x, c_star["pos"].z)) <= ring_rad:
						for f in selected_fleets:
							dispatch_fleet_to_system_pos(f, current_rendered_system, click_hit)
			else:
				var hit_star = false
				for i in range(galaxy_generator.star_data.size()):
					var s_pos = galaxy_generator.star_data[i]["pos"]
					var s_screen = camera.unproject_position(s_pos)
					if not camera.is_position_behind(s_pos) and s_screen.distance_to(event.position) < 45.0:
						var f_copy = selected_fleets.duplicate()
						for f in f_copy:
							var start_loc = f["system_index"] if f.has("system_index") and f["system_index"] != -1 else f.get("target_system", -1)
							if start_loc != -1 and start_loc != i:
								var path = galaxy_generator.get_hyperlane_path(start_loc, i)
								if path.size() > 1: order_intersystem_jump(f, path, i)
						hit_star = true
						break
						
				# Natively explicitly strip bounds unconditionally upon void right clicks on Map modes exclusively!
				if not hit_star:
					clear_selection()
	if event is InputEventMouseMotion and is_dragging:
		drag_rect.position = Vector2(min(drag_start.x, event.position.x), min(drag_start.y, event.position.y))
		drag_rect.size = Vector2(abs(drag_start.x - event.position.x), abs(drag_start.y - event.position.y))
		selection_box.queue_redraw()

func _on_selection_box_draw():
	if is_dragging and drag_rect.size.length() > 5.0:
		selection_box.draw_rect(drag_rect, Color(0.2, 1.0, 0.5, 0.15), true)
		selection_box.draw_rect(drag_rect, Color(0.2, 1.0, 0.5, 0.8), false, 2.0)

func _execute_selection():
	var newly_selected: Array[Dictionary] = []
	var single_click = drag_rect.size.length() < 5.0
	
	for fleet in global_fleets:
		if current_rendered_system == -1:
			# Galaxy Map Selection Projection natively unrolling!
			if fleet.has("system_index") and fleet["system_index"] != -1:
				var star_pos = galaxy_generator.star_data[fleet["system_index"]]["pos"]
				var map_node_pos = star_pos + Vector3(6.0, 0, 0)
				
				# Check macro jump offsets dynamically natively prioritizing live movement paths mathematically
				if fleet.has("is_jumping") and fleet["is_jumping"] and fleet.has("map_render_pos"):
					map_node_pos = fleet["map_render_pos"] + Vector3(6.0, 0, 0)
				
				var screen_pos = camera.unproject_position(map_node_pos)
				if not camera.is_position_behind(map_node_pos):
					if single_click and screen_pos.distance_to(drag_start) < 45.0:
						newly_selected.append(fleet)
						break
		else:
			# Local System Projection natively enforcing standard rules
			if fleet["system_index"] != current_rendered_system: continue
			if not fleet.has("visual_node") or not is_instance_valid(fleet["visual_node"]): continue
			
			var screen_pos = camera.unproject_position(fleet["local_pos"])
			if camera.is_position_behind(fleet["local_pos"]): continue
			
			if single_click:
				if screen_pos.distance_to(drag_start) < 25.0:
					newly_selected.append(fleet)
					break 
			else:
				if drag_rect.has_point(screen_pos):
					newly_selected.append(fleet)
				
	if newly_selected.size() > 0:
		_apply_selection(newly_selected)
	elif single_click:
		var hit_star = false
		if current_rendered_system == -1:
			for i in range(galaxy_generator.star_data.size()):
				var s_pos = galaxy_generator.star_data[i]["pos"]
				var s_screen = camera.unproject_position(s_pos)
				if not camera.is_position_behind(s_pos) and s_screen.distance_to(drag_start) < 45.0:
					hit_star = true
					break
		if not hit_star:
			_clear_selection()

func _apply_selection(fleets: Array[Dictionary]):
	_clear_selection()
	selected_fleets = fleets
	for f in selected_fleets:
		_set_fleet_focus_visuals(f, true)
		
	if galaxy_generator.has_method("clear_planet_selection"):
		galaxy_generator.clear_planet_selection()
		
	if selected_fleets.size() > 0:
		var uim = get_node_or_null("/root/Main/CanvasLayer")
		if uim and uim.has_method("open_and_scroll_to_fleet"):
			uim.open_and_scroll_to_fleet(selected_fleets[0])

func set_selection(fleets: Array):
	var typed_fleets: Array[Dictionary] = []
	typed_fleets.assign(fleets)
	_apply_selection(typed_fleets)

func clear_selection():
	_clear_selection()

func _clear_selection():
	for f in selected_fleets:
		_set_fleet_focus_visuals(f, false)
	selected_fleets.clear()

# --- Visual Logic ---
func _set_fleet_focus_visuals(fleet: Dictionary, active: bool):
	fleet["selected"] = active
	
	if fleet.has("visual_node") and is_instance_valid(fleet["visual_node"]):
		var ship = fleet["visual_node"]
		var marker = ship.get_node_or_null("FocusMarker")
		
		if active and marker == null:
			marker = Node3D.new()
			marker.name = "FocusMarker"
			ship.add_child(marker)
			for i in range(4):
				var angle = i * (PI / 2.0)
				var inward_dir = Vector3(cos(angle), 0, -sin(angle)).normalized()
				var arr = Label3D.new()
				arr.text = "➤"
				arr.font_size = 350
				arr.modulate = Color(0.2, 1.0, 0.5)
				arr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				arr.rotation.x = -PI/2
				arr.rotation.y = atan2(-inward_dir.z, inward_dir.x)
				arr.position = -inward_dir * 3.5 
				marker.add_child(arr)
			var t = create_tween().bind_node(marker).set_loops()
			t.tween_property(marker, "rotation:y", PI * 2.0, 6.0).as_relative()
		elif not active and marker != null:
			marker.name = "freed" # Free up the path instantly natively preventing same-frame re-selection pointer lookup collision!
			marker.queue_free()
			
		if ship.has_meta("waypoint_visuals") and is_instance_valid(ship.get_meta("waypoint_visuals")):
			ship.get_meta("waypoint_visuals").visible = active

func _spawn_pending_system_waypoint(fleet: Dictionary, entry_pos: Vector3, click_hit: Vector3):
	if fleet.has("pending_system_wp") and is_instance_valid(fleet["pending_system_wp"]):
		fleet["pending_system_wp"].queue_free()
		
	var wp = Node3D.new()
	wp.name = "PendingWaypointNode"
	add_child(wp)
	
	var distance = entry_pos.distance_to(click_hit)
	wp.position = entry_pos.lerp(click_hit, 0.5)
	
	# Aim correctly strictly mathematically isolating the local horizon correctly explicitly	
	var local_dir = (click_hit - entry_pos).normalized()
	wp.rotation.y = atan2(-local_dir.x, -local_dir.z)

	var line_node = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(0.8, distance)
	line_node.name = "LinePlane"
	line_node.mesh = plane_mesh
	line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var wp_mat = _get_waypoint_shader()
	wp_mat.set_shader_parameter("scale_y", float(distance) / 1.5)
	line_node.material_override = wp_mat
	wp.add_child(line_node)
	
	var dest_node = MeshInstance3D.new()
	dest_node.name = "EndCircle"
	dest_node.position = Vector3(0, 0, distance * -0.5) # Match PlaneMesh geometry coordinates natively
	var t_mesh = TorusMesh.new()
	t_mesh.inner_radius = 2.0
	t_mesh.outer_radius = 2.3
	dest_node.mesh = t_mesh
	var dest_mat = StandardMaterial3D.new()
	dest_mat.albedo_color = Color(0.2, 1.0, 0.5, 0.7)
	dest_mat.emission_enabled = true
	dest_mat.emission = Color(0.2, 1.0, 0.5)
	dest_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dest_node.material_override = dest_mat
	wp.add_child(dest_node)
	
	fleet["pending_system_wp"] = wp

func dispatch_fleet_to_system_pos(fleet: Dictionary, target_system: int, target_pos: Vector3):
	var start_loc = fleet["system_index"] if fleet.has("system_index") and fleet["system_index"] != -1 else fleet.get("target_system", -1)
	if fleet.has("is_jumping") and fleet["is_jumping"] and fleet.has("hyperlane_path") and fleet["hyperlane_path"].size() > 0:
		start_loc = fleet["hyperlane_path"][0]

	if start_loc != -1 and start_loc != target_system:
		var path = galaxy_generator.get_hyperlane_path(start_loc, target_system)
		if path.size() > 1:
			order_intersystem_jump(fleet, path, target_system)
			fleet["final_local_target"] = target_pos
			
			var c_star = galaxy_generator.star_data[target_system]
			var ring_rad = max(275.0, sqrt(c_star["mass"]) * 275.0)
			var prev_sys = path[path.size()-2] if path.size() >= 2 else start_loc
			var prev_star = galaxy_generator.star_data[prev_sys]
			var t_dir = (c_star["pos"] - prev_star["pos"])
			t_dir.y = 0
			t_dir = t_dir.normalized()
			var entry_pos = c_star["pos"] - (t_dir * ring_rad)
			entry_pos.y = galaxy_generator.get_system_plane_height(target_system)
			
			_spawn_pending_system_waypoint(fleet, entry_pos, target_pos)
	else:
		fleet["jump_target"] = -1 # Purge queued hyper-jumps instantly logically overriding dynamically!
		order_fleet_move(fleet, target_pos)

func order_fleet_move(fleet: Dictionary, target_pos: Vector3):
	fleet["target_pos"] = target_pos
	fleet["move_start_pos"] = fleet["local_pos"]
	fleet["move_start_time"] = float(Time.get_unix_time_from_system())
	fleet["is_moving"] = true
	
	# Only spawn local WP nodes if we are explicitly literally looking at it!
	if fleet["system_index"] == current_rendered_system and fleet.has("visual_node") and is_instance_valid(fleet["visual_node"]):
		var ship = fleet["visual_node"]
		if ship.has_meta("waypoint_visuals") and is_instance_valid(ship.get_meta("waypoint_visuals")):
			ship.get_meta("waypoint_visuals").queue_free()
			
		var wp = Node3D.new()
		wp.name = "WaypointNode"
		add_child(wp)
		# ... wp geometry setup
		var line_node = MeshInstance3D.new()
		var plane_mesh = PlaneMesh.new()
		line_node.name = "LinePlane"
		line_node.mesh = plane_mesh
		line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line_node.material_override = _get_waypoint_shader()
		wp.add_child(line_node)
		var dest_node = MeshInstance3D.new()
		dest_node.name = "EndCircle"
		var t_mesh = TorusMesh.new()
		t_mesh.inner_radius = 2.0
		t_mesh.outer_radius = 2.3
		dest_node.mesh = t_mesh
		var dest_mat = StandardMaterial3D.new()
		dest_mat.albedo_color = Color(0.2, 1.0, 0.5, 0.7)
		dest_mat.emission_enabled = true
		dest_mat.emission = Color(0.2, 1.0, 0.5)
		dest_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dest_node.material_override = dest_mat
		wp.add_child(dest_node)
		
		ship.set_meta("waypoint_visuals", wp)
		if not fleet["selected"]: wp.visible = false

func order_fleet_jump(fleet: Dictionary, target_sys: int):
	var curr_idx = fleet["system_index"]
	if curr_idx != -1:
		var path = [curr_idx, target_sys]
		order_intersystem_jump(fleet, path, target_sys)

func _execute_jump(fleet: Dictionary):
	var next_sys = fleet["jump_target"]
	fleet["jump_target"] = -1
	
	if fleet.has("hyperlane_path") and fleet["hyperlane_path"].size() > 1:
		if fleet.has("visual_node") and is_instance_valid(fleet["visual_node"]):
			_play_warp_flash(fleet["visual_node"].global_position)
			if fleet["visual_node"].has_meta("waypoint_visuals"):
				var wp = fleet["visual_node"].get_meta("waypoint_visuals")
				if is_instance_valid(wp): wp.queue_free()
			fleet["visual_node"].queue_free()
			fleet.erase("visual_node")
			
		fleet["is_jumping"] = true
		fleet["jump_start_time"] = Time.get_unix_time_from_system()
		var c_sys = fleet["system_index"] if fleet["system_index"] != -1 else fleet["hyperlane_path"][0]
		fleet["map_local_pos"] = galaxy_generator.star_data[c_sys]["pos"]
		fleet["map_render_pos"] = fleet["map_local_pos"]
		fleet["system_index"] = -1

func _play_warp_flash(pos: Vector3):
	# Mimic explicitly the Cherenkov plasma bloom physically mirroring the Pulsar Horizon shader!
	var flash_mesh = PlaneMesh.new()
	flash_mesh.size = Vector2(40.0, 40.0)
	
	var f_mat = ShaderMaterial.new()
	f_mat.shader = load("res://Shaders/warp_flash.gdshader")
	
	var flash_node = MeshInstance3D.new()
	flash_node.mesh = flash_mesh
	flash_node.material_override = f_mat
	flash_node.position = pos
	
	# Billboard dynamically exactly mimicking a perfect volumetric sphere glow regardless of camera angle
	var mat_override_internal = StandardMaterial3D.new() # We inject billboard natively via standard geometry tracking
	flash_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash_node)
	
	# Manually orient to face active camera properly explicitly identically
	var cam = get_viewport().get_camera_3d()
	if cam:
		flash_node.look_at(cam.global_position, Vector3.UP)
		flash_node.rotate_x(PI/2) # PlaneMesh aligns flat initially, stand it up towards the lens!
	
	var t = create_tween().set_parallel(true)
	
	flash_node.scale = Vector3(0.01, 0.01, 0.01)
	t.tween_property(flash_node, "scale", Vector3(1.5, 1.5, 1.5), 0.15).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v): f_mat.set_shader_parameter("explosion_alpha", v), 1.0, 0.0, 0.6).set_delay(0.05)
	
	t.chain().tween_callback(flash_node.queue_free)

var _cached_waypoint_shader: ShaderMaterial = null
func _get_waypoint_shader() -> ShaderMaterial:
	if _cached_waypoint_shader != null: return _cached_waypoint_shader.duplicate()
	var mat = ShaderMaterial.new()
	mat.shader = load("res://Shaders/fleet_waypoint.gdshader")
	_cached_waypoint_shader = mat
	return mat.duplicate()

# --- Orchestration Methods ---
func create_fleet(sys_index: int, start_local_pos: Vector3, fleet_class: String = "military"):
	var class_count = 0
	for f in global_fleets:
		if f.has("fleet_class") and f["fleet_class"] == fleet_class:
			class_count += 1
			
	var fleet_name = fleet_class.capitalize() + " Fleet " + str(class_count + 1)
	
	var p_y = 15.0
	if is_instance_valid(galaxy_generator):
		p_y = galaxy_generator.get_system_plane_height(sys_index)
		
	var data = {
		"system_index": sys_index,
		"local_pos": Vector3(start_local_pos.x, p_y, start_local_pos.z),
		"target_pos": Vector3(start_local_pos.x, p_y, start_local_pos.z),
		"is_moving": false,
		"speed": 18.0,
		"selected": false,
		"fleet_class": fleet_class,
		"faction": "humans",
		"name": fleet_name,
		"is_jumping": false # Inter-system persistent state flag formally attached!
	}
	global_fleets.append(data)

func order_intersystem_jump(fleet: Dictionary, path: Array, final_dest: int):
	if fleet.has("is_jumping") and fleet["is_jumping"]:
		fleet["hyperlane_path"] = path
		fleet["target_system"] = final_dest
		return
		
	fleet["hyperlane_path"] = path
	fleet["target_system"] = final_dest
	
	var curr_idx = fleet["system_index"]
	if curr_idx != -1:
		var c_star = galaxy_generator.star_data[curr_idx]
		var t_star = galaxy_generator.star_data[path[1]]
		
		var dir = (t_star["pos"] - c_star["pos"])
		dir.y = 0
		dir = dir.normalized()
		
		var ring_rad = max(275.0, sqrt(c_star["mass"]) * 275.0)
		var edge_pos = c_star["pos"] + Vector3(dir.x * ring_rad, 0, dir.z * ring_rad)
		edge_pos.y = galaxy_generator.get_system_plane_height(curr_idx)
		
		order_fleet_move(fleet, edge_pos)
		fleet["jump_target"] = path[1]

func render_system_fleets(sys_index: int):
	# Safely wipes any visual noise before painting securely manually
	clear_ships()
	current_rendered_system = sys_index
	
	for fleet in global_fleets:
		if fleet["system_index"] == sys_index:
			_instantiate_fleet_geometry(fleet)
		elif fleet.get("target_system", -1) == sys_index and fleet.has("final_local_target"):
			var start_loc = fleet["system_index"] if fleet["system_index"] != -1 else fleet.get("target_system", -1)
			if fleet.has("is_jumping") and fleet["is_jumping"] and fleet.has("hyperlane_path") and fleet["hyperlane_path"].size() > 0:
				start_loc = fleet["hyperlane_path"][0] # Enforce actively transitioning logical starting points seamlessly

			var path = galaxy_generator.get_hyperlane_path(start_loc, sys_index)
			if path.size() >= 1:
				var c_star = galaxy_generator.star_data[sys_index]
				var ring_rad = max(275.0, sqrt(c_star["mass"]) * 275.0)
				var prev_sys = path[path.size()-2] if path.size() >= 2 else start_loc
				var prev_star = galaxy_generator.star_data[prev_sys]
				var t_dir = (c_star["pos"] - prev_star["pos"])
				t_dir.y = 0
				t_dir = t_dir.normalized()
				var entry_pos = c_star["pos"] - (t_dir * ring_rad)
				entry_pos.y = galaxy_generator.get_system_plane_height(sys_index)
				_spawn_pending_system_waypoint(fleet, entry_pos, fleet["final_local_target"])

func _instantiate_fleet_geometry(fleet: Dictionary):
	var ship_node = Node3D.new()
	ship_node.position = fleet["local_pos"]
	
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	mesh_inst.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0) # Base invisible
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 0.0
	mesh_inst.material_override = mat
	ship_node.add_child(mesh_inst)
	
	var t = create_tween().bind_node(ship_node).set_loops()
	t.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	t.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 1.5)
	t.tween_property(mat, "albedo_color:a", 1.0, 0.1)
	t.parallel().tween_property(mat, "emission_energy_multiplier", 15.0, 0.1)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	t.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.2)
	
	var ring = MeshInstance3D.new()
	var ring_m = TorusMesh.new()
	ring_m.inner_radius = 1.8
	ring_m.outer_radius = 2.1
	ring.mesh = ring_m
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.2, 1.0, 0.5, 0.85)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.2, 1.0, 0.5)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	ship_node.add_child(ring)
	
	var class_sprite = Sprite3D.new()
	var class_img = Image.new()
	var icon_path = "res://Resources/icon_fleet.png"
	
	if fleet.has("fleet_class"):
		if fleet["fleet_class"] == "construction":
			icon_path = "res://Resources/icon_constructor.png"
		elif fleet["fleet_class"] == "colonizer":
			icon_path = "res://Resources/icon_colonizer.png"
			
	if class_img.load(icon_path) == OK:
		class_sprite.texture = ImageTexture.create_from_image(class_img)
		
	class_sprite.position = Vector3(4.0, 0.0, 0.0) # Render physically outside the selection binding ring native!
	class_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	class_sprite.pixel_size = 0.003
	class_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	class_sprite.transparent = true
	class_sprite.cast_shadow = false
	class_sprite.shaded = false
	ship_node.add_child(class_sprite)
	
	add_child(ship_node)
	fleet["visual_node"] = ship_node
	
	# Retrigger active state visualizations natively
	if fleet["selected"]:
		_set_fleet_focus_visuals(fleet, true)
	if fleet["is_moving"]:
		order_fleet_move(fleet, fleet["target_pos"])

func clear_ships():
	current_rendered_system = -1
	for f in global_fleets:
		if f.has("visual_node") and is_instance_valid(f["visual_node"]):
			var wp = f["visual_node"].get_meta("waypoint_visuals") if f["visual_node"].has_meta("waypoint_visuals") else null
			if is_instance_valid(wp): wp.queue_free()
			f["visual_node"].queue_free()
			f.erase("visual_node")
			
		if f.has("pending_system_wp") and is_instance_valid(f["pending_system_wp"]):
			f["pending_system_wp"].queue_free()
			f.erase("pending_system_wp")

func get_transit_time_remaining(fleet: Dictionary) -> float:
	var total_time = 0.0
	
	if fleet.get("is_moving", false) and fleet.has("target_pos") and fleet.has("local_pos"):
		total_time += fleet["local_pos"].distance_to(fleet["target_pos"]) / fleet["speed"]
		
	if fleet.has("hyperlane_path") and fleet["hyperlane_path"].size() > 1:
		if fleet.get("is_jumping", false):
			var t_pos = galaxy_generator.star_data[fleet["hyperlane_path"][1]]["pos"]
			var dist = fleet["map_local_pos"].distance_to(t_pos)
			
			# Compensate directly natively tracking partial completion across the node mathematically!
			var elapsed = float(Time.get_unix_time_from_system()) - fleet.get("jump_start_time", float(Time.get_unix_time_from_system()))
			var remaining_dist = max(0.0, dist - (50.0 * elapsed))
			total_time += remaining_dist / 50.0
			
		var start_idx = 1 if fleet.get("is_jumping", false) else 0
		for i in range(start_idx, fleet["hyperlane_path"].size() - 1):
			var s_idx = fleet["hyperlane_path"][i]
			var t_idx = fleet["hyperlane_path"][i+1]
			var s_pos = galaxy_generator.star_data[s_idx]["pos"]
			var t_pos = galaxy_generator.star_data[t_idx]["pos"]
			total_time += s_pos.distance_to(t_pos) / 50.0
			
			# Only add intermediate system sublight crossing structural delays sequentially!
			if i > 0:
				var rad_s = max(275.0, sqrt(galaxy_generator.star_data[s_idx]["mass"]) * 275.0)
				total_time += (rad_s * 2.0) / fleet["speed"]
			
		if fleet.has("final_local_target") and typeof(fleet["final_local_target"]) == TYPE_VECTOR3:
			var dest_star = galaxy_generator.star_data[fleet["target_system"]]
			var rad_dest = max(275.0, sqrt(dest_star["mass"]) * 275.0)
			total_time += rad_dest / fleet["speed"]
			
	return total_time
