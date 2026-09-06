extends Node3D
const Simulation = preload("res://sim/simulation.gd")
const Definitions = preload("res://adapters/definitions.gd")
const Save = preload("res://adapters/save_service.gd")
const Runner = preload("res://adapters/simulation_runner.gd")
const World = preload("res://presentation/world_view.gd")
const HUD = preload("res://presentation/ui/hud.gd")
var sim := Simulation.new()
var runner := Runner.new()
var world: Node3D
var hud: CanvasLayer
var snapshot: Dictionary
var tool: String = "select"
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
	hud.tool_selected.connect(_select_tool)
	hud.speed_selected.connect(func(value: int) -> void: runner.speed = value; refresh())
	hud.order.connect(command)
	hud.action.connect(action)
	hud.locate.connect(locate)
	hud.map_navigate.connect(func(point: Vector3) -> void: world.focus = point; world.update_camera())
	refresh()
	if not OS.is_userfs_persistent(): hud.message_label.text = "Persistencia no disponible: el guardado podría perderse al cerrar."

func _process(delta: float) -> void:
	if snapshot.is_empty(): return
	world.pan(delta)
	hud.minimap.focus = world.focus
	hud.minimap.zoom = world.camera.size
	var stepped: int = runner.advance(sim,delta)
	if stepped > 0: snapshot = sim.get_snapshot()
	if runner.speed > 0: animation_time += minf(delta,0.25)*runner.speed
	world.animate(snapshot,runner.accumulator*sim.definitions.balance.ticks_per_second,animation_time)
	refresh_time += delta
	if refresh_time >= 0.2:
		refresh_time = 0
		world.sync(snapshot,sim.definitions)
		hud.refresh(snapshot,runner.speed)
		web_probe.publish(self)
		hud.debug_label.text = "FPS %d · tick %.2f ms · población %d\nSin ruta %d · %s" % [Engine.get_frames_per_second(),runner.tick_usec/1000.0,snapshot.citizens.size(),snapshot.citizens.filter(func(c: Dictionary) -> bool: return c.activity == "Sin ruta").size(),"Velocidad limitada" if runner.slowed else "Ritmo normal"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		runner.accumulator = 0
		runner.speed = 0

func refresh() -> void:
	snapshot = sim.get_snapshot()
	world.sync(snapshot,sim.definitions)
	hud.refresh(snapshot,runner.speed)
	hover_cell = -2

func _select_tool(kind: String) -> void:
	tool = kind
	dragging = false
	hud.set_tool(kind)
	world.show_preview([],true)
	hover_cell = -2

func command(order: Dictionary) -> void:
	var result: Dictionary = sim.apply_command(order)
	hud.message_label.text = "Orden completada" if result.ok else result.message
	refresh()

func locate(id: int) -> void:
	var item: Dictionary = sim.building(id)
	if item.is_empty(): return
	world.focus = Vector3(item.x,0,item.z)
	world.camera.size = 30
	world.update_camera()
	hud.selected_citizen = 0
	hud.selected_building = id
	hud.last_inspector = ""
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_select_tool("select")
				hud.help_panel.hide()
			KEY_SPACE:
				runner.speed = 1 if runner.speed == 0 else 0
				refresh()
			KEY_F3: hud.debug_label.visible = not hud.debug_label.visible
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: _select_tool("select")
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.camera.size = maxf(12,world.camera.size-1.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.camera.size = minf(160,world.camera.size+1.5)
		if event.button_index == MOUSE_BUTTON_LEFT:
			var cell: int = world.cell_at(event.position)
			if event.pressed:
				if cell < 0: return
				if tool == "road":
					dragging = true
					drag_start = cell
				elif tool == "select": select_at(event.position,cell)
				elif tool == "demolish": command({"type":"demolish","cell":cell})
				else: command({"type":"build","kind":tool,"x":cell%sim.width(),"z":cell/sim.width()})
			elif dragging:
				dragging = false
				if cell >= 0: command({"type":"road","cells":road_segment(drag_start,cell)})
				world.show_preview([],true)
	if event is InputEventMouseMotion:
		var cell: int = world.cell_at(event.position)
		if cell == hover_cell: return
		hover_cell = cell
		if cell < 0 or tool in ["select","demolish"]:
			world.show_preview([],true)
			return
		var cells: Array = road_segment(drag_start,cell) if tool == "road" and dragging else ([cell] if tool == "road" else sim.footprint(tool,cell%sim.width(),cell/sim.width()))
		var order: Dictionary = {"type":"road","cells":cells} if tool == "road" else {"type":"build","kind":tool,"x":cell%sim.width(),"z":cell/sim.width()}
		var checked: Dictionary = sim.validate_command(order)
		world.show_preview(cells,checked.ok)
		hud.message_label.text = "Coste: %d monedas · %d madera · Clic para construir" % [checked.coins,checked.wood] if checked.ok else checked.message

func _input(event: InputEvent) -> void:
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
		"overview":
			world.focus = Vector3(64,0,64)
			world.camera.size = 145
			world.update_camera()
		"save": hud.message_label.text = Save.save_game(sim)
		"water":
			world.water_view = not world.water_view
			world.refresh_overlay(snapshot,sim.definitions)
		"debug": hud.debug_label.visible = not hud.debug_label.visible
		"load","new":
			var dialog := ConfirmationDialog.new()
			dialog.theme = hud.root.theme
			dialog.dialog_text = "¿Sustituir la partida actual? Los cambios sin guardar se perderán."
			dialog.title = "Cargar partida" if name_value == "load" else "Nueva partida"
			dialog.ok_button_text = "Continuar"
			dialog.cancel_button_text = "Cancelar"
			add_child(dialog)
			dialog.confirmed.connect(func() -> void:
				if name_value == "new": sim.create(1530,sim.definitions)
				else:
					var result: Dictionary = Save.load_game(sim)
					hud.message_label.text = "Partida cargada" if result.ok else result.message
				runner.speed = 0
				runner.accumulator = 0
				world.topology = -1
				for model: Node in world.buildings.values(): model.free()
				world.buildings.clear()
				hud.selected_building = 0
				hud.selected_citizen = 0
				refresh()
				dialog.queue_free())
			dialog.canceled.connect(dialog.queue_free)
			dialog.popup_centered()
