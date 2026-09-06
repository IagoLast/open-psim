extends RefCounted

static func total(inventory: Dictionary) -> int:
	var count: int = 0
	for value: int in inventory.values(): count += value
	return count

static func validate_trade(sim: Variant, command: Dictionary) -> Dictionary:
	var resource: String = command.get("resource", "")
	var direction: String = command.get("direction", "")
	if not sim.definitions.resources.has(resource) or direction not in ["buy", "sell"]: return sim.result("Operación no permitida")
	var quantity: Variant = command.get("quantity")
	if not quantity is int or quantity <= 0 or quantity > 500: return sim.result("Cantidad entera positiva, máximo 500")
	var price: int = sim.definitions.resources[resource][direction]
	if price < 0: return sim.result("Operación no permitida")
	if direction == "buy":
		if sim.state.coins < price * quantity: return sim.result("Monedas insuficientes")
		if total(sim.state.inventory) + quantity > sim.definitions.balance.inventory_capacity: return sim.result("Almacén lleno")
	elif sim.state.inventory[resource] < quantity: return sim.result("Existencias insuficientes")
	return sim.result()

static func trade(sim: Variant, command: Dictionary) -> void:
	var sign_value: int = 1 if command.direction == "buy" else -1
	sim.state.inventory[command.resource] += sign_value * command.quantity
	sim.state.coins -= sign_value * command.quantity * sim.definitions.resources[command.resource][command.direction]
	if command.direction == "sell" and command.resource == "salted_fish": sim.state.exported += command.quantity
	milestones(sim)

static func recipe_error(sim: Variant, definition: Dictionary) -> String:
	for resource: String in definition.inputs:
		if sim.state.inventory[resource] < definition.inputs[resource]:
			return "Falta " + sim.definitions.resources[resource].label.to_lower()
	if definition.inputs.has("fish"):
		if sim.state.inventory.grain + sim.state.inventory.fish - definition.inputs.fish < sim.state.citizens.size() * sim.definitions.balance.reserve_days:
			return "Reserva alimentaria protegida"
	if total(sim.state.inventory) - total(definition.inputs) + total(definition.outputs) > sim.definitions.balance.inventory_capacity:
		return "Almacén lleno"
	return ""

static func produce(sim: Variant) -> void:
	for item: Dictionary in sim.state.buildings:
		var definition: Dictionary = sim.definitions.buildings[item.type]
		if definition.jobs == 0: continue
		var block: String = ""
		if not item.active: block = "Desactivado"
		elif not item.connected: block = "Sin camino al almacén"
		elif not sim.terrain_error(item.type, item.x, item.z).is_empty(): block = sim.terrain_error(item.type, item.x, item.z)
		elif item.assigned == 0: block = "0/%d trabajadores" % definition.jobs
		elif item.present == 0: block = "Trabajadores de camino" if sim.state.tick % sim.definitions.balance.ticks_per_day < sim.definitions.balance["return"] else "Jornada terminada"
		else: block = recipe_error(sim, definition)
		if block.is_empty():
			item.work = mini(definition.work, item.work + item.present)
			if item.work >= definition.work:
				# Space includes freed inputs. Commit all inputs and outputs exactly once.
				for resource: String in definition.inputs: sim.state.inventory[resource] -= definition.inputs[resource]
				for resource: String in definition.outputs: sim.state.inventory[resource] += definition.outputs[resource]
				item.produced += total(definition.outputs)
				item.work -= definition.work
		if block != item.block:
			item.block = block
			if not block.is_empty():
				sim.state.alerts.append("%s: %s" % [definition.label, block])
				if sim.state.alerts.size() > 6: sim.state.alerts.pop_front()

static func milestones(sim: Variant) -> void:
	var achieved: Array = []
	for item: Dictionary in sim.state.buildings:
		if item.type == "farm" and item.produced > 0: achieved.append("Granja en marcha")
		if item.type == "fishery" and item.assigned > 0: achieved.append("Empleo pesquero")
		if item.type == "saltery" and item.produced > 0: achieved.append("Primera sardina salada")
	if sim.state.exported >= 10: achieved.append("Diez unidades exportadas")
	var supplied: int = 0
	for citizen: Dictionary in sim.state.citizens:
		if citizen.fed and citizen.water: supplied += 1
	if supplied >= 20: achieved.append("Veinte habitantes abastecidos")
	for title: String in achieved:
		if not sim.state.milestones.has(title): sim.state.milestones.append(title)
