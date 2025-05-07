extends Control

func _ready():
	pass
	
func _process(_delta):
	pass

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/kernel.tscn")


func _on_homehowtoplay_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/how_to_play_menu.tscn")


func _on_homeexit_pressed() -> void:
	get_tree().quit()
