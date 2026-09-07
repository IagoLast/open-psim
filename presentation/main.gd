extends Node3D
const Map = preload("res://sim/world_map.gd")
const RoadSurfaces = preload("res://sim/road_surfaces.gd")
const Simulation = preload("res://sim/simulation.gd")
const Definitions = preload("res://adapters/definitions.gd")
const Save = preload("res://adapters/save_service.gd")
const Runner = preload("res://adapters/simulation_runner.gd")
const World = preload("res://presentation/world_view.gd")
const HUD = preload("res://presentation/ui/hud.gd")
const MainMenu = preload("res://presentation/ui/main_menu.gd")
const CityPresets = preload("res://sim/city_presets.gd")
var developer_tools := preload("res://sim/developer_tools.gd").new()
var developer_console := preload("res://presentation/ui/developer_console.gd").new()
var main_menu := MainMenu.new()
var has_started: bool = false
var sim := Simulation.new()
var runner := Runner.new()
var world: Node3D
var hud: CanvasLayer
var snapshot: Dictionary
var tool: String = "select"
var building_rotation: int = 0
var dragging: bool = false
var drag_start: int = -1
var hover_cell: int = -2
var animation_time: float = 0
var refresh_time: float = 0
var web_probe := preload("res://adapters/web_probe.gd").new()

func _ready() -> void:
	var definitions: Dictionary = Definitions.load_data()
	if definitions.is_empty():
		push_error("Datos de juego inválidos")
		return
	sim.create(1530,definitions)
	snapshot = sim.get_snapshot()
	world = World.new()
	add_child(world)
	world.setup(snapshot)
	hud = HUD.new()
	add_child(hud)
	hud.setup(definitions)
	world.sidebar_width = hud.SIDEBAR_WIDTH
	world.update_camera()
	hud.tool_selected.connect(_select_tool)
	hud.speed_selected.connect(func(value: int) -> void: runner.speed = value; refresh())
	hud.order.connect(command)
	hud.action.connect(action)
	hud.locate.connect(locate)
	hud.citizen_selected.connect(func(id: int) -> void:
		hud.selected_citizen = id
		hud.selected_building = 0
		refresh())
	hud.map_navigate.connect(func(point: Vector3) -> void: world.focus = point; world.update_camera())
	add_child(main_menu)
	main_menu.setup()
	main_menu.selected.connect(_menu_selected)
	add_child(developer_console)
	developer_console.setup(definitions)
	developer_console.command_submitted.connect(_developer_command)
	developer_console.closed.connect(func() -> void: hud.show(); refresh())
	refresh()
	if not OS.is_userfs_persistent(): hud.message_label.text = "Persistencia no disponible: el guardado podría perderse al cerrar."
	_open_main_menu()

func _process(delta: float) -> void:
	if snapshot.is_empty(): return
	if not _modal_open(): world.pan(delta)
	hud.minimap.focus = world.focus
	hud.minimap.zoom = world.camera.size
	var stepped: int = runner.advance(sim,delta)
	developer_tools.enforce(sim)
	if stepped > 0: snapshot = sim.get_snapshot()
	if runner.speed > 0: animation_time += minf(delta,0.25)*runner.speed
	world.animate(snapshot,runner.accumulator*sim.definitions.balance.ticks_per_second,animation_time)
	refresh_time += delta
	if refresh_time >= 0.2:
		refresh_time = 0
		world.sync(snapshot,sim.definitions)
		_refresh_hud()
		web_probe.publish(self)
		hud.debug_label.text = "FPS %d · tick %.2f ms · población %d\nSin ruta %d · %s" % [Engine.get_frames_per_second(),runner.tick_usec/1000.0,snapshot.citizens.size(),snapshot.citizens.filter(func(c: Dictionary) -> bool: return c.activity == "Sin ruta").size(),"Velocidad limitada" if runner.slowed else "Ritmo normal"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		runner.accumulator = 0
		runner.speed = 0

func refresh() -> void:
	snapshot = sim.get_snapshot()
	world.sync(snapshot,sim.definitions)
	_refresh_hud()
	hover_cell = -2

func _refresh_hud() -> void:
	hud.refresh(snapshot,runner.speed)
	if developer_tools.infinite_money: hud.resource_values.coins.text = "∞"

func _select_tool(kind: String) -> void:
	tool = kind
	dragging = false
	hud.set_tool(kind)
	world.show_preview([],true)
	hover_cell = -2

func command(order: Dictionary) -> void:
	developer_tools.enforce(sim)
	var result: Dictionary = sim.apply_command(order)
	developer_tools.enforce(sim)
	hud.message_label.text = "Orden completada" if result.ok else result.message
	refresh()

func locate(id: int) -> void:
	var item: Dictionary = sim.building(id)
	if id == 0:
		for candidate: Dictionary in sim.state.buildings:
			if candidate.type == "warehouse":
				item = candidate
				break
	if item.is_empty():
		world.focus = Map.START_FOCUS
		world.camera.size = 30
		world.update_camera()
		return
	world.focus = Vector3(item.x,0,item.z)
	world.camera.size = 30
	world.update_camera()
	hud.selected_citizen = 0
	hud.selected_building = id
	hud.last_inspector = ""
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(hud.confirmation_overlay):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: hud.close_confirmation()
		return
	if main_menu.is_open() or developer_console.is_open(): return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if tool != "select": _select_tool("select")
				else: _open_main_menu()
			KEY_SPACE:
				runner.speed = 1 if runner.speed == 0 else 0
				refresh()
			KEY_R:
				if sim.definitions.buildings.has(tool):
					building_rotation = (building_rotation+1)%4
					hover_cell = -2
					hud.message_label.text = "Giro %d° · R para girar" % (building_rotation*90)
			KEY_F3: hud.debug_label.visible = not hud.debug_label.visible
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: _select_tool("select")
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.camera.size = maxf(12,world.camera.size-1.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.camera.size = minf(Map.OVERVIEW_ZOOM+30,world.camera.size+1.5)
		if event.button_index == MOUSE_BUTTON_LEFT:
			var cell: int = world.cell_at(event.position)
			if event.pressed:
				if cell < 0: return
				if RoadSurfaces.TOOLS.has(tool):
					dragging = true
					drag_start = cell
				elif tool == "select": select_at(event.position,cell)
				elif tool == "demolish": command({"type":"demolish","cell":cell})
				else: command({"type":"build","kind":tool,"x":cell%sim.width(),"z":cell/sim.width(),"rotation":building_rotation})
			elif dragging:
				dragging = false
				if cell >= 0: command({"type":"road","surface":RoadSurfaces.TOOLS[tool],"cells":road_segment(drag_start,cell)})
				world.show_preview([],true)
	if event is InputEventMouseMotion:
		var cell: int = world.cell_at(event.position)
		if cell == hover_cell: return
		hover_cell = cell
		if cell < 0 or tool in ["select","demolish"]:
			world.show_preview([],true)
			return
		var cells: Array = road_segment(drag_start,cell) if RoadSurfaces.TOOLS.has(tool) and dragging else ([cell] if RoadSurfaces.TOOLS.has(tool) else sim.footprint(tool,cell%sim.width(),cell/sim.width(),building_rotation))
		var order: Dictionary = {"type":"road","surface":RoadSurfaces.TOOLS[tool],"cells":cells} if RoadSurfaces.TOOLS.has(tool) else {"type":"build","kind":tool,"x":cell%sim.width(),"z":cell/sim.width(),"rotation":building_rotation}
		var checked: Dictionary = sim.validate_command(order)
		world.show_preview(cells,checked.ok)
		hud.show_build_cost(checked)

func _input(event: InputEvent) -> void:
	if is_instance_valid(hud) and event is InputEventKey and event.pressed and not event.echo:
		if main_menu.is_open():
			if event.keycode == KEY_ESCAPE and has_started: _close_main_menu()
			if event.keycode in [KEY_ESCAPE,KEY_F4,KEY_SPACE]: get_viewport().set_input_as_handled()
			return
		if developer_console.is_open() and event.keycode == KEY_ESCAPE:
			developer_console.close_console()
			get_viewport().set_input_as_handled()
			return
		if not is_instance_valid(hud.confirmation_overlay) and event.keycode == KEY_F4:
			if developer_console.is_open(): developer_console.close_console()
			else: _open_console()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if get_viewport().gui_get_hovered_control() != null and dragging:
			dragging = false
			world.show_preview([],true)

func road_segment(start: int, end: int) -> Array:
	var cells: Array = [start]
	var x: int = start%sim.width()
	var z: int = start/sim.width()
	while x != end%sim.width():
		x += 1 if end%sim.width() > x else -1
		cells.append(z*sim.width()+x)
	while z != end/sim.width():
		z += 1 if end/sim.width() > z else -1
		cells.append(z*sim.width()+x)
	return cells

func select_at(screen: Vector2, cell: int) -> void:
	var best: int = 0
	var distance: float = 15.0
	for id: int in world.people:
		if not world.people[id].visible: continue
		var projected: Vector2 = world.camera.unproject_position(world.people[id].position+Vector3(0,0.4,0))
		if screen.distance_to(projected) < distance:
			best = id
			distance = screen.distance_to(projected)
	hud.selected_citizen = best
	hud.selected_building = sim.occupied.get(cell,0) if best == 0 else 0
	hud.last_inspector = ""
	refresh()

func action(name_value: String) -> void:
	match name_value:
		"menu": _open_main_menu()
		"console": _open_console()
		"overview":
			world.focus = Map.OVERVIEW_FOCUS
			world.camera.size = Map.OVERVIEW_ZOOM
			world.update_camera()
		"save": hud.message_label.text = Save.save_game(sim)
		"water":
			world.water_view = not world.water_view
			world.refresh_overlay(snapshot,sim.definitions)
		"debug": hud.debug_label.visible = not hud.debug_label.visible
		"load","new":
			_menu_selected(name_value)

func _modal_open() -> bool:
	return main_menu.is_open() or developer_console.is_open() or is_instance_valid(hud.confirmation_overlay)

func _pause_interaction() -> void:
	runner.speed = 0
	runner.accumulator = 0
	_select_tool("select")
	refresh()

func _open_main_menu() -> void:
	_pause_interaction()
	if developer_console.is_open(): developer_console.close_console()
	hud.close_panels()
	hud.hide()
	main_menu.open_menu(has_started,FileAccess.file_exists(Save.SAVE_PATH))

func _close_main_menu() -> void:
	main_menu.close_menu()
	hud.show()
	refresh()

func _menu_selected(choice: String) -> void:
	if choice == "help":
		_close_main_menu()
		hud.open_panel(hud.help_panel)
		return
	if choice == "continue":
		_close_main_menu()
		return
	if choice == "save":
		main_menu.message_label.text = Save.save_game(sim)
		main_menu.buttons.load.disabled = not FileAccess.file_exists(Save.SAVE_PATH)
		return
	_pause_interaction()
	if not has_started:
		_start_city(choice)
		return
	var return_to_menu: bool = main_menu.is_open()
	main_menu.close_menu()
	hud.show()
	var titles: Dictionary = {"new":"Nueva villa","load":"Cargar guardado","developing":"Villa en desarrollo","advanced":"Ciudad avanzada"}
	hud.confirm_action(titles.get(choice,"Sustituir ciudad"),func() -> void: _start_city(choice),func() -> void:
		if return_to_menu: _open_main_menu())

func _start_city(choice: String) -> void:
	var result: Dictionary = {"ok":true,"message":"Nueva villa fundada. Construye un almacén para comenzar."}
	match choice:
		"new": sim.create(1530,sim.definitions)
		"load":
			result = Save.load_game(sim)
			if result.ok: result.message = "Partida cargada. Pulsa Espacio para continuar."
		"developing","advanced": result = CityPresets.generate(sim,choice)
		_: return
	if not result.ok:
		_open_main_menu()
		main_menu.message_label.text = result.message
		return
	developer_tools.reset()
	has_started = true
	main_menu.close_menu()
	hud.show()
	_reset_city_view()
	hud.message_label.text = result.message

func _reset_city_view() -> void:
	runner.speed = 0
	runner.accumulator = 0
	animation_time = 0
	building_rotation = 0
	world.topology = -1
	for model: Node in world.buildings.values(): model.free()
	world.buildings.clear()
	world.hovered_building = 0
	hud.close_panels()
	hud.last_inspector = ""
	_select_tool("select")
	locate(0)
	refresh()

func _open_console() -> void:
	if not has_started or main_menu.is_open() or is_instance_valid(hud.confirmation_overlay): return
	_pause_interaction()
	developer_console.open_console(developer_tools.infinite_money)

func _developer_command(text: String) -> void:
	if developer_tools.replaces_city(text):
		developer_console.close_console()
		hud.confirm_action("Generar ciudad de desarrollo",func() -> void:
			_execute_developer_command(text)
			_open_console(),_open_console)
		return
	_execute_developer_command(text)

func _execute_developer_command(text: String) -> void:
	developer_tools.enforce(sim)
	var result: Dictionary = developer_tools.execute(sim,text)
	developer_tools.enforce(sim)
	if result.get("replaced",false): _reset_city_view()
	refresh()
	developer_console.money_button.set_pressed_no_signal(developer_tools.infinite_money)
	developer_console.write_line(result.message)
	hud.message_label.text = result.message
