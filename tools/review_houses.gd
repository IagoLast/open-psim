extends SceneTree
## Actual GLB catalogue at gameplay scale, selected through AssetFactory by identity.
const Assets = preload("res://presentation/asset_factory.gd")
const Models = preload("res://presentation/model_library.gd")
var stage: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1536,1024)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#f3e5c5")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#e8e7e0")
	settings.ambient_light_energy = 0.50
	env.environment = settings
	stage.add_child(env)
	for config: Vector3 in [Vector3(-50,-35,0.30),Vector3(-35,145,0.12)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(config.x,config.y,0)
		light.light_energy = config.z
		light.shadow_enabled = config.z > 0.2
		light.shadow_opacity = 0.32
		stage.add_child(light)
	var families: Array[String] = ["house_cottage","house","house_tall"]
	var right := Vector3(1,0,-1).normalized()
	var back := Vector3(-1,0,-1).normalized()
	for row: int in range(3):
		var family: String = families[row]
		var names: Array = Models.Variants.options(family)
		for col: int in range(1,names.size()):
			var name: String = names[col]
			var identity: String = ""
			for i: int in range(4096):
				if Models.Variants.choose(family,1530,str(i)) == name:
					identity = str(i)
					break
			assert(not identity.is_empty(),"Unreachable housing variant " + name)
			var house: Node3D = Assets.building("house",2,col,name,1530,identity,{"model_family":family,"front":2})
			assert(house.get_node("Model").get_meta("model_kind") == name)
			house.position = right * (col-2)*3.2 + back * (1-row)*3.7 - Vector3(1,0,1)
			stage.add_child(house)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.8
	stage.add_child(camera)
	camera.position = Vector3(12,15,12)
	camera.look_at(Vector3(0,.8,0))
	for i: int in range(12): await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://art/renders/house-variants-godot.png")
	print("HOUSING REVIEW: 9 catalogue variants selected through AssetFactory, 2x2 plots")
	stage.queue_free()
	await process_frame
	quit()
