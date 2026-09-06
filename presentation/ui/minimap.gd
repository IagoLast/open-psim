extends Control
const Map = preload("res://sim/world_map.gd")
signal navigate(point: Vector3)
var snapshot: Dictionary = {}
var focus: Vector3 = Map.START_FOCUS
var zoom: float = 30
var terrain_texture: ImageTexture
var terrain_seed: int = -1
const COLORS: Dictionary = {"water":Color("#4fabb4"),"land":Color("#b9bd8c"),"fertile":Color("#a8b578"),"forest":Color("#788858"),"rock":Color("#96999e"),"clay":Color("#c17b57"),"ore":Color("#677787")}

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(330,330)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Ría de Pontevedra · norte arriba · clic para viajar"

func _draw() -> void:
	if snapshot.is_empty(): return
	var width: int = snapshot.map_size
	var tile: Vector2 = size / float(width)
	if terrain_texture == null or terrain_seed != snapshot.seed:
		var raster: Image = Image.create(width,width,false,Image.FORMAT_RGB8)
		for cell: int in range(snapshot.terrain.size()): raster.set_pixel(cell%width,cell/width,COLORS[snapshot.terrain[cell]])
		terrain_texture = ImageTexture.create_from_image(raster)
		terrain_seed = snapshot.seed
	draw_texture_rect(terrain_texture,Rect2(Vector2.ZERO,size),false)
	draw_rect(Rect2(Vector2(Map.BURGO_BRIDGE.position)*tile,Vector2(Map.BURGO_BRIDGE.size)*tile),Color("#e5d7b4"))
	for cell: int in snapshot.roads: draw_rect(Rect2(Vector2(cell%width,cell/width)*tile,tile),Color("#e5d7b4"))
	for item: Dictionary in snapshot.buildings: draw_rect(Rect2(Vector2(item.x,item.z)*tile,tile*2),Color("#d39860"))
	for voyage: Dictionary in snapshot.voyages:
		var phase: float = float(voyage.elapsed)/voyage.duration
		var travel: float = phase*2 if phase < 0.5 else (1-phase)*2
		var cell: int = voyage.path[mini(voyage.path.size()-1,int(travel*(voyage.path.size()-1)))]
		draw_circle(Vector2(cell%width+0.5,cell/width+0.5)*tile,3,Color.WHITE)
	for marker: Dictionary in Map.LANDMARKS:
		var font: Font = get_theme_font("font","Label")
		var text: String = marker.label
		var major: bool = text in ["PONTEVEDRA","COMBARRO","MARÍN"]
		var font_size: int = 14 if major else 12
		var anchor := Vector2(marker.x,marker.z)*tile
		if text == "RÍA DE PONTEVEDRA": text = "RÍA DE\nPONTEVEDRA"
		if major: draw_circle(anchor,2.5,Color("#704835"))
		var line_number: int = 0
		for line: String in text.split("\n"):
			var extent: float = font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			var position := Vector2(clampf(anchor.x-extent/2,4,size.x-extent-4),anchor.y-6+line_number*14)
			draw_string_outline(font,position,line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("#e5e2bf"))
			draw_string(font,position,line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#3b493a"))
			line_number += 1
	draw_string(get_theme_font("font","Label"),Vector2(10,20),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#3b493a"))
	draw_rect(Rect2(Vector2(focus.x-zoom*0.5,focus.z-zoom*0.4)*tile,Vector2(zoom,zoom*0.8)*tile),Color("#fff3d8"),false,1.5)
	draw_rect(Rect2(Vector2.ZERO,size),Color("#b59b6d"),false,1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		navigate.emit(Vector3(event.position.x/size.x*snapshot.map_size,0,event.position.y/size.y*snapshot.map_size))
		accept_event()
