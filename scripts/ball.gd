extends RigidBody3D

func _ready():
	$CameraRig.top_level = true  # Prevent inherits from rotation
	gravity_scale = 7.0  # Increase gravity (default is 1.0)
	continuous_cd = true  # enables swept collision detection




func _physics_process(delta):
	$CameraRig.global_transform.origin = global_transform.origin


	
