extends GutTest
## The shipped plan must match the architect's area table (plan APD, Oct. 2015).
## The source PDF is a raster scan, so room-level tolerance is wider than the total.

const PLAN_PATH := "res://data/log16.json"
const ARCHITECT_AREAS := {
	"r_sejour": 31.10,  # cuisine 8.30 + séjour 22.80, one open space
	"r_entree": 4.00,
	"r_wc": 1.80,
	"r_sdb": 5.60,
	"r_ch1": 14.00,
	"r_ch2": 10.50,
	"r_terrasse": 7.00,
}
const ARCHITECT_LIVING_AREA := 67.00
const LIVING_AREA_TOLERANCE := 0.03
const ROOM_TOLERANCE := 0.10

var _project: ProjectData


func before_all() -> void:
	var result := ProjectSerializer.from_json(FileAccess.get_file_as_string(PLAN_PATH))
	assert_true(result.is_ok(), "errors: %s" % [result.errors])
	_project = result.project


func _room(id: String) -> Room:
	for room in _project.rooms:
		if room.id == id:
			return room
	return null


func test_every_architect_room_exists() -> void:
	for id in ARCHITECT_AREAS:
		assert_not_null(_room(id), id)


func test_living_area_matches_architect_total() -> void:
	var total := 0.0
	for room in _project.rooms:
		if room.floor_kind != "outdoor":
			total += Geometry.room_net_area(_project, room)
	assert_almost_eq(total, ARCHITECT_LIVING_AREA, ARCHITECT_LIVING_AREA * LIVING_AREA_TOLERANCE)


func test_each_room_area_is_close_to_architect_table() -> void:
	for id in ARCHITECT_AREAS:
		var expected: float = ARCHITECT_AREAS[id]
		var actual := Geometry.room_net_area(_project, _room(id))
		assert_almost_eq(actual, expected, expected * ROOM_TOLERANCE, id)


func test_every_wall_has_a_footprint() -> void:
	assert_eq(Geometry.wall_footprints(_project).size(), _project.walls.size())
