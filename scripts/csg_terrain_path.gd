@tool
class_name CSGTerrainPath
extends Path3D

## Number of divisions affected around the path.
@export var width: int = 5:
	set(value):
		if value < 1: value = 1
		width = value
		curve_changed.emit()

## Amount of curvature around the path. Zero is flat.
@export var smoothness: float = 1:
	set(value):
		if value < 0: value = 0
		smoothness = value
		curve_changed.emit()

@export var apply_path_texture: bool = true:
	set(value):
		apply_path_texture = value
		curve_changed.emit()

## Number of pixels around the path that will be painted.
@export var texture_width: int = 5:
	set(value):
		if value < 0: value = 0
		texture_width = value
		curve_changed.emit()

## How strong the texture will merge with the terrain.
@export var texture_smoothness: float = 1:
	set(value):
		if value < 0: value = 0
		texture_smoothness = value
		curve_changed.emit()
