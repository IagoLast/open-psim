extends SceneTree
## Capture the same landscape viewpoints with the real GL renderer.
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
	var suffix: String = "before" if "--before" in OS.get_cmdline_user_args() else "after"
	DirAccess.make_dir_recursive_absolute("res://build")
	for shot: Dictionary in [
		{"name":"village","focus":Vector3(101,0,33),"zoom":30.0},
		{"name":"bridge","focus":Vector3(101,0,19),"zoom":17.0},
		{"name":"forest","focus":Vector3(111,0,42),"zoom":20.0},
		{"name":"coast","focus":Vector3(80,0,32),"zoom":28.0},
		{"name":"overview","focus":Vector3(64,0,64),"zoom":145.0}
	]:
		game.world.focus = shot.focus
		game.world.camera.size = shot.zoom
		game.world.update_camera()
		for i: int in range(8): await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://build/landscape-%s-%s.png" % [shot.name,suffix])
		print("LANDSCAPE ",shot.name," draw calls: ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	game.queue_free()
	await process_frame
	quit()
