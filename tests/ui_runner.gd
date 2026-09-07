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
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func drag_road(start: Vector2, end: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = start
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = start
	event.pressed = true
	root.push_input(event,true)
	motion.position = end
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	event = event.duplicate()
	event.position = end
	event.pressed = false
	root.push_input(event,true)
	await settle()

func button(node: Node, title: String) -> Button:
	if node is Button and (node.text == title or node.tooltip_text == title) and node.is_visible_in_tree(): return node
	for child: Node in node.get_children():
		var found: Button = button(child,title)
		if found != null: return found
	return null

func wheel(point: Vector2, direction: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.button_index = direction
	event.factor = 1.0
	event.position = point
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func press(title: String) -> void:
	var found: Button = button(game,title)
	check(found != null,"Control visible: " + title)
	if found != null: await click(found.get_global_rect().get_center())

func reveal(control: Control) -> void:
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await settle()

func sidebar_layout(title: String) -> void:
	var bounds: Rect2 = game.hud.navigation_panel.get_global_rect()
	check(root.get_visible_rect().encloses(bounds),title+": menú dentro de la ventana")
	check(game.hud.minimap.is_visible_in_tree() and bounds.encloses(game.hud.minimap.get_global_rect()),title+": minimapa siempre visible")
	var visible_pages: int = 0
	for page: Control in game.hud.page_host.get_children():
		if page.visible:
			visible_pages += 1
			check(bounds.encloses(page.get_global_rect()),title+": submenú contenido en el lateral")
	check(visible_pages == 1,title+": un solo submenú abierto")

func run() -> void:
	root.size = Vector2i(1366,768)
	root.content_scale_size = Vector2i(1366,768)
	game = Main.new()
	root.add_child(game)
	await settle()
	game.set_process(false)
	check(game.snapshot.terrain.size() == 262144 and game.snapshot.buildings.is_empty(),"Mapa ampliado arranca vacío")
	check(game.main_menu.is_open() and not game.hud.visible,"El menú principal recibe al jugador")
	check(not game.main_menu.buttons["continue"].visible,"El primer menú no ofrece continuar una partida inexistente")
	check(game.main_menu.buttons.load.disabled == not FileAccess.file_exists(game.Save.SAVE_PATH),"Cargar solo está disponible cuando existe guardado")
	for viewport_size: Vector2i in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1366,768)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await settle()
		check(root.get_visible_rect().encloses(game.main_menu.panel.get_global_rect()),"Menú principal contenido en "+str(viewport_size))
	var menu_zoom: float = game.world.camera.size
	await wheel(Vector2(20,400),MOUSE_BUTTON_WHEEL_DOWN)
	await key(KEY_SPACE)
	check(game.world.camera.size == menu_zoom and game.runner.speed == 0,"Menú bloquea zoom y reproducción")
	await press("Nueva villa")
	check(not game.main_menu.is_open() and game.hud.visible and game.has_started,"Nueva villa entra en la partida")
	sidebar_layout("Inicio")
	check(game.hud.immigration_status.text.contains("En pausa") and game.hud.immigration_status.text.contains("almacén"),"Inicio explica pausa y requisito para recibir vecinos")
	check(game.hud.objective_label.text.contains("Funda"),"Encargo inicial visible")
	await press("Comercio")
	await press("Construir almacén")
	check(game.tool == "warehouse" and game.hud.build_panel.visible,"Comercio permite colocar el primer almacén desde el inicio")
	await press("Seleccionar")
	await press("Construir")
	game.hud.show_buildings("Servicios")
	for i: int in range(20): await process_frame
	var scroll: ScrollContainer = game.hud.catalog.get_parent()
	var menu_point: Vector2 = scroll.get_global_rect().get_center()
	var initial_zoom: float = game.world.camera.size
	await wheel(menu_point,MOUSE_BUTTON_WHEEL_DOWN)
	check(scroll.scroll_vertical > 0,"La rueda desplaza el catálogo")
	check(game.world.camera.size == initial_zoom,"Scroll del catálogo no cambia el zoom")
	scroll.scroll_vertical = 100000
	await settle()
	await wheel(menu_point,MOUSE_BUTTON_WHEEL_DOWN)
	scroll.scroll_vertical = 0
	await settle()
	await wheel(menu_point,MOUSE_BUTTON_WHEEL_UP)
	await wheel(game.hud.header_panel.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_DOWN)
	await wheel(game.hud.minimap.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_UP)
	check(game.world.camera.size == initial_zoom,"Los bordes del scroll, cabecera y minimapa bloquean el zoom")
	await wheel(Vector2(500,400),MOUSE_BUTTON_WHEEL_DOWN)
	check(game.world.camera.size > initial_zoom,"La rueda sobre el mapa aleja la cámara")
	await wheel(Vector2(500,400),MOUSE_BUTTON_WHEEL_UP)
	check(game.world.camera.size == initial_zoom,"La rueda sobre el mapa acerca la cámara")
	game.hud.show_buildings("Puerto")
	await settle()
	var warehouse_card: Button = game.hud.catalog.get_node("warehouse")
	await reveal(warehouse_card)
	await click(warehouse_card.get_global_rect().get_center())
	check(game.tool == "warehouse","Almacén construible desde catálogo")
	var rotation := InputEventKey.new()
	rotation.keycode = KEY_R
	rotation.pressed = true
	root.push_input(rotation,true)
	await settle()
	check(game.building_rotation == 1,"R gira la parcela")
	var point: Vector2 = game.world.camera.unproject_position(Vector3(441.5,0,128.5))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await settle()
	check(game.world.preview.get_child_count() == 13 and game.world.preview.has_node("BuildingPreview"),"Vista previa 3D con parcela rectangular de 12 casillas")
	await click(point)
	check(game.sim.state.buildings.size() == 1 and game.sim.building(1).rotation == 1,"Clic construye rectángulo girado")
	check(game.sim.state.coins == 940,"Construcción cobra una sola vez")
	var stored_inventory: Dictionary = game.sim.state.inventory.duplicate()
	for resource: String in game.sim.state.inventory: game.sim.state.inventory[resource] = 0
	game.sim.state.inventory.wood = game.sim.definitions.balance.inventory_capacity + game.sim.definitions.buildings.warehouse.get("storage",0)
	var cargo_snapshot: Dictionary = game.sim.get_snapshot()
	cargo_snapshot.buildings[0].connected = true
	game.world.sync(cargo_snapshot,game.sim.definitions)
	check(game.world.buildings[1].get_node("CargoWarning").text == "ALMACÉN LLENO" and game.world.buildings[1].get_meta("cargo_count") == 8,"Almacén lleno muestra carga y aviso sin seleccionar")
	game.sim.state.inventory = stored_inventory
	game.refresh()
	check(game.world.buildings[1].get_node("CargoWarning").text.is_empty(),"El aviso desaparece al liberar espacio")
	await press("Seleccionar")
	game.hud.selected_building = 1
	game.refresh()
	await settle()
	await reveal(button(game,"Comprar / vender"))
	await press("Comprar / vender")
	check(game.hud.merchant_panel.visible,"El almacén abre compras y ventas")
	check(game.hud.merchant_buy.disabled,"Comprar deshabilitado antes del atraque")
	for i: int in range(301): game.sim.step()
	game.refresh()
	await settle()
	game.hud.merchant_resource.select(game.sim.definitions.resources.keys().find("salt"))
	game.refresh()
	await settle()
	var before: int = game.sim.state.coins
	await press("Comprar")
	check(game.sim.state.inventory.salt == 10 and game.sim.state.coins == before-20,"Compra real desde formulario del almacén")
	before = game.sim.state.coins
	await press("Vender")
	check(game.sim.state.inventory.salt == 0 and game.sim.state.coins == before+10,"Venta real desde formulario")
	sidebar_layout("Mercaderes")
	await press("Rutas propias del muelle")
	check(game.hud.trade_panel.visible,"Rutas propias accesibles")
	await press("Cerrar")
	await press("Construir")
	game.hud.show_buildings("Alimentos")
	await settle()
	var granary_card: Button = game.hud.catalog.get_node("horreo")
	await reveal(granary_card)
	check(granary_card.tooltip_text.contains("Guarda maíz") and granary_card.tooltip_text.contains("400"),"Hórreo explica función y capacidad antes de construir")
	await click(granary_card.get_global_rect().get_center())
	check(game.tool == "horreo","Hórreo disponible en el catálogo de alimentos")
	await click(game.world.camera.unproject_position(Vector3(441.5,0,133.5)))
	check(game.sim.state.buildings.size() == 2 and game.sim.building(2).type == "horreo","Hórreo se construye desde la interfaz")
	check(game.world.buildings.has(2) and not game.world.buildings[2].get_meta("placeholder"),"Hórreo utiliza su modelo Blender")
	game.sim.create(1530,game.sim.definitions)
	game.world.topology = -1
	var ids: Dictionary = Startup.build_economy(game.sim)
	for i: int in range(2400): game.sim.step()
	game.refresh()
	await settle()
	check(game.world.people.size() == 8,"Vecinos visibles tras la fundación")
	for i: int in range(240):
		if game.sim.state.buildings.any(func(b: Dictionary) -> bool: return b.present > 0): break
		game.sim.step()
	game.refresh()
	game.world.animate(game.snapshot,0,0)
	var worker: Dictionary = {}
	for citizen: Dictionary in game.snapshot.citizens:
		if citizen.activity == "Trabajando": worker = citizen; break
	check(not worker.is_empty(),"Hay un trabajador que ha llegado al edificio")
	if not worker.is_empty():
		check(not game.world.people[worker.id].visible,"El trabajador queda dentro, sin animación exterior")
		var marker: Label3D = game.world.buildings[worker.job].get_node("Workers")
		check(marker.visible and marker.text.begins_with("●") and marker.modulate == Color("#91bd72"),"Un punto verde indica trabajadores dentro")
		while game.sim.state.tick%300 < 260: game.sim.step()
		game.refresh()
		game.world.animate(game.snapshot,0,0)
		check(game.world.people[worker.id].visible,"El trabajador reaparece al salir del edificio")
		check(marker.visible and marker.modulate == Color("#e4ba68"),"Un punto ámbar distingue personal asignado fuera")

	check(game.world.buildings[ids.house].get_meta("model_family") == "house_cottage","Casa inicial pequeña")
	var home: Dictionary = game.sim.building(ids.house)
	home.level = 3
	game.refresh()
	check(game.world.buildings[ids.house].get_meta("model_family") == "house_tall","Mejora cambia 3D sin cambiar caminos")
	check(game.hud.resource_values.population.text == "8 / 12","Capacidad evolutiva visible")
	check(game.world.buildings[ids.house].get_meta("front") == home.front,"Fachada respeta acceso")
	game.hud.selected_building = ids.house
	game.refresh()
	await settle()
	check(game.hud.housing_card.visible and game.hud.housing_card.occupancy.text.contains("/ 8") and not game.hud.housing_card.next_step.text.is_empty(),"Inspector explica crecimiento")
	check(game.hud.housing_card.next_step.text.contains("Carencias:") or game.hud.housing_card.next_step.text.contains("Falta:"),"La vivienda enumera las necesidades pendientes")
	var resident: Button = game.hud.housing_card.resident_buttons.values()[0]
	await reveal(resident)
	await click(resident.get_global_rect().get_center())
	check(game.hud.selected_citizen > 0 and not game.hud.housing_card.visible,"La tarjeta de vecino abre su ficha")
	await reveal(button(game,"Localizar vivienda"))
	await press("Localizar vivienda")
	check(game.hud.housing_card.visible,"Se puede volver del vecino a su vivienda")
	game.sim.Risks.ruin(game.sim,home,"Prueba")
	game.sim.rebuild()
	game.refresh()
	await settle()
	check(game.hud.inspector_label.text.contains("EN RUINAS"),"Ruina y reparación visibles")
	await reveal(button(game,"Reparar · 20 monedas / 4 madera"))
	await press("Reparar · 20 monedas / 4 madera")
	check(not home.ruined,"Reparación desde inspector")
	await press("Ciudad")
	game.refresh()
	await settle()
	check(game.hud.objective_details.text.contains("Estabilidad"),"Ciudad muestra etapa y progreso")
	await press("Cerrar")
	await press("Recursos")
	await press("Cadenas")
	await press("Territorio")
	await press("Existencias")
	await press("Cerrar")
	await press("Ver toda la ría")
	check(game.world.camera.size == 580,"Vista general ajustada al mapa ampliado")
	await press("Inicio")
	check(game.world.camera.size == 30,"Volver al barrio")
	await press("Comercio")
	for viewport_size: Vector2i in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1366,768)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await settle()
		sidebar_layout(str(viewport_size))
		check(game.hud.header_panel.get_global_rect().encloses(game.hud.speed_buttons[4].get_global_rect()),"Controles de velocidad dentro de cabecera")
	game.action("new")
	await settle()
	await press("Cancelar")
	check(game.sim.state.citizens.size() == 8,"Cancelar conserva población")
	game.action("new")
	await settle()
	await press("Continuar")
	check(game.sim.state.buildings.is_empty() and game.world.buildings.is_empty() and game.world.people.is_empty(),"Reiniciar limpia edificios y vecinos")
	check(game.world.focus == preload("res://sim/world_map.gd").START_FOCUS,"Nueva partida enfoca la fundación")
	await press("Construir")
	game.hud.show_buildings("Servicios")
	await settle()
	var dirt_card: Button = game.hud.catalog.get_node("road_dirt")
	await reveal(dirt_card)
	await click(dirt_card.get_global_rect().get_center())
	check(game.tool == "road_dirt","Camino de tierra seleccionable en Servicios")
	var road_from: Vector2 = game.world.camera.unproject_position(Vector3(437.5,0,132.5))
	var road_to: Vector2 = game.world.camera.unproject_position(Vector3(439.5,0,132.5))
	await drag_road(road_from,road_to)
	check(game.sim.RoadSurfaces.at(game.sim.state,132*512+438) == "dirt" and game.sim.roads.has(132*512+438),"Arrastrar coloca un tramo de tierra")
	var dirt_models: int = 0
	for model: Node3D in game.world.road_nodes.get_children():
		if model.get_meta("model_kind") == "road_dirt": dirt_models += 1
	check(dirt_models == 3,"Tres casillas utilizan el gráfico de tierra")
	var paved_card: Button = game.hud.catalog.get_node("road")
	await reveal(paved_card)
	await click(paved_card.get_global_rect().get_center())
	await drag_road(road_from,road_to)
	check(game.sim.RoadSurfaces.at(game.sim.state,132*512+438) == "paved","Arrastrar pavimento transforma el tramo existente")
	await press("Menú")
	check(game.main_menu.is_open() and game.main_menu.buttons["continue"].visible,"Menú durante partida ofrece continuar")
	await press("Villa en desarrollo")
	await press("Cancelar")
	check(game.main_menu.is_open() and game.sim.state.buildings.is_empty(),"Cancelar la ciudad preparada vuelve al menú y conserva la partida")
	await press("Villa en desarrollo")
	await press("Continuar")
	check(not game.main_menu.is_open() and game.sim.state.buildings.size() > 10 and game.sim.state.citizens.size() > 0,"Villa en desarrollo carga edificios y vecinos reales")
	check(game.runner.speed == 0 and game.hud.selected_building == 0 and game.hud.selected_citizen == 0,"Ciudad preparada comienza pausada y sin selección anterior")
	var developing_buildings: int = game.sim.state.buildings.size()
	await key(KEY_F4)
	check(game.developer_console.is_open() and game.runner.speed == 0,"F4 abre la consola en pausa")
	var console_zoom: float = game.world.camera.size
	await wheel(Vector2(20,400),MOUSE_BUTTON_WHEEL_DOWN)
	await key(KEY_SPACE)
	check(game.world.camera.size == console_zoom and game.runner.speed == 0,"La consola bloquea rueda y atajos del mundo")
	game.developer_console.input.text = "money infinite"
	await press("Ejecutar")
	check(game.developer_tools.infinite_money,"La consola activa dinero infinito")
	await press("Ciudad avanzada")
	await press("Cancelar")
	check(game.developer_console.is_open() and game.sim.state.buildings.size() == developing_buildings,"Cancelar la generación conserva ciudad y reabre consola")
	await press("Ciudad avanzada")
	await press("Continuar")
	check(game.developer_console.is_open() and game.sim.state.buildings.size() > developing_buildings,"Consola genera ciudad avanzada tras confirmar")
	await key(KEY_F4)
	check(not game.developer_console.is_open(),"F4 cierra consola sin reanudar el tiempo")
	await press("Consola")
	await key(KEY_ESCAPE)
	check(not game.developer_console.is_open() and not game.main_menu.is_open(),"Escape cierra consola sin abrir otro menú")
	await key(KEY_ESCAPE)
	check(game.main_menu.is_open(),"Escape abre menú desde la ciudad")
	await press("Nueva villa")
	await press("Continuar")
	check(game.sim.state.buildings.is_empty() and not game.developer_tools.infinite_money,"Nueva villa limpia ciudad y desactiva los trucos")
	await press("Construir")
	game.hud.show_buildings("Servicios")
	await settle()
	var convent_card: Button = game.hud.catalog.get_node("convent")
	await reveal(convent_card)
	await click(convent_card.get_global_rect().get_center())
	check(game.tool == "convent","Convento seleccionable desde Construir → Servicios")
	await key(KEY_R)
	check(game.building_rotation == 1 and game.sim.footprint("convent",441,136,game.building_rotation).size() == 80,"Convento permite girar su parcela rectangular monumental")
	await press("Seleccionar")
	if "--capture" in OS.get_cmdline_user_args():
		Startup.build_economy(game.sim)
		for i: int in range(2400): game.sim.step()
		game.refresh()
		game.hud.open_panel(game.hud.merchant_panel)
		await settle()
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://build/mechanics-review.png")
	print("UI RESULTADO: ",failures," fallos")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
