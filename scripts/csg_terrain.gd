@tool
extends CSGMesh3D

signal remake_terrain

## Size of each side of the square.
@export var size: float = 500:
	set(value):
		size = value
		remake_terrain.emit()

## Number of subdivisions.
@export_range(1, 100) var divs: int = 50:
	set(value):
		divs = value
		remake_terrain.emit()

@export var clear_terrain: bool = false

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
	# Create mesh
	surface_array.resize(Mesh.ARRAY_MAX)
	remake_all()
	
	# Populate path list
	path_list.clear()
	for child in get_children():
		_child_entered(child)
	update_curves()
	
	# Signals
	remake_terrain.connect(remake_all)
	child_entered_tree.connect(_child_entered)
	child_exiting_tree.connect(_child_exit)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if clear_terrain == true:
		clear_terrain = false
		remake_all()


func _child_entered(child) -> void:
	if child is Path3D:
		child = child as Path3D
		if not is_instance_of(child, CSGTerrainPath):
			child.set_script(CSGTerrainPath)
			child.curve.bake_interval = size / divs
		path_list.append(child)
		child.curve_changed.connect(update_curves)


func _child_exit(child) -> void:
	if child is Path3D:
		child.curve_changed.disconnect(update_curves)
		var index: int = path_list.find(child)
		path_list.remove_at(index)
		if not NOTIFICATION_EXIT_TREE:
			update_curves()


# Vertex Grid follow the pattern [x][z]. This will important for triangle generation.
func create_vertex_matrix() -> void:
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


func create_mesh_arrays() -> void:
	create_vertex_matrix()
	
	# Make uvs
	uvs.clear()
	uvs.resize((divs + 1) * (divs + 1))
	var uv_step: float = 1.0 / divs
	#var uv_step_z: float = 1.0 / div_z
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
	commit_vertices()


func commit_vertices() -> void:
	# Organize vertex matrix in format PackedVector3Array
	var vert_list: PackedVector3Array = []
	for array in vertex_grid:
		vert_list.append_array(array)
	
	surface_array[Mesh.ARRAY_VERTEX] = vert_list
	
	#Commit to the main mash
	mesh.clear_surfaces()
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from_arrays(surface_array)
	st.generate_normals()
	st.generate_tangents()
	mesh = st.commit()
	#mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	textures.apply_textures(path_list, size, material)


func update_curves() -> void:
	create_vertex_matrix()
	for path in path_list:
		follow_curve(path)
	commit_vertices()


func follow_curve(path: CSGTerrainPath) -> void:
	var width: int = path.width
	var smoothness: float = path.smoothness
	
	var pos: Vector3 = path.position
	var curve: Curve3D = path.curve
	var points: PackedVector3Array = curve.get_baked_points()
	
	# Dictionaries with checked points
	var points_checked = {}
	var verts_checked = {}
	
	for point in points:
		# From path position to local position
		var local_point: Vector3 = point + pos
		# From local position to index position
		local_point.x = local_point.x * divs / size
		local_point.z = local_point.z * divs / size
		
		var point2D: Vector2i = Vector2i(int(local_point.x), int(local_point.z))
		#vertex_grid[point2D.x][point2D.y].y = local_point.y
		
		if points_checked.has(point2D):
			continue
		points_checked[point2D] = true
		
		var point_min = point2D - width * Vector2i.ONE
		point_min = point_min.clamp(Vector2i.ZERO, (divs + 1) * Vector2i.ONE)
		var point_max = point2D + width * Vector2i.ONE
		point_max = point_max.clamp(Vector2i.ZERO, (divs + 1) * Vector2i.ONE)
		
		# Smooth around the curve
		for i in range(point_min.x, point_max.x):
			for j in range(point_min.y, point_max.y):
				# Skip if the vertex was analyded already
				var pos2D = Vector2i(i,j)
				
				if verts_checked.has(pos2D):
					continue
				verts_checked[pos2D] = true
				
				# Current vertex on the mesh
				var vert: Vector3 = vertex_grid[i][j]
				
				# From local position to path position
				var local_vert: Vector3 = vert - pos
				local_vert.y = point.y
				
				# Get closest point in the curve
				var baked: Vector3 = curve.get_closest_point(local_vert)
				
				# Distance between current vertex and curve on the xz plane
				var vert2d: Vector2 = Vector2(local_vert.x, local_vert.z)
				var baked2d: Vector2 = Vector2(baked.x, baked.z)
				var dist: float = vert2d.distance_to(baked2d)
				var dist_relative: float = (dist * divs) / (width * size)
				
				# Quadratic smooth
				var lerp_weight: float = dist_relative * dist_relative * smoothness
				lerp_weight = clampf(lerp_weight, 0, 1)
				var height: float = lerpf(baked.y + pos.y, vertex_grid[i][j].y, lerp_weight)
				vertex_grid[i][j].y = height


func remake_all() -> void:
	create_mesh_arrays()
	for path in path_list:
		follow_curve(path)
	commit_mesh()
