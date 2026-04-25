extends Camera3D

# Camera movement speed
@export var move_speed = 10.0
# Mouse sensitivity
@export var mouse_sensitivity = 0.2

# Rotation angles
var rotation_x = 0.0
var rotation_y = 0.0

func _ready():
	# Capture the mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta):
	# Camera movement
	var direction = Vector3()
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"):
		direction += transform.basis.x
	
	direction = direction.normalized()
	if direction != Vector3():
		translate(direction * move_speed * delta)

func _input(event):
	if event is InputEventMouseMotion:
		# Camera rotation
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_y -= event.relative.x * mouse_sensitivity
		
		rotation_x = clamp(rotation_x, -90, 90)
		
		rotation_degrees.x = rotation_x
		rotation_degrees.y = rotation_y
	elif event is InputEventKey and event.pressed:
			# Toggle mouse capture mode
			if event.keycode == KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

