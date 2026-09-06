extends RefCounted

static func load_data() -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["buildings", "resources", "balance", "history", "ports"]:
		var file := FileAccess.open("res://data/%s.json" % key, FileAccess.READ)
		if file == null:
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed == null:
			return {}
		result[key] = _integers(parsed)
	if result.resources.is_empty() or result.buildings.is_empty() or result.ports.is_empty():
		return {}
	for definition: Dictionary in result.buildings.values():
		for field: String in ["size", "coins", "wood", "jobs"]:
			if not definition.has(field) or not definition[field] is int or definition[field] < 0:
				return {}
	for field: String in ["ticks_per_day", "ticks_per_second", "move_ticks", "inventory_capacity", "labor_interval"]:
		if not result.balance.get(field, 0) is int or result.balance.get(field, 0) <= 0:
			return {}
	return result

static func _integers(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_integers(item))
		return items
	if value is Dictionary:
		var items: Dictionary = {}
		for key: Variant in value:
			items[key] = _integers(value[key])
		return items
	return value
