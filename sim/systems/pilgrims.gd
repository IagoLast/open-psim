extends RefCounted

static func daily(sim: Variant) -> void:
	var day: int = sim.state.tick/sim.definitions.balance.ticks_per_day
	if day % sim.definitions.scenario.pilgrim_interval_days != 0: return
	for inn: Dictionary in sim.state.buildings:
		if inn.type != "inn" or not inn.service_active: continue
		var guests: int = sim.state.pilgrims.filter(func(p: Dictionary) -> bool: return p.inn == inn.id and p.phase != "leaving").size()
		var beds: int = sim.definitions.buildings.inn.beds
		for i: int in range(mini(2,beds-guests)):
			sim.state.pilgrims.append({"id":sim.state.next_pilgrim,"inn":inn.id,"cell":sim.Map.entrance(),"phase":"arriving","stay":0,"served":false,"route":[],"route_version":-1})
			sim.state.next_pilgrim += 1

static func step(sim: Variant) -> void:
	if sim.state.tick % sim.definitions.balance.move_ticks != 0: return
	for p: Dictionary in sim.state.pilgrims.duplicate():
		var inn: Dictionary = sim.building(p.inn)
		if inn.is_empty() or not inn.service_active: p.phase = "leaving"
		if p.phase == "staying":
			p.stay += sim.definitions.balance.move_ticks
			if p.stay >= sim.definitions.balance.ticks_per_day:
				var reserve: int = sim.state.citizens.size()*sim.definitions.scenario.reserve_days
				if sim.Economy.food(sim) > reserve:
					for resource: String in ["bread","grain","fish"]:
						if sim.state.inventory[resource] > 0:
							sim.state.inventory[resource] -= 1
							sim.Economy.record_flow(sim,"consumption",resource,1)
							break
					p.served = true
					sim.state.coins += 4
					sim.state.operating += 4
				p.phase = "leaving"
				p.route_version = -1
			continue
		var destination: int = sim.Map.exit_cell() if p.phase == "leaving" else inn.access
		if p.cell == destination:
			if p.phase == "arriving":
				p.phase = "staying"
				p.route_version = -1
			else:
				if p.served:
					sim.state.pilgrims_served += 1
					sim.state.reputation = mini(100,sim.state.reputation+1)
				sim.state.pilgrims.erase(p)
			continue
		if p.route_version != sim.topology:
			p.route = sim.Paths.route(p.cell,destination,sim.roads,sim.width())
			p.route_version = sim.topology
		if not p.route.is_empty(): p.cell = p.route.pop_front()
