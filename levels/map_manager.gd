extends Node

@export var prev_scene: String
@export var next_scene: String

func _process(_delta):
	if Input.is_action_pressed("restart"):	
		get_tree().reload_current_scene()
	if Input.is_action_pressed("escape"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if Input.is_action_just_pressed("previous_level"):
		_change_scene_in_place(prev_scene)
	if Input.is_action_just_pressed("next_level"):
		_change_scene_in_place(next_scene)

func _change_scene_in_place(scene_path: String):
	var root = get_tree().root
	var to_change = get_parent()
	var parent_to_change = to_change.get_parent()
	var scene = load(scene_path).instantiate()
	
	to_change.queue_free()
	parent_to_change.add_child(scene)
