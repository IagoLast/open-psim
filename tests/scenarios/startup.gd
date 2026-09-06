extends RefCounted

static func build_economy(sim: Variant) -> void:
	for order: Dictionary in [
		{"type":"build","kind":"farm","x":14,"z":15},
		{"type":"build","kind":"lumber","x":10,"z":23},
		{"type":"build","kind":"fishery","x":28,"z":17},
		{"type":"build","kind":"saltery","x":25,"z":17}
	]:
		assert(sim.apply_command(order).ok)
	var path: Array = []
	for x: int in range(10,19): path.append(19 * 40 + x)
	for z: int in range(20,23): path.append(z * 40 + 18)
	for x: int in range(17,9,-1): path.append(22 * 40 + x)
	assert(sim.apply_command({"type":"road","cells":path}).ok)
	assert(sim.apply_command({"type":"trade","direction":"buy","resource":"salt","quantity":10}).ok)
