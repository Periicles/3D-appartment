extends Node
## Autoload holding the open project. Views never edit the data directly:
## they call the store and react to its signals.

signal project_loaded

var project: ProjectData = ProjectData.new()


## Replaces the open project. On failure the current project is kept and the
## reasons are returned.
func load_from_file(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray(["fichier introuvable : %s" % path])
	var result := ProjectSerializer.from_json(FileAccess.get_file_as_string(path))
	if not result.is_ok():
		return result.errors
	project = result.project
	project_loaded.emit()
	return PackedStringArray()
