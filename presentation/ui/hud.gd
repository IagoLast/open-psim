extends CanvasLayer

signal tool_selected(tool: String)
signal speed_selected(speed: int)
signal order(command: Dictionary)
signal action(name: String)
signal locate(id: int)
signal map_navigate(point: Vector3)
const Illustration = preload("res://presentation/ui/illustration.gd")
const MapView = preload("res://presentation/ui/minimap.gd")
var resource_values: Dictionary = {}
var speed_buttons: Dictionary = {}
var minimap: Control
var top_label: Label
var resource_label: Label
var inspector_label: Label
var message_label: Label
var debug_label: Label
var selection_label: Label
var inspector_actions: VBoxContainer
var help_panel: PanelContainer
var history_label: Label
var milestones_label: Label
var inspector_title: Label
var buttons: Dictionary = {}
var selected_building: int = 0
var selected_citizen: int = 0
var definitions: Dictionary
var root: Control
var last_inspector: String = ""
var sidebar: PanelContainer
var city_open: bool = false
var build_panel: PanelContainer
var catalog: HBoxContainer
var catalog_title: Label
var back_button: Button
var current_category: String = ""
var map_panel: PanelContainer
var reserve_bar: ProgressBar
const CATEGORIES: Dictionary = {
	"Viviendas":["house"],
	"Servicios":["road","well"],
	"Alimentación":["farm","fishery","saltery"],
	"Materias primas":["lumber"]
}
const CATEGORY_ICONS: Dictionary = {"Viviendas":"category_housing","Servicios":"category_services","Alimentación":"category_food","Materias primas":"category_materials"}

func setup(data: Dictionary) -> void:
	definitions = data
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = preload("res://presentation/ui/parchment_theme.gd").create()
	var top: PanelContainer = _panel(Vector2(10,8),Vector2(-10,110),Control.PRESET_TOP_WIDE)
	var top_rows := VBoxContainer.new()
	top.add_child(top_rows)
	var first := HBoxContainer.new()
	top_rows.add_child(first)
	first.add_theme_constant_override("separation",14)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 208
	first.add_child(identity)
	var brand: Label = _label(identity,"P O N T E V E D R A",18)
	brand.add_theme_color_override("font_color",Color("#302319"))
	brand.tooltip_text = "Unha ría, mil vidas"
	_label(identity,"Ambientación: c. 1530",12).add_theme_color_override("font_color",Color("#765b3f"))
	for resource: String in ["population","grain","wood","fish","salt","salted_fish","coins","happiness"]:
		var tile := HBoxContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		first.add_child(tile)
		var icon := Illustration.new()
		icon.kind = resource
		icon.custom_minimum_size = Vector2(44,43)
		tile.add_child(icon)
		var values := VBoxContainer.new()
		tile.add_child(values)
		var value: Label = _label(values,"0",17)
		value.add_theme_color_override("font_color",Color("#302319"))
		resource_values[resource] = value
		var captions: Dictionary = {"population":"Vecinos","coins":"Monedas","happiness":"Satisfacción","salted_fish":"Salada"}
		_label(values,captions.get(resource,definitions.resources.get(resource,{}).get("label","")),12).add_theme_color_override("font_color",Color("#765b3f"))
	var divider := HSeparator.new()
	top_rows.add_child(divider)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",6)
	top_rows.add_child(controls)
	top_label = _label(controls,"Día 1 · En pausa",14)
	top_label.custom_minimum_size.x = 205
	resource_label = _label(controls,"",13)
	resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reserve_bar = ProgressBar.new()
	reserve_bar.custom_minimum_size = Vector2(120,10)
	reserve_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reserve_bar.show_percentage = false
	reserve_bar.tooltip_text = "Reserva de cereal y sardina respecto a dos días de población."
	var reserve_background := StyleBoxFlat.new()
	reserve_background.bg_color = Color("#c5b28d")
	reserve_background.set_corner_radius_all(4)
	var reserve_fill := StyleBoxFlat.new()
	reserve_fill.bg_color = Color("#819653")
	reserve_fill.set_corner_radius_all(4)
	reserve_bar.add_theme_stylebox_override("background",reserve_background)
	reserve_bar.add_theme_stylebox_override("fill",reserve_fill)
	controls.add_child(reserve_bar)
	for value: int in [0,1,2,4]:
		var speed_button: Button = _button(controls,"Pausa" if value == 0 else "×" + str(value),func() -> void: speed_selected.emit(value))
		speed_button.toggle_mode = true
		speed_buttons[value] = speed_button
	var game_menu: PanelContainer = _panel(Vector2(-220,118),Vector2(-12,310),Control.PRESET_TOP_RIGHT)
	game_menu.hide()
	var menu_rows := VBoxContainer.new()
	game_menu.add_child(menu_rows)
	for entry: Array in [["Guardar","save"],["Cargar","load"],["Nueva partida","new"]]:
		_button(menu_rows,entry[0],func() -> void: game_menu.hide(); action.emit(entry[1]))
	_button(menu_rows,"Ayuda",func() -> void: game_menu.hide(); help_panel.visible = not help_panel.visible)
	_button(controls,"Menú",func() -> void: game_menu.visible = not game_menu.visible)
	sidebar = _panel(Vector2(-296,124),Vector2(-12,-88),Control.PRESET_RIGHT_WIDE)
	sidebar.hide()
	var scroll := ScrollContainer.new()
	sidebar.add_child(scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(side)
	inspector_title = _label(side,"EL CONSEJO DE LA VILLA",17)
	inspector_title.add_theme_color_override("font_color",Color("#624021"))
	side.add_child(HSeparator.new())
	_button(side,"Cerrar",func() -> void: selected_building = 0; selected_citizen = 0; city_open = false; sidebar.hide())
	inspector_label = _label(side,"Selecciona un edificio o un vecino.",15)
	inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_actions = VBoxContainer.new()
	side.add_child(inspector_actions)
	_button(side,"Cobertura de agua",func() -> void: action.emit("water"))
	milestones_label = _label(side,"",14)
	milestones_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_label = _label(side,"",13)
	history_label.add_theme_color_override("font_color",Color("#765b3f"))
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_panel = _panel(Vector2(12,-274),Vector2(194,-88),Control.PRESET_BOTTOM_LEFT)
	var map_rows := VBoxContainer.new()
	map_panel.add_child(map_rows)
	map_panel.hide()
	minimap = MapView.new()
	minimap.navigate.connect(func(point: Vector3) -> void: map_navigate.emit(point))
	map_rows.add_child(minimap)
	_label(map_rows,"RÍA DE PONTEVEDRA",12).add_theme_color_override("font_color",Color("#765b3f"))
	var bottom: PanelContainer = _panel(Vector2(12,-76),Vector2(-12,-12),Control.PRESET_BOTTOM_WIDE)
	var bottom_rows := VBoxContainer.new()
	bottom.add_child(bottom_rows)
	var dock := HBoxContainer.new()
	bottom_rows.add_child(dock)
	_button(dock,"Construir",func() -> void:
		var was_open: bool = build_panel.visible
		tool_selected.emit("select")
		if was_open: build_panel.hide()
		else: show_categories())
	_button(dock,"Seleccionar",func() -> void: tool_selected.emit("select"),"select")
	_button(dock,"Demoler",func() -> void: tool_selected.emit("demolish"),"demolish")
	_button(dock,"Ciudad",func() -> void: city_open = not city_open; selected_building = 0; selected_citizen = 0)
	_button(dock,"Mapa",func() -> void: build_panel.hide(); map_panel.visible = not map_panel.visible)
	selection_label = _label(dock,"Selecciona Construir para abrir el catálogo.",12)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_label = _label(bottom_rows,"Construye producción, conecta caminos y comercia desde el almacén.",12)
	message_label.add_theme_color_override("font_color",Color("#834c25"))
	build_panel = _panel(Vector2(12,-280),Vector2(580,-88),Control.PRESET_BOTTOM_LEFT)
	build_panel.hide()
	var build_rows := VBoxContainer.new()
	build_panel.add_child(build_rows)
	var catalog_heading := HBoxContainer.new()
	build_rows.add_child(catalog_heading)
	back_button = _button(catalog_heading,"Volver",show_categories)
	catalog_title = _label(catalog_heading,"Construir",15)
	catalog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(catalog_heading,"Cerrar",func() -> void: build_panel.hide())
	catalog = HBoxContainer.new()
	build_rows.add_child(catalog)
	debug_label = _label(root,"",14)
	debug_label.position = Vector2(22,140)
	debug_label.visible = false
	help_panel = _panel(Vector2(25,142),Vector2(560,552),Control.PRESET_TOP_LEFT)
	help_panel.visible = false
	var help_scroll := ScrollContainer.new()
	help_panel.add_child(help_scroll)
	var help_rows := VBoxContainer.new()
	help_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_scroll.add_child(help_rows)
	_label(help_rows,"UN PUERTO POR CONSTRUIR",23)
	var introduction: Label = _label(help_rows,"Empiezas en pausa. Construye una granja en la zona verde clara y une su borde al camino. Los vecinos ocupan los puestos automáticamente y salen al trabajo al comenzar la jornada.\n\nDespués: leñadores junto al bosque, pesquería en la costa y salazón. Selecciona el almacén para comprar sal y vender sardina salada.\n\nLos edificios pueden estar sin camino, pero no funcionan. La prioridad Alta afecta a nuevas asignaciones; no desplaza a otros empleados.\n\nAzul: vivienda con agua. Rojo: sin servicio. Clic derecho/Escape cancela la herramienta. Demoler no devuelve materiales.",15)
	introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for card: Dictionary in definitions.history:
		_label(help_rows,card.title + " · " + card.classification,15)
		var description: Label = _label(help_rows,card.text,14)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not card.source.is_empty():
			var source := LinkButton.new()
			source.text = "Fuente: Visit Pontevedra"
			source.pressed.connect(func() -> void: OS.shell_open(card.source))
			help_rows.add_child(source)
	_button(help_rows,"Entendido · construir mi ciudad",func() -> void: help_panel.hide())

func _panel(start: Vector2, end: Vector2, preset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = start.x
	panel.offset_top = start.y
	panel.offset_right = end.x
	panel.offset_bottom = end.y
	return panel

func _label(parent: Node, text_value: String, size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, callback: Callable, icon_kind: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	if not icon_kind.is_empty():
		button.icon = load("res://assets/ui/%s.png" % icon_kind) as Texture2D
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width",20)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func set_tool(kind: String) -> void:
	if kind == "select":
		build_panel.hide()
		city_open = false
		selected_building = 0
		selected_citizen = 0
		sidebar.hide()
	selection_label.text = definitions.buildings[kind].requirement if definitions.buildings.has(kind) else {"select":"Seleccionar · WASD/flechas: mover · Rueda: zoom · Espacio: pausa","road":"Arrastra caminos · coste total validado antes de construir","demolish":"Demoler · sin devolución; las viviendas ocupadas están protegidas"}.get(kind,"")

func clear_catalog() -> void:
	for child: Node in catalog.get_children():
		catalog.remove_child(child)
		child.queue_free()

func show_categories() -> void:
	clear_catalog()
	map_panel.hide()
	build_panel.show()
	back_button.hide()
	catalog_title.text = "Construir  ›  Tipo de edificio"
	current_category = ""
	for category: String in CATEGORIES:
		add_card(CATEGORY_ICONS[category],category,"%d opciones" % CATEGORIES[category].size(),func() -> void: show_buildings(category))

func show_buildings(category: String) -> void:
	clear_catalog()
	current_category = category
	back_button.show()
	catalog_title.text = "Construir  ›  " + category
	for kind: String in CATEGORIES[category]:
		var d: Dictionary = definitions.buildings.get(kind,{})
		var title: String = d.get("label","Camino")
		var cost: String = "%d monedas · %d madera" % [d.get("coins",1),d.get("wood",0)]
		var card: Button = add_card(kind,title,cost,func() -> void:
			build_panel.hide()
			tool_selected.emit(kind))
		card.tooltip_text = d.get("requirement","Arrastra caminos ortogonales.")

func add_card(kind: String, title: String, subtitle: String, callback: Callable) -> Button:
	var card: Button = _button(catalog,"",callback)
	card.name = kind
	card.custom_minimum_size = Vector2(126,132)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	card.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 6
	content.offset_left = 5
	content.offset_right = -5
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var illustration := Illustration.new()
	illustration.kind = kind
	illustration.custom_minimum_size.y = 72
	content.add_child(illustration)
	var caption: Label = _label(content,title,13)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if definitions.buildings.has(kind) or kind == "road":
		var costs := HBoxContainer.new()
		costs.alignment = BoxContainer.ALIGNMENT_CENTER
		costs.add_theme_constant_override("separation",12)
		costs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(costs)
		var definition: Dictionary = definitions.buildings.get(kind,{})
		cost_badge(costs,"coins",definition.get("coins",1))
		if definition.get("wood",0) > 0:
			cost_badge(costs,"wood",definition.wood)
	else:
		var price: Label = _label(content,subtitle,11)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return card

func cost_badge(parent: Control, resource: String, amount: int) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",3)
	parent.add_child(row)
	var icon := Illustration.new()
	icon.kind = resource
	icon.custom_minimum_size = Vector2(24,24)
	row.add_child(icon)
	_label(row,str(amount),14)
	row.tooltip_text = "%d %s" % [amount,"monedas" if resource == "coins" else "madera"]

func refresh(snapshot: Dictionary, speed: int) -> void:
	var capacity: int = 0
	var unemployed: int = 0
	var happiness: int = 0
	for item: Dictionary in snapshot.buildings:
		if item.type == "house": capacity += 4
	for citizen: Dictionary in snapshot.citizens:
		if citizen.job == 0: unemployed += 1
		happiness += citizen.satisfaction
	top_label.text = "Día %d   ·   %s" % [1+snapshot.tick/definitions.balance.ticks_per_day,"En pausa" if speed == 0 else "Velocidad ×"+str(speed)]
	resource_label.text = "Sin empleo: %d   ·   Reserva alimentaria: %d / %d" % [unemployed,snapshot.inventory.grain+snapshot.inventory.fish,snapshot.citizens.size()*2]
	reserve_bar.max_value = maxi(1,snapshot.citizens.size()*2)
	reserve_bar.value = snapshot.inventory.grain+snapshot.inventory.fish
	for resource: String in definitions.resources:
		resource_values[resource].text = str(snapshot.inventory[resource])
	resource_values.population.text = "%d/%d" % [snapshot.citizens.size(),capacity]
	resource_values.coins.text = str(snapshot.coins)
	resource_values.happiness.text = "%d%%" % [happiness/maxi(1,snapshot.citizens.size())]
	for value: int in speed_buttons: speed_buttons[value].button_pressed = value == speed
	minimap.snapshot = snapshot
	minimap.queue_redraw()
	milestones_label.text = "\nPROGRESO DE LA VILLA\n\n"
	for milestone: String in ["Granja en marcha","Empleo pesquero","Primera sardina salada","Diez unidades exportadas","Veinte habitantes abastecidos"]:
		milestones_label.text += ("✓ " if snapshot.milestones.has(milestone) else "· ") + milestone + "\n"
	history_label.text = "\nAVISOS\n" + "\n".join(snapshot.alerts.slice(maxi(0,snapshot.alerts.size()-3)))
	inspect(snapshot)

func inspect(snapshot: Dictionary) -> void:
	sidebar.visible = city_open or selected_building > 0 or selected_citizen > 0
	milestones_label.visible = city_open
	history_label.visible = city_open
	var item: Dictionary = {}
	if selected_citizen > 0:
		for c: Dictionary in snapshot.citizens:
			if c.id == selected_citizen: item = c
	elif selected_building > 0:
		for b: Dictionary in snapshot.buildings:
			if b.id == selected_building: item = b
	var key: String = "%d:%d:%s" % [selected_building,selected_citizen,not item.is_empty()]
	var changed: bool = key != last_inspector
	if changed:
		last_inspector = key
		for child: Node in inspector_actions.get_children(): child.free()
	if item.is_empty():
		inspector_title.text = "EL CONSEJO DE LA VILLA"
		inspector_label.text = "Construye, conecta y da empleo.\nComercia desde el almacén.\n\nSelecciona un edificio o un vecino para ver su actividad."
		return
	if selected_citizen > 0:
		inspector_title.text = item.name
		inspector_label.text = "Vecino #%d · personaje ficticio\n\n%s\nVivienda #%d\nEmpleo: %s\nDestino: %s\n\nComida reciente: %s\nAgua: %s\nSatisfacción: %d/100" % [item.id,item.activity,item.home,str(item.job) if item.job > 0 else "Sin empleo",str(item.destination),"Sí" if item.fed else "No","Sí" if item.water else "No",item.satisfaction]
		if changed:
			_button(inspector_actions,"Localizar vivienda",func() -> void: locate.emit(item.home))
			if item.job > 0: _button(inspector_actions,"Localizar empleo",func() -> void: locate.emit(item.job))
		return
	var d: Dictionary = definitions.buildings[item.type]
	inspector_title.text = d.label.to_upper()
	inspector_label.text = "#%d · %s\n%s\n" % [item.id,"Conectado al almacén" if item.connected else "Sin camino al almacén",d.requirement]
	if d.jobs > 0:
		inspector_label.text += "\n%d/%d asignados · %d presentes\n%s · Prioridad %s\nCiclo: %d/%d trabajo\nProducción acumulada: %d\n%s\n\nEntradas: %s\nSalidas: %s" % [item.assigned,d.jobs,item.present,"Activo" if item.active else "Desactivado","Alta" if item.priority else "Normal",item.work,d.work,item.produced,item.block if not item.block.is_empty() else "Produciendo",_resources(d.inputs),_resources(d.outputs)]
		if item.type == "saltery": inspector_label.text += "\n\nReserva protegida: dos días de cereal + sardina."
		if changed:
			_button(inspector_actions,"Activar / desactivar",func() -> void: order.emit({"type":"activity","id":item.id}))
			_button(inspector_actions,"Prioridad Normal / Alta",func() -> void: order.emit({"type":"priority","id":item.id}))
			_label(inspector_actions,"Prioridad: solo nuevas asignaciones.",12)
	elif item.type == "house":
		inspector_label.text += "\nAgua: %s\n%s\n\nOCUPANTES\n" % ["Sí" if item.water else "No","Cuidada" if item.care_days >= 3 else "Humilde"]
		for citizen: Dictionary in snapshot.citizens:
			if citizen.home == item.id:
				inspector_label.text += "%s · %d%%\n" % [citizen.name,citizen.satisfaction]
				if changed: _button(inspector_actions,citizen.name,func() -> void: selected_citizen = citizen.id; selected_building = 0)
	elif item.type == "warehouse":
		inspector_label.text += "\nAlmacén común: %d/500\nComercio exterior instantáneo.\nDisponibilidad ilimitada.\nCantidades completas, sin parciales.\n" % preload("res://sim/systems/economy.gd").total(snapshot.inventory)
		if changed:
			for resource: String in definitions.resources:
				var r: Dictionary = definitions.resources[resource]
				_label(inspector_actions,r.label,15)
				for direction: String in ["buy","sell"]:
					if r[direction] < 0: continue
					var row := HBoxContainer.new()
					inspector_actions.add_child(row)
					for quantity: int in [1,10]:
						var button: Button = _button(row,"%s %d · %d" % ["Comprar" if direction == "buy" else "Vender",quantity,r[direction]*quantity],func() -> void: order.emit({"type":"trade","resource":resource,"direction":direction,"quantity":quantity}))
						button.add_theme_font_size_override("font_size",12)
						button.icon = load("res://assets/ui/coins.png")
						button.expand_icon = true
						button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						button.add_theme_constant_override("icon_max_width",20)
						button.tooltip_text = "%d monedas" % (r[direction]*quantity)

func _resources(items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in items: parts.append("%d %s" % [items[key],definitions.resources[key].label])
	return ", ".join(parts) if not parts.is_empty() else "Ninguna"
