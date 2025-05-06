class_name Marble
extends RigidBody3D

@export var drag_radius_px : float = 1800.0
@export var max_tilt_deg   : float = 180.0
@export var tilt_speed     : float = 4.0
@export var gravity_mag    : float = 9.8
@export var g_scale  : float = 3.0

@onready var rc : RayCast3D = $Gravity

var _dragging    := false
var _start_mouse = Vector2.ZERO
var _desired_q   = Quaternion.IDENTITY
var _current_q   = Quaternion.IDENTITY

signal tilt_changed(q: Quaternion)

# ───────────────────────── Input → desired tilt ───────────────────────── #
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("click"):
		_dragging    = true
		_start_mouse = event.position
	elif Input.is_action_just_released("click"):
		_dragging    = false
		_desired_q   = Quaternion.IDENTITY
	elif _dragging and event is InputEventMouseMotion:
		_desired_q = _mouse_to_quaternion(event.position)

func _mouse_to_quaternion(pos: Vector2) -> Quaternion:
	var d  = (pos - _start_mouse) / drag_radius_px
	var dx = clamp(d.y, -1.0, 1.0)             # pitch
	var dy = clamp(-d.x, -1.0, 1.0)             # roll

	var pitch = deg_to_rad(max_tilt_deg) * dx
	var roll  = deg_to_rad(max_tilt_deg) * dy

	var q_pitch = Quaternion(Vector3(-1, 0, 0), pitch)   # X
	var q_roll  = Quaternion(Vector3(0, 0, -1), roll)    # Z (world‑right)
	return q_roll * q_pitch                              # roll ∘ pitch

# ───────────────────────── Physics & gravity ──────────────────────────── #
func _physics_process(delta: float) -> void:
	_current_q = _current_q.slerp(_desired_q, clamp(tilt_speed * delta, 0.0, 1.0))
	emit_signal("tilt_changed", _current_q)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var g_world = _current_q * Vector3(0, -gravity_mag, 0)

	state.apply_central_force(g_world * g_scale)  # F = m g
	
	var cast_length = 0.5

	var world_end = global_transform.origin + g_world * cast_length

	rc.target_position = rc.to_local(world_end)
