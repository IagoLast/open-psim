extends CanvasLayer
signal command_submitted(command: String)
signal closed
const Parchment = preload("res://presentation/ui/parchment_theme.gd")
var overlay: Control
var panel: PanelContainer
var output: RichTextLabel
var input: LineEdit
var money_button: CheckButton
var history: Array[String] = []
var history_index: int = 0
var lines: Array[String] = []

func setup(_definitions: Dictionary) -> void:
	layer = 30
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme = Parchment.create()
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.06,0.09,0.09,0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	panel = PanelContainer.new()
	overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "Consola de desarrollo"
	title.theme_type_variation = "FolioTitle"
	title.add_theme_font_size_override("font_size",28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := Button.new()
	close.text = "Cerrar · F4"
	close.pressed.connect(close_console)
	heading.add_child(close)
	var note := Label.new()
	note.text = "Partida en pausa · Los cambios de la ciudad se incluyen al guardar."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	money_button = CheckButton.new()
	money_button.text = "Dinero infinito"
	money_button.toggled.connect(func(enabled: bool) -> void: command_submitted.emit("money infinite" if enabled else "money off"))
	column.add_child(money_button)
	var shortcuts := HFlowContainer.new()
	column.add_child(shortcuts)
	for entry: Array in [["+10.000 monedas","money 10000"],["Reponer recursos","stock"],["Reparar edificios","repair"],["Villa en desarrollo","city developing"],["Ciudad avanzada","city advanced"]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func() -> void: _submit(entry[1]))
		shortcuts.add_child(button)
	output = RichTextLabel.new()
	output.custom_minimum_size.y = 170
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.bbcode_enabled = false
	output.selection_enabled = true
	output.scroll_following = true
	output.add_theme_color_override("default_color",Parchment.INK)
	column.add_child(output)
	var command_row := HBoxContainer.new()
	column.add_child(command_row)
	input = LineEdit.new()
	input.placeholder_text = "help · money infinite · resource wood 100"
	input.add_theme_color_override("font_placeholder_color",Parchment.MUTED)
	input.max_length = 160
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(_submit)
	input.gui_input.connect(_history_input)
	command_row.add_child(input)
	var run := Button.new()
	run.text = "Ejecutar"
	run.pressed.connect(func() -> void: _submit(input.text))
	command_row.add_child(run)
	get_viewport().size_changed.connect(_layout)
	_layout()
	write_line("Escribe help para ver todos los comandos. ↑ / ↓ recuperan el historial.")
	overlay.hide()

func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(850,size.x-32),minf(540,size.y-32))
	panel.position = (size-panel.size)/2

func open_console(infinite_money: bool) -> void:
	money_button.set_pressed_no_signal(infinite_money)
	overlay.show()
	input.grab_focus()

func close_console() -> void:
	if not is_open(): return
	input.release_focus()
	overlay.hide()
	closed.emit()

func is_open() -> bool:
	return is_instance_valid(overlay) and overlay.visible

func write_line(text: String) -> void:
	lines.append(text)
	while lines.size() > 80: lines.pop_front()
	output.text = "\n".join(lines)

func _submit(text: String) -> void:
	var command: String = text.strip_edges()
	if command.is_empty(): return
	history.append(command)
	if history.size() > 50: history.pop_front()
	history_index = history.size()
	write_line("> " + command)
	input.clear()
	command_submitted.emit(command)
	if is_open(): input.grab_focus()

func _history_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_UP,KEY_DOWN]:
		history_index = clampi(history_index+(-1 if event.keycode == KEY_UP else 1),0,history.size())
		input.text = history[history_index] if history_index < history.size() else ""
		input.caret_column = input.text.length()
		input.accept_event()
