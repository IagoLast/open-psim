extends CanvasLayer
## A single entry point for starting, resuming, and loading a town.
signal selected(choice: String)
signal music_toggled(enabled: bool)
const ParchmentTheme = preload("res://presentation/ui/parchment_theme.gd")
const Folio = preload("res://presentation/ui/folio.gd")
var root: Control
var panel: PanelContainer
var buttons: Dictionary = {}
var message_label: Label
var can_continue: bool = false
var music_toggle: CheckButton

func setup() -> void:
	layer = 5
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = ParchmentTheme.create()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_force_pass_scroll_events = false
	var shade := ColorRect.new()
	shade.color = Color(0.06,0.13,0.12,0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",10)
	scroll.add_child(rows)
	var heading := HBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(heading)
	Folio.icon(heading,"crest",56)
	var titles := VBoxContainer.new()
	heading.add_child(titles)
	Folio.label(titles,"Pontevedra",42).theme_type_variation = "FolioTitle"
	Folio.label(titles,"UNA VILLA EN LA RÍA · GALICIA, 1530",15)
	var introduction: Label = Folio.paragraph(rows,"Funda tu villa o toma las riendas de una ciudad que ya está en marcha.",19)
	introduction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(HSeparator.new())
	_add_button(rows,"continue","Continuar","Vuelve a la villa. La simulación permanece en pausa.","seal")
	_add_button(rows,"new","Nueva villa","Un territorio vacío para construir desde el principio.","quill")
	_add_button(rows,"developing","Villa en desarrollo","Un barrio habitado, caminos y producción básica.","crate")
	buttons.developing.theme_type_variation = "PrimaryButton"
	_add_button(rows,"advanced","Ciudad avanzada","Más vecinos, talleres y servicios para explorar la ciudad.","crest")
	var archive := HBoxContainer.new()
	rows.add_child(archive)
	for entry: Array in [["load","Cargar guardado"],["save","Guardar partida"],["help","Ayuda"]]:
		var choice: String = entry[0]
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: selected.emit(choice))
		archive.add_child(button)
		buttons[choice] = button
	music_toggle = CheckButton.new()
	music_toggle.text = "Música"
	music_toggle.tooltip_text = "Activa o desactiva la banda sonora."
	music_toggle.toggled.connect(func(enabled: bool) -> void: music_toggled.emit(enabled))
	rows.add_child(music_toggle)
	message_label = Folio.paragraph(rows,"",16)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color",ParchmentTheme.RUBRIC)
	var footnote: Label = Folio.paragraph(rows,"Las ciudades preparadas se abren en pausa. F4 abre la consola de desarrollo durante la partida.",16)
	footnote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footnote.add_theme_color_override("font_color",ParchmentTheme.MUTED)
	root.resized.connect(_layout)
	_layout()
	hide()

func _add_button(parent: Node, choice: String, title: String, description: String, emblem: String) -> void:
	var button := Button.new()
	button.text = title
	button.tooltip_text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = load("res://assets/ui/chrome/%s.svg" % emblem)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width",28)
	button.add_theme_constant_override("h_separation",12)
	button.add_theme_font_size_override("font_size",22)
	button.custom_minimum_size.y = 44
	button.pressed.connect(func() -> void: selected.emit(choice))
	parent.add_child(button)
	buttons[choice] = button
	var caption: Label = Folio.paragraph(parent,description,16)
	# Hide the continuation's caption with its button on the first visit.
	button.visibility_changed.connect(func() -> void: caption.visible = button.visible)

func _layout() -> void:
	var available: Vector2 = root.size
	panel.size = Vector2(minf(620,available.x-32),minf(680 if can_continue else 580,available.y-32))
	panel.position = (available-panel.size)*0.5

func open_menu(has_game: bool, has_save: bool) -> void:
	can_continue = has_game
	buttons["continue"].visible = has_game
	buttons.save.visible = has_game
	buttons.help.visible = has_game
	buttons.load.disabled = not has_save
	buttons.load.tooltip_text = "Carga la última partida guardada." if has_save else "Todavía no hay una partida guardada."
	message_label.text = ""
	_layout()
	show()
	(buttons["continue"] if has_game else buttons.developing).grab_focus()

func close_menu() -> void:
	hide()

func is_open() -> bool:
	return visible
