extends RigidBody3D

# Adjust this value to control the movement speed.
var move_speed : float = 20.0

func _physics_process(delta: float) -> void:
	# Get the input vector from custom actions.
	# "move_left" maps to negative X, "move_right" maps to positive X.
	# "move_forward" maps to negative Y (so forward gives -1) and "move_backward" maps to positive Y.
	var input_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Convert the 2D input vector to a 3D direction.
	# Here, X remains the same and the 2D Y is used as Z.
	# This assumes that a negative Y (from "move_forward") corresponds to moving in the negative Z direction (Godot's forward).
	var direction : Vector3 = Vector3(input_vector.x, 0, input_vector.y)
	
	# If there is any input, apply a central force.
	if direction != Vector3.ZERO:
		# Normalize the direction and scale it by the movement speed.
		var force : Vector3 = direction.normalized() * move_speed
		apply_central_force(force)
