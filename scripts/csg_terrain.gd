@tool
extends CSGMesh3D

@export var size_x: int = 3
@export var size_z: int = 2
@export var create_terrain: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if create_terrain == true:
		create_terrain = false
		create()


func create() -> void:
	var uv_step_x: float = 1.0 / size_x
	var uv_step_z: float = 1.0 / size_z
	
	# Create surface tool
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Make vertices
	for z in range(size_z + 1):
		for x in range(size_x + 1):
			st.set_uv(Vector2(x * uv_step_x, z * uv_step_z))
			st.add_vertex(Vector3(x, 0, z))
	
	# Make faces with two triangles
	var row: int = 0
	var next_row: int = size_x + 1
	for z in range(size_z):
		for x in range(size_x):
			# First triangle vertices
			st.add_index(row + x)
			st.add_index(next_row + x + 1)
			st.add_index(next_row + x)
			# Second triangle vertices
			st.add_index(row + x)
			st.add_index(row + x + 1)
			st.add_index(next_row + x + 1)
		row = next_row
		next_row += size_x + 1
	
	# Generate normals, tangents and commit to the terrain mesh
	st.generate_normals()
	st.generate_tangents()
	mesh = st.commit()
