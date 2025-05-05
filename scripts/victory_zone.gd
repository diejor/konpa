extends Area3D

@export_file("*.tscn") var NEXT_LEVEL = ""

func _on_body_entered(body: Node3D) -> void:
	if body.name == "ball":
		get_tree().change_scene_to_file(NEXT_LEVEL)
