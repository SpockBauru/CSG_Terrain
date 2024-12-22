# Class Responsible to export an optimized MeshInstance3D into the scene.
class_name CSGTerrainExport


func create_mesh(csg_mesh: CSGMesh3D, size: float, path_mask_resolution) -> void:
	# Creating a meshArray
	var array_mesh: ArrayMesh = csg_mesh.get_meshes()[1].duplicate()
	var surface: Array = array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = surface[Mesh.ARRAY_TEX_UV]
	
	# The vertex output of CSG Mesh is deindexed, made with triangles
	# Removing triangles that contains the bottom quad, from the end to beginning
	for i in range(vertices.size() - 1, -1, -3):
		var remove: bool = false
		for j in range(3):
			#The bottom quad is the only where y has the value -size
			if vertices[i - j].y == -size:
				remove = true
		
		# Removing triangle from vertex and uvs
		if remove == true:
			vertices.remove_at(i)
			vertices.remove_at(i - 1)
			vertices.remove_at(i - 2)
			
			uvs.remove_at(i)
			uvs.remove_at(i - 1)
			uvs.remove_at(i - 2)
	
	# Optimizing final mesh
	surface[Mesh.ARRAY_TEX_UV2] = uvs
	
	var st = SurfaceTool.new()
	st.create_from_arrays(surface)
	st.index()
	st.optimize_indices_for_cache()
	st.generate_normals()
	st.generate_tangents()
	
	array_mesh.clear_surfaces()
	array_mesh = st.commit()
	array_mesh.surface_set_material(0, csg_mesh.material.duplicate())
	
	# Creating the new MeshInstance3D
	var terrain_mesh: MeshInstance3D = MeshInstance3D.new()
	terrain_mesh.name = csg_mesh.name + "-Mesh"
	terrain_mesh.mesh = array_mesh
	terrain_mesh.mesh.lightmap_size_hint = Vector2i(path_mask_resolution, path_mask_resolution)
	
	# Copy Mesh parameters
	terrain_mesh.transform = csg_mesh.transform
	terrain_mesh.gi_mode = csg_mesh.gi_mode
	terrain_mesh.gi_lightmap_scale = csg_mesh.gi_lightmap_scale
	terrain_mesh.visibility_range_begin = csg_mesh.visibility_range_begin
	terrain_mesh.visibility_range_begin_margin = csg_mesh.visibility_range_begin_margin
	terrain_mesh.visibility_range_end = csg_mesh.visibility_range_end
	terrain_mesh.visibility_range_end_margin = csg_mesh.visibility_range_end_margin
	terrain_mesh.visibility_range_fade_mode = csg_mesh.visibility_range_fade_mode
	
	# Add node in the scene
	var mesh_parent = csg_mesh.get_parent()
	mesh_parent.add_child(terrain_mesh, true)
	var root_node: Node = csg_mesh.get_tree().edited_scene_root
	terrain_mesh.set_owner(root_node)
	
	print("Created ", terrain_mesh.name)
