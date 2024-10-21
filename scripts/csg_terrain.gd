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
	
	# Populate path list
	path_list.clear()
	for child in get_children():
		_child_entered(child)
	update_mesh()
	
	# Signals
	remake_terrain.connect(update_mesh)
	child_entered_tree.connect(_child_entered)
	child_exiting_tree.connect(_child_exit)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if clear_terrain == true:
		clear_terrain = false
		update_mesh()
	#update_mesh()


func _child_entered(child) -> void:
	if child is Path3D:
		child = child as Path3D
		if not is_instance_of(child, CSGTerrainPath):
			child.set_script(CSGTerrainPath)
			child.curve.bake_interval = size / divs
		path_list.append(child)
		child.curve_changed.connect(update_mesh)


func _child_exit(child) -> void:
	if child is Path3D:
		child.curve_changed.disconnect(update_mesh)
		var index: int = path_list.find(child)
		path_list.remove_at(index)
		if not NOTIFICATION_EXIT_TREE:
			update_mesh()


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
	#textures.apply_textures(path_list, size, material)


func update_mesh() -> void:
	create_mesh_arrays()
	for path in path_list:
		follow_curve(path)
	commit_mesh()


func follow_curve0(path: CSGTerrainPath) -> void:
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


func follow_curve(path: CSGTerrainPath) -> void:
	DebugDraw3D.config.frustum_length_scale = 1
	var width: int = path.width
	var smoothness: float = path.smoothness
	
	var pos: Vector3 = path.position
	var curve: Curve3D = path.curve
	var points: PackedVector3Array = curve.get_baked_points()
	
	# Dictionaries with checked points
	var points_checked = {}
	var verts_checked = {}
	
	for idx in range(points.size() - 1):
		var point: Vector3 = points[idx]
		var local_point: Vector3 = point + pos
		var next_point: Vector3 = points[idx + 1] + pos
		var point2D: Vector2 = Vector2(local_point.x, local_point.z)
		var next_point2D: Vector2 = Vector2(next_point.x, next_point.z)
		
		# Point in the vertex_grid
		var grid_point: Vector3 = local_point * divs / size
		var grid_index: Vector2i = Vector2i(int(grid_point.x), int(grid_point.z))
		grid_index = grid_index.clamp(Vector2i.ZERO, (divs + 1) * Vector2i.ONE)
		
		# Edges that make the square around our point. Formed by two vertices each.
		var edges_idx: Array = [
			[grid_index.x, grid_index.y,      grid_index.x, grid_index.y+1],
			[grid_index.x, grid_index.y+1,    grid_index.x+1, grid_index.y+1],
			[grid_index.x+1, grid_index.y+1,  grid_index.x+1, grid_index.y],
			[grid_index.x+1, grid_index.y,    grid_index.x, grid_index.y]]
		
		# Point where the curve cross the square edge in 3D space. Will return INF if not crossed.
		var central_point: Vector3 = Vector3.INF
		
		for edge in edges_idx:
			var x1: int = edge[0]
			var y1: int = edge[1]
			var x2: int = edge[2]
			var y2: int = edge[3]
			
			var vertex_1: Vector3 = vertex_grid[x1][y1]
			var vertex_2: Vector3 = vertex_grid[x2][y2]
			var edge2D_1: Vector2 = Vector2(vertex_1.x, vertex_1.z)
			var edge2D_2: Vector2 = Vector2(vertex_2.x, vertex_2.z)
			
			var crossed: PackedVector2Array = Geometry2D.get_closest_points_between_segments(
				point2D, next_point2D, edge2D_1, edge2D_2)
			
			# If the closest point on both segment is the same, so they crossed
			if crossed[0].is_equal_approx(crossed[1]):
				# Get the crossed point in the 3D curve
				var curve_point = Geometry3D.get_closest_points_between_segments(
					local_point, next_point,
					Vector3(crossed[0].x, -65536, crossed[0].y),
					Vector3(crossed[0].x, +65536, crossed[0].y))
				
				# Point where the curve cross the square edge in 3D space
				central_point = curve_point[0]
				
				if not points_checked.has(Vector2(x1, y1)):
					vertex_grid[x1][y1].y = central_point.y
					points_checked[Vector2(x1, y1)] = true
				else:
					if vertex_1.y > central_point.y:
						vertex_grid[x1][y1].y = central_point.y
				
				if not points_checked.has(Vector2(x2, y2)):
					vertex_grid[x2][y2].y = central_point.y
					points_checked[Vector2(x2, y2)] = true
				else:
					if vertex_2.y > central_point.y:
						vertex_grid[x2][y2].y = central_point.y
				
				DebugDraw3D.draw_sphere(central_point, 0.5, Color.WHITE)
				DebugDraw3D.draw_line(vertex_1, vertex_2)
				DebugDraw3D.draw_sphere(local_point, 0.5, Color.RED)
			
			DebugDraw3D.draw_sphere(vertex_grid[grid_index.x][grid_index.y], 0.5,  Color.BLUE)
			DebugDraw3D.draw_sphere(vertex_grid[grid_index.x][grid_index.y+1])
			DebugDraw3D.draw_sphere(vertex_grid[grid_index.x+1][grid_index.y+1])
			DebugDraw3D.draw_sphere(vertex_grid[grid_index.x+1][grid_index.y])
		
		
		
		
		#if central_point == Vector3.INF: continue
		
		#var offset: float = curve.get_closest_offset(point)
		#var transf: Transform3D = curve.sample_baked_with_rotation(offset, false, false)
		#var basis_x: Vector3 = transf.basis.x * size / divs
		
		#for x in range(-1, 2):
			#var curved = central_point + basis_x * x
			#DebugDraw3D.draw_sphere(curved)
