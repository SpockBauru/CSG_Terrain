@tool
extends CSGMesh3D

signal remake_curve
signal remake_terrain

@export var size_x: int = 3:
	set(value):
		size_x = value
		remake_terrain.emit()

@export var size_z: int = 2:
	set(value):
		size_z = value
		remake_terrain.emit()

@export var smooth_range: int = 5:
	set(value):
		if value < 0: value = 0
		smooth_range = value
		remake_curve.emit()

@export var smooth_strenght: float = 1:
	set(value):
		if value < 0: value = 0
		smooth_strenght = value
		remake_curve.emit()

@export var clear_terrain: bool = false

@onready var path: Path3D = $Path3D

## Vertex grid in [x][z] pattern
var vertices: Array = []
var uvs: PackedVector2Array = []
var indices: PackedInt32Array = []
## Mesh in ArrayMesh format
var surface_array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create mesh
	surface_array.resize(Mesh.ARRAY_MAX)
	remake_all()
	
	path.curve_changed.connect(follow_curve)
	remake_curve.connect(follow_curve)
	remake_terrain.connect(remake_all)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if clear_terrain == true:
		clear_terrain = false
		create_mesh_arrays()
		commit_mesh()
		follow_curve()


## Vertex Grid follow the pattern [x][z]. This will important for triangle generation.
func create_vertex_matrix() -> void:
	vertices.clear()
	vertices.resize(size_x + 1)
	
	for x in range(size_x + 1):
		var vertices_z: Array = []
		vertices_z.resize(size_z + 1)
		for z in range(size_z + 1):
			vertices_z[z] = Vector3(x, 0, z)
		vertices[x] = vertices_z


func create_mesh_arrays() -> void:
	create_vertex_matrix()
	
	# Make uvs
	uvs.clear()
	uvs.resize((size_x + 1) * (size_z + 1))
	var uv_step_x: float = 1.0 / size_x
	var uv_step_z: float = 1.0 / size_z
	var index: int = 0
	for x in range(size_x + 1):
		for z in range(size_z + 1):
			uvs[index] = Vector2(x * uv_step_x, z * uv_step_z)
			index += 1
	
	# Make faces with two triangles
	indices.clear()
	indices.resize(size_x * size_z * 6)
	var row: int = 0
	var next_row: int = 0
	index = 0
	for x in range(size_x):
		row = next_row
		next_row += size_z + 1
		
		for z in range(size_z):
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
	for array in vertices:
		vert_list.append_array(array)
	
	surface_array[Mesh.ARRAY_VERTEX] = vert_list
	
	#Commit to the main mash
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)


func follow_curve() -> void:
	create_vertex_matrix()
	
	var curve: Curve3D = path.curve
	var points: PackedVector3Array = curve.get_baked_points()
	
	for point in points:
		# Position in the vertex grid
		var x: int = int(point.x)
		var z: int = int(point.z)
		var y: float = point.y
		
		var xmin: int = x - smooth_range
		xmin = clampi(xmin, 0, size_x + 1)
		var xmax: int = x + smooth_range
		xmax = clampi(xmax, 0, size_x + 1)
		
		var zmin: int = z - smooth_range
		zmin = clampi(zmin, 0, size_z + 1)
		var zmax: int = z + smooth_range
		zmax = clampi(zmax, 0, size_z + 1)
		
		# Smooth around the curve
		for i in range(xmin, xmax):
			for j in range(zmin, zmax):
				# Current vertex on the mesh
				var vert: Vector3 = vertices[i][j]
				
				# Get closest point in the curve
				var baked: Vector3 = curve.get_closest_point(vert)
				
				# Distance between current vertex and curve on xz plane
				var vert2d: Vector2 = Vector2(vert.x, vert.z)
				var baked2d: Vector2 = Vector2(baked.x, baked.z)
				var dist: float = vert2d.distance_to(baked2d)
				var dist_relative: float = dist / smooth_range
				
				# Quadratic smooth
				var lerp_weight: float = dist_relative * dist_relative * smooth_strenght
				lerp_weight = clampf(lerp_weight, 0, 1)
				var height: float = lerpf(baked.y, 0.0, lerp_weight)
				vertices[i][j].y = height
	
	commit_vertices()

func remake_all() -> void:
	create_mesh_arrays()
	commit_mesh()
	follow_curve()
