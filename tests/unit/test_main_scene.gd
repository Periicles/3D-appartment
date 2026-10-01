extends GutTest
## Smoke test: the application scene loads the shipped plan and builds it.

const MainScene := preload("res://src/main.tscn")


func test_main_scene_builds_the_shipped_plan() -> void:
	var main: Node3D = add_child_autofree(MainScene.instantiate())
	await wait_physics_frames(2)
	var walls := main.get_node_or_null("World/Walls")
	assert_not_null(walls)
	assert_eq(walls.get_child_count(), ProjectStore.project.walls.size())
	assert_eq(main.get_node("World/Floors").get_child_count(), ProjectStore.project.rooms.size())
	assert_not_null(main.get_node_or_null("Camera"))
	assert_not_null(main.get_node_or_null("Environment"))
	assert_not_null(main.get_node_or_null("Sun"))
