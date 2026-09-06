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
	if node is Button and (node.text == title or node.tooltip_text == title) and node.is_visible_in_tree(): return node
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
	check(game.snapshot.terrain.size() == 16384,"Escena carga la ría interior")
	check(root.get_visible_rect().encloses(game.hud.header_panel.get_global_rect()),"Cabecera completa dentro de la ventana")
	check(root.get_visible_rect().encloses(game.hud.footer_panel.get_global_rect()),"Barra inferior completa dentro de la ventana")
	for value: int in game.hud.speed_buttons:
		check(game.hud.header_panel.get_global_rect().encloses(game.hud.speed_buttons[value].get_global_rect()),"Control de velocidad %d dentro de la cabecera" % value)
	await press("Construir")
	check(game.hud.build_panel.visible and game.hud.catalog.get_child_count() == 6,"Seis categorías de construcción")
	await click(game.hud.catalog.get_child(1).get_global_rect().get_center())
	check(game.hud.current_category == "Servicios" and game.hud.catalog.get_child_count() == 7,"Servicios públicos disponibles en catálogo")
	var card: Button = game.hud.catalog.get_node("market")
	check(game.hud.build_panel.get_global_rect().encloses(card.get_global_rect()),"Tarjeta y coste dentro del panel")
	await click(card.get_global_rect().get_center())
	check(game.tool == "market" and not game.hud.build_panel.visible,"Seleccionar mercado prepara construcción")
	var preview := InputEventMouseMotion.new()
	preview.position = game.world.camera.unproject_position(Vector3(99.5,0,29.5))
	root.push_input(preview,true)
	await settle()
	check(game.hud.build_costs.get_child_count() == 2 and game.hud.message_label.text.is_empty(),"Previsualización muestra monedas y madera sin texto redundante")
	await click(game.world.camera.unproject_position(Vector3(99.5,0,29.5)))
	check(game.sim.state.buildings.any(func(b: Dictionary) -> bool: return b.type == "market"),"Clic en terreno construye mercado")
	check(game.sim.state.coins == 935,"Clic de construcción cobra una vez")
	var model: Node3D = game.world.buildings.get(5)
	check(model != null and model.get_meta("placeholder",false) and model.get_node("Title").visible,"Edificio nuevo tiene bloque y etiqueta visible")
	await press("Seleccionar")
	await press("Recursos")
	check(game.hud.ledger_panel.visible and game.hud.ledger_values.size() == 16,"Panel de 16 existencias y recetas")
	await press("Cadenas")
	await press("Territorio")
	await press("Existencias")
	await press("Cerrar")
	await press("Comercio")
	check(game.hud.trade_panel.visible and game.hud.dock_ids.is_empty(),"Comercio explica requisito de muelle")
	check(game.hud.trade_payment.text == "28" and not game.hud.trade_income.is_visible_in_tree(),"Importación distingue el pago inicial sin mostrar cobro")
	check(game.hud.trade_repeat.get_parent().get_parent().get_global_rect().encloses(game.hud.trade_repeat.get_global_rect()),"Repetición visible completa sin desplazar el formulario")
	game.hud.trade_direction.select(1)
	game.hud.trade_direction.item_selected.emit(1)
	game.refresh()
	await settle()
	check(game.hud.trade_payment.text == "8" and game.hud.trade_income.is_visible_in_tree(),"Exportación separa flete al salir e ingreso al volver")
	game.hud.trade_direction.select(0)
	game.hud.trade_direction.item_selected.emit(0)
	game.refresh()
	await settle()
	await press("Enviar nave")
	check(game.sim.state.voyages.is_empty() and game.hud.message_label.text.contains("muelle"),"No se puede enviar barco sin muelle")
	await press("Cerrar")
	# Use the same game command handler for a coastal district; all costs and validation apply.
	game.command({"type":"build","kind":"dock","x":90,"z":35})
	Startup.road(game.sim,Vector2i(98,31),Vector2i(98,38))
	Startup.road(game.sim,Vector2i(98,38),Vector2i(90,38))
	Startup.road(game.sim,Vector2i(90,38),Vector2i(90,37))
	game.refresh()
	await press("Comercio")
	check(game.hud.dock_ids.size() == 1,"Muelle construido disponible para rutas")
	await press("Enviar nave")
	check(game.sim.state.voyages.size() == 1 and game.sim.state.inventory.salt == 0,"Formulario envía importación diferida de sal")
	check(game.world.ships.size() == 1,"Travesía crea nave visible")
	await press("Travesías")
	check(game.hud.voyage_rows.get_child_count() == 1,"Travesía tiene ficha con cargamento y progreso")
	await press("Contratar nave")
	check(game.hud.trade_panel.get_global_rect().encloses(button(game,"Enviar nave").get_global_rect()),"Acción de envío completa dentro del panel")
	var saved: Dictionary = game.sim.serialize()
	for i: int in range(600): game.sim.step()
	game.refresh()
	check(game.sim.state.inventory.salt == 10 and game.hud.trade_status.text.contains("Importadas 10 Sal"),"Entrega marítima reflejada en recursos e historial")
	check(game.sim.restore(saved).ok,"Restaurar travesía desde escena real")
	game.refresh()
	await press("Cerrar")
	await press("Mapa")
	check(game.hud.map_panel.visible,"Minimapa desplegable")
	check(game.hud.map_panel.get_global_rect().end.y < game.hud.footer_panel.get_global_rect().position.y,"Minimapa no invade controles inferiores")
	await click(game.hud.minimap.get_global_rect().position+Vector2(260,70))
	check(game.world.focus.x > 90 and game.world.focus.z < 40,"Clic en minimapa navega al interior")
	for town: Dictionary in preload("res://sim/world_map.gd").LANDMARKS:
		if town.label not in ["PONTEVEDRA","COMBARRO","MARÍN"]: continue
		var target := Vector2(town.x,town.z)
		await click(game.hud.minimap.get_global_rect().position+target/game.snapshot.map_size*game.hud.minimap.size)
		check(Vector2(game.world.focus.x,game.world.focus.z).distance_to(target) < 0.1,"La carta lleva a " + town.label)
	await press("Ver toda la ría")
	check(game.world.camera.size == 145,"Vista completa de la ría")
	await press("Inicio")
	check(game.world.focus.x == 95 and game.world.camera.size == 30,"Volver al asentamiento")
	await click(game.hud.speed_buttons[4].get_global_rect().get_center())
	check(game.runner.speed == 4,"Selector de velocidad")
	check(game.hud.speed_buttons[4].button_pressed and game.hud.speed_label.text == "×4","Velocidad activa reflejada en el HUD")
	await click(game.hud.speed_buttons[0].get_global_rect().get_center())
	check(game.runner.speed == 0,"Control de pausa")
	await press("Ciudad")
	game.refresh()
	await settle()
	check(game.hud.city_open and game.hud.milestone_checks.size() == 13,"Consejo muestra los hitos de prosperidad")
	await press("Cerrar")
	await press("Menú")
	await press("Ayuda")
	check(game.hud.help_panel.visible,"Libro de ayuda disponible desde el menú")
	await press("Cerrar")
	var coins_before: int = game.sim.state.coins
	game.action("new")
	await settle()
	check(is_instance_valid(game.hud.confirmation_overlay),"Confirmación con el tema de la villa")
	await press("Cancelar")
	check(game.hud.confirmation_overlay == null and game.sim.state.coins == coins_before,"Cancelar conserva la partida")
	game.action("new")
	await settle()
	await press("Continuar")
	check(game.hud.confirmation_overlay == null and game.sim.state.tick == 0 and game.sim.state.voyages.is_empty(),"Confirmar inicia una partida nueva")
	check(game.world.focus == preload("res://sim/world_map.gd").START_FOCUS and game.world.camera.size == 30,"La nueva partida vuelve a Pontevedra")
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
