extends SceneTree
## Render the real menu and console at desktop and compact sizes.
const Main = preload("res://presentation/main.gd")
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i: int in range(8): await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(path)
	print("Captura: ",path)

func run() -> void:
	root.size = Vector2i(1366,768)
	root.content_scale_size = root.size
	game = Main.new()
	root.add_child(game)
	await capture("res://build/main-menu.png")
	root.size = Vector2i(1024,640)
	root.content_scale_size = root.size
	await capture("res://build/main-menu-compact.png")
	game._menu_selected("developing")
	game._open_console()
	game._execute_developer_command("help")
	await capture("res://build/developer-console-compact.png")
	root.size = Vector2i(1366,768)
	root.content_scale_size = root.size
	await capture("res://build/developer-console.png")
	game.developer_console.close_console()
	game._start_city("advanced")
	game.world.focus = Vector3(447,0,129)
	game.world.camera.size = 60
	game.world.update_camera()
	await capture("res://build/advanced-city.png")
	game._open_main_menu()
	root.size = Vector2i(1024,640)
	root.content_scale_size = root.size
	await capture("res://build/main-menu-resume-compact.png")
	game.queue_free()
	await process_frame
	quit()
