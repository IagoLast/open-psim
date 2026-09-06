extends SceneTree
## Compare the real imported granite and paving at playing and inspection zooms.
const Main = preload("res://presentation/main.gd")
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366,768)
	root.content_scale_size = Vector2i(1366,768)
	game = Main.new()
	root.add_child(game)
	game.set_process(false)
	DirAccess.make_dir_recursive_absolute("res://build")
	for shot: Dictionary in [
		{"name":"street","focus":Vector3(102,0,32),"zoom":12.0},
		{"name":"village","focus":Vector3(101,0,33),"zoom":30.0},
		{"name":"bridge","focus":Vector3(101,0,19),"zoom":17.0}
	]:
		game.world.focus = shot.focus
		game.world.camera.size = shot.zoom
		game.world.update_camera()
		for i: int in range(8): await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://build/granite-%s.png" % shot.name)
		print("GRANITE REVIEW ",shot.name)
	game.queue_free()
	await process_frame
	quit()
