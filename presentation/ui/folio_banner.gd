extends Control
## A single original painted navigation desk, cropped as a quiet panel masthead.
var artwork: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/chrome/merchant-chart.png"):
		artwork = load("res://assets/ui/chrome/merchant-chart.png")
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if artwork != null:
		var extent: Vector2 = artwork.get_size()
		var crop_height: float = minf(extent.y,extent.x*size.y/maxf(size.x,1))
		var tint := Color(1,1,1,0.24)
		draw_texture_rect_region(artwork,Rect2(Vector2.ZERO,size),Rect2(0,(extent.y-crop_height)*0.5,extent.x,crop_height),tint)
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.96,0.89,0.73,0.2))
	draw_line(Vector2(0,size.y-1),Vector2(size.x,size.y-1),Color("#ac8857"),2)
