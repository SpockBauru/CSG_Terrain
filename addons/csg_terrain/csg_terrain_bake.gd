## Class Responsible to create a MeshInstance3D in the scene.
class_name CSGTerrainBake

var fileDialog: FileDialog = null
var csg_mesh: CSGMesh3D = null
var size: float = 0
var divs: int = 0


func create_mesh(csg_mesh: CSGMesh3D, size: float, divs: int) -> MeshInstance3D:
	# Creating a new meshArray.
	var new_array_mesh: ArrayMesh = ArrayMesh.new()
	new_array_mesh.clear_surfaces()
	
	var old_array_mesh: ArrayMesh = csg_mesh.get_meshes()[1]
	var surfaces_count: int = old_array_mesh.get_surface_count()
	
	# Creating each surface of the mesh.
	for count in range(surfaces_count):
		var surface: Array = old_array_mesh.surface_get_arrays(count)
		var vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = surface[Mesh.ARRAY_TEX_UV]
		
		# The vertex output of CSG Mesh is deindexed, made with triangles.
		# Removing triangles that contains the bottom quad, from the end to beginning.
		for i in range(vertices.size() - 1, -1, -3):
			var remove: bool = false
			for j in range(3):
				# The bottom quad is the only where y has the value -size.
				if vertices[i - j].y == -size:
					remove = true
			
			# Removing triangle from vertex and uvs.
			if remove == true:
				vertices.remove_at(i)
				vertices.remove_at(i - 1)
				vertices.remove_at(i - 2)
				
				uvs.remove_at(i)
				uvs.remove_at(i - 1)
				uvs.remove_at(i - 2)
		
		# Making UV2 for Lightmaps
		var uv2: PackedVector2Array = []
		uv2.resize(uvs.size())
		
		for i in uv2.size():
			uv2[i] = Vector2(0.5, 0.5) + Vector2(vertices[i].x, vertices[i].z) / size
		surface[Mesh.ARRAY_TEX_UV2] = uv2
	
		# Optimizing surface.
		var st = SurfaceTool.new()
		st.create_from_arrays(surface)
		st.index()
		#st.optimize_indices_for_cache()
		st.generate_normals()
		st.generate_tangents()
		st.commit(new_array_mesh)
		
		# Set material.
		var old_material: Material = old_array_mesh.surface_get_material(count)
		if is_instance_valid(old_material):
			var new_material = old_material.duplicate(true)
			new_array_mesh.surface_set_material(count, new_material)
	
	# Creating the new MeshInstance3D.
	var terrain_mesh: MeshInstance3D = MeshInstance3D.new()
	terrain_mesh.name = csg_mesh.name + "-Mesh"
	terrain_mesh.mesh = new_array_mesh
	terrain_mesh.mesh.lightmap_size_hint = Vector2i(divs * 10, divs * 10)
	
	# Copy Mesh parameters.
	terrain_mesh.transform = csg_mesh.transform
	terrain_mesh.gi_mode = csg_mesh.gi_mode
	terrain_mesh.gi_lightmap_scale = csg_mesh.gi_lightmap_scale
	terrain_mesh.visibility_range_begin = csg_mesh.visibility_range_begin
	terrain_mesh.visibility_range_begin_margin = csg_mesh.visibility_range_begin_margin
	terrain_mesh.visibility_range_end = csg_mesh.visibility_range_end
	terrain_mesh.visibility_range_end_margin = csg_mesh.visibility_range_end_margin
	terrain_mesh.visibility_range_fade_mode = csg_mesh.visibility_range_fade_mode
	
	return terrain_mesh


## Create a file dialog, then call _export_gltf when the file path is chosen.
func export_terrain(_csg_mesh: CSGMesh3D, _size: float, _divs: int) -> void:
	csg_mesh = _csg_mesh
	size = _size
	divs = _divs
	
	var path = "res://" + csg_mesh.name + ".glb"
	var editorViewport = Engine.get_singleton(&"EditorInterface").get_editor_viewport_3d()
	fileDialog = FileDialog.new()
	editorViewport.add_child(fileDialog, true)
	
	fileDialog.file_selected.connect(_export_gltf)
	fileDialog.current_path = path
	fileDialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fileDialog.access = FileDialog.ACCESS_FILESYSTEM
	fileDialog.set_meta("_created_by", csg_mesh)
	fileDialog.popup(Rect2i(100, 100, 600, 400))


## Export the mesh to GLTF file.
func _export_gltf(path: String):
	# Creating the new mesh.
	var mesh = create_mesh(csg_mesh, size, divs)
	csg_mesh.get_parent().add_child(mesh, true)
	
	# Saving GLTF file.
	var gltf_document_save := GLTFDocument.new()
	var gltf_state_save := GLTFState.new()
	gltf_document_save.append_from_scene(mesh, gltf_state_save)
	gltf_document_save.write_to_filesystem(gltf_state_save, path)
	
	# Cleaning.
	fileDialog.queue_free()
	mesh.queue_free()
	Engine.get_singleton(&"EditorInterface").get_resource_filesystem().scan_sources()
