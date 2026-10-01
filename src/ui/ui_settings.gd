class_name UiSettings
extends RefCounted
## Per-user interface preferences, stored in a small config file.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "interface"
const MIN_ZOOM := 0.7
const MAX_ZOOM := 1.6
const ZOOM_STEP := 0.1

var zoom := 1.0


static func load_from(path: String = DEFAULT_PATH) -> UiSettings:
	var settings := UiSettings.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return settings
	var value = file.get_value(SECTION, "zoom", 1.0)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		settings.zoom = _clamped(value)
	return settings


func save_to(path: String = DEFAULT_PATH) -> Error:
	var file := ConfigFile.new()
	file.set_value(SECTION, "zoom", zoom)
	return file.save(path)


func zoom_in() -> void:
	zoom = _clamped(zoom + ZOOM_STEP)


func zoom_out() -> void:
	zoom = _clamped(zoom - ZOOM_STEP)


func reset_zoom() -> void:
	zoom = 1.0


## Interface scale for a screen whose backing scale is `screen_scale`
## (2 on a Retina display); a non-positive scale counts as 1.
func ui_scale(screen_scale: float) -> float:
	return (screen_scale if screen_scale > 0.0 else 1.0) * zoom


## Clamped to the limits and rounded to the step, so repeated steps never drift.
static func _clamped(value: float) -> float:
	return clampf(snappedf(value, ZOOM_STEP), MIN_ZOOM, MAX_ZOOM)
