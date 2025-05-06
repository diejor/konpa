# Marble.gd - Optimized and clarified

class_name Marble
extends RigidBody3D

# ────────────────────────── Tunables ────────────────────────── #
@export var drag_radius_px: float = 1800.0    # Pixel radius for drag-to-tilt mapping
@export var max_tilt_deg: float = 180.0       # Maximum tilt angle in degrees
@export var tilt_speed: float = 4.0           # How quickly the marble tilts toward target
@export var gravity_strength: float = 9.8     # Base gravity magnitude
@export var gravity_s: float = 6.0        # Gravity force multiplier

# RayCast to visualize gravity direction in tool/editor
@onready var gravity_ray: RayCast3D = $Gravity

# ───────────────────────── State ───────────────────────────── #
var dragging: bool = false
var start_mouse_pos: Vector2 = Vector2.ZERO
var target_rotation: Quaternion = Quaternion.IDENTITY
var current_rotation: Quaternion = Quaternion.IDENTITY

signal tilt_changed(new_rotation: Quaternion)

# ─────────────────────── Input Handling ────────────────────── #
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Begin dragging: record start and preserve current tilt
			dragging = true
			start_mouse_pos = event.position
			target_rotation = current_rotation
		else:
			# End dragging: reset tilt to upright
			dragging = false
			target_rotation = Quaternion.IDENTITY

	elif dragging and event is InputEventMouseMotion:
		# Update desired tilt based on mouse movement
		target_rotation = _compute_target_rotation(event.position)

# Maps mouse position difference to a tilt quaternion
func _compute_target_rotation(mouse_pos: Vector2) -> Quaternion:
	var delta = (mouse_pos - start_mouse_pos) / drag_radius_px
	# Clamp vertical (pitch) and horizontal (roll) deltas
	var pitch_amount = clamp(delta.y, -1.0, 1.0) * deg_to_rad(max_tilt_deg)
	var roll_amount  = clamp(-delta.x, -1.0, 1.0) * deg_to_rad(max_tilt_deg)

	# Build quaternions: pitch around X, roll around Z
	var pitch_q = Quaternion(Vector3.RIGHT, -pitch_amount)
	var roll_q  = Quaternion(Vector3.FORWARD, roll_amount)
	return roll_q * pitch_q  # apply roll then pitch

# ─────────────────── Physics Processing ────────────────────── #
func _physics_process(delta: float) -> void:
	# Smoothly interpolate toward desired tilt
	var t = clamp(tilt_speed * delta, 0.0, 1.0)
	current_rotation = current_rotation.slerp(target_rotation, t)
	emit_signal("tilt_changed", current_rotation)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Rotate gravity vector by current tilt
	var gravity_dir = current_rotation * Vector3.DOWN * gravity_strength
	# Apply force: F = m * g
	state.apply_central_force(gravity_dir * gravity_s)

	# Update raycast target to visualize gravity direction
	var ray_length = 10.
	var world_end = global_transform.origin + gravity_dir.normalized() * ray_length
	gravity_ray.target_position = gravity_ray.to_local(world_end)
