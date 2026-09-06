extends Control
## Every illustration comes from the same Blender models used by the world.
var kind: String = "house"
var supplied_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = "res://assets/ui/%s.png" % kind
	if not ResourceLoader.exists(path):
		push_error("Falta la ilustración Blender: " + path)
		return
	supplied_texture = load(path) as Texture2D
	if supplied_texture == null: push_error("Ilustración Blender inválida: " + path)
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if supplied_texture == null: return
	var texture_size: Vector2 = supplied_texture.get_size()
	var ratio: float = minf(size.x / texture_size.x, size.y / texture_size.y)
	var target_size: Vector2 = texture_size * ratio
	draw_texture_rect(supplied_texture, Rect2((size - target_size) / 2, target_size), false)
