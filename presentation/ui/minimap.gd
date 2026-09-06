extends Control
signal navigate(point: Vector3)
var snapshot: Dictionary = {}
var focus: Vector3 = Vector3(20,0,20)

func _ready() -> void:
	custom_minimum_size = Vector2(158,138)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Mapa de la ciudad · clic para desplazar la cámara"

func _draw() -> void:
	if snapshot.is_empty(): return
	var tile: Vector2 = size / 40.0
	var colors: Dictionary = {"water":Color("#4fabb4"),"land":Color("#b9bd8c"),"fertile":Color("#a8b578"),"forest":Color("#788858")}
	for cell: int in range(1600):
		draw_rect(Rect2(Vector2(cell%40,cell/40)*tile,tile+Vector2(0.4,0.4)),colors[snapshot.terrain[cell]])
	for cell: int in snapshot.roads:
		draw_rect(Rect2(Vector2(cell%40,cell/40)*tile,tile),Color("#d3c6a3"))
	for item: Dictionary in snapshot.buildings:
		draw_rect(Rect2(Vector2(item.x,item.z)*tile,tile*2),Color("#d3a16d"))
	draw_rect(Rect2(Vector2(focus.x-8,focus.z-6)*tile,Vector2(16,12)*tile),Color("#efe1b9"),false,1.5)
	draw_rect(Rect2(Vector2.ZERO,size),Color("#b59b6d"),false,1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		navigate.emit(Vector3(event.position.x/size.x*40,0,event.position.y/size.y*40))
		accept_event()
