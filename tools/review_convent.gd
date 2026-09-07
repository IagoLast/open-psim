extends SceneTree
## Inspect the actual model in the advanced city and its construction card.
const Main = preload("res://presentation/main.gd")
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i: int in range(8): await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(path)
	print("CONVENT REVIEW: ",path)

func run() -> void:
	root.size = Vector2i(1366,768)
	root.content_scale_size = root.size
	game = Main.new()
	root.add_child(game)
	game._start_city("advanced")
	game.set_process(false)
	var convent: Dictionary = {}
	for item: Dictionary in game.sim.state.buildings:
		if item.type == "convent": convent = item; break
	assert(not convent.is_empty(),"Advanced city contains the convent")
	game.locate(convent.id)
	game.world.focus = Vector3(convent.x+5,0,convent.z+4)
	game.world.camera.size = 28
	game.world.update_camera()
	await capture("res://art/renders/convent-godot.png")
	game.hud.open_panel(game.hud.build_panel)
	game.hud.show_buildings("Servicios")
	for i: int in range(4): await process_frame
	var card: Button = game.hud.catalog.get_node("convent")
	var scroll: ScrollContainer = game.hud.catalog.get_parent()
	scroll.ensure_control_visible(card)
	await capture("res://build/convent-catalog.png")
	game.queue_free()
	await process_frame
	quit()
