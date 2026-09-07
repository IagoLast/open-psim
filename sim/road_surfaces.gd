extends RefCounted
const TOOLS: Dictionary = {"road":"paved","road_dirt":"dirt"}
const LABELS: Dictionary = {"road":"Camino pavimentado","road_dirt":"Camino de tierra"}

static func at(state: Dictionary, cell: int) -> String:
	return state.get("road_surfaces",{}).get(str(cell),"paved")

static func model(surface: String) -> String:
	return "road_dirt" if surface == "dirt" else "road"
