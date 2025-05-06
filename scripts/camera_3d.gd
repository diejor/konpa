# FollowCamera.gd — attach to your Camera3D
extends Camera3D

@export var target: Node3D

@export var speed_xz: float = 5.0    # how fast to catch up horizontally
@export var speed_y: float  = 1.0    # how fast to catch up vertically

var offset: Vector3

func _ready() -> void:
	offset = position

func _process(delta: float) -> void:
	if not target:
		return

	# Compute the “ideal” follow position
	var desired = target.global_position + offset

	# Smooth X and Z quickly
	var x = lerp(global_position.x, desired.x, speed_xz * delta)
	var z = lerp(global_position.z, desired.z, speed_xz * delta)
	# Smooth Y more gently
	var y = lerp(global_position.y, desired.y, speed_y  * delta)

	global_position = Vector3(x, y, z)
