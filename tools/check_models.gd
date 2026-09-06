extends SceneTree
## Validate the actual imported Blender scenes and their in-game placement.
const Models = preload("res://presentation/model_library.gd")
const Assets = preload("res://presentation/asset_factory.gd")
const FOOTPRINTS: Dictionary = {
	"house": 2.0, "house_cottage": 2.0, "house_tall": 2.0,
	"road": 1.0, "well": 1.0, "farm": 4.0, "lumber": 2.0,
	"fishery": 2.0, "saltery": 2.0, "warehouse": 3.0,
	"sailboat": 0.0, "rowboat": 0.0, "tree_oak": 0.0,
	"tree_cypress": 0.0, "citizen": 0.0,
	"wood": 0.0, "grain": 0.0, "fish": 0.0, "salt": 0.0,
	"salted_fish": 0.0, "coins": 0.0, "population": 0.0, "happiness": 0.0
}
var failures: int = 0

func _initialize() -> void:
	for file_name: String in DirAccess.get_files_at("res://assets/models"):
		if file_name.get_extension() == "glb" and not FOOTPRINTS.has(file_name.get_basename()):
			fail("UNLISTED MODEL " + file_name)
	for kind: String in FOOTPRINTS:
		check_model(kind)
	check_citizen()
	check_house_variants()
	print("MODELS: ", FOOTPRINTS.size(), " checked; ", failures, " failures")
	quit(1 if failures > 0 else 0)

func check_model(kind: String) -> void:
	var path: String = "res://assets/models/%s.glb" % kind
	if not ResourceLoader.exists(path):
		fail("MISSING " + path)
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		fail("INVALID SCENE " + path)
		return
	var raw: Node3D = scene.instantiate() as Node3D
	if raw == null:
		fail("INVALID ROOT " + path)
		return
	var stats: Dictionary = {"meshes": 0, "triangles": 0, "boxes": []}
	collect(raw, Transform3D.IDENTITY, stats)
	if stats.meshes == 0 or stats.triangles == 0:
		fail("EMPTY " + path)
		raw.free()
		return
	var bound: AABB = merge_bounds(stats.boxes)
	if not valid_bounds(bound): fail("INVALID BOUNDS %s %s" % [kind, bound])
	var budget: int = 20000
	if kind.begins_with("tree_"): budget = 2500
	if kind in ["sailboat", "rowboat"]: budget = 6000
	if kind == "citizen": budget = 1500
	if kind == "road": budget = 1000
	if stats.triangles > budget: fail("TRIANGLE BUDGET %s %d > %d" % [kind, stats.triangles, budget])
	if kind != "citizen" and stats.meshes > 4:
		fail("STATIC MESHES %s has %d mesh nodes; join geometry before export" % [kind, stats.meshes])
	var width: float = FOOTPRINTS[kind]
	var footprint: Vector2 = Vector2.ONE * (width - (0.02 if kind == "road" else 0.06)) if width > 0.0 else Vector2.ZERO
	var placed: Node3D = Models.create(kind, 0.0, footprint, kind == "road")
	if placed == null:
		fail("PLACEMENT " + kind)
	else:
		var placed_stats: Dictionary = {"meshes": 0, "triangles": 0, "boxes": []}
		collect(placed, Transform3D.IDENTITY, placed_stats)
		var actual: AABB = merge_bounds(placed_stats.boxes)
		if absf(actual.position.y) > 0.001 or absf(actual.get_center().x) > 0.001 or absf(actual.get_center().z) > 0.001:
			fail("GROUND / CENTER %s %s" % [kind, actual])
		if width > 0.0:
			if actual.size.x > footprint.x + 0.001 or actual.size.z > footprint.y + 0.001:
				fail("FOOTPRINT %s %s" % [kind, actual.size])
			if kind != "road" and not is_equal_approx(actual.size.x / bound.size.x, actual.size.y / bound.size.y):
				fail("DISTORTED HEIGHT " + kind)
		elif not actual.size.is_equal_approx(bound.size):
			fail("NATURAL SCALE " + kind)
		placed.free()
	print("MODEL ", kind, ": ", stats.meshes, " meshes, ", stats.triangles, " triangles; bounds ", bound.size)
	raw.free()

func check_citizen() -> void:
	if not ResourceLoader.exists("res://assets/models/citizen.glb"): return
	var citizen: Node3D = Assets.citizen(1)
	if citizen == null:
		fail("CITIZEN INSTANCE")
		return
	var limbs: Dictionary = citizen.get_meta("limbs")
	for name_value: String in Assets.LIMBS:
		if not limbs.has(name_value):
			fail("CITIZEN PIVOT " + name_value)
			continue
		var limb: Node3D = limbs[name_value]
		var initial: Transform3D = limb.transform
		var resting: Dictionary = {"meshes": 0, "triangles": 0, "boxes": []}
		collect(limb, Transform3D.IDENTITY, resting)
		if resting.meshes == 0:
			fail("CITIZEN LIMB WITHOUT GEOMETRY " + name_value)
			continue
		limb.rotation.x = 0.5
		var moving: Dictionary = {"meshes": 0, "triangles": 0, "boxes": []}
		collect(limb, Transform3D.IDENTITY, moving)
		if merge_bounds(moving.boxes).is_equal_approx(merge_bounds(resting.boxes)):
			fail("CITIZEN ANIMATION DOES NOT MOVE GEOMETRY " + name_value)
		limb.transform = initial
	citizen.free()

func check_house_variants() -> void:
	var seen: Dictionary = {}
	for id: int in range(3):
		if not ResourceLoader.exists("res://assets/models/%s.glb" % Assets.HOUSE_VARIANTS[id]): return
		var building: Node3D = Assets.building("house", 2, id, "Vivienda")
		var model: Node3D = building.get_node_or_null("Model") as Node3D
		if model == null: fail("HOUSE VARIANT %d" % id)
		else: seen[model.get_meta("model_kind")] = true
		building.free()
	if seen.size() != 3: fail("HOUSE VARIANTS are not all used")

func collect(node: Node3D, parent_transform: Transform3D, stats: Dictionary) -> void:
	var transform: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		stats.meshes += 1
		stats.boxes.append(transform * node.get_aabb())
		for surface: int in range(node.mesh.get_surface_count()):
			if node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				fail("NON-TRIANGLE SURFACE " + str(node.name))
				continue
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			stats.triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	for child: Node in node.get_children():
		if child is Node3D: collect(child, transform, stats)

func merge_bounds(boxes: Array) -> AABB:
	var merged: AABB = boxes[0]
	for index: int in range(1, boxes.size()): merged = merged.merge(boxes[index])
	return merged

func valid_bounds(bound: AABB) -> bool:
	return bound.position.is_finite() and bound.size.is_finite() and bound.size.x > 0.001 and bound.size.y > 0.001 and bound.size.z > 0.001 and bound.size.x < 10.0 and bound.size.y < 10.0 and bound.size.z < 10.0

func fail(message: String) -> void:
	failures += 1
	printerr(message)
