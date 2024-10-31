# Still in development. Does not work properly :'(
class_name CSGTerrainExport

func create_mesh(csg_mesh: CSGMesh3D) -> void:
	# Creating a meshArray
	var array_mesh: ArrayMesh
	array_mesh = csg_mesh.get_meshes()[1]
	var surface_test = array_mesh.surface_get_arrays(0)
	surface_test[Mesh.ARRAY_TEX_UV2] = surface_test[Mesh.ARRAY_TEX_UV]
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_test)
	array_mesh.surface_set_material(0, csg_mesh.material)
	
	# Creating the new MeshInstance3D
	var csg_terrain_mesh: MeshInstance3D = MeshInstance3D.new()
	csg_terrain_mesh.name = csg_mesh.name + "-Mesh"
	csg_terrain_mesh.mesh = array_mesh
	
	# Copy Mesh parameters
	csg_terrain_mesh.transform = csg_mesh.transform
	csg_terrain_mesh.gi_mode = csg_mesh.gi_mode
	csg_terrain_mesh.gi_lightmap_scale = csg_mesh.gi_lightmap_scale
	csg_terrain_mesh.visibility_range_begin = csg_mesh.visibility_range_begin
	csg_terrain_mesh.visibility_range_begin_margin = csg_mesh.visibility_range_begin_margin
	csg_terrain_mesh.visibility_range_end = csg_mesh.visibility_range_end
	csg_terrain_mesh.visibility_range_end_margin = csg_mesh.visibility_range_end_margin
	csg_terrain_mesh.visibility_range_fade_mode = csg_mesh.visibility_range_fade_mode
	
	# Add node in the scene
	var mesh_parent = csg_mesh.get_parent()
	mesh_parent.add_child(csg_terrain_mesh, true)
	var root_node: Node = csg_mesh.get_tree().edited_scene_root
	csg_terrain_mesh.set_owner(root_node)
	
	print("Created ", csg_terrain_mesh.name)
