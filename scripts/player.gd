extends RigidBody3D
"""
Transfers spin from the rotating platform to the marble.
The marble’s speed is clamped to   ω · r · speed_factor
so it can never outrun (or tunnel through) the floor.
"""

@export var transfer_factor               : float = 1.0   # how much of ω we convert to linear
@export var impulse_threshold             : float = 1.0   # ignore tiny spins
@export var speed_factor                  : float = 1.05  # allow ±5% slip over surface speed
@export var damping_coefficient           : float = 1.0   # “b” in τ_drag = –b·v (linear tangential)
@export var angular_damping_coefficient   : float = 0.1   # base scale for angular drag (see below)

func _ready() -> void:
	contact_monitor       = true
	max_contacts_reported = 8

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var v_old    = state.linear_velocity
	var inv_m    = state.inverse_mass
	if inv_m == 0.0:
		return
	var dt       = state.get_step()
	var contacts = state.get_contact_count()
	if contacts == 0:
		return

	# ───────── Tangential damping ───────── #
	var contact_n_local = state.get_contact_local_normal(0)
	var n_world         = state.transform.basis * contact_n_local
	var v_tangent       = v_old - n_world * v_old.dot(n_world)
	var damp_impulse    = -v_tangent * damping_coefficient * dt * inv_m
	state.apply_central_impulse(damp_impulse)

	# ───────── Angular damping (dynamic) ───────── #
	# Scale the torque drag by the angular speed so it's negligible when ω is small,
	# and grows stronger as spin increases.
	var w_old    = state.angular_velocity
	var w_len    = w_old.length()
	# dynamic_coeff = b * |ω|
	var dynamic_coeff = angular_damping_coefficient * w_len
	# torque impulse: τ = – dynamic_coeff · ω
	var ang_damp_imp = -w_old * dynamic_coeff * dt * inv_m
	state.apply_torque_impulse(ang_damp_imp)

	# ───────── Spin‐transfer impulse ───────── #
	for i in range(contacts):
		# find the RigidBody3D we hit
		var collider_obj = state.get_contact_collider_object(i).get_parent()
		var platform : RigidBody3D = collider_obj as RigidBody3D
		if not platform and collider_obj is CollisionShape3D and collider_obj.owner is RigidBody3D:
			platform = collider_obj.owner
		if not platform:
			continue

		var omega_vec = platform.angular_velocity
		var omega_mag = omega_vec.length()
		if omega_mag < impulse_threshold:
			continue

		# compute platform surface velocity at contact
		var cp     = state.get_contact_collider_position(i)
		var r_rel  = cp - platform.global_transform.origin
		var v_surf = omega_vec.cross(r_rel)
		if v_old.dot(v_surf) > 0.0:
			continue

		# platform “up” axis in world coords
		var axis  = platform.global_transform.basis.y.normalized()
		var align = abs(n_world.normalized().dot(axis))
		if align <= 0.0:
			continue
		var angle_fac = align

		# compute kick along axis
		var perp_len = v_old.dot(axis)
		var v_para   = v_old - axis * perp_len
		var r_len    = state.transform.origin.length()
		var kick     = omega_mag * transfer_factor * r_len * angle_fac
		var new_perp = abs(perp_len) + kick
		var v_target = v_para + axis * new_perp

		# apply impulse & clamp
		var dv = v_target - v_old
		print(dv)
		state.apply_central_impulse(dv * inv_m)

		var surface_speed = omega_mag * r_len
		var max_allowed   = surface_speed * speed_factor
		var v_new         = state.linear_velocity
		if v_new.length() > max_allowed:
			state.linear_velocity = v_new.normalized() * max_allowed

		break  # only first valid spin contact
