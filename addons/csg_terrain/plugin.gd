@tool
extends EditorPlugin

var icon: Texture2D = preload("CSGTerrain.svg")


func _enter_tree() -> void:
	add_custom_type("CSGTerrain", "CSGMesh3D", preload("csg_terrain.gd"), icon)


func _exit_tree() -> void:
	remove_custom_type("CSGTerrain")
