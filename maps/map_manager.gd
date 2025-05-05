extends Node

@export var prev_scene: String
@export var next_scene: String

func _process(delta):
	if Input.is_action_pressed("restart"):	
		get_tree().reload_current_scene()
	if Input.is_action_pressed("escape"):
		get_tree().change_scene_to_file("main_menu.tscn")
	if Input.is_action_just_pressed("previous_level"):
		get_tree().change_scene_to_file(prev_scene)
	if Input.is_action_just_pressed("next_level"):
		get_tree().change_scene_to_file(next_scene)
	
