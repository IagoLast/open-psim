extends RefCounted

static func total(inventory: Dictionary) -> int:
	var count: int = 0
	for value: int in inventory.values(): count += value
	return count

static func reserved(sim: Variant) -> int:
	var amount: int = 0
	for voyage: Dictionary in sim.state.voyages:
		if voyage.direction == "buy": amount += voyage.quantity
	return amount

static func capacity(sim: Variant) -> int:
	var amount: int = sim.definitions.balance.inventory_capacity
	for item: Dictionary in sim.state.buildings:
		if item.connected: amount += sim.definitions.buildings[item.type].get("storage",0)
	return amount

static func physical_capacity(sim: Variant) -> int:
	var amount: int = sim.definitions.balance.inventory_capacity
	for item: Dictionary in sim.state.buildings: amount += sim.definitions.buildings[item.type].get("storage",0)
	return amount

static func food(sim: Variant) -> int:
	return sim.state.inventory.grain + sim.state.inventory.fish + sim.state.inventory.bread

static func recipe_error(sim: Variant, definition: Dictionary) -> String:
	for resource: String in definition.inputs:
		if sim.state.inventory[resource] < definition.inputs[resource]:
			return "Falta " + sim.definitions.resources[resource].label.to_lower()
	if definition.inputs.has("fish") and not definition.outputs.has("bread"):
		if food(sim) - definition.inputs.fish < sim.state.citizens.size() * sim.definitions.balance.reserve_days:
			return "Reserva alimentaria protegida"
	if total(sim.state.inventory) - total(definition.inputs) + total(definition.outputs) + reserved(sim) > capacity(sim):
		return "Almacén lleno"
	return ""

static func produce(sim: Variant) -> void:
	for item: Dictionary in sim.state.buildings:
		var definition: Dictionary = sim.definitions.buildings[item.type]
		if definition.jobs == 0 or definition.has("service"): continue
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
	if sim.state.trade_completed >= 1: achieved.append("Primera travesía completada")
	if sim.state.exported >= 10: achieved.append("Diez unidades exportadas")
	var supplied: int = 0
	for citizen: Dictionary in sim.state.citizens:
		if citizen.fed and citizen.water: supplied += 1
	if supplied >= 20: achieved.append("Veinte habitantes abastecidos")
	for resource: String in ["tools","wine","cloth","pottery","bread"]:
		if sim.state.inventory[resource] > 0: achieved.append("Recurso: " + sim.definitions.resources[resource].label)
	for home: Dictionary in sim.state.buildings:
		if home.type == "house" and home.level >= 2: achieved.append("Barrio próspero")
		if home.type == "house" and home.level >= 3: achieved.append("Villa mercantil")
	for title: String in achieved:
		if not sim.state.milestones.has(title): sim.state.milestones.append(title)
