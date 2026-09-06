extends RefCounted
## Opt-in read-only browser verification. No commands or alternate simulation.
var enabled: bool = false

func _init() -> void:
	if OS.has_feature("web"):
		enabled = bool(JavaScriptBridge.eval("location.search.includes('verify')",true))

func publish(main: Node) -> void:
	if not enabled: return
	var controls: Array = []
	_controls(main,controls)
	var cells: Array = []
	for cell: int in range(1600):
		var point: Vector2 = main.world.camera.unproject_position(Vector3(cell%40+0.5,0,cell/40+0.5))
		cells.append([point.x,point.y])
	var data: Dictionary = {"state":main.snapshot,"controls":controls,"cells":cells,"fps":Engine.get_frames_per_second(),"tick_usec":main.runner.tick_usec,"speed":main.runner.speed,"message":main.hud.message_label.text}
	JavaScriptBridge.eval("window.psimProbe = " + JSON.stringify(data) + ";",true)

func _controls(node: Node, found: Array) -> void:
	if node is Button and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		found.append({"text":node.text,"x":rect.get_center().x,"y":rect.get_center().y})
	for child: Node in node.get_children(): _controls(child,found)
