class_name SpinPlatform
extends RigidBody3D

# ───── Tunables ────────────────────────────────────────────────────────── #
@export var drag_radius_px        := 150.0
@export var KP                    := 250.0
@export var KD                    := 100.0
@export var responsiveness_boost  := 1.5
@export var max_torque            := 500.0
# ───────────────────────────────────────────────────────────────────────── #

var _dragging      : bool       = false
var _start_mouse   : Vector2    = Vector2.ZERO
var _initial_q     : Quaternion = Quaternion.IDENTITY    # ← store starting orientation
var _desired_q     : Quaternion = Quaternion.IDENTITY
var _prev_angle    : float      = 0.0
const EPS := 1e-4



# ───────────────────────── Mouse handling ─────────────────────────────── #
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("click"):
		_dragging     = true
		_start_mouse  = event.position
		_initial_q    = global_transform.basis.get_rotation_quaternion()
		_desired_q    = _initial_q
		_prev_angle   = 0.0

	elif Input.is_action_just_released("click"):
		_dragging     = false
		_desired_q    = Quaternion.IDENTITY
		_prev_angle   = 0.0

	elif _dragging and event is InputEventMouseMotion:
		_desired_q = _mouse_to_quaternion(event.position)


# ─────────────────── full‐sphere mapping via Euler angles ─────────────── #
func _mouse_to_quaternion(pos: Vector2) -> Quaternion:
	var d  = (pos - _start_mouse) / drag_radius_px
	# clamp to [-1,1] so you can’t overshoot
	var dx = clamp(d.y, -1.0, 1.0)
	var dy = clamp(-d.x, -1.0, 1.0)

	# map dx→pitch around X; dy→roll around Z
	var pitch = dx * PI      # → ±180°
	var roll  = dy * PI      # → ±180°

	var q_pitch = Quaternion(Vector3(1, 0, 0), pitch)
	var q_roll  = Quaternion(Vector3(0, 0, 1), roll)

	# apply both to the orientation you had when you clicked
	return q_roll * q_pitch * _initial_q


# ───────────────────── Physics: PD torque controller ──────────────────── #
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var q_now = state.transform.basis.get_rotation_quaternion()
	var q_err = q_now.inverse() * _desired_q
	var angle = q_err.get_angle()

	var axis = q_err.get_axis().normalized()
	var gain = KP
	if _dragging and angle > _prev_angle:
		gain *= responsiveness_boost
	_prev_angle = angle

	var torque = axis * (gain * angle) - state.angular_velocity * KD
	if torque.length() > max_torque:
		torque = torque.normalized() * max_torque
	state.apply_torque(torque)


# ───────────────── Tangential velocity helper (local math) ────────────── #
func get_tangential_velocity_world(p_world: Vector3) -> Vector3:
	var r_local     = global_transform.affine_inverse() * p_world
	var omega_local = global_transform.basis * angular_velocity
	var v_local     = omega_local.cross(r_local)
	return global_transform.basis * v_local
