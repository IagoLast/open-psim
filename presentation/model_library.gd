extends RefCounted
## Blender is the only source of visible models. Instances share meshes/materials.
const Variants = preload("res://presentation/model_variants.gd")
static var scenes: Dictionary = {}
static var bounds: Dictionary = {}

static func create_variant(kind: String, world_seed: int, identity: String, rotation: float = 0.0, footprint: Vector2 = Vector2.ZERO) -> Node3D:
	return create(Variants.choose(kind, world_seed, identity), rotation, footprint)

static func create(kind: String, rotation: float = 0.0, footprint: Vector2 = Vector2.ZERO, tile: bool = false) -> Node3D:
	var path: String = "res://assets/models/%s.glb" % kind
	if not scenes.has(kind):
		if not ResourceLoader.exists(path):
			push_error("Falta el modelo Blender: " + path)
			return null
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			push_error("Modelo Blender inválido: " + path)
			return null
		scenes[kind] = scene
	var model: Node3D = scenes[kind].instantiate() as Node3D
	if model == null:
		push_error("El modelo debe tener una raíz Node3D: " + path)
		return null
	var holder := Node3D.new()
	holder.name = "Model"
	holder.add_child(model)
	if not bounds.has(kind):
		var boxes: Array[AABB] = []
		_collect_bounds(model, Transform3D.IDENTITY, boxes)
		if boxes.is_empty():
			push_error("Modelo Blender sin geometría: " + path)
			holder.free()
			return null
		var merged: AABB = boxes[0]
		for index: int in range(1, boxes.size()): merged = merged.merge(boxes[index])
		bounds[kind] = merged
	var box: AABB = bounds[kind]
	# Fit buildings uniformly so roof pitches and proportions survive import.
	# Trees, boats and people keep their authored natural size.
	var fit_scale := Vector3.ONE
	if footprint != Vector2.ZERO:
		var fit: float = minf(footprint.x / maxf(box.size.x, 0.001), footprint.y / maxf(box.size.z, 0.001))
		fit_scale = Vector3.ONE * fit
		if tile: fit_scale = Vector3(footprint.x / box.size.x, 1.0, footprint.y / box.size.z)
	model.scale *= fit_scale
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit_scale
	holder.rotation.y = rotation
	holder.set_meta("model_kind", kind)
	holder.set_meta("model_height", box.size.y * fit_scale.y)
	return holder

static func _collect_bounds(node: Node3D, parent_transform: Transform3D, output: Array[AABB]) -> void:
	var transform: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		output.append(transform * node.get_aabb())
	for child: Node in node.get_children():
		if child is Node3D: _collect_bounds(child, transform, output)
