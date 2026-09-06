extends RefCounted
## Shared manuscript furniture for every game panel.
const Banner = preload("res://presentation/ui/folio_banner.gd")

static func label(parent: Node, value: String, font_size: int = 17) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size",font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func icon(parent: Node, kind: String, side: int = 32) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load("res://assets/ui/chrome/%s.svg" % kind)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(side,side)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func heading(parent: Node, title: String, subtitle: String, emblem: String, close: Callable = Callable()) -> Label:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "FolioHeading"
	panel.custom_minimum_size.y = 40
	panel.tooltip_text = subtitle
	parent.add_child(panel)
	panel.add_child(Banner.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	panel.add_child(row)
	icon(row,emblem,26)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation",0)
	row.add_child(titles)
	var title_label: Label = label(titles,title,22)
	title_label.theme_type_variation = "FolioTitle"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if close.is_valid():
		var button := Button.new()
		button.text = "×"
		button.tooltip_text = "Cerrar"
		button.custom_minimum_size = Vector2(28,28)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(close)
		row.add_child(button)
	return title_label

static func section(parent: Node, title: String, emblem: String = "quill") -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	icon(row,emblem,18)
	label(row,title,17).theme_type_variation = "FolioTitle"
	var rule := HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rule)

static func inset(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "LedgerInset"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	return rows

static func paragraph(parent: Node, value: String, font_size: int = 17) -> Label:
	var node: Label = label(parent,value,font_size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

static func badge(parent: Node, caption: String, value: String, emblem: String) -> Label:
	var rows: VBoxContainer = inset(parent)
	var row := HBoxContainer.new()
	rows.add_child(row)
	rows.get_parent().tooltip_text = caption
	icon(row,emblem,24)
	var number: Label = label(row,value,20)
	return number
