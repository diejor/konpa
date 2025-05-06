class_name TiltCamera
extends Camera3D

@export var distance     : float    = 15.0
@export var height       : float    = 10.0
@export var follow_speed : float    = 10.0

@onready var _target : Marble = $".."

# 1) Store your base offset (resting offset) once:
var _base_offset  : Vector3
# 2) Keep track of the current offset as state:
var _current_offset : Vector3

var _tilt_q : Quaternion  = Quaternion.IDENTITY

func _ready() -> void:
	if not _target:
		return
	_target.tilt_changed.connect(_on_tilt_changed)

	# Compute what “resting” offset looks like in marble space:
	_base_offset = Vector3(0, height, distance)
	# Initialize _current_offset to that base:
	_current_offset = _base_offset

func _on_tilt_changed(q: Quaternion) -> void:
	_tilt_q = q

func _process(delta: float) -> void:
	if not _target:
		return

	var t = clamp(follow_speed * delta, 0.0, 1.0)

	# 3) Compute the desired offset by rotating the base by your current tilt:
	var desired_offset = _tilt_q * _base_offset

	# 4) Smoothly move your “current offset” toward that desired offset:
	_current_offset = _current_offset.slerp(desired_offset, t)

	# 5) Reposition camera relative to marble using that smoothed offset:
	var marble_pos = _target.global_transform.origin
	global_transform.origin = marble_pos + _current_offset

	# 6) Always look at the marble with the correct “up”:
	look_at(marble_pos, _tilt_q * Vector3.UP)
