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
var catalog: GridContainer
var catalog_title: Label
var back_button: Button
var current_category: String = ""
var map_panel: PanelContainer
var reserve_bar: ProgressBar
var CATEGORIES: Dictionary = {}
const CATEGORY_ICONS: Dictionary = {"Viviendas":"category_housing","Servicios":"category_services","Alimentos":"category_food","Materiales":"category_materials","Talleres":"saltery","Puerto":"sailboat"}
var ledger_panel: PanelContainer
var ledger_values: Dictionary = {}
var trade_panel: PanelContainer
var trade_port: OptionButton
var trade_direction: OptionButton
var trade_resource: OptionButton
var trade_quantity: SpinBox
var trade_repeat: CheckBox
var trade_info: Label
var trade_status: Label
var trade_dock: OptionButton
var dock_ids: Array = []
var trade_resource_ids: Array = []
var trade_snapshot: Dictionary = {}
const Economy = preload("res://sim/systems/economy.gd")
const Citizens = preload("res://sim/systems/citizens.gd")

func setup(data: Dictionary) -> void:
	definitions = data
	for category: String in CATEGORY_ICONS: CATEGORIES[category] = []
	CATEGORIES.Servicios.append("road")
	for kind: String in definitions.buildings:
		if kind != "warehouse": CATEGORIES[definitions.buildings[kind].category].append(kind)
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
	map_panel = _panel(Vector2(12,-510),Vector2(372,-88),Control.PRESET_BOTTOM_LEFT)
	var map_rows := VBoxContainer.new()
	map_panel.add_child(map_rows)
	map_panel.hide()
	minimap = MapView.new()
	minimap.navigate.connect(func(point: Vector3) -> void: map_navigate.emit(point))
	map_rows.add_child(minimap)
	_label(map_rows,"PROVINCIA · N ↑ · 128 × 128",12).add_theme_color_override("font_color",Color("#765b3f"))
	_button(map_rows,"Ver toda la provincia",func() -> void: action.emit("overview"))
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
	_button(dock,"Recursos",func() -> void: ledger_panel.visible = not ledger_panel.visible; trade_panel.hide())
	_button(dock,"Comercio",func() -> void: trade_panel.visible = not trade_panel.visible; ledger_panel.hide())
	_button(dock,"Inicio",func() -> void: locate.emit(1))
	selection_label = _label(dock,"Selecciona Construir para abrir el catálogo.",12)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_label = _label(bottom_rows,"Construye una granja al norte; conecta caminos. Abre Recursos para ver las cadenas de producción.",12)
	message_label.add_theme_color_override("font_color",Color("#834c25"))
	build_panel = _panel(Vector2(12,-456),Vector2(700,-88),Control.PRESET_BOTTOM_LEFT)
	build_panel.hide()
	var build_rows := VBoxContainer.new()
	build_panel.add_child(build_rows)
	var catalog_heading := HBoxContainer.new()
	build_rows.add_child(catalog_heading)
	back_button = _button(catalog_heading,"Volver",show_categories)
	catalog_title = _label(catalog_heading,"Construir",15)
	catalog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(catalog_heading,"Cerrar",func() -> void: build_panel.hide())
	var catalog_scroll := ScrollContainer.new()
	catalog_scroll.custom_minimum_size.y = 290
	build_rows.add_child(catalog_scroll)
	catalog = GridContainer.new()
	catalog.columns = 4
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_scroll.add_child(catalog)
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
	var introduction: Label = _label(help_rows,"Empiezas en pausa con ocho vecinos. Construye una granja en el terreno fértil al norte y une su borde al camino. Añade leñadores junto al bosque del este y una pesquería en la costa. Necesitas viviendas libres, empleos, agua y dos días de comida para atraer vecinos.\n\nRecursos muestra las cadenas: cereal → harina → pan; uva → vino; arcilla → cerámica; hierro + madera → herramientas; lana → paños. Hay granito, arcilla y hierro señalados por su color en el mapa.\n\nConstruye un muelle junto al mar y conéctalo. En Comercio elige Porto, Lisboa o Burdeos, compra sal o exporta tus productos. Una nave por muelle; cada viaje tarda entre 2 y 4 días. La carga y el flete se pagan al salir. Puedes repetir automáticamente; los cupos se renuevan cada 10 días.\n\nMercado, hospital y capilla con personal permiten viviendas prósperas tras 3 días. Guardia, escuela y 1 unidad diaria de cerámica, paños y vino por vivienda permiten una villa mercantil. Los servicios cobran mantenimiento diario; las casas mejores pagan más impuestos.\n\nMapa: clic para moverte; Inicio: volver al almacén. WASD/flechas y rueda para explorar. Espacio pausa; clic derecho/Escape cancela. Edificios nuevos: bloques con etiquetas.",15)
	introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for card: Dictionary in definitions.history:
		_label(help_rows,card.title + " · " + card.classification,15)
		var description: Label = _label(help_rows,card.text,14)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not card.source.is_empty():
			var source := LinkButton.new()
			source.text = "Consultar fuente"
			source.pressed.connect(func() -> void: OS.shell_open(card.source))
			help_rows.add_child(source)
	_button(help_rows,"Entendido · construir mi ciudad",func() -> void: help_panel.hide())
	setup_ledger()
	setup_trade()

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
		card.tooltip_text = d.get("requirement","Arrastra caminos ortogonales.") + ("\nMateriales: " + _resources(d.materials) if d.has("materials") and not d.materials.is_empty() else "")

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
		for resource: String in definition.get("materials",{}):
			cost_badge(costs,resource,definition.materials[resource])
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
	row.tooltip_text = "%d %s" % [amount,"monedas" if resource == "coins" else definitions.resources[resource].label]

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
	resource_label.text = "Sin empleo: %d   ·   Reserva alimentaria: %d / %d" % [unemployed,Economy.food({"state":snapshot}),snapshot.citizens.size()*2]
	reserve_bar.max_value = maxi(1,snapshot.citizens.size()*2)
	reserve_bar.value = Economy.food({"state":snapshot})
	for resource: String in definitions.resources:
		if resource_values.has(resource): resource_values[resource].text = str(snapshot.inventory[resource])
		ledger_values[resource].text = str(snapshot.inventory[resource])
	resource_values.population.text = "%d/%d" % [snapshot.citizens.size(),capacity]
	resource_values.coins.text = str(snapshot.coins)
	resource_values.happiness.text = "%d%%" % [happiness/maxi(1,snapshot.citizens.size())]
	for value: int in speed_buttons: speed_buttons[value].button_pressed = value == speed
	minimap.snapshot = snapshot
	minimap.queue_redraw()
	milestones_label.text = "\nPROGRESO DE LA VILLA\n\n"
	for milestone: String in ["Granja en marcha","Empleo pesquero","Primera sardina salada","Diez unidades exportadas","Veinte habitantes abastecidos","Primera travesía completada","Recurso: Pan","Recurso: Herramientas","Recurso: Vino","Recurso: Cerámica","Recurso: Paños","Barrio próspero","Villa mercantil"]:
		milestones_label.text += ("✓ " if snapshot.milestones.has(milestone) else "· ") + milestone + "\n"
	history_label.text = "\nAVISOS\n" + "\n".join(snapshot.alerts.slice(maxi(0,snapshot.alerts.size()-3)))
	refresh_trade(snapshot)
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
		inspector_label.text = "Expande la villa, abastece los hogares y abre rutas marítimas.\n\nNivel 2: agua, comida, mercado, salud y culto durante 3 días.\nNivel 3: añade seguridad, educación, cerámica, paños y vino.\n\nServicios: requieren personal, caminos y mantenimiento diario."
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
	if d.has("service"):
		inspector_label.text += "\nServicio: %s\nAlcance: %d pasos por caminos\nPersonal: %d/%d\nMantenimiento: %d monedas/día\nEstado: %s" % [Citizens.SERVICE_LABELS[d.service],d.radius,item.assigned,d.jobs,d.get("upkeep",0),"Disponible" if item.service_active else "Sin cobertura: revisa camino, personal y presupuesto"]
		if changed and d.jobs > 0:
			_button(inspector_actions,"Activar / desactivar",func() -> void: order.emit({"type":"activity","id":item.id}))
	elif d.jobs > 0:
		inspector_label.text += "\n%d/%d asignados · %d presentes\n%s · Prioridad %s\nCiclo: %d/%d trabajo\nProducción acumulada: %d\n%s\n\nEntradas: %s\nSalidas: %s" % [item.assigned,d.jobs,item.present,"Activo" if item.active else "Desactivado","Alta" if item.priority else "Normal",item.work,d.work,item.produced,item.block if not item.block.is_empty() else "Produciendo",_resources(d.inputs),_resources(d.outputs)]
		if item.type == "saltery": inspector_label.text += "\n\nReserva protegida: dos días de cereal + sardina."
		if changed:
			_button(inspector_actions,"Activar / desactivar",func() -> void: order.emit({"type":"activity","id":item.id}))
			_button(inspector_actions,"Prioridad Normal / Alta",func() -> void: order.emit({"type":"priority","id":item.id}))
			_label(inspector_actions,"Prioridad: solo nuevas asignaciones.",12)
	elif item.type == "house":
		inspector_label.text += "\nAgua: %s\n%s\n\nOCUPANTES\n" % ["Sí" if item.water else "No",["Humilde","Próspera","Mercantil"][item.level-1]]
		for service: String in Citizens.SERVICE_LABELS:
			inspector_label.text += ("✓ " if item.services.get(service,false) else "· ") + Citizens.SERVICE_LABELS[service] + "\n"
		inspector_label.text += "\nImpuesto: %d por vecino abastecido/día\n" % item.level
		for citizen: Dictionary in snapshot.citizens:
			if citizen.home == item.id:
				inspector_label.text += "%s · %d%%\n" % [citizen.name,citizen.satisfaction]
				if changed: _button(inspector_actions,citizen.name,func() -> void: selected_citizen = citizen.id; selected_building = 0)
	elif item.type in ["warehouse","depot"]:
		inspector_label.text += "\nExistencias: %d\nCarga en camino: %d\n\nLas nuevas importaciones y la producción necesitan espacio libre. Los depósitos conectados añaden 800 unidades.\n\nConstruye un muelle para comerciar por mar." % [Economy.total(snapshot.inventory),snapshot.voyages.reduce(func(n: int,v: Dictionary) -> int: return n+(v.quantity if v.direction == "buy" else 0),0)]
		if changed: _button(inspector_actions,"Ver recursos y cadenas",func() -> void: ledger_panel.show(); trade_panel.hide())
	elif item.type == "dock":
		inspector_label.text += "\nUna nave por muelle.\nPorto · 2 días\nLisboa · 3 días\nBurdeos · 4 días\n\nNecesita una ruta de agua abierta al Atlántico."
		if changed: _button(inspector_actions,"Abrir comercio marítimo",func() -> void: trade_panel.show(); ledger_panel.hide())

func _resources(items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in items: parts.append("%d %s" % [items[key],definitions.resources[key].label])
	return ", ".join(parts) if not parts.is_empty() else "Ninguna"

func setup_ledger() -> void:
	ledger_panel = _panel(Vector2(18,124),Vector2(708,-88),Control.PRESET_LEFT_WIDE)
	ledger_panel.hide()
	var scroll := ScrollContainer.new()
	ledger_panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var heading := HBoxContainer.new()
	rows.add_child(heading)
	_label(heading,"RECURSOS Y CADENAS",20).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading,"Cerrar",func() -> void: ledger_panel.hide())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",18)
	rows.add_child(grid)
	for resource: String in definitions.resources:
		_label(grid,definitions.resources[resource].label,15)
		ledger_values[resource] = _label(grid,"0",17)
	_label(rows,"CADENAS DE PRODUCCIÓN",17)
	for text_value: String in ["Granja: cereal → molino: harina → horno (+ madera): pan", "Pesquería: sardina + sal importada → salazón: sardina salada", "Viñedo: uva → bodega: vino", "Barrera: arcilla + madera → alfar: cerámica", "Mina: hierro + madera → herrería: herramientas", "Pastos: lana → tejedor: paños", "Cantera: granito para muelles, depósitos y servicios públicos"]:
		var line: Label = _label(rows,text_value,14)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(rows,"TERRITORIO",17)
	var legend: Label = _label(rows,"Verde claro: tierra fértil · Verde oscuro: bosque\nGris: granito · Terracota: arcilla · Azul grisáceo: hierro\nLos yacimientos y el bosque deben estar a 3 casillas del edificio.\nComida diaria: 1 pan, cereal o sardina por vecino.\nVivienda mercantil: 1 cerámica + 1 paño + 1 vino por día.",14)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func setup_trade() -> void:
	trade_panel = _panel(Vector2(18,124),Vector2(700,-88),Control.PRESET_LEFT_WIDE)
	trade_panel.hide()
	var scroll := ScrollContainer.new()
	trade_panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var heading := HBoxContainer.new()
	rows.add_child(heading)
	_label(heading,"COMERCIO POR MAR",20).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading,"Cerrar",func() -> void: trade_panel.hide())
	_label(rows,"Muelle y puerto de destino",14)
	var selectors := HBoxContainer.new()
	rows.add_child(selectors)
	trade_dock = OptionButton.new()
	trade_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(trade_dock)
	trade_port = OptionButton.new()
	for port: String in definitions.ports: trade_port.add_item(definitions.ports[port].label)
	selectors.add_child(trade_port)
	trade_port.item_selected.connect(func(_i: int) -> void: update_trade_resources())
	var cargo := HBoxContainer.new()
	rows.add_child(cargo)
	trade_direction = OptionButton.new()
	trade_direction.add_item("Importar")
	trade_direction.add_item("Exportar")
	cargo.add_child(trade_direction)
	trade_direction.item_selected.connect(func(_i: int) -> void: update_trade_resources())
	trade_resource = OptionButton.new()
	trade_resource.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo.add_child(trade_resource)
	trade_quantity = SpinBox.new()
	trade_quantity.min_value = 1
	trade_quantity.max_value = 60
	trade_quantity.value = 10
	cargo.add_child(trade_quantity)
	trade_repeat = CheckBox.new()
	trade_repeat.text = "Repetir ruta automáticamente (revisa cada día)"
	rows.add_child(trade_repeat)
	trade_info = _label(rows,"",14)
	trade_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	_button(actions,"Enviar nave",func() -> void:
		if dock_ids.is_empty():
			message_label.text = "Construye y conecta un muelle junto al mar"
			return
		order.emit({"type":"route" if trade_repeat.button_pressed else "trade","repeat":trade_repeat.button_pressed,"dock":dock_ids[trade_dock.selected],"port":definitions.ports.keys()[trade_port.selected],"direction":"buy" if trade_direction.selected == 0 else "sell","resource":trade_resource_ids[trade_resource.selected],"quantity":int(trade_quantity.value)}))
	_button(actions,"Detener repetición",func() -> void:
		if not dock_ids.is_empty(): order.emit({"type":"route","repeat":false,"dock":dock_ids[trade_dock.selected]}))
	trade_status = _label(rows,"",14)
	trade_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_trade_resources()

func update_trade_resources() -> void:
	trade_resource.clear()
	var port: Dictionary = definitions.ports[definitions.ports.keys()[trade_port.selected]]
	trade_resource_ids = (port.sells if trade_direction.selected == 0 else port.buys).keys()
	for resource: String in trade_resource_ids: trade_resource.add_item(definitions.resources[resource].label)
	trade_quantity.max_value = port.capacity

func refresh_trade(snapshot: Dictionary) -> void:
	trade_snapshot = snapshot
	var ids: Array = []
	for item: Dictionary in snapshot.buildings:
		if item.type == "dock": ids.append(item.id)
	if ids != dock_ids:
		dock_ids = ids
		trade_dock.clear()
		for id: int in ids: trade_dock.add_item("Muelle #%d" % id)
		if ids.is_empty(): trade_dock.add_item("Construye un muelle")
	var port_key: String = definitions.ports.keys()[trade_port.selected]
	var port: Dictionary = definitions.ports[port_key]
	var direction: String = "buy" if trade_direction.selected == 0 else "sell"
	var resource: String = trade_resource_ids[trade_resource.selected]
	var price: int = (port.sells if direction == "buy" else port.buys)[resource]
	var quantity: int = int(trade_quantity.value)
	var quota: int = port.capacity*3-snapshot.trade_volume.get("%s:%s:%s" % [port_key,direction,resource],0)
	var reserved: int = 0
	for voyage: Dictionary in snapshot.voyages:
		if voyage.direction == "buy": reserved += voyage.quantity
	var capacity: int = definitions.balance.inventory_capacity
	for item: Dictionary in snapshot.buildings:
		if item.connected: capacity += definitions.buildings[item.type].get("storage",0)
	trade_info.text = "%d monedas/unidad · Flete: %d · Viaje: %d días\n%s\nCupo restante: %d · Renovación en %d días\nAlmacén: %d + %d reservadas / %d" % [price,port.fee,port.days,"Pago al salir: %d monedas" % (price*quantity+port.fee) if direction == "buy" else "Pago al salir: %d · Cobro al volver: %d monedas" % [port.fee,price*quantity],quota,10-(snapshot.tick/definitions.balance.ticks_per_day)%10,Economy.total(snapshot.inventory),reserved,capacity]
	trade_status.text = "\nTRAVESÍAS\n"
	if snapshot.voyages.is_empty(): trade_status.text += "Sin naves en viaje. Construye un muelle, conecta un camino y envía tu primera carga.\n"
	for voyage: Dictionary in snapshot.voyages:
		trade_status.text += "Muelle #%d → %s · %d %s · %d%%\n%s · %.1f días restantes\n" % [voyage.dock,definitions.ports[voyage.port].label,voyage.quantity,definitions.resources[voyage.resource].label,100*voyage.elapsed/voyage.duration,voyage.status,float(voyage.duration-voyage.elapsed)/definitions.balance.ticks_per_day]
	for route: Dictionary in snapshot.trade_routes:
		trade_status.text += "Ruta automática #%d: %s\n" % [route.dock,route.status]
	trade_status.text += "\nÚLTIMAS ENTREGAS\n"+"\n".join(snapshot.trade_history)
