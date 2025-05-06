extends Area3D

@export_file("*.tscn") var NEXT_LEVEL = ""

@onready var map_manager = $"../MapManager"

func _on_body_entered(body: Node3D) -> void:
	if body.name == "ball":
		map_manager._change_scene_in_place(NEXT_LEVEL)
