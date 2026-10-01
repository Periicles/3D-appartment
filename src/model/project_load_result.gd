class_name ProjectLoadResult
extends RefCounted
## Outcome of loading a project: either a project, or the reasons it was rejected.

var project: ProjectData = null
var errors := PackedStringArray()


static func success(p_project: ProjectData) -> ProjectLoadResult:
	var result := ProjectLoadResult.new()
	result.project = p_project
	return result


static func failure(p_errors: PackedStringArray) -> ProjectLoadResult:
	var result := ProjectLoadResult.new()
	result.errors = p_errors
	return result


func is_ok() -> bool:
	return project != null
