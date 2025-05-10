## Class responsible to make the mask that show the path texture (when they are enabled).
class_name CSGTerrainTextures

var mask: Image = Image.new()


# Main texture manager. This is what external classes should call.
func apply_textures(material: Material, path_list: Array[CSGTerrainPath], mask_size: int, size: float) -> void:
	if path_list.size() <= 0: 
		return
	
	# Don't set a mask if paths have no paint
	var have_paint : bool = false;
	for path in path_list:
		if path.paint_width > 0:
			have_paint = true;
	
	if have_paint == false:
		material.set_shader_parameter("path_mask", null)
		return
	
	# Making the mask
	mask = Image.create_empty(mask_size, mask_size, false, Image.FORMAT_R8)
	var data: PackedByteArray = mask.get_data()
	
	for path in path_list:
		if path.paint_width > 0:
			_apply_path_mask(data, path, mask_size, size, material)
	
	mask.set_data(mask_size, mask_size, false, Image.FORMAT_R8, data)
	material.set_shader_parameter("path_mask", ImageTexture.create_from_image(mask))


func _apply_path_mask(data: PackedByteArray, path: CSGTerrainPath, mask_size: int, size: float,  material: Material) -> void:
	var texture_width: int = path.paint_width
	var texture_smoothness: float = path.paint_smoothness
	var pos: Vector3 = path.position
	var center: Vector3 = Vector3(0.5 * size, 0, 0.5 * size)
	
	# Recriate the 3D curve in xz plane.
	var curve: Curve3D = path.curve
	var curve2D: Curve2D = Curve2D.new()
	curve2D.bake_interval = 2 * texture_width
	for idx in path.curve.point_count:
		var point3D = path.curve.get_point_position(idx)
		# From path space to local space.
		var localPoint: Vector3 = point3D + pos + center
		# From local space to UV space.
		localPoint = localPoint / size
		# From UV space to pixel space.
		localPoint *= mask_size
		# Curve on xz plane.
		var point2D: Vector2 = Vector2(localPoint.x, localPoint.z)
		curve2D.add_point(point2D)
		
		# Curve "point in" and "point out" in path space.
		var pointIn: Vector3 = curve.get_point_in(idx)
		pointIn = pointIn * mask_size / size
		curve2D.set_point_in(idx, Vector2(pointIn.x, pointIn.z))
		
		var pointOut: Vector3 = curve.get_point_out(idx)
		pointOut = pointOut * mask_size / size
		curve2D.set_point_out(idx, Vector2(pointOut.x, pointOut.z))
	
	# Godot 4.4 has support for closed (cyclic) 3D curves, but not in 2D. 
	# Workaround is to place the last point in the place of the first one.
	if path.curve.closed == true:
		curve2D.add_point(curve2D.get_point_position(0))
		curve2D.set_point_in(curve2D.point_count - 1, -curve2D.get_point_out(0))
	
	# Dictionary conaining the pixels positions around the curve.
	var pixel_grid = {}
	
	# Get pixels around the curve.
	for textel in curve2D.get_baked_points():
		var pixel: Vector2i = Vector2i(textel)
		
		# Verify the correct range before the nested "for".
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
				pixel_grid[Vector2i(i, j)] = true
	
	# Set values to pixels.
	for pixel_index in pixel_grid:
		# Pixel position in the data array.
		var array_index: int = pixel_index.x + pixel_index.y * mask_size
		var value: int = data[array_index]
		
		var closest: Vector2 = curve2D.get_closest_point(Vector2(pixel_index))
		var dist: float = closest.distance_to(Vector2(pixel_index))
		var dist_relative: float = dist / texture_width
		
		# Quadratic smooth.
		var lerp_weight: float = dist_relative * dist_relative * texture_smoothness
		lerp_weight = clampf(lerp_weight, 0, 1)
		value = int(lerp(255, value, lerp_weight))
		
		# Finally, the correct value of the pixel.
		data[array_index] = value
