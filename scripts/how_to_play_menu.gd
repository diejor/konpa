extends Control


func _ready():
	pass
	

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
