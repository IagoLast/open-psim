extends SceneTree
## Exercise the real scene and input dispatch, with layout assertions at game resolution.
const Main = preload("res://presentation/main.gd")
const Startup = preload("res://tests/scenarios/startup.gd")
var game: Node3D
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	print("UI OK " if ok else "UI FAIL ",title)
	if not ok: failures += 1

func settle() -> void:
	for i: int in range(4): await process_frame

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func button(node: Node, title: String) -> Button:
	if node is Button and node.text == title and node.is_visible_in_tree(): return node
	for child: Node in node.get_children():
		var found: Button = button(child,title)
		if found != null: return found
	return null

func press(title: String) -> void:
	var found: Button = button(game,title)
	check(found != null,"Control visible: " + title)
	if found != null: await click(found.get_global_rect().get_center())

func run() -> void:
	game = Main.new()
	root.add_child(game)
	await settle()
	check(game.snapshot.terrain.size() == 16384,"Escena carga provincia")
	await press("Construir")
	check(game.hud.build_panel.visible and game.hud.catalog.get_child_count() == 6,"Seis categorías de construcción")
	await click(game.hud.catalog.get_child(1).get_global_rect().get_center())
	check(game.hud.current_category == "Servicios" and game.hud.catalog.get_child_count() == 7,"Servicios públicos disponibles en catálogo")
	var card: Button = game.hud.catalog.get_node("market")
	check(game.hud.build_panel.get_global_rect().encloses(card.get_global_rect()),"Tarjeta y coste dentro del panel")
	await click(card.get_global_rect().get_center())
	check(game.tool == "market" and not game.hud.build_panel.visible,"Seleccionar mercado prepara construcción")
	await click(game.world.camera.unproject_position(Vector3(69.5,0,51.5)))
	check(game.sim.state.buildings.any(func(b: Dictionary) -> bool: return b.type == "market"),"Clic en terreno construye mercado")
	check(game.sim.state.coins == 935,"Clic de construcción cobra una vez")
	var model: Node3D = game.world.buildings.get(5)
	check(model != null and model.get_meta("placeholder",false) and model.get_node("Title").visible,"Edificio nuevo tiene bloque y etiqueta visible")
	await press("Seleccionar")
	await press("Recursos")
	check(game.hud.ledger_panel.visible and game.hud.ledger_values.size() == 16,"Panel de 16 existencias y recetas")
	await press("Cerrar")
	await press("Comercio")
	check(game.hud.trade_panel.visible and game.hud.dock_ids.is_empty(),"Comercio explica requisito de muelle")
	await press("Enviar nave")
	check(game.sim.state.voyages.is_empty() and game.hud.message_label.text.contains("muelle"),"No se puede enviar barco sin muelle")
	await press("Cerrar")
	# Use the same game command handler for a coastal district; all costs and validation apply.
	game.command({"type":"build","kind":"dock","x":60,"z":57})
	Startup.road(game.sim,Vector2i(68,53),Vector2i(68,60))
	Startup.road(game.sim,Vector2i(68,60),Vector2i(60,60))
	Startup.road(game.sim,Vector2i(60,60),Vector2i(60,59))
	game.refresh()
	await press("Comercio")
	check(game.hud.dock_ids.size() == 1,"Muelle construido disponible para rutas")
	await press("Enviar nave")
	check(game.sim.state.voyages.size() == 1 and game.sim.state.inventory.salt == 0,"Formulario envía importación diferida de sal")
	check(game.world.ships.size() == 1,"Travesía crea nave visible")
	var saved: Dictionary = game.sim.serialize()
	for i: int in range(600): game.sim.step()
	game.refresh()
	check(game.sim.state.inventory.salt == 10 and game.hud.trade_status.text.contains("Importadas 10 Sal"),"Entrega marítima reflejada en recursos e historial")
	check(game.sim.restore(saved).ok,"Restaurar travesía desde escena real")
	game.refresh()
	await press("Cerrar")
	await press("Mapa")
	check(game.hud.map_panel.visible,"Minimapa desplegable")
	check(game.hud.map_panel.get_global_rect().end.y <= root.get_visible_rect().size.y-76,"Minimapa no invade controles inferiores")
	await click(game.hud.minimap.get_global_rect().position+Vector2(260,70))
	check(game.world.focus.x > 90 and game.world.focus.z < 40,"Clic en minimapa navega al interior")
	await press("Ver toda la provincia")
	check(game.world.camera.size == 145,"Vista completa de provincia")
	await press("Inicio")
	check(game.world.focus.x == 65 and game.world.camera.size == 30,"Volver al asentamiento")
	await press("×4")
	check(game.runner.speed == 4,"Selector de velocidad")
	await press("Pausa")
	check(game.runner.speed == 0,"Control de pausa")
	print("UI RESULTADO: ",failures," fallos")
	# Optional visual review: leave a populated paused scene for a short bounded capture window.
	if "--review" in OS.get_cmdline_user_args():
		game.hud.sidebar.hide()
		game.hud.selected_building = 0
		game.hud.map_panel.hide()
		game.hud.trade_panel.visible = not "--map" in OS.get_cmdline_user_args()
		if "--map" in OS.get_cmdline_user_args():
			game.action("overview")
			game.hud.map_panel.show()
		await create_timer(180).timeout
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
