extends Camera

const right_angle = 0.25 * TAU

var move_input := Vector2.ZERO
var move_y := 0.0
var mouse := Vector2.ZERO
var movement := Vector3.ZERO


func _ready():
	# Capture mouse
	Input.set_mouse_mode(2)


func _process(delta: float):
	if Input.get_mouse_mode() > 0:
		rotate_y(-0.25 * mouse.x * delta)  # yaw globally
		rotate(transform.basis.x, -0.25 * mouse.y * delta)  # pitch locally
		if global_transform.basis.y.y < 0.0:
			rotate(transform.basis.x, 0.25 * mouse.y * delta)
	# Reset mouse vector to avoid drift
	mouse = Vector2.ZERO
	
	# Movement input
	var input = global_transform.basis * Vector3(move_input.x, move_y, move_input.y)
	movement = movement.linear_interpolate(0.1 * input, 10 * delta)
	global_transform.origin += movement


func _unhandled_input(event: InputEvent):
	# Mouse control
	if event is InputEventMouseMotion:
		mouse = event.relative
	# Mouse control toggle
	if event is InputEventMouseButton and event.is_pressed():
		if event.get_button_index() == BUTTON_LEFT:
			Input.set_mouse_mode(-Input.get_mouse_mode() + 2)
	
	move_input = Input.get_vector('ui_left', 'ui_right', 'ui_up', 'ui_down')
	move_y = Input.get_axis('ui_select', 'ui_accept')
