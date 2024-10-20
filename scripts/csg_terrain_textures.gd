@tool
class_name CSGTerrainTextures
extends Node

var mask_size: int = 512
var mask: Image = Image.new()


# Called when the node enters the scene tree for the first time.
func _init() -> void:
	mask = Image.create_empty(mask_size, mask_size, false, Image.FORMAT_R8)


func apply_textures(path_list: Array[CSGTerrainPath], size: float,  material: Material) -> void:
	if path_list.size() <= 0: return
	
	mask = Image.create_empty(mask_size, mask_size, false, Image.FORMAT_R8)
	
	var data: PackedByteArray = mask.get_data()
	
	for path in path_list:
		if path.apply_path_texture == false:
			continue
		
		var texture_width: int = path.texture_width
		var texture_smoothness: float = path.texture_smoothness
		var points_checked = {}
		var verts_checked = {}
		
		var pos: Vector3 = path.position
		for point3D in path.curve.get_baked_points():
			# From path position to local position
			var localPoint: Vector3 = point3D + pos
			# From local position to UV position
			localPoint = localPoint / size
			# From UV position to pixel position
			localPoint *= mask_size
			# Plane position
			var point: Vector2i = Vector2i(int(localPoint.x), int(localPoint.z))
			
			if points_checked.has(point):
					continue
			points_checked[point] = true
			
			var point_min = point - texture_width * Vector2i.ONE
			point_min = point_min.clamp(Vector2.ZERO, mask_size * Vector2.ONE)
			var point_max = point + texture_width * Vector2i.ONE
			point_max = point_max.clamp(Vector2.ZERO, mask_size * Vector2.ONE)
			
			for i in range(point_min.x, point_max.x):
				for j in range(point_min.y, point_max.y):
					var vec: Vector2 = Vector2(i, j)
					
					if verts_checked.has(vec):
						continue
					verts_checked[vec] = true
					
					# From pixel position to path position
					var vec3D: Vector3 = Vector3(i, 0, j)
					vec3D = (size * vec3D / mask_size) - pos
					vec3D.y = point3D.y
					var baked: Vector3 = path.curve.get_closest_point(vec3D)
					# from path position to pixel position
					baked = (baked + pos) * mask_size / size
					var baked2D: Vector2 = Vector2(baked.x, baked.z)
					
					var dist: float = vec.distance_to(baked2D)
					var dist_relative: float = (dist)  / (texture_width)
					
					var lerp_weight: float = dist_relative * dist_relative * texture_smoothness
					lerp_weight = clampf(lerp_weight, 0, 1)
					var value: int = int(lerp(255, 0, lerp_weight))
					
					# Pixel position
					var index: int = mask_size * int(vec.y) + int(vec.x)
					data[index] = value
	
	mask.set_data(mask_size, mask_size, false, Image.FORMAT_R8, data)
	material.set_shader_parameter("path_mask", ImageTexture.create_from_image(mask))
