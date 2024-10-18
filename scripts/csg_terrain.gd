@tool
extends CSGMesh3D

signal remake_curve
signal remake_terrain

@export var size: Vector2 = Vector2(50, 50):
	set(value):
		size = value
		remake_terrain.emit()


@export_range(1, 100) var subdivide_width: int = 10:
	set(value):
		subdivide_width = value
		div_x = value
		remake_terrain.emit()
var div_x: int = 10


@export_range(1, 100) var subdivide_depth: int = 10:
	set(value):
		subdivide_depth = value
		div_z = value
		remake_terrain.emit()
var div_z: int = 10


@export var width: int = 5:
	set(value):
		if value < 1: value = 1
		width = value
		remake_curve.emit()

@export var smoothness: float = 1:
	set(value):
		if value < 0: value = 0
		smoothness = value
		remake_curve.emit()

@export var clear_terrain: bool = false

@onready var path: Path3D = $Path3D

## Vertex grid in [x][z] plane
var vertex_grid: Array = []
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
		remake_all()


## Vertex Grid follow the pattern [x][z]. This will important for triangle generation.
func create_vertex_matrix() -> void:
	vertex_grid.clear()
	vertex_grid.resize(div_x + 1)
	
	# apply scale
	var step_x = size.x / div_x
	var step_z = size.y / div_z
	
	for x in range(div_x + 1):
		var vertices_z: Array = []
		vertices_z.resize(div_z + 1)
		for z in range(div_z + 1):
			vertices_z[z] = Vector3(x * step_x, 0, z * step_z)
		vertex_grid[x] = vertices_z


func create_mesh_arrays() -> void:
	create_vertex_matrix()
	
	# Make uvs
	uvs.clear()
	uvs.resize((div_x + 1) * (div_z + 1))
	var uv_step_x: float = 1.0 / div_x
	var uv_step_z: float = 1.0 / div_z
	var index: int = 0
	for x in range(div_x + 1):
		for z in range(div_z + 1):
			uvs[index] = Vector2(x * uv_step_x, z * uv_step_z)
			index += 1
	
	# Make faces with two triangles
	indices.clear()
	indices.resize(div_x * div_z * 6)
	var row: int = 0
	var next_row: int = 0
	index = 0
	for x in range(div_x):
		row = next_row
		next_row += div_z + 1
		
		for z in range(div_z):
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
	
	#var st: SurfaceTool = SurfaceTool.new()
	#st.create_from_arrays(surface_array)
	#st.generate_normals()
	#st.generate_tangents()
	#mesh = st.commit()
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)


func follow_curve() -> void:
	create_vertex_matrix()
	
	var pos: Vector3 = path.position
	var curve: Curve3D = path.curve
	var points: PackedVector3Array = curve.get_baked_points()
	
	for point in points:
		# From path position to local position
		point += pos
		# From local position to index position
		point.x = point.x * div_x / size.x
		point.z = point.z * div_z / size.y
		
		# Position in the vertex grid
		var x: int = int(point.x)
		var z: int = int(point.z)
		var y: float = point.y
		
		var xmin: int = x - width
		xmin = clampi(xmin, 0, div_x + 1)
		var xmax: int = x + width
		xmax = clampi(xmax, 0, div_x + 1)
		
		var zmin: int = z - width
		zmin = clampi(zmin, 0, div_z + 1)
		var zmax: int = z + width
		zmax = clampi(zmax, 0, div_z + 1)
		
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
				var dist_relative: float = (dist * div_x) / (width * size.x)
				
				# Quadratic smooth
				var lerp_weight: float = dist_relative * dist_relative * smoothness
				lerp_weight = clampf(lerp_weight, 0, 1)
				var height: float = lerpf(baked.y, 0.0, lerp_weight)
				vertex_grid[i][j].y = height
	
	commit_vertices()

func remake_all() -> void:
	create_mesh_arrays()
	commit_mesh()
	follow_curve()
