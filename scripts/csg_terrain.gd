@tool
class_name CSGTerrain
extends CSGMesh3D

signal remake_terrain

## Size of each side of the square.
@export var size: float = 512:
	set(value):
		var old_value = size
		size = value
		_size_changed(old_value)

## Number of subdivisions.
@export_range(1, 128) var divs: int = 64:
	set(value):
		var old_value = divs
		divs = value
		_divs_changed(old_value)

## Resolution of the mask applied to paths. Change if the path texture doesn't merge accordingly
@export var path_mask_resolution: int = 512:
	set(value):
		var old_value = path_mask_resolution
		path_mask_resolution = value
		_resolution_changed(old_value)


# Vertex grid in [x][z] plane
var vertex_grid: Array = []

var uvs: PackedVector2Array = []
var indices: PackedInt32Array = []

# Mesh in ArrayMesh format
var surface_array = []

var path_list: Array[CSGTerrainPath] = []
var textures = CSGTerrainTextures.new()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not is_instance_valid(mesh):
		mesh = ArrayMesh.new()
		print("instance")
	
	if not is_instance_valid(material):
		material = load("res://materials/terrain_material.tres").duplicate()
	
	# Create mesh
	surface_array.resize(Mesh.ARRAY_MAX)
	
	# Populate path list
	path_list.clear()
	for child in get_children():
		_child_entered(child)
	update_mesh()
	
	# Signals
	remake_terrain.connect(update_mesh)
	child_entered_tree.connect(_child_entered)
	child_exiting_tree.connect(_child_exit)
	child_order_changed.connect(_child_order_changed)


func _child_entered(child) -> void:
	if child is Path3D:
		child = child as Path3D
		if not is_instance_of(child, CSGTerrainPath):
			child.set_script(CSGTerrainPath)
			child.curve.bake_interval = size / divs
		path_list.append(child)
		if not child.curve_changed.is_connected(update_mesh):
			child.curve_changed.connect(update_mesh)


func _child_exit(child) -> void:
	if child is Path3D:
		if child.curve_changed.is_connected(update_mesh):
			child.curve_changed.disconnect(update_mesh)
		var index: int = path_list.find(child)
		path_list.remove_at(index)
		if not NOTIFICATION_EXIT_TREE:
			update_mesh()


func _child_order_changed() -> void:
	path_list.clear()
	for child in get_children():
		if child is CSGTerrainPath:
			path_list.append(child)


func _size_changed(old_size: float) -> void:
	for path in path_list:
		path.curve_changed.disconnect(update_mesh)
		var new_width = path.width * old_size / size
		path.width = int(new_width)
		path.curve_changed.connect(update_mesh)
		var new_texture_width = path.texture_width * old_size / size
		path.texture_width = int(new_texture_width)


func _divs_changed(old_divs: int) -> void:
	for path in path_list:
		var new_width: float = path.width * float(divs) / old_divs
		path.width = int(new_width)


func _resolution_changed(old_resolution) -> void:
	for path in path_list:
		var new_texture_width = path.texture_width * path_mask_resolution / old_resolution
		path.texture_width = int(new_texture_width)


func create_mesh_arrays() -> void:
	# Vertex Grid follow the pattern [x][z]. This will important for triangle generation.
	vertex_grid.clear()
	vertex_grid.resize(divs + 1)
	
	# apply scale
	var step = size / divs
	
	for x in range(divs + 1):
		var vertices_z: Array = []
		vertices_z.resize(divs + 1)
		for z in range(divs + 1):
			vertices_z[z] = Vector3(x * step, 0, z * step)
		vertex_grid[x] = vertices_z
	
	# Make uvs
	uvs.clear()
	uvs.resize((divs + 1) * (divs + 1))
	var uv_step: float = 1.0 / divs
	var index: int = 0
	for x in range(divs + 1):
		for z in range(divs + 1):
			uvs[index] = Vector2(x * uv_step, z * uv_step)
			index += 1
	
	# Make faces with two triangles
	indices.clear()
	indices.resize(divs * divs * 6)
	var row: int = 0
	var next_row: int = 0
	index = 0
	for x in range(divs):
		row = next_row
		next_row += divs + 1
		
		for z in range(divs):
			# First triangle vertices
			indices[index] = z + row
			index += 1
			indices[index] = z + next_row + 1
			index += 1
			indices[index] = z + row + 1
			index += 1
			# Second triangle vertices
			indices[index] = z + row
			index += 1
			indices[index] = z + next_row
			index += 1
			indices[index] = z + next_row + 1
			index += 1


func commit_mesh() -> void:
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = indices
	
	# Organize vertex matrix in format PackedVector3Array
	var vert_list: PackedVector3Array = []
	for array in vertex_grid:
		vert_list.append_array(array)
	
	surface_array[Mesh.ARRAY_VERTEX] = vert_list
	
	#Commit to the main mash
	mesh.clear_surfaces()
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from_arrays(surface_array)
	st.optimize_indices_for_cache()
	st.generate_normals()
	st.generate_tangents()
	mesh = st.commit()
	#mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	textures.apply_textures(path_list, path_mask_resolution, size, material)


func update_mesh() -> void:
	create_mesh_arrays()
	for path in path_list:
		follow_curve(path)
	commit_mesh()


func follow_curve(path: CSGTerrainPath) -> void:
	var width: int = path.width
	var smoothness: float = path.smoothness
	
	var pos: Vector3 = path.position
	var curve: Curve3D = path.curve
	var points: PackedVector3Array = curve.get_baked_points()
	
	if points.size() < 2: return
	
	# Dictionary with vertices around the curve by witdh size
	var curve_vertices = {}
	for point in points:
		var local_point: Vector3 = point + pos
		
		# Point in the vertex_grid
		var grid_point: Vector3 = local_point * divs / size
		var grid_index: Vector2i = Vector2i(int(grid_point.x), int(grid_point.z))
		grid_index = grid_index.clamp(Vector2i.ZERO, divs * Vector2i.ONE)
		
		for i in range(-width + 1, width + 2):
			for j in range(-width + 1, width + 2):
				var grid: Vector2i = Vector2i(grid_index.x + i, grid_index.y + j)
				grid = grid.clamp(Vector2i.ZERO, divs * Vector2i.ONE)
				curve_vertices[grid] = true
	
	for grid_idx in curve_vertices:
		var vertex: Vector3 = vertex_grid[grid_idx.x][grid_idx.y]
		var old_vertex: Vector3 = vertex
		
		# vertex in path space
		var path_vertex: Vector3 = vertex - pos
		var path_vertex2D = Vector2(path_vertex.x, path_vertex.z)
		var closest: Vector3 = get_closest_point_in_xz_plane(curve, path_vertex2D)
		# Back to local space
		closest += pos
		
		# Distance relative to path witdh.
		vertex.y = closest.y
		var dist = vertex.distance_to(closest)
		if width == 0: width = 1
		var dist_relative: float = (dist * divs) / (width * size)
		
		# Quadratic smooth
		var lerp_weight: float = dist_relative * dist_relative * smoothness
		lerp_weight = clampf(lerp_weight, 0, 1)
		var height: float = lerpf(closest.y, old_vertex.y, lerp_weight)
		vertex.y = height
		
		vertex_grid[grid_idx.x][grid_idx.y] = vertex
	
	# Update indices on affected vertices
	for grid_idx in curve_vertices:
		update_quad_indices(grid_idx)


func get_closest_point_in_xz_plane(curve: Curve3D, vertex2D: Vector2) -> Vector3:
	var baked_points: PackedVector3Array = curve.get_baked_points()
	var closest_point: Vector3 = Vector3.ZERO
	var closest_point2D: Vector2 = Vector2.ZERO
	
	# Get the closest point in xz plane
	var min_dist: float = INF
	var min_dist_idx: int = 0
	for i in range(baked_points.size() - 1):
		var point2D: Vector2 = Vector2(baked_points[i].x, baked_points[i].z)
		var next_point2D: Vector2 = Vector2(baked_points[i + 1].x,baked_points[i + 1].z)
		
		var closest2D: Vector2 = Geometry2D.get_closest_point_to_segment(vertex2D, point2D, next_point2D)
		var dist = closest2D.distance_squared_to(vertex2D)
		
		if dist < min_dist:
			min_dist = dist
			min_dist_idx = i
			closest_point2D = closest2D
	
	# Get the point in the 3D curve
	var point3D: Vector3 = baked_points[min_dist_idx]
	var next_point3D: Vector3 = baked_points[min_dist_idx + 1]
	var close3D: PackedVector3Array = Geometry3D.get_closest_points_between_segments(
		point3D, next_point3D,
		# Vertical axis that cross the curve
		Vector3(closest_point2D.x, -65536, closest_point2D.y), Vector3(closest_point2D.x, 65536, closest_point2D.y))
	closest_point = close3D[0]
	
	return closest_point


# There are two ways to triangularize a quad. To better follow the path, convex in y will be used
func update_quad_indices(idx: Vector2i) -> void:
	var x: int = idx.x
	if (x + 1) > divs: return
	var z: int = idx.y
	if (z + 1) > divs: return
	# Make faces with two triangles
	var row: int = x * (divs + 1)
	var next_row: int = row + divs + 1
	var index: int = 6 * (x * divs + z)
	 
	# There are two ways to triangularize a quad. Each one with one diagonal.
	# Getting the middle point of each diagonal
	var diagonal_1: Vector3 = 0.5 * (vertex_grid[x][z] + vertex_grid[x + 1][z + 1])
	var diagonal_2: Vector3 = 0.5 * (vertex_grid[x + 1][z] + vertex_grid[x][z + 1])
	
	# The diagonal with the upper middle point will be convex in y
	if diagonal_1.y >= diagonal_2.y:
		# First triangle vertices
		indices[index] = z + row
		index += 1
		indices[index] = z + next_row + 1
		index += 1
		indices[index] = z + row + 1
		index += 1
		# Second triangle vertices
		indices[index] = z + row
		index += 1
		indices[index] = z + next_row
		index += 1
		indices[index] = z + next_row + 1
	else:
		# First triangle vertices
		indices[index] = z + next_row
		index += 1
		indices[index] = z + next_row + 1
		index += 1
		indices[index] = z + row + 1
		index += 1
		## Second triangle vertices
		indices[index] = z + next_row
		index += 1
		indices[index] = z + row + 1
		index += 1
		indices[index] = z + row
