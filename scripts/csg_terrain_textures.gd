@tool
class_name CSGTerrainTextures

var mask: Image = Image.new()

func apply_textures(path_list: Array[CSGTerrainPath], mask_size: int, size: float,  material: Material) -> void:
	if path_list.size() <= 0: return
	mask = Image.create_empty(mask_size, mask_size, false, Image.FORMAT_R8)
	var data: PackedByteArray = mask.get_data()
	
	for path in path_list:
		if path.path_texture == false:
			continue
		
		var texture_width: int = path.texture_width
		var texture_smoothness: float = path.texture_smoothness
		var pos: Vector3 = path.position
		
		var points_checked = {}
		
		# Make a curve on xz plane, define on pixel space
		var points_3D: PackedVector3Array = path.curve.get_baked_points()
		var points_2D: Array[Vector2i] = []
		for i in range(points_3D.size()):
			var point3D: Vector3 = points_3D[i]
			# From path space to local space
			var localPoint: Vector3 = point3D + pos
			# From local space to UV space
			localPoint = localPoint / size
			# From UV space to pixel space
			localPoint *= mask_size
			# Pixel position
			var pixel_index: Vector2i = Vector2i(int(localPoint.x), int(localPoint.z))
			if not points_checked.has(pixel_index):
				points_2D.append(pixel_index)
				points_checked[pixel_index] = true
		
		# Key is pixel position.
		var pixel_grid = {}
		
		# Get pixels around the curve
		for idx in range(points_2D.size() - 1):
			var pixel: Vector2i = points_2D[idx]
			var range_min_x: int = -texture_width + pixel.x
			range_min_x = clampi(range_min_x, 0, mask_size)
			var range_max_x: int = texture_width + 1 + pixel.x
			range_max_x = clampi(range_max_x, 0, mask_size)
			var range_min_y: int = -texture_width + pixel.y
			range_min_y = clampi(range_min_y, 0, mask_size)
			var range_max_y: int = texture_width + 1 + pixel.y
			range_max_y = clampi(range_max_y, 0, mask_size)
			
			for i in range(range_min_x, range_max_x):
				for j in range(range_min_y, range_max_y):
					var grid: Vector2i = Vector2i(i, j)
					pixel_grid[grid] = true
		
		var curve: Curve3D = path.curve
		var curve2D: Curve2D = Curve2D.new()
		curve2D.bake_interval = float(mask_size) / 32
		for idx in path.curve.point_count:
			var point3D = path.curve.get_point_position(idx)
			var localPoint: Vector3 = point3D + pos
			# From local space to UV space
			localPoint = localPoint / size
			# From UV space to pixel space
			localPoint *= mask_size
			# Pixel position
			var point: Vector2i = Vector2i(int(localPoint.x), int(localPoint.z))
			curve2D.add_point(point)
			
			var pointIn: Vector3 = curve.get_point_in(idx)
			pointIn = pointIn * mask_size / size
			curve2D.set_point_in(idx, Vector2(pointIn.x, pointIn.z))
			var pointOut: Vector3 = curve.get_point_out(idx)
			pointOut = pointOut * mask_size / size
			curve2D.set_point_out(idx, Vector2(pointOut.x, pointOut.z))
		
		# Set values to pixels
		for pixel_index in pixel_grid:
			var closest: Vector2 = curve2D.get_closest_point(Vector2(pixel_index))
			var dist: float = closest.distance_to(Vector2(pixel_index))
			var dist_relative: float = dist / texture_width
			
			var lerp_weight: float = dist_relative * dist_relative * texture_smoothness
			lerp_weight = clampf(lerp_weight, 0, 1)
			var value: int = int(lerp(255, 0, lerp_weight))
			
			# Pixel position in the data array
			var array_index: int = pixel_index.x + pixel_index.y * mask_size
			data[array_index] = value
	
	mask.set_data(mask_size, mask_size, false, Image.FORMAT_R8, data)
	material.set_shader_parameter("path_mask", ImageTexture.create_from_image(mask))
