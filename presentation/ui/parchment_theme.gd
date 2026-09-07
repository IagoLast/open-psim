extends RefCounted
## Nine-slice carved stone keeps bevels crisp when panels resize.
const INK := Color("#392b20")
const MUTED := Color("#705c42")
const OLIVE := Color("#65704b")
const RUBRIC := Color("#793d32")
const PAPER := Color("#e8d6af")
const WALNUT := Color("#76583c")
const GOLD := Color("#af8a50")
const DISPLAY_FONT = preload("res://assets/fonts/Almendra-Regular.ttf")

static func stone(base: Color, rim: Color, inset: int = 16, scale_value: float = 1.0) -> StyleBoxTexture:
	var svg: String = '''<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">
<defs><linearGradient id="paper" x2="0.3" y2="1"><stop stop-color="#FACE_LIGHT"/><stop offset=".5" stop-color="#FACE"/><stop offset="1" stop-color="#FACE_DARK"/></linearGradient></defs>
<path d="M9 5H87L95 13V88L86 96H10L2 88V13Z" fill="#352c20" opacity=".16"/>
<path d="M8 1H86L94 9V84L85 92H9L1 84V9Z" fill="#SHADOW"/>
<path d="M8 1H86L94 9L86 16H10L1 9Z" fill="#LIGHT"/>
<path d="M1 9L10 16V76L1 84Z" fill="#RIM"/>
<path d="M86 16L94 9V84L85 92L78 78Z" fill="#RIM_DARK"/>
<path d="M10 76H80L85 92H9L1 84Z" fill="#RIM_DARK"/>
<path d="M11 10H83L87 14V77L81 84H12L7 78V15Z" fill="#RIM"/>
<path d="M15 13H79L84 18V75L78 81H16L11 76V18Z" fill="#SHADOW"/>
<path d="M15 13H79L84 18L78 22H18L11 18Z" fill="#RIM_DARK"/>
<path d="M18 18H77L80 22V73L76 77H19L15 73V22Z" fill="url(#paper)"/>
<path d="M18 18H77L80 22H20V73L15 73V22Z" fill="#FACE_LIGHT" opacity=".8"/>
<path d="M19 77H76L80 73V68L74 73H19Z" fill="#FACE_DARK" opacity=".6"/>
<path d="M3 10L9 4H22L17 8H10L7 14Z M74 4H85L90 9L84 11H76Z M4 66L9 62V76L4 80Z" fill="#LIGHT" opacity=".65"/>
<path d="M88 29L93 25V42L88 46Z M65 86H79L82 89H62Z" fill="#SHADOW" opacity=".22"/>
<path d="M22 24L29 20H36L26 26Z M66 63L77 58V65L71 68Z M20 55L25 61L20 68Z" fill="#FACE_DARK" opacity=".18"/>
</svg>'''
	var colors: Dictionary = {
		"FACE_LIGHT":base.lightened(0.12), "FACE_DARK":base.darkened(0.055),
		"FACE":base, "RIM_DARK":rim.darkened(0.16), "RIM":rim,
		"SHADOW":rim.darkened(0.32), "LIGHT":rim.lightened(0.35)
	}
	for key: String in colors: svg = svg.replace("#"+key, "#"+colors[key].to_html(false))
	var image := Image.new()
	image.load_svg_from_string(svg,scale_value)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.set_texture_margin_all(20*scale_value)
	style.set_expand_margin_all(2)
	style.expand_margin_bottom = 5
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func button_style(base: Color, rim: Color) -> StyleBoxTexture:
	var style: StyleBoxTexture = stone(base,rim,9,0.35)
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	return style

static func create() -> Theme:
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/EBGaramond.ttf")
	font.variation_opentype = {"wght":500.0}
	theme.default_font = font
	theme.default_font_size = 17
	for control: String in ["Button","OptionButton"]:
		theme.set_font("font",control,DISPLAY_FONT)
		theme.set_font_size("font_size",control,16)
	theme.set_type_variation("FolioTitle","Label")
	theme.set_font("font","FolioTitle",DISPLAY_FONT)
	theme.set_color("font_color","FolioTitle",RUBRIC)
	var panel: StyleBoxTexture = stone(PAPER,WALNUT,12,0.55)
	for control: String in ["PanelContainer","PopupPanel","AcceptDialog","TooltipPanel"]:
		theme.set_stylebox("panel",control,panel)
	theme.set_type_variation("HeaderPanel","PanelContainer")
	var header: StyleBoxTexture = stone(PAPER,WALNUT,12,0.45)
	header.content_margin_left = 66
	header.content_margin_top = 4
	header.content_margin_bottom = 8
	header.set_expand_margin_all(0)
	theme.set_stylebox("panel","HeaderPanel",header)
	theme.set_type_variation("FolioPanel","PanelContainer")
	theme.set_stylebox("panel","FolioPanel",stone(PAPER,WALNUT,12,0.55))
	theme.set_type_variation("FolioHeading","PanelContainer")
	var masthead := StyleBoxFlat.new()
	masthead.bg_color = Color("#ecdbb7")
	masthead.content_margin_left = 4
	masthead.content_margin_right = 4
	masthead.content_margin_top = 3
	masthead.content_margin_bottom = 3
	theme.set_stylebox("panel","FolioHeading",masthead)
	theme.set_type_variation("LedgerInset","PanelContainer")
	var leaf := StyleBoxFlat.new()
	leaf.bg_color = Color("#efdfbb")
	leaf.set_border_width_all(0)
	leaf.set_corner_radius_all(3)
	leaf.content_margin_left = 10
	leaf.content_margin_right = 10
	leaf.content_margin_top = 8
	leaf.content_margin_bottom = 8
	theme.set_stylebox("panel","LedgerInset",leaf)
	theme.set_type_variation("PrimaryButton","Button")
	theme.set_stylebox("normal","PrimaryButton",button_style(RUBRIC,GOLD))
	theme.set_stylebox("hover","PrimaryButton",button_style(RUBRIC.lightened(0.1),GOLD.lightened(0.1)))
	theme.set_stylebox("pressed","PrimaryButton",button_style(RUBRIC.darkened(0.1),GOLD))
	theme.set_color("font_color","PrimaryButton",Color("#fff0cf"))
	theme.set_color("font_hover_color","PrimaryButton",Color("#fff7dc"))
	theme.set_color("font_focus_color","PrimaryButton",Color("#fff7dc"))
	theme.set_type_variation("CatalogCard","Button")
	for state_name: String in ["pressed","hover_pressed"]:
		theme.set_stylebox(state_name,"CatalogCard",button_style(Color("#cfba8b"),GOLD))
	for control: String in ["Button","OptionButton"]:
		for state_name: String in ["normal","hover","pressed","hover_pressed","disabled"]:
			var base := Color("#dfcba3")
			var rim := Color("#a58a60")
			if state_name == "hover": base = Color("#f0dfba"); rim = GOLD
			if state_name in ["pressed","hover_pressed"]: base = RUBRIC; rim = GOLD
			if state_name == "hover_pressed": base = base.lightened(0.08)
			if state_name == "disabled": base = Color("#d6ccb6"); rim = Color("#b9ad96")
			theme.set_stylebox(state_name,control,button_style(base,rim))
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("#9f623f")
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(4)
		theme.set_stylebox("focus",control,focus)
		theme.set_color("font_pressed_color",control,Color("#fff0cf"))
		theme.set_color("font_hover_pressed_color",control,Color("#fff0cf"))
		theme.set_color("icon_pressed_color",control,Color("#fff0cf"))
		theme.set_color("icon_hover_pressed_color",control,Color("#fff0cf"))
		theme.set_constant("h_separation",control,6)
	for control: String in ["Label","Button","OptionButton","CheckBox","LineEdit","PopupMenu","LinkButton","TooltipLabel"]:
		theme.set_color("font_color",control,INK)
		theme.set_color("font_hover_color",control,INK)
		theme.set_color("font_focus_color",control,INK)
		theme.set_color("font_disabled_color",control,MUTED)
	theme.set_stylebox("panel","PopupMenu",stone(PAPER,WALNUT,10,0.4))
	theme.set_stylebox("panel","TooltipPanel",stone(Color("#f1e5c9"),GOLD,10,0.35))
	theme.set_color("font_hover_color","PopupMenu",INK)
	theme.set_constant("v_separation","PopupMenu",6)
	theme.set_icon("arrow","OptionButton",preload("res://assets/ui/chrome/chevron.svg"))
	for state_name: String in ["checked","checked_disabled"]:
		theme.set_icon(state_name,"CheckBox",preload("res://assets/ui/chrome/check_on.svg"))
	for state_name: String in ["unchecked","unchecked_disabled"]:
		theme.set_icon(state_name,"CheckBox",preload("res://assets/ui/chrome/check_off.svg"))
	theme.set_icon("updown","SpinBox",preload("res://assets/ui/chrome/spinner.svg"))
	for state_name: String in ["normal","hover","pressed","hover_pressed","disabled"]:
		var checkbox := StyleBoxEmpty.new()
		checkbox.content_margin_top = 2
		checkbox.content_margin_bottom = 2
		theme.set_stylebox(state_name,"CheckBox",checkbox)
	for state_name: String in ["font_pressed_color","font_hover_pressed_color"]:
		theme.set_color(state_name,"CheckBox",INK)
	theme.set_stylebox("hover","PopupMenu",button_style(Color("#cfba8b"),GOLD))
	theme.set_stylebox("normal","LineEdit",button_style(Color("#f0e0be"),Color("#a58a60")))
	theme.set_stylebox("focus","LineEdit",theme.get_stylebox("focus","Button"))
	theme.set_color("caret_color","LineEdit",INK)
	theme.set_color("selection_color","LineEdit",OLIVE)
	for control: String in ["HSeparator","VSeparator"]:
		var rule := StyleBoxLine.new()
		rule.color = Color("#b8a382")
		rule.thickness = 1
		rule.vertical = control == "VSeparator"
		theme.set_stylebox("separator",control,rule)
		theme.set_constant("separation",control,6)
	theme.set_constant("separation","HBoxContainer",5)
	theme.set_constant("separation","VBoxContainer",4)
	theme.set_constant("h_separation","GridContainer",5)
	theme.set_constant("v_separation","GridContainer",5)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#c7b99c")
	track.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = OLIVE
	fill.border_color = Color("#94a276")
	fill.border_width_top = 2
	fill.set_corner_radius_all(4)
	theme.set_stylebox("background","ProgressBar",track)
	theme.set_stylebox("fill","ProgressBar",fill)
	track = track.duplicate()
	track.content_margin_left = 3
	track.content_margin_right = 3
	theme.set_stylebox("scroll","VScrollBar",track)
	for state_name: String in ["grabber","grabber_highlight","grabber_pressed"]:
		theme.set_stylebox(state_name,"VScrollBar",fill)
	return theme
