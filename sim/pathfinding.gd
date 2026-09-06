extends RefCounted

static func neighbors(cell: int, width: int = 40) -> Array[int]:
	var result: Array[int] = []
	if cell >= width: result.append(cell - width)
	if cell % width > 0: result.append(cell - 1)
	if cell % width < width - 1: result.append(cell + 1)
	if cell < width * (width - 1): result.append(cell + width)
	return result

static func distances(start: int, roads: Dictionary) -> Dictionary:
	if start < 0: return {}
	var found: Dictionary = {start: 0}
	var queue: Array[int] = [start]
	var index: int = 0
	while index < queue.size():
		var cell: int = queue[index]
		index += 1
		for next: int in neighbors(cell):
			if roads.has(next) and not found.has(next):
				found[next] = found[cell] + 1
				queue.append(next)
	return found

static func route(start: int, goal: int, roads: Dictionary) -> Array:
	if start == goal: return []
	if start < 0 or goal < 0: return []
	var previous: Dictionary = {start: -1}
	var queue: Array[int] = [start]
	var index: int = 0
	while index < queue.size():
		var cell: int = queue[index]
		index += 1
		for next: int in neighbors(cell):
			if not roads.has(next) or previous.has(next): continue
			previous[next] = cell
			if next == goal:
				var result: Array = [goal]
				var cursor: int = cell
				while cursor != start:
					result.push_front(cursor)
					cursor = previous[cursor]
				return result
			queue.append(next)
	return []
