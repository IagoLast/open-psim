extends CanvasLayer

signal tool_selected(tool: String)
signal speed_selected(speed: int)
signal order(command: Dictionary)
signal action(name: String)
signal locate(id: int)
signal citizen_selected(id: int)
signal map_navigate(point: Vector3)
const Illustration = preload("res://presentation/ui/illustration.gd")
const ParchmentTheme = preload("res://presentation/ui/parchment_theme.gd")
const Folio = preload("res://presentation/ui/folio.gd")
const RoadSurfaces = preload("res://sim/road_surfaces.gd")
const MapView = preload("res://presentation/ui/minimap.gd")
var resource_values: Dictionary = {}
var speed_buttons: Dictionary = {}
var minimap: Control
var header_panel: PanelContainer
const SIDEBAR_WIDTH: float = 356.0
var navigation_panel: PanelContainer
var navigation_rows: VBoxContainer
var page_host: PanelContainer
var home_panel: PanelContainer
var tool_art: Control
var tool_title: Label
var tool_description: Label
var immigration_status: Label
var status_panel: VBoxContainer
var speed_label: Label
var employment_label: Label
var top_label: Label
var resource_label: Label
var inspector_label: Label
var message_label: Label
var debug_label: Label
var selection_label: Label
var inspector_actions: VBoxContainer
var housing_card: VBoxContainer
var inspector_body: VBoxContainer
var help_panel: PanelContainer
var inspector_art: Control
var city_progress: ProgressBar
var milestone_box: VBoxContainer
var milestone_checks: Dictionary = {}
var history_label: Label
var milestones_label: Label
var inspector_title: Label
var buttons: Dictionary = {}
var active_tool: String = "select"
var selected_building: int = 0
var selected_citizen: int = 0
var definitions: Dictionary
var root: Control
var confirmation_overlay: Control
var confirmation_cancelled: Callable
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
var ledger_total: Label
var ledger_storage: Label
var ledger_coins: Label
var build_costs: HBoxContainer
var build_cost_signature: String = ""
var trade_payment: Label
var trade_income: Label
var trade_panel: PanelContainer
var trade_port: OptionButton
var trade_direction: OptionButton
var trade_resource: OptionButton
var trade_quantity: SpinBox
var trade_repeat: CheckBox
var trade_price: Label
var trade_fee: Label
var trade_days: Label
var trade_cargo: Control
var voyage_rows: VBoxContainer
var voyage_signature: String = ""
var trade_info: Label
var trade_status: Label
var trade_dock: OptionButton
var dock_ids: Array = []
var trade_resource_ids: Array = []
var trade_snapshot: Dictionary = {}
var merchant_panel: PanelContainer
var merchant_status: Label
var merchant_quote: Label
var merchant_feedback: Label
var merchant_resource: OptionButton
var merchant_quantity: SpinBox
var merchant_buy: Button
var merchant_sell: Button
var merchant_warehouse: int = 0
var merchant_build_warehouse: Button
var objective_label: Label
var objective_details: Label
const Housing = preload("res://sim/systems/housing.gd")
const Footprints = preload("res://sim/footprints.gd")
const Economy = preload("res://sim/systems/economy.gd")
const MILESTONES: Array[String] = ["Granja en marcha","Empleo pesquero","Primera sardina salada","Diez unidades exportadas","Veinte habitantes abastecidos","Primera travesía completada","Recurso: Pan","Recurso: Herramientas","Recurso: Vino","Recurso: Cerámica","Recurso: Paños","Barrio próspero","Villa mercantil"]
const Citizens = preload("res://sim/systems/citizens.gd")

func setup(data: Dictionary) -> void:
	definitions = data
	for category: String in CATEGORY_ICONS: CATEGORIES[category] = []
	CATEGORIES.Servicios.append_array(["road_dirt","road"])
	for kind: String in definitions.buildings:
		CATEGORIES[definitions.buildings[kind].category].append(kind)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = ParchmentTheme.create()
	setup_navigation()
	setup_header()
	setup_inspector()
	setup_catalog()
	debug_label = _label(root,"",14)
	debug_label.position = Vector2(18,156)
	debug_label.visible = false
	setup_help()
	setup_ledger()
	setup_trade()
	setup_merchants()
	setup_home()
	close_panels()

func setup_navigation() -> void:
	navigation_panel = _panel(Vector2(-SIDEBAR_WIDTH,98),Vector2.ZERO,Control.PRESET_RIGHT_WIDE)
	navigation_panel.name = "PermanentSidebar"
	navigation_rows = VBoxContainer.new()
	navigation_rows.add_theme_constant_override("separation",8)
	navigation_panel.add_child(navigation_rows)
	setup_map()
	var navigation := GridContainer.new()
	navigation.columns = 3
	navigation_rows.add_child(navigation)
	_navigation_button(navigation,"Construir","category_housing",func() -> void:
		tool_selected.emit("select")
		show_categories())
	_navigation_button(navigation,"Seleccionar","select",func() -> void: tool_selected.emit("select"))
	_navigation_button(navigation,"Demoler","demolish",func() -> void: tool_selected.emit("demolish"))
	_navigation_button(navigation,"Ciudad","population",func() -> void:
		tool_selected.emit("select")
		city_open = true
		open_panel(sidebar))
	_navigation_button(navigation,"Recursos","warehouse",func() -> void: navigate_panel(ledger_panel))
	_navigation_button(navigation,"Comercio","sailboat",func() -> void: navigate_panel(merchant_panel))
	page_host = PanelContainer.new()
	page_host.name = "Submenus"
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_host.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	navigation_rows.add_child(page_host)
	status_panel = VBoxContainer.new()
	status_panel.custom_minimum_size.y = 46
	status_panel.add_theme_constant_override("separation",0)
	navigation_rows.add_child(status_panel)
	var cost_row := HBoxContainer.new()
	objective_label = _label(status_panel,"Fundación · abre Ciudad para ver el encargo",14)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.max_lines_visible = 2
	status_panel.add_child(cost_row)
	selection_label = _label(cost_row,"",16)
	selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_costs = HBoxContainer.new()
	cost_row.add_child(build_costs)
	message_label = _label(status_panel,"",15)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.max_lines_visible = 2
	message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_label.mouse_filter = Control.MOUSE_FILTER_STOP
	message_label.add_theme_color_override("font_color",ParchmentTheme.RUBRIC)
	message_label.draw.connect(func() -> void: message_label.tooltip_text = message_label.text)

func _navigation_button(parent: Control, title: String, art: String, callback: Callable) -> void:
	var button: Button = _button(parent,"Selección" if title == "Seleccionar" else title,callback,art)
	button.name = title
	button.tooltip_text = title
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(100,36)
	button.add_theme_font_size_override("font_size",15)
	button.add_theme_constant_override("icon_max_width",22)
	button.add_theme_constant_override("h_separation",3)
	buttons[title] = button

func _page() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_host.add_child(panel)
	panel.hide()
	return panel

func setup_home() -> void:
	home_panel = _page()
	var rows: VBoxContainer = _scroll_rows(home_panel)
	tool_title = Folio.heading(rows,"Tu villa","HERRAMIENTAS DEL CONCEJO","seal")
	immigration_status = Folio.paragraph(rows,"",17)
	tool_art = _resource_icon(rows,"house",72)
	tool_description = Folio.paragraph(rows,"Selecciona un edificio o un vecino para ver su ficha. Funda tu barrio: conecta un almacén, viviendas, pozo y empleos al camino. La comida inicial cubre las primeras llegadas. R gira los edificios.",17)
	_button(rows,"Abrir construcción",show_categories,"category_housing")
	_button(rows,"Cancelar herramienta",func() -> void: tool_selected.emit("select"))

func navigate_panel(panel: PanelContainer) -> void:
	tool_selected.emit("select")
	open_panel(panel)

func _scroll_rows(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",9)
	scroll.add_child(rows)
	return rows

func _building_art(kind: String) -> String:
	if kind == "saltworks": return "salt"
	if ResourceLoader.exists("res://assets/ui/%s.png" % kind): return kind
	return CATEGORY_ICONS.get(definitions.buildings.get(kind,{}).get("category",""),"category_housing")

func close_panels() -> void:
	for panel: Node in page_host.get_children(): panel.hide()
	city_open = false
	selected_building = 0
	selected_citizen = 0
	if is_instance_valid(home_panel): home_panel.show()

func open_panel(panel: PanelContainer) -> void:
	for page: Node in page_host.get_children(): page.hide()
	if panel != sidebar:
		city_open = false
		selected_building = 0
		selected_citizen = 0
	panel.show()

func toggle_panel(panel: PanelContainer) -> void:
	var was_open: bool = panel.visible
	close_panels()
	if not was_open: navigate_panel(panel)

func setup_inspector() -> void:
	sidebar = _page()
	var shell := VBoxContainer.new()
	sidebar.add_child(shell)
	inspector_title = Folio.heading(shell,"Consejo de la villa","PONTEVEDRA · 1530","seal",close_panels)
	inspector_title.add_theme_font_size_override("font_size",20)
	var side: VBoxContainer = _scroll_rows(shell)
	inspector_body = side
	housing_card = preload("res://presentation/ui/housing_card.gd").new()
	side.add_child(housing_card)
	housing_card.citizen_selected.connect(func(id: int) -> void: citizen_selected.emit(id))
	housing_card.hide()
	inspector_art = Illustration.new()
	inspector_art.kind = "population"
	inspector_art.custom_minimum_size.y = 58
	side.add_child(inspector_art)
	inspector_label = Folio.paragraph(Folio.inset(side),"Selecciona un edificio o un vecino.",17)
	inspector_actions = VBoxContainer.new()
	side.add_child(inspector_actions)
	_button(side,"Cobertura de agua",func() -> void: action.emit("water"),"well")
	milestone_box = VBoxContainer.new()
	side.add_child(milestone_box)
	Folio.section(milestone_box,"Encargo del concejo","seal")
	objective_details = Folio.paragraph(milestone_box,"",16)
	_button(milestone_box,"Solicitar ayuda de emergencia",func() -> void: order.emit({"type":"aid"}))
	Folio.section(milestone_box,"Prosperidad de la villa","seal")
	milestones_label = _label(milestone_box,"",16)
	city_progress = ProgressBar.new()
	city_progress.max_value = MILESTONES.size()
	city_progress.custom_minimum_size.y = 12
	city_progress.show_percentage = false
	milestone_box.add_child(city_progress)
	for milestone: String in MILESTONES:
		var row := HBoxContainer.new()
		milestone_box.add_child(row)
		milestone_checks[milestone] = Folio.icon(row,"check_off",18)
		Folio.paragraph(row,milestone,16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_label = Folio.paragraph(side,"",16)
	history_label.add_theme_color_override("font_color",Color("#825c40"))

func setup_map() -> void:
	map_panel = PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	navigation_rows.add_child(map_panel)
	var shell := HBoxContainer.new()
	shell.add_theme_constant_override("separation",10)
	map_panel.add_child(shell)
	minimap = MapView.new()
	minimap.navigate.connect(func(point: Vector3) -> void: map_navigate.emit(point))
	minimap.custom_minimum_size = Vector2(132,132)
	shell.add_child(minimap)
	minimap.tooltip_text = "Norte arriba · Pulsa en la carta para viajar"
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(controls)
	Folio.icon(controls,"compass",32)
	var title: Label = Folio.paragraph(controls,"Carta de la ría",21)
	title.theme_type_variation = "FolioTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(controls,"Ver toda la ría",func() -> void: action.emit("overview"))
	_button(controls,"Inicio",func() -> void: locate.emit(0),"house")

func setup_catalog() -> void:
	build_panel = _page()
	var build_rows := VBoxContainer.new()
	build_panel.add_child(build_rows)
	catalog_title = Folio.heading(build_rows,"Gremios de la villa","OBRAS · OFICIOS · ABASTECIMIENTO","seal",func() -> void: tool_selected.emit("select"))
	var navigation := HBoxContainer.new()
	build_rows.add_child(navigation)
	back_button = _button(navigation,"‹ Gremios",show_categories)
	var catalog_scroll := ScrollContainer.new()
	catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_rows.add_child(catalog_scroll)
	catalog = GridContainer.new()
	catalog.columns = 2
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_scroll.add_child(catalog)

func setup_help() -> void:
	help_panel = _page()
	var shell := VBoxContainer.new()
	help_panel.add_child(shell)
	Folio.heading(shell,"El buen gobierno","CONSEJOS PARA UNA VILLA PRÓSPERA","quill",close_panels)
	var rows: VBoxContainer = _scroll_rows(shell)
	for entry: Array in [
		["01 · Los primeros oficios","crate","Empiezas en pausa con el camino y el puente. Construye un almacén, viviendas, un pozo y empleos conectados. Los vecinos llegan desde el sur. Hay tierra fértil al norte y bosque al sudeste."],
		["02 · El sustento de la villa","seal","Las viviendas libres, los empleos, el agua y dos días de comida atraen vecinos. Cereal → harina → pan; uva → vino; arcilla → cerámica; hierro + madera → herramientas; lana → paños."],
		["03 · El arte del comercio","anchor","Abre Comprar / vender en el almacén o Comercio para negociar con los mercaderes durante su estancia en puerto. Sus barcos llegan periódicamente y tienen cupos por visita. Construye un muelle para contratar tus propias rutas a Porto, Lisboa o Burdeos."],
		["04 · De aldea a villa mercantil","coins_seal","Mercado, hospital y capilla con personal permiten viviendas prósperas tras 3 días. Guardia, escuela y una unidad diaria de cerámica, paños y vino permiten viviendas mercantiles. Los servicios tienen mantenimiento diario."],
		["05 · Leer y recorrer la carta","compass","WASD o flechas: mover · Rueda: zoom · Espacio: pausa · R: girar edificio. Clic derecho o Escape: cancelar herramienta. Arrastra para trazar caminos. El minimapa lateral permite viajar e Inicio vuelve al almacén."]]:
		var chapter: VBoxContainer = Folio.inset(rows)
		Folio.section(chapter,entry[0],entry[1])
		Folio.paragraph(chapter,entry[2])
	Folio.section(rows,"Crónicas de Pontevedra","quill")
	for card: Dictionary in definitions.history:
		var chapter: VBoxContainer = Folio.inset(rows)
		_label(chapter,card.title,20)
		_label(chapter,card.classification,14).add_theme_color_override("font_color",ParchmentTheme.MUTED)
		Folio.paragraph(chapter,card.text)
		if not card.source.is_empty():
			var source := LinkButton.new()
			source.text = "Consultar fuente"
			source.pressed.connect(func() -> void: OS.shell_open(card.source))
			chapter.add_child(source)
	_button(rows,"Construir mi ciudad",show_categories).theme_type_variation = "PrimaryButton"

func setup_header() -> void:
	header_panel = _panel(Vector2.ZERO,Vector2(0,98),Control.PRESET_TOP_WIDE)
	header_panel.theme_type_variation = "HeaderPanel"
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",2)
	header_panel.add_child(rows)
	var first := HBoxContainer.new()
	first.custom_minimum_size.y = 40
	first.add_theme_constant_override("separation",8)
	rows.add_child(first)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 150
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation",0)
	first.add_child(identity)
	_label(identity,"Pontevedra",23).theme_type_variation = "FolioTitle"
	_label(identity,"Galicia · 1530",14).add_theme_color_override("font_color",ParchmentTheme.MUTED)
	var captions: Dictionary = {"population":"Vecinos / capacidad de las viviendas","coins":"Monedas","happiness":"Satisfacción media"}
	for resource: String in ["population","grain","wood","fish","salt","salted_fish","coins","happiness"]:
		_separator(first)
		var tile := HBoxContainer.new()
		tile.name = "Resource_"+resource
		tile.tooltip_text = captions.get(resource,definitions.resources.get(resource,{}).get("label",""))
		tile.add_theme_constant_override("separation",3)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		first.add_child(tile)
		_resource_icon(tile,resource,34)
		resource_values[resource] = _label(tile,"0",21)
		resource_values[resource].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var controls := HBoxContainer.new()
	controls.custom_minimum_size.y = 32
	controls.add_theme_constant_override("separation",8)
	rows.add_child(controls)
	var day := HBoxContainer.new()
	controls.add_child(day)
	_chrome_icon(day,"calendar",Vector2(24,26))
	top_label = _label(day,"Día 1",17)
	top_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_separator(controls)
	var pace := HBoxContainer.new()
	pace.custom_minimum_size.x = 62
	controls.add_child(pace)
	speed_label = _label(pace,"Pausa",17)
	pace.tooltip_text = "Velocidad de la simulación · Espacio: pausar o continuar"
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_separator(controls)
	var employment := HBoxContainer.new()
	employment.tooltip_text = "Vecinos sin empleo"
	controls.add_child(employment)
	_resource_icon(employment,"citizen",26)
	employment_label = _label(employment,"0",17)
	employment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_separator(controls)
	var reserve := HBoxContainer.new()
	reserve.tooltip_text = "Reserva alimentaria / comida necesaria para dos días"
	controls.add_child(reserve)
	_chrome_icon(reserve,"crate",Vector2(26,26))
	resource_label = _label(reserve,"0 / 16",17)
	resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reserve_bar = ProgressBar.new()
	reserve_bar.custom_minimum_size = Vector2(110,6)
	reserve_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reserve_bar.show_percentage = false
	reserve_bar.tooltip_text = reserve.tooltip_text
	reserve.add_child(reserve_bar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation",3)
	controls.add_child(playback)
	for value: int in [0,1,2,4]:
		var speed_button: Button = _button(playback,"",func() -> void: speed_selected.emit(value))
		speed_button.name = "Speed%d" % value
		speed_button.icon = load("res://assets/ui/chrome/%s.svg" % {0:"pause",1:"play",2:"fast",4:"fastest"}[value])
		speed_button.custom_minimum_size = Vector2(32,30)
		speed_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speed_button.add_theme_constant_override("icon_max_width",17)
		for state_name: String in ["icon_normal_color","icon_hover_color","icon_focus_color"]:
			speed_button.add_theme_color_override(state_name,ParchmentTheme.INK)
		speed_button.tooltip_text = "Pausa · Espacio" if value == 0 else "Velocidad ×%d" % value
		speed_button.toggle_mode = true
		speed_buttons[value] = speed_button
	_button(controls,"Consola",func() -> void: action.emit("console")).tooltip_text = "Consola de desarrollo · F4"
	var menu_button: Button = _button(controls,"Menú",func() -> void: action.emit("menu"))
	menu_button.icon = preload("res://assets/ui/chrome/scroll.svg")
	menu_button.add_theme_constant_override("icon_max_width",20)
	var crest: TextureRect = _chrome_icon(root,"crest",Vector2(60,98))
	crest.position = Vector2(2,0)
	crest.z_index = 2

func _chrome_icon(parent: Node, kind: String, minimum: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/chrome/%s.svg" % kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = minimum
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _separator(parent: Node) -> void:
	var rule := VSeparator.new()
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.custom_minimum_size = Vector2(4,26)
	parent.add_child(rule)

func _panel(start: Vector2, end: Vector2, preset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	# Keep wheel events inside the HUD, including at the ends of a scroll area.
	panel.mouse_force_pass_scroll_events = false
	panel.theme_type_variation = "FolioPanel"
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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	active_tool = kind
	if kind == "select":
		close_panels()
	if kind == "demolish": open_panel(home_panel)
	tool_title.text = "Demoler" if kind == "demolish" else "Tu villa"
	tool_art.set_kind("demolish" if kind == "demolish" else "house")
	tool_description.text = "Pulsa en un edificio o un camino para retirarlo. No se devuelven materiales. Las viviendas ocupadas están protegidas.\n\nEscape o clic derecho para cancelar." if kind == "demolish" else "Selecciona un edificio o un vecino para ver su ficha. Funda tu barrio: conecta un almacén, viviendas, pozo y empleos al camino. La comida inicial cubre las primeras llegadas. R gira los edificios."
	selection_label.text = definitions.buildings.get(kind,{}).get("label",RoadSurfaces.LABELS.get(kind,{"demolish":"Demoler"}.get(kind,"")))
	selection_label.visible = kind != "select"
	selection_label.mouse_filter = Control.MOUSE_FILTER_STOP
	selection_label.tooltip_text = building_tooltip(kind) if definitions.buildings.has(kind) or RoadSurfaces.TOOLS.has(kind) else {"demolish":"Sin devolución; las viviendas ocupadas están protegidas"}.get(kind,"")
	message_label.text = ""
	show_build_cost({"ok":false,"message":""})

func show_build_cost(checked: Dictionary) -> void:
	var costs: Dictionary = {}
	if checked.ok:
		costs["coins"] = checked.coins
		if checked.get("wood",0) > 0: costs["wood"] = checked.wood
		var materials: Dictionary = definitions.buildings.get(active_tool,{}).get("materials",{})
		for resource: String in materials: costs[resource] = materials[resource]
	var signature: String = str(costs)
	if signature != build_cost_signature:
		build_cost_signature = signature
		for child: Node in build_costs.get_children(): child.free()
		for resource: String in costs: cost_badge(build_costs,resource,costs[resource])
	message_label.text = "" if checked.ok else checked.get("message","")

func clear_catalog() -> void:
	for child: Node in catalog.get_children():
		catalog.remove_child(child)
		child.queue_free()

func show_categories() -> void:
	if active_tool != "select": tool_selected.emit("select")
	clear_catalog()
	catalog.columns = 2
	open_panel(build_panel)
	back_button.get_parent().hide()
	catalog_title.text = "Gremios de la villa"
	current_category = ""
	for category: String in CATEGORIES:
		add_card(CATEGORY_ICONS[category],category,func() -> void: show_buildings(category),false)

func show_buildings(category: String) -> void:
	clear_catalog()
	catalog.columns = 2
	current_category = category
	back_button.get_parent().show()
	catalog_title.text = category
	for kind: String in CATEGORIES[category]:
		var d: Dictionary = definitions.buildings.get(kind,{})
		var title: String = d.get("label",RoadSurfaces.LABELS.get(kind,"Camino"))
		var card: Button = add_card(kind,title,func() -> void:
			tool_selected.emit(kind))
		card.toggle_mode = true
		card.tooltip_text = building_tooltip(kind)

func building_tooltip(kind: String) -> String:
	if RoadSurfaces.TOOLS.has(kind):
		return RoadSurfaces.LABELS[kind]+"\nConecta viviendas y lugares de trabajo con el almacén\ny lleva la cobertura de los servicios a la villa.\n\nArrastra para trazar caminos o cambiar su acabado.\nTierra y pavimento ofrecen la misma conexión.\nCoste: %d moneda(s) por casilla nueva o modificada." % definitions.balance.road_cost
	var d: Dictionary = definitions.buildings[kind]
	var lines: Array[String] = [d.label,d.get("description",""),""]
	if not d.get("outputs",{}).is_empty():
		lines.append("Produce por ciclo: " + _resources(d.outputs))
		if not d.get("inputs",{}).is_empty(): lines.append("Consume por ciclo: " + _resources(d.inputs))
	if d.get("capacity",0) > 0: lines.append("Capacidad inicial: %d vecinos" % d.capacity)
	if d.get("storage",0) > 0: lines.append("Almacenamiento adicional: %d unidades" % d.storage)
	if d.get("food_storage",0) > 0: lines.append("Reserva de cereal, harina y pan: %d unidades" % d.food_storage)
	if d.get("beds",0) > 0: lines.append("Camas para peregrinos: %d" % d.beds)
	if d.get("radius",0) > 0: lines.append("Cobertura: %d pasos por caminos" % d.radius)
	if d.jobs > 0: lines.append("Trabajadores necesarios: %d" % d.jobs)
	if d.get("upkeep",0) > 0: lines.append("Mantenimiento: %d monedas/día" % d.upkeep)
	lines.append("\n%d×%d casillas · R para girar" % [d.footprint[0],d.footprint[1]])
	lines.append(d.requirement)
	if not d.get("materials",{}).is_empty(): lines.append("Materiales: " + _resources(d.materials))
	return "\n".join(lines)

func add_card(kind: String, title: String, callback: Callable, show_cost: bool = true) -> Button:
	var card: Button = _button(catalog,"",callback)
	card.theme_type_variation = "CatalogCard"
	card.name = kind
	card.custom_minimum_size = Vector2(146,142 if show_cost else 86)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	card.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 6
	content.offset_left = 4
	content.offset_right = -4
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var illustration := Illustration.new()
	illustration.kind = _building_art(kind)
	illustration.custom_minimum_size.y = 52 if show_cost else 40
	content.add_child(illustration)
	var caption: Label = _label(content,title,17)
	caption.theme_type_variation = "FolioTitle"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",16)
	caption.custom_minimum_size.y = 40 if show_cost else 24
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if show_cost and (definitions.buildings.has(kind) or RoadSurfaces.TOOLS.has(kind)):
		var costs := HBoxContainer.new()
		costs.alignment = BoxContainer.ALIGNMENT_CENTER
		costs.add_theme_constant_override("separation",3)
		costs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(costs)
		var definition: Dictionary = definitions.buildings.get(kind,{})
		cost_badge(costs,"coins",definition.get("coins",definitions.balance.road_cost))
		if definition.get("wood",0) > 0:
			cost_badge(costs,"wood",definition.wood)
		for resource: String in definition.get("materials",{}):
			cost_badge(costs,resource,definition.materials[resource])
	card.tooltip_text = title
	return card

func cost_badge(parent: Control, resource: String, amount: int) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation",3)
	parent.add_child(row)
	var icon := Illustration.new()
	icon.kind = resource
	icon.custom_minimum_size = Vector2(24,24)
	row.add_child(icon)
	var value: Label = _label(row,str(amount),16)
	row.tooltip_text = "Monedas" if resource == "coins" else definitions.resources[resource].label
	return value

func refresh(snapshot: Dictionary, speed: int) -> void:
	var capacity: int = 0
	var unemployed: int = 0
	var happiness: int = 0
	for item: Dictionary in snapshot.buildings:
		if item.type == "house": capacity += Housing.capacity(item,definitions)
	for citizen: Dictionary in snapshot.citizens:
		if citizen.job == 0: unemployed += 1
		happiness += citizen.satisfaction
	top_label.text = "Día %d" % [1+snapshot.tick/definitions.balance.ticks_per_day]
	speed_label.text = "Pausa" if speed == 0 else "×"+str(speed)
	var immigration: Dictionary = Citizens.immigration_plan(snapshot,definitions)
	var arrival_text: String = ""
	if immigration.arriving > 0:
		arrival_text = "%d vecinos de camino hacia sus casas." % immigration.arriving
	elif not immigration.reason.is_empty(): arrival_text = immigration.reason
	else: arrival_text = "%d vecinos pueden llegar en la próxima jornada." % immigration.count
	if speed == 0: arrival_text = "En pausa: pulsa ▶ o Espacio para que pase el tiempo.\n"+arrival_text
	immigration_status.text = "LLEGADA DE VECINOS\n"+arrival_text
	resource_values.population.get_parent().tooltip_text = immigration_status.text
	employment_label.text = str(unemployed)
	resource_label.text = "%d / %d" % [Economy.food({"state":snapshot}),snapshot.citizens.size()*2]
	reserve_bar.max_value = maxi(1,snapshot.citizens.size()*2)
	reserve_bar.value = Economy.food({"state":snapshot})
	for resource: String in definitions.resources:
		if resource_values.has(resource): resource_values[resource].text = str(snapshot.inventory[resource])
		ledger_values[resource].text = str(snapshot.inventory[resource])
	ledger_total.text = str(Economy.total(snapshot.inventory))
	var general_storage: int = definitions.balance.inventory_capacity
	var granary_storage: int = 0
	for item: Dictionary in snapshot.buildings:
		if not item.connected: continue
		general_storage += definitions.buildings[item.type].get("storage",0)
		granary_storage += definitions.buildings[item.type].get("food_storage",0)
	ledger_storage.text = "Almacén general: %d plazas\nHórreos: %d plazas de cereal, harina y pan" % [general_storage,granary_storage]
	ledger_coins.text = str(snapshot.coins)
	resource_values.population.text = "%d / %d" % [snapshot.citizens.size(),capacity]
	resource_values.coins.text = str(snapshot.coins)
	resource_values.happiness.text = "%d%%" % [happiness/maxi(1,snapshot.citizens.size())]
	for value: int in speed_buttons: speed_buttons[value].button_pressed = value == speed
	inspect(snapshot)
	var nav_states: Dictionary = {"Construir":build_panel.visible or definitions.buildings.has(active_tool) or RoadSurfaces.TOOLS.has(active_tool),"Seleccionar":active_tool == "select" and (home_panel.visible or selected_building > 0 or selected_citizen > 0),"Demoler":active_tool == "demolish","Ciudad":city_open,"Recursos":ledger_panel.visible,"Comercio":trade_panel.visible or merchant_panel.visible}
	for title: String in buttons:
		buttons[title].set_pressed_no_signal(nav_states[title])
	for card: Button in catalog.get_children():
		if card.toggle_mode: card.set_pressed_no_signal(str(card.name) == active_tool)
	minimap.definitions = definitions
	minimap.snapshot = snapshot
	minimap.queue_redraw()
	var completed: int = 0
	for milestone: String in MILESTONES:
		var achieved: bool = snapshot.milestones.has(milestone)
		if achieved: completed += 1
		milestone_checks[milestone].texture = load("res://assets/ui/chrome/%s.svg" % ("check_on" if achieved else "check_off"))
	city_progress.value = completed
	milestones_label.text = "%d / %d hitos" % [completed,MILESTONES.size()]
	history_label.text = "\nAVISOS\n" + "\n".join(snapshot.alerts.slice(maxi(0,snapshot.alerts.size()-3)))
	objective_label.text = snapshot.objective.message
	objective_details.text = snapshot.objective.message+"\n\n"+snapshot.objective.get("details","Construye un almacén conectado al camino, viviendas con agua y empleos para atraer vecinos.")
	refresh_merchants(snapshot)
	refresh_trade(snapshot)

func inspect(snapshot: Dictionary) -> void:
	if city_open or selected_building > 0 or selected_citizen > 0:
		if not sidebar.visible: open_panel(sidebar)
	elif sidebar.visible:
		close_panels()
	milestone_box.visible = city_open
	history_label.visible = city_open and not snapshot.alerts.is_empty()
	var item: Dictionary = {}
	if selected_citizen > 0:
		for c: Dictionary in snapshot.citizens:
			if c.id == selected_citizen: item = c
	elif selected_building > 0:
		for b: Dictionary in snapshot.buildings:
			if b.id == selected_building: item = b
	var key: String = "%d:%d:%s:%s:%s" % [selected_building,selected_citizen,not item.is_empty(),city_open,item.get("ruined",false)]
	var changed: bool = key != last_inspector
	housing_card.visible = selected_citizen == 0 and item.get("type","") == "house" and not item.get("ruined",false)
	if changed:
		last_inspector = key
		inspector_art.set_kind("population" if item.is_empty() else ("citizen" if selected_citizen > 0 else _building_art(item.type)))
		for child: Node in inspector_actions.get_children():
			inspector_actions.remove_child(child)
			child.queue_free()
	if item.is_empty():
		inspector_title.text = "Consejo de la villa"
		inspector_label.text = ""
		inspector_label.get_parent().get_parent().hide()
		inspector_art.hide()
		return
	inspector_label.get_parent().get_parent().show()
	inspector_art.show()
	if selected_citizen > 0:
		inspector_title.text = item.name
		inspector_art.tooltip_text = "Vecino #%d · personaje ficticio" % item.id
		inspector_art.mouse_filter = Control.MOUSE_FILTER_STOP
		inspector_label.text = "%s\nVivienda #%d · %s\nComida: %s · Agua: %s\nSatisfacción: %d%%" % [item.activity,item.home,"Empleo #%d" % item.job if item.job > 0 else "Sin empleo","Sí" if item.fed else "No","Sí" if item.water else "No",item.satisfaction]
		if changed:
			_button(inspector_actions,"Localizar vivienda",func() -> void: locate.emit(item.home))
			if item.job > 0: _button(inspector_actions,"Localizar empleo",func() -> void: locate.emit(item.job))
		return
	var d: Dictionary = definitions.buildings[item.type]
	inspector_title.text = d.label
	inspector_label.text = "#%d · %s" % [item.id,"Conectado" if item.connected else "Sin camino al almacén"]
	var size: Vector2i = Footprints.dimensions(d,item.rotation)
	inspector_label.text += "\nParcela %d×%d · Estado %d%%\nRiesgo de fuego %d%%" % [size.x,size.y,item.condition,item.fire_risk]
	if item.burn_days > 0: inspector_label.text += "\n¡FUEGO! Necesita vigías y agua"
	if changed: _button(inspector_actions,"Reparar · 20 monedas / 4 madera",func() -> void: order.emit({"type":"repair","id":item.id}))
	if item.ruined:
		inspector_label.text += "\nEN RUINAS · repara para recuperar el edificio"
		return
	inspector_art.tooltip_text = building_tooltip(item.type) + ("\n\n● Verde: trabajadores dentro.\n● Ámbar: personal asignado, fuera del edificio." if d.jobs > 0 else "")
	inspector_art.mouse_filter = Control.MOUSE_FILTER_STOP
	if item.type == "house":
		inspector_art.hide()
		inspector_label.get_parent().get_parent().hide()
		housing_card.update_home(item,snapshot,definitions)
		return
	if d.has("service"):
		inspector_label.text += "\nServicio: %s\nAlcance: %d pasos\nPersonal: %d/%d\nEstado: %s" % [Citizens.SERVICE_LABELS[d.service],d.radius,item.assigned,d.jobs,"Disponible" if item.service_active else "Sin cobertura: revisa camino, personal y presupuesto"]
		if changed:
			var upkeep := HBoxContainer.new()
			inspector_actions.add_child(upkeep)
			cost_badge(upkeep,"coins",d.get("upkeep",0))
			_label(upkeep,"/ día",16)
			upkeep.tooltip_text = "Mantenimiento diario"
		if changed and d.jobs > 0:
			_button(inspector_actions,"Activar / desactivar",func() -> void: order.emit({"type":"activity","id":item.id}))
	elif d.jobs > 0:
		inspector_label.text += "\n%d/%d asignados · %d dentro\n%s · Prioridad %s\nCiclo: %d/%d trabajo\nProducción acumulada: %d\n%s\n\nEntradas: %s\nSalidas: %s" % [item.assigned,d.jobs,item.present,"Activo" if item.active else "Desactivado","Alta" if item.priority else "Normal",item.work,d.work,item.produced,item.block if not item.block.is_empty() else "Produciendo",_resources(d.inputs),_resources(d.outputs)]
		if item.type == "saltery": inspector_label.text += "\n\nReserva protegida: dos días de cereal + sardina."
		if changed:
			_button(inspector_actions,"Activar / desactivar",func() -> void: order.emit({"type":"activity","id":item.id}))
			_button(inspector_actions,"Prioridad Normal / Alta",func() -> void: order.emit({"type":"priority","id":item.id}))
			_label(inspector_actions,"Prioridad: solo nuevas asignaciones.",12)
	elif item.type == "horreo":
		inspector_label.text += "\nReserva de alimentos: +%d unidades\nCereal (maíz), harina y pan.\n%s\nLos alimentos se almacenan automáticamente." % [d.food_storage,"Disponible para la villa" if item.connected else "Conecta un camino al almacén para usarlo"]
		if changed: _button(inspector_actions,"Ver alimentos",func() -> void: open_panel(ledger_panel))
	elif item.type in ["warehouse","depot"]:
		inspector_label.text += "\nExistencias: %d\nEn camino: %d" % [Economy.total(snapshot.inventory),snapshot.voyages.reduce(func(n: int,v: Dictionary) -> int: return n+(v.quantity if v.direction == "buy" else 0),0)]
		inspector_label.text += "\n\nLos recursos de la villa se guardan y distribuyen automáticamente. No necesita trabajadores."
		if item.type == "warehouse":
			inspector_label.text += "\n\nPara comerciar: conecta el almacén al camino principal, deja avanzar el tiempo y espera al mercader. Abre Comprar / vender cuando esté en puerto; el intercambio es inmediato y no requiere muelle."
		if changed:
			if item.type == "warehouse": _button(inspector_actions,"Comprar / vender",func() -> void: merchant_warehouse = item.id; open_panel(merchant_panel))
			_button(inspector_actions,"Ver recursos y cadenas",func() -> void: open_panel(ledger_panel))
	elif item.type == "dock":
		inspector_label.text += "\nUna nave por muelle.\nPorto · 2 días\nLisboa · 3 días\nBurdeos · 4 días\n\nNecesita una ruta de agua abierta al Atlántico."
		if changed: _button(inspector_actions,"Abrir comercio marítimo",func() -> void: open_panel(trade_panel))

func _resources(items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in items: parts.append("%d %s" % [items[key],definitions.resources[key].label])
	return ", ".join(parts) if not parts.is_empty() else "Ninguna"

func confirm_action(title: String, callback: Callable, cancelled: Callable = Callable()) -> void:
	close_confirmation(false)
	confirmation_cancelled = cancelled
	confirmation_overlay = Control.new()
	root.add_child(confirmation_overlay)
	confirmation_overlay.z_index = 10
	confirmation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.09,0.13,0.11,0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirmation_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "FolioPanel"
	panel.custom_minimum_size.x = 440
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	panel.add_child(rows)
	Folio.heading(rows,title,"ARCHIVO DE LA VILLA","seal")
	Folio.paragraph(rows,"¿Sustituir la partida actual?\nLos cambios sin guardar se perderán.",17)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	rows.add_child(actions)
	_button(actions,"Cancelar",close_confirmation).grab_focus()
	_button(actions,"Continuar",func() -> void: close_confirmation(false); callback.call()).theme_type_variation = "PrimaryButton"

func close_confirmation(cancelled: bool = true) -> void:
	if is_instance_valid(confirmation_overlay):
		root.remove_child(confirmation_overlay)
		confirmation_overlay.queue_free()
	confirmation_overlay = null
	var callback: Callable = confirmation_cancelled
	confirmation_cancelled = Callable()
	if cancelled and callback.is_valid(): callback.call()

func refresh_voyage_cards(snapshot: Dictionary) -> void:
	var signature: String = str(snapshot.voyages.map(func(v: Dictionary) -> Array: return [v.dock,int(100*v.elapsed/v.duration),v.status]))
	if signature == voyage_signature: return
	voyage_signature = signature
	for child: Node in voyage_rows.get_children():
		voyage_rows.remove_child(child)
		child.queue_free()
	if snapshot.voyages.is_empty():
		var empty: VBoxContainer = Folio.inset(voyage_rows)
		_resource_icon(empty,"sailboat",48)
		_label(empty,"Sin travesías",20).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Folio.paragraph(empty,"Sin naves en viaje. Conecta un muelle y contrata tu primera carga.",17)
	for voyage: Dictionary in snapshot.voyages:
		var card: VBoxContainer = Folio.inset(voyage_rows)
		var line := HBoxContainer.new()
		card.add_child(line)
		_resource_icon(line,"sailboat",36)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(details)
		_label(details,"Muelle #%d → %s" % [voyage.dock,definitions.ports[voyage.port].label],19)
		var cargo := HBoxContainer.new()
		details.add_child(cargo)
		cost_badge(cargo,voyage.resource,voyage.quantity)
		_label(cargo,voyage.status,16)
		var progress := ProgressBar.new()
		progress.value = 100.0*voyage.elapsed/voyage.duration
		progress.custom_minimum_size.y = 12
		progress.show_percentage = false
		card.add_child(progress)
		_label(card,"%d%% · %.1f días restantes" % [progress.value,float(voyage.duration-voyage.elapsed)/definitions.balance.ticks_per_day],16)

func _tabs(parent: Node, names: Array[String]) -> Array[VBoxContainer]:
	var tab_row := HBoxContainer.new()
	parent.add_child(tab_row)
	var pages: Array[VBoxContainer] = []
	var tab_buttons: Array[Button] = []
	for title: String in names:
		var page := VBoxContainer.new()
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.visible = pages.is_empty()
		parent.add_child(page)
		pages.append(page)
		var tab := Button.new()
		tab.text = title
		tab.toggle_mode = true
		tab.button_pressed = tab_buttons.is_empty()
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(tab)
		tab_buttons.append(tab)
		var index: int = pages.size()-1
		tab.pressed.connect(func() -> void:
			for i: int in range(pages.size()):
				pages[i].visible = i == index
				tab_buttons[i].set_pressed_no_signal(i == index))
	return pages

func _resource_icon(parent: Node, kind: String, side: int = 40) -> Control:
	var icon := Illustration.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(side,side)
	parent.add_child(icon)
	return icon

func setup_ledger() -> void:
	ledger_panel = _page()
	var shell := VBoxContainer.new()
	ledger_panel.add_child(shell)
	Folio.heading(shell,"Libro de cuentas","MERCANCÍAS · OFICIOS · TERRITORIO","coins_seal",close_panels)
	var pages: Array[VBoxContainer] = _tabs(shell,["Existencias","Cadenas","Territorio"])
	var rows: VBoxContainer = _scroll_rows(pages[0])
	var totals := HBoxContainer.new()
	rows.add_child(totals)
	Folio.icon(totals,"crate",24)
	ledger_total = _label(totals,"0",19)
	totals.tooltip_text = "Existencias totales y monedas disponibles"
	ledger_coins = cost_badge(totals,"coins",0)
	ledger_storage = Folio.paragraph(rows,"",16)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(grid)
	for resource: String in definitions.resources:
		var entry: VBoxContainer = Folio.inset(grid)
		entry.get_parent().custom_minimum_size = Vector2(92,42)
		var line := HBoxContainer.new()
		entry.add_child(line)
		_resource_icon(line,resource,30)
		ledger_values[resource] = _label(line,"0",20)
		entry.get_parent().tooltip_text = definitions.resources[resource].label
	var chains: VBoxContainer = _scroll_rows(pages[1])
	var recipes := GridContainer.new()
	recipes.columns = 1
	recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chains.add_child(recipes)
	for recipe: Array in [
		["El pan de cada día",["grain","flour","bread"],"Granja → molino → horno · El horno necesita madera."],
		["La riqueza de la ría",["fish","salt","salted_fish"],"Pesquería + salinas → salazón · También puedes comprar sal."],
		["Fruto de los viñedos",["grapes","wine"],"Viñedo → bodega"],
		["Barro y fuego",["clay","wood","pottery"],"Barrera + madera → alfar"],
		["El trabajo de la forja",["iron","wood","tools"],"Mina + madera → herrería"],
		["Paños para el mercado",["wool","cloth"],"Pastos → tejedor"]]:
		var recipe_rows: VBoxContainer = Folio.inset(recipes)
		_label(recipe_rows,recipe[0],18).theme_type_variation = "FolioTitle"
		var line := HBoxContainer.new()
		recipe_rows.add_child(line)
		for i: int in range(recipe[1].size()):
			if i > 0: _label(line,"+" if recipe[1].size() == 3 and recipe[1][1] in ["salt","wood"] and i == 1 else "→",24)
			var resource: String = recipe[1][i]
			var resource_icon: Control = _resource_icon(line,resource,30)
			resource_icon.mouse_filter = Control.MOUSE_FILTER_STOP
			resource_icon.tooltip_text = definitions.resources[resource].label
		recipe_rows.get_parent().tooltip_text = recipe[2]
	var land: VBoxContainer = _scroll_rows(pages[2])
	Folio.section(land,"Las riquezas de la ría","compass")
	for entry: Array in [["grain","Tierra fértil","El cereal sostiene los hogares y abastece los molinos."],["wood","Bosques","Los leñadores trabajan junto a las masas de árboles."],["stone","Canteras de granito","Piedra para muelles, depósitos y servicios públicos."],["clay","Tierras de arcilla","La barrera extrae el barro que necesita el alfar."],["iron","Vetas de hierro","Mineral para las herramientas de la herrería."]]:
		var card: VBoxContainer = Folio.inset(land)
		var line := HBoxContainer.new()
		card.add_child(line)
		_resource_icon(line,entry[0],32)
		_label(line,entry[1],18)
		card.get_parent().tooltip_text = entry[2] + ("\nA un máximo de 3 casillas del edificio." if entry[0] != "grain" else "")

func setup_trade() -> void:
	trade_panel = _page()
	var shell := VBoxContainer.new()
	trade_panel.add_child(shell)
	Folio.heading(shell,"Comercio marítimo","PONTEVEDRA · RUTAS DEL ATLÁNTICO","anchor",close_panels)
	var pages: Array[VBoxContainer] = _tabs(shell,["Contratar nave","Travesías"])
	var rows: VBoxContainer = _scroll_rows(pages[0])
	var selectors := HBoxContainer.new()
	rows.add_child(selectors)
	trade_dock = OptionButton.new()
	trade_dock.fit_to_longest_item = false
	trade_dock.clip_text = true
	trade_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade_dock.add_item("Construye un muelle")
	selectors.add_child(trade_dock)
	trade_port = OptionButton.new()
	trade_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for port: String in definitions.ports: trade_port.add_item(definitions.ports[port].label)
	selectors.add_child(trade_port)
	trade_port.item_selected.connect(func(_i: int) -> void: update_trade_resources())
	var cargo := HBoxContainer.new()
	rows.add_child(cargo)
	trade_cargo = _resource_icon(cargo,"salt",28)
	trade_direction = OptionButton.new()
	trade_direction.add_item("Importar")
	trade_direction.add_item("Exportar")
	cargo.add_child(trade_direction)
	trade_direction.item_selected.connect(func(_i: int) -> void: update_trade_resources())
	trade_resource = OptionButton.new()
	trade_resource.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo.add_child(trade_resource)
	var quantity_row := HBoxContainer.new()
	rows.add_child(quantity_row)
	_label(quantity_row,"Cantidad",16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade_quantity = SpinBox.new()
	trade_quantity.custom_minimum_size.x = 76
	trade_quantity.min_value = 1
	trade_quantity.max_value = 60
	trade_quantity.value = 10
	trade_quantity.tooltip_text = "Unidades de mercancía que embarcarán"
	quantity_row.add_child(trade_quantity)
	var accounts := HBoxContainer.new()
	rows.add_child(accounts)
	trade_price = cost_badge(accounts,"coins",0)
	_label(accounts,"/ ud.",15)
	_separator(accounts)
	_label(accounts,"Flete",16)
	trade_fee = cost_badge(accounts,"coins",0)
	_separator(accounts)
	Folio.icon(accounts,"calendar",22)
	trade_days = _label(accounts,"0",17)
	accounts.tooltip_text = "Precio por unidad · Flete · Días de travesía"
	var payment := HBoxContainer.new()
	pages[0].add_child(payment)
	_label(payment,"Al salir",16)
	trade_payment = cost_badge(payment,"coins",0)
	var income := HBoxContainer.new()
	payment.add_child(income)
	_label(income,"Al volver",16)
	trade_income = cost_badge(income,"coins",0)
	trade_info = Folio.paragraph(rows,"",16)
	trade_repeat = CheckBox.new()
	trade_repeat.text = "Repetir ruta"
	trade_repeat.tooltip_text = "Al regresar la nave, se intentará contratar un nuevo viaje cada día."
	quantity_row.add_child(trade_repeat)
	var actions := HBoxContainer.new()
	pages[0].add_child(actions)
	var send: Button = _button(actions,"Enviar nave",func() -> void:
		if dock_ids.is_empty():
			message_label.text = "Construye y conecta un muelle junto al mar"
			return
		order.emit({"type":"route" if trade_repeat.button_pressed else "trade","repeat":trade_repeat.button_pressed,"dock":dock_ids[trade_dock.selected],"port":definitions.ports.keys()[trade_port.selected],"direction":"buy" if trade_direction.selected == 0 else "sell","resource":trade_resource_ids[trade_resource.selected],"quantity":int(trade_quantity.value)}),"sailboat")
	send.theme_type_variation = "PrimaryButton"
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(actions,"Detener repetición",func() -> void:
		if not dock_ids.is_empty(): order.emit({"type":"route","repeat":false,"dock":dock_ids[trade_dock.selected]}))
	var journeys: VBoxContainer = _scroll_rows(pages[1])
	Folio.section(journeys,"Naves y cargamentos","anchor")
	voyage_rows = VBoxContainer.new()
	journeys.add_child(voyage_rows)
	trade_status = Folio.paragraph(journeys,"",16)
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
	var food_capacity: int = 0
	for item: Dictionary in snapshot.buildings:
		if item.connected: capacity += definitions.buildings[item.type].get("storage",0)
		if item.connected: food_capacity += definitions.buildings[item.type].get("food_storage",0)
	trade_price.text = str(price)
	trade_fee.text = str(port.fee)
	trade_days.text = str(port.days)
	if trade_cargo.kind != resource: trade_cargo.set_kind(resource)
	trade_payment.text = str(price*quantity+port.fee if direction == "buy" else port.fee)
	trade_income.text = str(price*quantity)
	trade_income.get_parent().get_parent().visible = direction == "sell"
	trade_info.text = "Cupo %d · Almacenamiento %d / %d" % [quota,Economy.total(snapshot.inventory)+reserved,capacity+food_capacity]
	if food_capacity > 0: trade_info.text += "\nHórreos: +%d plazas para cereal, harina y pan" % food_capacity
	trade_info.mouse_filter = Control.MOUSE_FILTER_STOP
	trade_info.tooltip_text = "Cupo renovado en %d días. Almacén: %d disponibles + %d en camino / %d." % [10-(snapshot.tick/definitions.balance.ticks_per_day)%10,Economy.total(snapshot.inventory),reserved,capacity]
	refresh_voyage_cards(snapshot)
	trade_status.text = ""
	for route: Dictionary in snapshot.trade_routes:
		trade_status.text += "Ruta automática #%d: %s\n" % [route.dock,route.status]
	trade_status.text += "\nÚLTIMAS ENTREGAS\n"+("\n".join(snapshot.trade_history) if not snapshot.trade_history.is_empty() else "El libro de entregas aún está en blanco.")

func setup_merchants() -> void:
	merchant_panel = _page()
	var shell := VBoxContainer.new()
	merchant_panel.add_child(shell)
	Folio.heading(shell,"Mercaderes del puerto","COMPRAS Y VENTAS DEL ALMACÉN","anchor",close_panels)
	var rows: VBoxContainer = _scroll_rows(shell)
	merchant_status = Folio.paragraph(Folio.inset(rows),"",16)
	merchant_build_warehouse = _button(rows,"Construir almacén",func() -> void:
		show_categories()
		show_buildings("Puerto")
		tool_selected.emit("warehouse"),"warehouse")
	merchant_build_warehouse.tooltip_text = building_tooltip("warehouse")
	Folio.paragraph(rows,"1. Almacén conectado al camino principal.\n2. Avanza el tiempo hasta que atraque la nave.\n3. Elige qué y cuánto comprar o vender.",16)
	Folio.section(rows,"Preparar intercambio","crate")
	Folio.label(rows,"Mercancía",15)
	merchant_resource = OptionButton.new()
	for resource: String in definitions.resources: merchant_resource.add_item(definitions.resources[resource].label)
	rows.add_child(merchant_resource)
	Folio.label(rows,"Cantidad de unidades",15)
	merchant_quantity = SpinBox.new()
	merchant_quantity.min_value = 1
	merchant_quantity.max_value = 60
	merchant_quantity.value = 10
	rows.add_child(merchant_quantity)
	merchant_quote = Folio.paragraph(Folio.inset(rows),"",16)
	merchant_feedback = Folio.paragraph(rows,"",16)
	var actions := HBoxContainer.new()
	shell.add_child(actions)
	merchant_buy = _button(actions,"Comprar",func() -> void: merchant_order("buy"),"coins")
	merchant_sell = _button(actions,"Vender",func() -> void: merchant_order("sell"),"warehouse")
	merchant_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	merchant_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(shell,"Rutas propias del muelle",func() -> void: open_panel(trade_panel),"sailboat")
	merchant_status.tooltip_text = "Los mercaderes llegan periódicamente. Cada visita tiene existencias y demanda limitadas. Las rutas propias requieren un muelle."

func merchant_order(direction: String) -> void:
	order.emit({"type":"merchant_trade","warehouse":merchant_warehouse,"direction":direction,"resource":definitions.resources.keys()[merchant_resource.selected],"quantity":int(merchant_quantity.value)})

func refresh_merchants(snapshot: Dictionary) -> void:
	var current: Dictionary = {}
	for b: Dictionary in snapshot.buildings:
		if b.type == "warehouse" and b.connected:
			if current.is_empty() or b.id == merchant_warehouse: current = b
	merchant_warehouse = current.get("id",0)
	var visit: Dictionary = snapshot.merchant
	var resource: String = definitions.resources.keys()[merchant_resource.selected]
	var d: Dictionary = definitions.resources[resource]
	var quantity: int = int(merchant_quantity.value)
	var ready: bool = not visit.is_empty() and visit.status == "En puerto" and merchant_warehouse > 0
	var buy_reason: String = ""
	var sell_reason: String = ""
	if not ready:
		buy_reason = "Conecta un almacén al camino principal." if merchant_warehouse == 0 else "Espera a que el mercader esté en puerto; deja avanzar el tiempo."
		sell_reason = buy_reason
	else:
		var inventory: Dictionary = snapshot.inventory.duplicate()
		inventory[resource] += quantity
		if d.buy < 0: buy_reason = "El mercader solo compra esta mercancía."
		elif visit.stock[resource] < quantity: buy_reason = "El mercader solo dispone de %d uds. Reduce la cantidad." % visit.stock[resource]
		elif snapshot.coins < quantity*d.buy: buy_reason = "Faltan %d monedas para comprar." % (quantity*d.buy-snapshot.coins)
		elif not Economy.storage_fits(inventory,snapshot.buildings,definitions,snapshot.voyages): buy_reason = "No hay espacio para esta compra. Vende recursos o amplía el almacenamiento."
		if snapshot.inventory[resource] < quantity: sell_reason = "Solo tienes %d uds. Reduce la cantidad para vender." % snapshot.inventory[resource]
		elif visit.demand[resource] < quantity: sell_reason = "El mercader acepta %d uds. más. Reduce la cantidad." % visit.demand[resource]
	merchant_buy.disabled = not buy_reason.is_empty()
	merchant_sell.disabled = not sell_reason.is_empty()
	merchant_buy.tooltip_text = buy_reason
	merchant_sell.tooltip_text = sell_reason
	merchant_feedback.text = buy_reason if not ready else "Compra: %s\nVenta: %s" % [buy_reason if not buy_reason.is_empty() else "Disponible; pagas y recibes la mercancía al instante.",sell_reason if not sell_reason.is_empty() else "Disponible; entregas la mercancía y cobras al instante."]
	merchant_status.text = "Construye un almacén conectado al camino para recibir mercaderes."
	merchant_build_warehouse.visible = merchant_warehouse == 0
	if merchant_warehouse == 0:
		var existing: Dictionary = {}
		for b: Dictionary in snapshot.buildings:
			if b.type == "warehouse":
				existing = b
				break
		if not existing.is_empty():
			merchant_build_warehouse.hide()
			merchant_status.text = "Repara el almacén desde su ficha para recibir mercaderes." if existing.ruined else "Ya tienes un almacén. Conéctalo al camino principal para recibir mercaderes."
	if merchant_warehouse > 0:
		merchant_status.text = "Almacén #%d · esperando la siguiente nave" % merchant_warehouse
		if not visit.is_empty():
			var until: int = definitions.balance.ticks_per_day*(3 if visit.status == "En puerto" else (1 if visit.status == "Llegando" else 4))-visit.elapsed
			merchant_status.text = "Almacén #%d · Mercader de %s\n%s · %.1f días restantes" % [merchant_warehouse,definitions.ports[visit.port].label,visit.status,float(until)/definitions.balance.ticks_per_day]
	merchant_quote.text = "Tus existencias: %d uds.\nCompra: %s · Venta: %d monedas/ud.\nTotal compra: %s · Total venta: %d" % [snapshot.inventory[resource],str(d.buy) if d.buy >= 0 else "No disponible",d.sell,str(d.buy*quantity) if d.buy >= 0 else "—",d.sell*quantity]
	if not visit.is_empty(): merchant_quote.text += "\nPuede venderte: %d uds.\nPuede comprarte: %d uds." % [visit.stock[resource],visit.demand[resource]]
