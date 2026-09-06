extends SceneTree
## Render every interface at a fixed game resolution for visual review.
const Main = preload("res://presentation/main.gd")
const Startup = preload("res://tests/scenarios/startup.gd")
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i: int in range(5): await process_frame
	RenderingServer.force_draw()

func press(title: String) -> void:
	var pending: Array[Node] = [game.hud.root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Button and (node.text == title or node.tooltip_text == title) and node.is_visible_in_tree():
			node.pressed.emit()
			return
		pending.append_array(node.get_children())

func run() -> void:
	root.size = Vector2i(1366,768)
	root.content_scale_size = Vector2i(1366,768)
	root.show()
	game = Main.new()
	root.add_child(game)
	await settle()
	game.set_process(false)
	Startup.build_economy(game.sim)
	game.refresh()
	for page: String in ["hud","catalog","buildings","ledger","chains","territory","trade","voyages","city","building","citizen","map","help","menu","confirmation"]:
		for panel: Control in [game.hud.build_panel,game.hud.ledger_panel,game.hud.trade_panel,game.hud.map_panel,game.hud.help_panel,game.hud.sidebar]: panel.hide()
		game.hud.selected_building = 0
		game.hud.selected_citizen = 0
		game.hud.city_open = false
		game.hud.close_confirmation()
		match page:
			"catalog": game.hud.show_categories()
			"buildings":
				game.hud.build_panel.show()
				game.hud.show_buildings("Servicios")
			"ledger","chains","territory":
				game.hud.ledger_panel.show()
				press({"ledger":"Existencias","chains":"Cadenas","territory":"Territorio"}[page])
			"trade","voyages":
				game.hud.trade_panel.show()
				press("Contratar nave" if page == "trade" else "Travesías")
			"city": game.hud.city_open = true
			"building": game.hud.selected_building = 1
			"citizen": game.hud.selected_citizen = 1
			"map": game.hud.map_panel.show()
			"help": game.hud.help_panel.show()
			"menu": press("Menú")
			"confirmation":
				press("Menú")
				game.action("new")
		game.refresh()
		await settle()
		root.get_texture().get_image().save_png("res://build/folio-%s.png" % page)
		print("REVIEW ",page)
	quit()
