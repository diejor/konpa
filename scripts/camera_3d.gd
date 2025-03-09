extends Camera3D

@export var _target: Node3D
@export var _offset: Vector3
@export var _speed: float = 1.

func _process(delta: float) -> void:
	if _target:
		global_position = global_position.lerp(_target.global_position + _offset, _speed * delta)
