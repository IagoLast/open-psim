extends RefCounted
## Pure visual selection: no simulation RNG, no runtime mesh/material mutations.
## Keep selection v1 stable. Canonical names and old saves require no migration.
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/model_variants.json"))

static func stable_seed(world_seed: int, identity: String, channel: String) -> int:
	# Specified FNV-1a/32; no engine-dependent String.hash or float arithmetic.
	var value: int = 2166136261
	for byte: int in ("visual-v1|%d|%s|%s" % [world_seed,identity,channel]).to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & 0xffffffff
	return value

static func family(kind: String) -> String:
	return catalog.models[kind].family if catalog.models.has(kind) else kind

static func options(kind: String) -> Array:
	return catalog.families.get(kind, [kind])

static func choose(kind: String, world_seed: int, identity: String) -> String:
	# Rendezvous ranking is independent of catalogue order and iteration order.
	var selected: String = kind
	var best: int = -1
	for candidate: String in options(kind):
		var score: int = stable_seed(world_seed, identity, kind+"/"+candidate)
		if score > best or (score == best and candidate < selected):
			best = score
			selected = candidate
	return selected
