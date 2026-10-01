class_name UiSettings
extends RefCounted
## Per-user preferences (interface zoom, recent projects), stored in a small
## config file.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "interface"
const FILES_SECTION := "files"
const MIN_ZOOM := 0.7
const MAX_ZOOM := 1.6
const ZOOM_STEP := 0.1
const MAX_RECENT := 8

var zoom := 1.0
## Most recent first: [{"path": String, "opened_at": float (unix seconds)}].
var recent_projects: Array[Dictionary] = []


static func load_from(path: String = DEFAULT_PATH) -> UiSettings:
	var settings := UiSettings.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return settings
	var value = file.get_value(SECTION, "zoom", 1.0)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		settings.zoom = _clamped(value)
	var recents = file.get_value(FILES_SECTION, "recent_projects", [])
	if typeof(recents) == TYPE_ARRAY:
		for entry in recents:
			if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("path")) == TYPE_STRING \
					and typeof(entry.get("opened_at")) in [TYPE_FLOAT, TYPE_INT]:
				settings.recent_projects.append({"path": entry.path, "opened_at": float(entry.opened_at)})
		settings.recent_projects = settings.recent_projects.slice(0, MAX_RECENT)
	return settings


func save_to(path: String = DEFAULT_PATH) -> Error:
	var file := ConfigFile.new()
	file.set_value(SECTION, "zoom", zoom)
	file.set_value(FILES_SECTION, "recent_projects", recent_projects)
	return file.save(path)


## Puts `path` first in the recent list (moving it if already there), keeping
## at most MAX_RECENT entries.
func remember_project(path: String, opened_at: float = Time.get_unix_time_from_system()) -> void:
	forget_project(path)
	recent_projects.push_front({"path": path, "opened_at": opened_at})
	recent_projects = recent_projects.slice(0, MAX_RECENT)


func forget_project(path: String) -> void:
	recent_projects = recent_projects.filter(func(entry: Dictionary) -> bool: return entry.path != path)


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
