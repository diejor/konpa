extends Node3D

var rotation_speed := 1.0  # radians per second

func _process(delta):
	if Input.is_action_pressed("rotate_left"):
		rotate_z(rotation_speed * delta)
	if Input.is_action_pressed("rotate_right"):
		rotate_z(-rotation_speed * delta)
	if Input.is_action_pressed("rotate_back"):
		rotate_x(rotation_speed * delta)
	if Input.is_action_pressed("rotate_forward"):
		rotate_x(-rotation_speed * delta)
	if Input.is_action_pressed("restart"):	
		get_tree().reload_current_scene()
	if Input.is_action_pressed("escape"):
		get_tree().change_scene_to_file("main_menu.tscn")
	if Input.is_action_just_pressed("next_level"):
		get_tree().change_scene_to_file("res://levels/level_6.tscn")
	if Input.is_action_just_pressed("previous_level"):
		get_tree().change_scene_to_file("res://levels/level_4.tscn")
