@tool
extends CSGMesh3D

signal remake_terrain

@export var size_x: int = 3
@export var size_z: int = 2

@export var smooth_range: int = 5:
	set(value):
		if value < 1: value = 1
		smooth_range = value
		remake_terrain.emit()
@export_range(0, 0.5) var smooth_strenght: float = 0.2:
	set(value):
		smooth_strenght = value
		remake_terrain.emit()

@export var create_terrain: bool = false

@onready var path: Path3D = $Path3D

#var vertices: PackedVector3Array = []
var vertices: Array = []
var uvs: PackedVector2Array = []
var indices: PackedInt32Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	create()
	path.curve_changed.connect(follow_curve)
	remake_terrain.connect(follow_curve)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if create_terrain == true:
		create_terrain = false
		follow_curve()


func create() -> void:
	vertices.clear()
	vertices.resize(size_z + 1)
	uvs.clear()
	uvs.resize((size_x + 1) * (size_z + 1))
	indices.clear()
	indices.resize(size_x * size_z * 6)
	
	# Make vertices and uvs
	var uv_step_x: float = 1.0 / size_x
	var uv_step_z: float = 1.0 / size_z
	var index: int = 0
	for z in range(size_z + 1):
		var vertices_x: Array = []
		vertices_x.resize(size_x + 1)
		
		for x in range(size_x + 1):
			vertices_x[x] = Vector3(x, 0, z)
			uvs[index] = Vector2(x * uv_step_x, z * uv_step_z)
			index += 1
		
		vertices[z] = vertices_x
	
	# Make faces with two triangles
	var row: int = 0
	var next_row: int = 0
	index = 0
	for z in range(size_z):
		row = next_row
		next_row += size_x + 1
		for x in range(size_x):
			# First triangle vertices
			indices[index] = row + x
			index += 1
			indices[index] = next_row + x + 1
			index += 1
			indices[index] = next_row + x
			index += 1
			# Second triangle vertices
			indices[index] = row + x
			index += 1
			indices[index] = row + x + 1
			index += 1
			indices[index] = next_row + x + 1
			index += 1


func commit() -> void:
	# Organize vertices in mesh format PackedVector3Array
	var vert_list: PackedVector3Array = []
	for array in vertices:
		vert_list.append_array(array)
	
	# Create surface array
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vert_list
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = indices
	
	#Commit to the main mash
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)


func follow_curve() -> void:
	create()
	
	var curve: Curve3D = path.curve
	var points: PackedVector3Array = curve.get_baked_points()
	var pos: Vector3 = path.position
	
	for point in points:
		#point += pos
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
		
		for i in range(xmin, xmax):
			for j in range(zmin, zmax):
				var vert: Vector3 = vertices[j][i]
				var offset: float = curve.get_closest_offset(vert)
				var baked: Vector3 = curve.sample_baked(offset)
				var direction = vert - baked
				direction.y = 0
				var dist = direction.length()
				
				var y_test = baked.y - smooth_strenght * baked.y * dist
				#print("(", i, "," , j , "): ", y_test)
				vertices[j][i].y = y_test
		
		commit()
