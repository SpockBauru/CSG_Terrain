# Main manager of CSGTerrain
@tool
@icon("CSGTerrain.svg")
class_name CSGTerrain
extends CSGMesh3D

signal terrain_need_update

## Size of each side of the square.
@export var size: float = 512:
	set(value):
		var old_value = size
		size = value
		_size_changed(old_value)

## Number of subdivisions.
@export_range(1, 128) var divs: int = 64:
	set(value):
		var old_value = divs
		divs = value
		_divs_changed(old_value)

## Resolution of the mask applied to paths. Change if the path texture doesn't merge accordingly
@export var path_mask_resolution: int = 512:
	set(value):
		var old_value = path_mask_resolution
		path_mask_resolution = value
		_resolution_changed(old_value)

## Create a static MeshInstance3D with optimized material for use in games.[br][br]
## Good topology is not guaranteed. You may need manually edit in an 3D software.
@export var create_static_mesh: bool = false

# CSGTerrain classes
var terrain_mesh = CSGTerrainMesh.new()
var textures = CSGTerrainTextures.new()
var path_list: Array[CSGTerrainPath] = []

var is_updating: bool = false


func _ready() -> void:
	# Skip if is not in editor
	if not Engine.is_editor_hint():
		return
	
	# Instantiate material if it's empty
	if not is_instance_valid(material):
		material = load("res://addons/csg_terrain/csg_terrain_material.tres").duplicate()
	
	# If there's no mesh, make a new one and also the first curve
	if not is_instance_valid(mesh):
		mesh = ArrayMesh.new()
		var path: Path3D = Path3D.new()
		path.name = "Path3D"
		var curve: Curve3D = Curve3D.new()
		curve.add_point(Vector3(0, 0, -40))
		curve.add_point(Vector3(0, 35, 0))
		curve.set_point_in(1 , Vector3(0, 0, -15))
		curve.set_point_out(1 , Vector3(0, 0, 15))
		path.curve = curve
		add_child(path, true)
		path.set_owner(get_tree().edited_scene_root)
	
	# Populate path list
	path_list.clear()
	for child in get_children():
		_child_entered(child)
	
	# Signals
	child_entered_tree.connect(_child_entered)
	child_exiting_tree.connect(_child_exit)
	child_order_changed.connect(_child_order_changed)
	terrain_need_update.connect(_update_terrain)
	
	terrain_need_update.emit()


# Wainting for Godot to implement @export_button. 
# Implemented on 4.4 dev, waiting for the beta
func _process(_delta: float) -> void:
	if create_static_mesh == true:
		create_static_mesh = false
		var export = CSGTerrainExport.new()
		export.create_mesh(self)


# When a Path3D enters, add the script CSGTerrainPath
func _child_entered(child) -> void:
	if child is Path3D:
		child = child as Path3D
		
		if not is_instance_of(child, CSGTerrainPath):
			child.set_script(CSGTerrainPath)
			child.curve.bake_interval = size / divs
		
		if not child.curve_changed.is_connected(_update_terrain):
			child.curve_changed.connect(_update_terrain)
		
		path_list.append(child)


func _child_exit(child) -> void:
	if child is Path3D:
		var index: int = path_list.find(child)
		path_list.remove_at(index)
		
		if child.curve_changed.is_connected(_update_terrain):
			child.curve_changed.disconnect(_update_terrain)
		
		terrain_need_update.emit()


func _child_order_changed() -> void:
	path_list.clear()
	for child in get_children():
		if child is CSGTerrainPath:
			path_list.append(child)


func _size_changed(old_size: float) -> void:
	for path in path_list:
		var new_width = path.width * old_size / size
		path.width = int(new_width)
		
		var new_texture_width = path.texture_width * old_size / size
		path.texture_width = int(new_texture_width)
	
	terrain_need_update.emit()


func _divs_changed(old_divs: int) -> void:
	for path in path_list:
		var new_width: float = path.width * float(divs) / old_divs
		path.width = int(new_width)
	
	terrain_need_update.emit()


func _resolution_changed(old_resolution) -> void:
	for path in path_list:
		var new_texture_width = path.texture_width * path_mask_resolution / old_resolution
		path.texture_width = int(new_texture_width)
	
	terrain_need_update.emit()


# Never call _update_terrain directly. Emit the signal terrain_need_update instead
func _update_terrain():
	# Block if alredy received an update request on the current frame
	if is_updating == true:
		return
	is_updating = true
	
	# CSGTerrain update methods
	terrain_mesh.update_mesh(mesh, path_list, divs, size)
	textures.apply_textures(material, path_list, path_mask_resolution, size)
	
	# Wait until next frame to recieve more update requests
	await get_tree().process_frame
	is_updating = false
