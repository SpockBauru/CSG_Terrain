# Class responsible for holding the information for the path's mesh and texture.
# Each path will have this attached.
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

## Paint a path bellow the curve.
@export var path_texture: bool = false:
	set(value):
		path_texture = value
		curve_changed.emit()

## Number of pixels around the path that will be painted.
@export var texture_width: int = 4:
	set(value):
		if value < 0: value = 0
		texture_width = value
		curve_changed.emit()

## How strong the texture will merge with the terrain.
@export var texture_smoothness: float = 1.0:
	set(value):
		if value < 0: value = 0
		texture_smoothness = value
		curve_changed.emit()
