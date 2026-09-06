extends Control
## Every illustration comes from the same Blender models used by the world.
var kind: String = "house"
var supplied_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_kind(kind)

func set_kind(value: String) -> void:
	kind = value
	supplied_texture = null
	var path: String = "res://assets/ui/%s.png" % kind
	if not ResourceLoader.exists(path): path = "res://assets/ui/resources/%s.svg" % kind
	if not ResourceLoader.exists(path):
		queue_redraw()
		return
	supplied_texture = load(path) as Texture2D
	if supplied_texture == null: push_error("Ilustración Blender inválida: " + path)
	queue_redraw()

func _draw() -> void:
	if supplied_texture == null:
		var color: Color = Color.from_hsv(float(posmod(kind.hash(),360))/360.0,0.30,0.72)
		var rect: Rect2 = Rect2(size*0.22,size*0.56)
		draw_rect(rect,color)
		draw_rect(rect,Color("#806845"),false,2)
		return
	var texture_size: Vector2 = supplied_texture.get_size()
	var ratio: float = minf(size.x / texture_size.x, size.y / texture_size.y)
	var target_size: Vector2 = texture_size * ratio
	draw_texture_rect(supplied_texture, Rect2((size - target_size) / 2, target_size), false)
