extends RefCounted

var speed: int = 0
var accumulator: float = 0.0
var tick_usec: int = 0
var slowed: bool = false

func advance(sim: Variant, delta: float) -> int:
	if speed == 0:
		accumulator = 0.0
		return 0
	accumulator += minf(delta, 0.25) * speed
	var interval: float = 1.0 / sim.definitions.balance.ticks_per_second
	var count: int = 0
	while accumulator >= interval and count < 8:
		var started: int = Time.get_ticks_usec()
		sim.step()
		tick_usec = Time.get_ticks_usec() - started
		accumulator -= interval
		count += 1
	slowed = accumulator >= interval
	accumulator = minf(accumulator, interval * 8)
	return count
