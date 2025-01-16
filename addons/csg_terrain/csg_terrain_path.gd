## Class responsible for holding the information for the path's mesh and texture.
## Each path will have this attached.
@tool
class_name CSGTerrainPath
extends Path3D

## Number of divisions affected around the path.
@export var width: int = 4:
	set(value):
		if value < 0: value = 0
		width = value
		curve_changed.emit()

## Amount of curvature around the path. Zero is flat.
@export var smoothness: float = 1.0:
	set(value):
		if value < 0: value = 0
		smoothness = value
		curve_changed.emit()

## Number of pixels around the path that will be painted.
@export var paint_width: int = 0:
	set(value):
		if value < 0: value = 0
		paint_width = value
		curve_changed.emit()

## How strong the texture will merge with the terrain.
@export var paint_smoothness: float = 1.0:
	set(value):
		if value < 0: value = 0
		paint_smoothness = value
		curve_changed.emit()

var old_transform: Transform3D


# Check if curve was moved
func _process(delta: float) -> void:
	if Engine.is_editor_hint() and old_transform != transform:
		old_transform = transform
		curve_changed.emit()
