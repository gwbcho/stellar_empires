extends Camera3D
class_name CameraController

@export var pan_speed: float = 400.0
@export var zoom_speed: float = 60.0
@export var min_zoom: float = 50.0
@export var max_zoom: float = 900.0  
@export var map_bounds: float = 1000.0 

var is_focused: bool = false
var in_system_view: bool = false
var dragging: bool = false
var last_mouse_pos: Vector2
var active_tween: Tween
var overscroll_amount: float = 0.0
var system_zoom_ceiling: float = 250.0

# Cached initial state for the galactic map
var galaxy_pos: Vector3 = Vector3(0, 700, 500)
var galaxy_rot: Vector3 = Vector3(-deg_to_rad(60), 0, 0)
var current_target_pos: Vector3

@onready var generator = $"../GalaxyGenerator"

func _ready():
	rotation = galaxy_rot
	position = galaxy_pos
	far = 45000.0 # Extend Z-far clipping explicitly preventing macro-scale geometry decapitation!

func _input(event):
	if is_focused: return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			last_mouse_pos = event.position
			
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if overscroll_amount > 0.0:
				# Consume scroll intent mathematically preventing hardware bounce ghosts from breaking physics
				overscroll_amount -= zoom_speed
				overscroll_amount = max(0.0, overscroll_amount)
			else:
				var forward = -transform.basis.z
				var next_pos = position + forward * zoom_speed
				if next_pos.y >= min_zoom:
					position = next_pos
				
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var forward = -transform.basis.z
			var next_pos = position - forward * zoom_speed
			
			if in_system_view:
				# Single strict boundary threshold tracking multiple physical inputs cumulatively!
				if position.y >= system_zoom_ceiling - 1.0:
					overscroll_amount += zoom_speed
					if overscroll_amount >= (zoom_speed * 10.0): # ~4 smooth scroll clicks
						overscroll_amount = 0.0
						return_to_galaxy()
				else:
					position = next_pos
			elif next_pos.y <= max_zoom:
				position = next_pos
				
	elif event is InputEventMouseMotion and dragging:
		var delta_pos = event.position - last_mouse_pos
		last_mouse_pos = event.position
		var right = transform.basis.x
		var up_flat = Vector3(0, 0, -1) 
		position += (-right * delta_pos.x + -up_flat * delta_pos.y) * 0.5
		
	clamp_camera_bounds()

func _process(delta):
	if is_focused: return
		
	var move_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move_dir += Vector3(0, 0, -1)
	if Input.is_key_pressed(KEY_S): move_dir += Vector3(0, 0, 1)
	if Input.is_key_pressed(KEY_A): move_dir += Vector3(-1, 0, 0)
	if Input.is_key_pressed(KEY_D): move_dir += Vector3(1, 0, 0)
		
	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()
		position += move_dir * pan_speed * delta

	clamp_camera_bounds()

func clamp_camera_bounds():
	if in_system_view:
		position.y = clamp(position.y, min_zoom, system_zoom_ceiling) # Restrict local height dynamically 
		# Create a horizontal invisible boundary proportional to the massive ring size!
		var horizontal_pos = Vector2(position.x - current_target_pos.x, position.z - current_target_pos.z)
		var trans_bounds = system_zoom_ceiling * 1.5
		if horizontal_pos.length() > trans_bounds:
			horizontal_pos = horizontal_pos.normalized() * trans_bounds
			position.x = current_target_pos.x + horizontal_pos.x
			position.z = current_target_pos.z + horizontal_pos.y
	else:
		position.y = clamp(position.y, min_zoom, max_zoom)
		var horizontal_pos = Vector2(position.x, position.z)
		if horizontal_pos.length() > map_bounds:
			horizontal_pos = horizontal_pos.normalized() * map_bounds
			position.x = horizontal_pos.x
			position.z = horizontal_pos.y


func focus_on_star(star_pos: Vector3, enter_system: bool, target_radius: float = 50.0):
	if is_focused and current_target_pos == star_pos and in_system_view == enter_system: return
	
	is_focused = true
	current_target_pos = star_pos
	
	if active_tween:
		active_tween.kill()
	
	var target_cam_pos = star_pos
	active_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	if enter_system:
		in_system_view = true
		overscroll_amount = 0.0
		min_zoom = 5.0 
		
		# Calculates exactly how high we need to place the camera base to fit a 60 degree FoV!
		var required_radius = target_radius + 60.0 # UI padding
		system_zoom_ceiling = max(100.0, required_radius * 1.5)
		
		# Offset proportionately to the required frame width!
		target_cam_pos += Vector3(0, system_zoom_ceiling * 0.8, system_zoom_ceiling * 0.9) 
		
		# Rotate camera to look at the star 3D geometry
		var dummy = Node3D.new()
		get_parent().add_child(dummy) 
		dummy.global_position = target_cam_pos
		dummy.look_at(star_pos, Vector3.UP)
		var target_rot = dummy.rotation
		dummy.queue_free()
		
		active_tween.tween_property(self, "rotation", target_rot, 1.2)
		
	active_tween.tween_property(self, "position", target_cam_pos, 1.2)
	active_tween.chain().tween_callback(func(): is_focused = false)


func return_to_galaxy():
	if not in_system_view: return
	
	is_focused = true
	in_system_view = false
	overscroll_amount = 0.0
	min_zoom = 50.0 # Restores deeply generous macro limits directly allowing text zoom!
	
	if generator.has_method("set_galactic_view"):
		generator.set_galactic_view()
	
	if active_tween:
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	active_tween.tween_property(self, "position", galaxy_pos, 1.2)
	active_tween.tween_property(self, "rotation", galaxy_rot, 1.2)
	active_tween.chain().tween_callback(func(): is_focused = false)
