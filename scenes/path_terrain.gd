@tool
class_name CGSTerrainPath
extends Path3D

@export var width: int = 5:
	set(value):
		if value < 1: value = 1
		width = value
		curve_changed.emit()

@export var smoothness: float = 1:
	set(value):
		if value < 0: value = 0
		smoothness = value
		curve_changed.emit()
