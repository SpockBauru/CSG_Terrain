# Main manager of CSG Terrain. This is what will call the other classes.
@tool
@icon("csg_terrain.svg")
class_name CSGTerrain
extends CSGMesh3D

signal terrain_need_update

## Size of each side of the square.
@export var size: float = 500:
	set(value):
		if value < 0.001:
			value = 0.001
		if value > 1024:
			value = 1024
		
		var old_value = size
		size = value
		_size_changed(old_value)

## Number of subdivisions.
@export_range(1, 128) var divs: int = 50:
	set(value):
		var old_value = divs
		divs = value
		_divs_changed(old_value)

## Resolution of the mask applied to paths. Change if the path texture doesn't merge accordingly.
@export_range(8, 1024) var path_mask_resolution: int = 512:
	set(value):
		var old_value = path_mask_resolution
		path_mask_resolution = value
		_resolution_changed(old_value)

## Create an optimized MeshInstance3D without the bottom cube.[br][br]
## Good topology is not guaranteed. You may need to edit it manually in 3D software.
@export_tool_button("Bake Terrain Mesh", "MeshInstance3D") var nake_button = _bake_terrain

## Create an GLTF file without the bottom cube.
@export_tool_button("Export Terrain File", "File") var export_button = _export_terrain

# Dialog box for Save GLTF file
var fileDialog: EditorFileDialog = null

# CSG Terrain classes.
var terrain_mesh = CSGTerrainMesh.new()
var textures = CSGTerrainTextures.new()
var path_list: Array[CSGTerrainPath] = []

var is_updating: bool = false


func _ready() -> void:
	# Skip if is not in editor.
	if not Engine.is_editor_hint():
		return
	
	# Instantiate material if it's empty.
	if not is_instance_valid(material):
		material = load("res://addons/csg_terrain/csg_terrain_material.tres").duplicate(true)
	
	# If there's no mesh, make a new one and also the first curve.
	if not is_instance_valid(mesh):
		mesh = ArrayMesh.new()
		var path: CSGTerrainPath = CSGTerrainPath.new()
		path.name = "Path3D"
		var curve: Curve3D = Curve3D.new()
		curve.add_point(Vector3(0, 0, 0))
		curve.add_point(Vector3(0, 35, -40))
		curve.set_point_in(1 , Vector3(0, 0, 15))
		curve.set_point_out(1 , Vector3(0, 0, -15))
		path.curve = curve
		add_child(path, true)
		path.set_owner(get_tree().edited_scene_root)
	
	# Populate path list.
	path_list.clear()
	for child in get_children():
		_child_entered(child)
	
	# Signals.
	child_entered_tree.connect(_child_entered)
	child_exiting_tree.connect(_child_exit)
	child_order_changed.connect(_child_order_changed)
	terrain_need_update.connect(_update_terrain)
	
	terrain_need_update.emit()


## When a Path3D enters, add the script CSGTerrainPath.
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
		
		var new_texture_width = path.paint_width * old_size / size
		path.paint_width = int(new_texture_width)
	
	terrain_need_update.emit()


func _divs_changed(old_divs: int) -> void:
	for path in path_list:
		var new_width: float = path.width * float(divs) / old_divs
		path.width = int(new_width)
	
	terrain_need_update.emit()


func _resolution_changed(old_resolution) -> void:
	for path in path_list:
		var new_texture_width = path.paint_width * path_mask_resolution / old_resolution
		path.paint_width = int(new_texture_width)
	
	terrain_need_update.emit()


## Never call _update_terrain directly. Emit the signal terrain_need_update instead.
func _update_terrain():
	# Block if alredy received an update request on the current frame.
	if is_updating == true:
		return
	is_updating = true
	# Wait until next frame to recieve more update requests.
	await get_tree().process_frame
	
	# CSG Terrain update methods.
	terrain_mesh.update_mesh(mesh, path_list, divs, size)
	textures.apply_textures(material, path_list, path_mask_resolution, size)
	
	is_updating = false


## Create an optimized MeshInstance3D without the bottom cube[br][br].
## Good topology is not guaranteed. You may need to edit it manually in 3D software.
func _bake_terrain() -> void:
	var bake = CSGTerrainBake.new()
	var new_mesh: MeshInstance3D = bake.create_mesh(self, size, path_mask_resolution)
	add_sibling(new_mesh, true)
	new_mesh.owner = owner


## Create a file dialog, then call _export_gltf when the file path is chosen.
func _export_terrain() -> void:
	var path = "res://" + name + ".glb"
	var editorViewport = EditorInterface.get_editor_viewport_3d()
	fileDialog = EditorFileDialog.new()
	editorViewport.add_child(fileDialog, true)
	
	fileDialog.file_selected.connect(_export_gltf)
	fileDialog.current_path = path
	fileDialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	fileDialog.set_meta("_created_by", self)
	fileDialog.popup_file_dialog()


## Export the mesh to GLTF file.
func _export_gltf(path: String):
	var export = CSGTerrainBake.new()
	export.export_gltf(path, self, size, path_mask_resolution)
	fileDialog.queue_free()
	EditorInterface.get_resource_filesystem().scan_sources()
