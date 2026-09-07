extends SceneTree
## Validate every Blender render consumed by the HUD, including tool buttons.
const Variants = preload("res://presentation/model_variants.gd")
const ICONS: Array[String] = [
	"grain", "wood", "fish", "salt", "salted_fish", "coins", "population", "happiness",
	"category_housing", "category_services", "category_food", "category_materials",
	"select", "demolish"
]
const BUILDINGS: Array[String] = ["house", "road", "road_dirt", "well", "farm", "lumber", "fishery", "saltery", "horreo"]
const COLLECTION: Array[String] = ["house_cottage", "house_tall", "warehouse", "sailboat", "rowboat", "tree_oak", "tree_cypress", "citizen", "tree_pine", "bridge_stone", "rock_cluster", "grass_clump", "wildflowers", "reeds", "gorse"]

func _initialize() -> void:
	var failures: int = 0
	var names: Array[String] = ICONS + BUILDINGS + COLLECTION
	for kind: String in preload("res://adapters/definitions.gd").load_data().buildings:
		if not names.has(kind): names.append(kind)
	for kind: String in Variants.catalog.models: names.append(kind)
	for file_name: String in DirAccess.get_files_at("res://assets/ui"):
		if file_name.get_extension() == "png" and file_name.get_basename() not in names:
			printerr("UNLISTED ILLUSTRATION ", file_name)
			failures += 1
	for kind: String in names:
		var path: String = "res://assets/ui/%s.png" % kind
		if not ResourceLoader.exists(path):
			printerr("MISSING ", path)
			failures += 1
			continue
		var texture: Texture2D = load(path) as Texture2D
		var expected: int = 256 if kind in ICONS else 512
		if texture == null or texture.get_width() != expected or texture.get_height() != expected:
			printerr("SIZE ", path, " expected ", expected)
			failures += 1
			continue
		var image: Image = texture.get_image()
		if image.is_compressed(): image.decompress()
		var bounds: Rect2i = image.get_used_rect()
		var transparent_corners: bool = true
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(expected - 1, 0), Vector2i(0, expected - 1), Vector2i.ONE * (expected - 1)]:
			if image.get_pixelv(corner).a > 0.01: transparent_corners = false
		if bounds.size.x < expected / 4 or bounds.size.y < expected / 4 or not transparent_corners:
			printerr("ALPHA / EMPTY ", path, " bounds ", bounds)
			failures += 1
			continue
		if bounds.position.x < 2 or bounds.position.y < 2 or bounds.end.x > expected - 2 or bounds.end.y > expected - 2:
			printerr("CLIPPED ", path, " bounds ", bounds)
			failures += 1
			continue
		print("OK ", kind, " ", texture.get_size(), " alpha; bounds ", bounds)
	print("UI ASSETS: ", names.size() - failures, "/", names.size(), " (", ICONS.size() + BUILDINGS.size(), " consumed by the HUD)")
	quit(1 if failures > 0 else 0)
