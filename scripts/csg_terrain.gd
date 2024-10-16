@tool
extends CSGMesh3D

@export var size_x: int = 3
@export var size_z: int = 2
@export var create_terrain: bool = false
@export var curve_terrain: bool = false

@onready var path: Path3D = $Path3D

var vertices: PackedVector3Array = []
var uvs: PackedVector2Array = []
var indices: PackedInt32Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if create_terrain == true:
		create_terrain = false
		create()
		commit()
	if curve_terrain == true:
		curve_terrain = false
		curve()
		commit()


func create() -> void:
	vertices.clear()
	vertices.resize((size_x + 1) * (size_z + 1))
	uvs.clear()
	uvs.resize((size_x + 1) * (size_z + 1))
	indices.clear()
	indices.resize(size_x * size_z * 6)
	
	# Make vertices and uvs
	var uv_step_x: float = 1.0 / size_x
	var uv_step_z: float = 1.0 / size_z
	var index: int = 0
	for z in range(size_z + 1):
		for x in range(size_x + 1):
			uvs[index] = Vector2(x * uv_step_x, z * uv_step_z)
			vertices[index] = Vector3(x, 0, z)
			index += 1
	
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


func curve() -> void:
	var points: PackedVector3Array = path.curve.get_baked_points()
	var pos: Vector3 = path.position
	
	for point in points:
		point += pos
		var x: int = int(point.x)
		var z: int = int(point.z)
		var y = point.y
		
		var index: int = x + (z * (size_x + 1))
		vertices[index].y = y
		vertices[index + 1].y = y
		index += size_x + 1
		vertices[index].y = y
		vertices[index + 1].y = y


func commit() -> void:
	# Create surface array and commit to the mash
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = indices
	
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
