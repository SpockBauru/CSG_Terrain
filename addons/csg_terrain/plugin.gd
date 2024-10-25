@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("CSGTerrain", "CSGMesh3D", preload("csg_terrain_mesh.gd"), preload("CSGTerrain.svg"))


func _exit_tree() -> void:
	remove_custom_type("CSGTerrain")
