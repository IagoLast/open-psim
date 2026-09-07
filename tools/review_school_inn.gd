extends SceneTree
## Inspect corrected entrances, rooflines and balcony supports in the real renderer.
const Main = preload("res://presentation/main.gd")
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366,768)
	root.content_scale_size = root.size
	game = Main.new()
	root.add_child(game)
	game._start_city("advanced")
	game.set_process(false)
	for kind: String in ["school","inn"]:
		var building: Dictionary = {}
		for item: Dictionary in game.sim.state.buildings:
			if item.type == kind: building = item; break
		assert(not building.is_empty())
		game.locate(building.id)
		game.world.focus = Vector3(building.x+1,0,building.z+1.5)
		game.world.camera.size = 12
		game.world.update_camera()
		for i: int in range(8): await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://art/renders/%s-godot.png" % kind)
		print("ARCHITECTURE REVIEW: ",kind)
	game.queue_free()
	await process_frame
	quit()
