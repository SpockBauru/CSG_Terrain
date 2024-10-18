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
var path_list: Array[Path3D] = []


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
		if not is_instance_of(child, CGSTerrainPath):
			child.set_script(CGSTerrainPath)
			child.curve.bake_interval = size / divs
		path_list.append(child)
		child.curve_changed.connect(update_curves)


func _child_exit(child) -> void:
	if child is Path3D:
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


func update_curves() -> void:
	create_vertex_matrix()
	for path in path_list:
		follow_curve(path)
	commit_vertices()


func follow_curve(path: CGSTerrainPath) -> void:
	# Grid from old iteraction
	var old_grid: Array = vertex_grid.duplicate(true)
	var width: int = path.width
	var smoothness: float = path.smoothness
	
	var pos: Vector3 = path.position
	var curve: Curve3D = path.curve
	var points: PackedVector3Array = curve.get_baked_points()
	
	for point in points:
		# From path position to local position
		point += pos
		# From local position to index position
		point.x = point.x * divs / size
		point.z = point.z * divs / size
		
		# Position in the vertex grid
		var x: int = int(point.x)
		var z: int = int(point.z)
		var y: float = point.y
		
		var xmin: int = x - width
		xmin = clampi(xmin, 0, divs + 1)
		var xmax: int = x + width
		xmax = clampi(xmax, 0, divs + 1)
		
		var zmin: int = z - width
		zmin = clampi(zmin, 0, divs + 1)
		var zmax: int = z + width
		zmax = clampi(zmax, 0, divs + 1)
		
		# Smooth around the curve
		for i in range(xmin, xmax):
			for j in range(zmin, zmax):
				# Current vertex on the mesh
				var vert: Vector3 = vertex_grid[i][j]
				
				# From local position to path position
				var local_vert: Vector3 = vert - pos
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
				var height: float = lerpf(baked.y + pos.y, old_grid[i][j].y, lerp_weight)
				vertex_grid[i][j].y = height


func remake_all() -> void:
	create_mesh_arrays()
	for path in path_list:
		path.curve_changed.disconnect(update_curves)
		path.curve.bake_interval = size / divs
		path.curve_changed.connect(update_curves)
		follow_curve(path)
	commit_mesh()
