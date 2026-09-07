extends RefCounted
const Models = preload("res://presentation/model_library.gd")
const HOUSE_VARIANTS: Array[String] = ["house", "house_cottage", "house_tall"]
const LIMBS: Array[String] = ["LegL", "LegR", "ArmL", "ArmR"]

static var materials: Dictionary = {}
static var meshes: Dictionary = {}

static func material(color: Color) -> StandardMaterial3D:
	if materials.has(color): return materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials[color] = mat
	return mat

## Shared primitives also provide labelled prototypes for new buildings.
static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh
	if meshes.has(size): mesh = meshes[size]
	else:
		mesh = BoxMesh.new()
		mesh.size = size
		meshes[size] = mesh
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = at
	parent.add_child(instance)
	return instance

static func label(parent: Node3D, text: String, at: Vector3, font_size: int = 32) -> Label3D:
	var item := Label3D.new()
	item.text = text
	item.font_size = font_size
	item.pixel_size = 0.018
	item.outline_size = 6
	item.modulate = Color("#fff3d8")
	item.outline_modulate = Color("#5e5143")
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.no_depth_test = true
	item.position = at
	parent.add_child(item)
	return item

static func building(kind: String, size: Variant, id: int, title: String, world_seed: int = 1530, identity: String = "", context: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	var extent: Vector2 = Vector2(size,size) if size is int else Vector2(size)
	var s: float = extent.x
	var depth: float = extent.y
	var model_kind: String = context.get("model_family","house_cottage") if kind == "house" else kind
	# Preserve the three established silhouettes; finite detail catalogues are optional.
	model_kind = Models.Variants.choose(model_kind,world_seed,identity if not identity.is_empty() else str(id))
	var front: int = context.get("front",2)
	var orientation: float = (front+2)*PI*0.5
	var fit_extent: Vector2 = Vector2(depth,s) if front%2 else extent
	var joined: int = context.get("adjoined",0)
	var context_family: String = model_kind+"_joined_%d" % joined
	if joined > 0 and Models.Variants.catalog.families.has(context_family): model_kind = Models.Variants.choose(context_family,world_seed,identity)
	var prototype: bool = not ResourceLoader.exists("res://assets/models/%s.glb" % model_kind)
	var model: Node3D = null if prototype else Models.create(model_kind, orientation, fit_extent - Vector2.ONE*0.06)
	root.set_meta("placeholder",prototype)
	var height: float = 2.0
	if model != null:
		root.add_child(model)
		model.position = Vector3(s / 2.0, 0.015, depth / 2.0)
		height = model.get_meta("model_height")
	if prototype:
		height = 1.2
		var color: Color = Color.from_hsv(float(posmod(kind.hash(),360))/360.0,0.30,0.72)
		box(root,Vector3(s-0.12,height,depth-0.12),Vector3(s/2.0,height/2,depth/2.0),color)
	root.set_meta("front",front)
	root.set_meta("adjoined",joined)
	root.set_meta("model_family",context.get("model_family",kind))
	if context.get("ruined",false):
		if model != null: model.scale.y = 0.25
		height *= 0.25
	if int(context.get("burn_days",0)) > 0:
		for i: int in range(3):
			box(root,Vector3(0.18,0.65+i*0.14,0.18),Vector3(s/2.0+(i-1)*0.24,height+0.1,depth/2.0),Color("#ed852d"))
	var name_label: Label3D = label(root, title, Vector3(s / 2.0, height + 0.55, depth / 2.0), 26)
	name_label.name = "Title"
	name_label.visible = prototype
	var status: Label3D = label(root, "", Vector3(s / 2.0, height + 0.22, depth / 2.0), 23)
	status.name = "Status"
	status.hide()
	var workers: Label3D = label(root,"●",Vector3(s/2.0,height+0.30,depth/2.0),22)
	workers.name = "Workers"
	workers.hide()
	return root

static func scenery(kind: String, angle: float = 0.0, scale_value: float = 1.0) -> Node3D:
	var model: Node3D = Models.create(kind, angle)
	if model != null: model.scale = Vector3.ONE * scale_value
	return model

static func road(surface: String = "paved") -> Node3D:
	return Models.create(preload("res://sim/road_surfaces.gd").model(surface), 0.0, Vector2.ONE * 0.98, true)

static func citizen(id: int) -> Node3D:
	var root: Node3D = Models.create("citizen")
	if root == null: return null
	root.name = "Citizen%d" % id
	var limbs: Dictionary = {}
	for limb_name: String in LIMBS:
		var limb: Node3D = root.find_child(limb_name, true, false) as Node3D
		if limb == null: push_error("Citizen Blender sin pivote: " + limb_name)
		else: limbs[limb_name] = limb
	root.set_meta("limbs", limbs)
	return root
