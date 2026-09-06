extends RefCounted
## Paper grain and borders generated locally, independent of simulation RNG.

static func paper(base: Color, border: Color, inset: int = 12) -> StyleBoxTexture:
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	var random := RandomNumberGenerator.new()
	random.seed = 1530
	for y: int in range(128):
		for x: int in range(128):
			var edge: int = mini(mini(x,127-x),mini(y,127-y))
			var grain: float = random.randf_range(-0.012,0.012)
			var fiber: float = sin(float(x*3+y*17))*0.003
			var color: Color = base.lightened(grain+fiber)
			if edge < 12:
				color = color.darkened((12-edge)*0.003)
			if edge <= 1:
				color = border
			elif edge == 3:
				color = base.lightened(0.12)
			elif edge == 6:
				color = border.lerp(base,0.55)
			image.set_pixel(x,y,color)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.set_texture_margin_all(12)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var ink := Color("#35291e")
	var faded := Color("#6e543b")
	var panel: StyleBoxTexture = paper(Color("#f2e7ce"),Color("#ae9470"),14)
	theme.set_stylebox("panel","PanelContainer",panel)
	theme.set_stylebox("panel","PopupPanel",panel)
	theme.set_stylebox("panel","AcceptDialog",panel)
	theme.set_stylebox("panel","TooltipPanel",panel)
	for state_name: String in ["normal","hover","pressed","disabled"]:
		var base: Color = Color("#e9d9b8")
		if state_name == "hover": base = Color("#fff1d8")
		if state_name == "pressed": base = Color("#d2b783")
		if state_name == "disabled": base = Color("#dfd3bb")
		var button: StyleBoxTexture = paper(base,Color("#b09873"),10)
		button.content_margin_top = 6
		button.content_margin_bottom = 6
		theme.set_stylebox(state_name,"Button",button)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#78512b")
	focus.set_border_width_all(2)
	theme.set_stylebox("focus","Button",focus)
	for control: String in ["Label","Button","LinkButton","TooltipLabel"]:
		theme.set_color("font_color",control,ink)
		theme.set_color("font_hover_color",control,ink)
		theme.set_color("font_pressed_color",control,ink)
		theme.set_color("font_focus_color",control,ink)
		theme.set_color("font_disabled_color",control,faded)
	var rule := StyleBoxLine.new()
	rule.color = Color("#b89a6d")
	rule.thickness = 1
	theme.set_stylebox("separator","HSeparator",rule)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#decca9")
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#a38559")
	grabber.set_corner_radius_all(2)
	theme.set_stylebox("scroll","VScrollBar",track)
	for state_name: String in ["grabber","grabber_highlight","grabber_pressed"]:
		theme.set_stylebox(state_name,"VScrollBar",grabber)
	return theme
