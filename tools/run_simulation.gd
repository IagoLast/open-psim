extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ticks: int = 10000
	var seed_value: int = 1530
	for i: int in range(args.size() - 1):
		if args[i] == "--ticks": ticks = int(args[i + 1])
		if args[i] == "--seed": seed_value = int(args[i + 1])
	var sim := preload("res://sim/simulation.gd").new()
	sim.create(seed_value, preload("res://adapters/definitions.gd").load_data())
	preload("res://tests/scenarios/startup.gd").build_economy(sim)
	for i: int in range(maxi(0, ticks)): sim.step()
	print(JSON.stringify({"tick":sim.state.tick,"population":sim.state.citizens.size(),"inventory":sim.state.inventory,"coins":sim.state.coins,"jobs":sim.state.citizens.map(func(c: Dictionary) -> int: return c.job),"milestones":sim.state.milestones}))
	quit()
