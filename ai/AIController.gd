extends Node
class_name AIController
## A small scripted opponent: keeps villagers gathering, expands houses,
## builds farms and a barracks, trains an army, then attack-moves once
## strong enough. Reads each player's civ_data() (bonuses, not hardcoded
## civ ids) so the same script adapts its economy/army targets and farm
## placement to whichever civilization it's been assigned.

var player_id: int = 1
var world_root: Node2D

var think_interval: float = 2.0
var _timer: float = 0.0


func setup(p_world_root: Node2D, p_player_id: int) -> void:
	world_root = p_world_root
	player_id = p_player_id


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= think_interval:
		_timer = 0.0
		_think()


func _think() -> void:
	if GameManager.game_over:
		return
	var ps: PlayerState = GameManager.get_player(player_id)
	if not ps:
		return
	# `reserved` accumulates as higher-priority needs (villagers, housing,
	# barracks, farms) go unfunded this tick, so lower-priority spending
	# (discretionary army training) treats that portion of the stockpile as
	# untouchable instead of greedily spending every resource the instant
	# it arrives -- otherwise a big-ticket item like a Farm would never get
	# a chance to accumulate its cost.
	var reserved: Dictionary = {}
	_assign_idle_villagers(ps)
	_maybe_train_villager(ps, reserved)
	_maybe_build_house(ps, reserved)
	_maybe_build_barracks(ps, reserved)
	_maybe_build_farm(ps, reserved)
	_maybe_train_military(ps, reserved)
	_maybe_attack(ps)


## True if `cost` can still be paid after setting aside everything already
## reserved for higher-priority needs this tick.
func _can_afford_with_reserve(ps: PlayerState, cost: Dictionary, reserved: Dictionary) -> bool:
	for res_type in cost.keys():
		var available: float = ps.resources.get(res_type, 0.0) - reserved.get(res_type, 0.0)
		if available < cost[res_type]:
			return false
	return true


## Marks `cost` as spoken-for so nothing lower-priority spends it this tick.
func _reserve(reserved: Dictionary, cost: Dictionary) -> void:
	for res_type in cost.keys():
		reserved[res_type] = reserved.get(res_type, 0.0) + float(cost[res_type])


## Villager count the AI aims to keep training. Raid civs lean on combat
## income instead of a big workforce, so they can run leaner.
func _target_villagers(ps: PlayerState) -> int:
	var civ: Dictionary = ps.civ_data()
	if not civ.get("raid_bonus", {}).is_empty():
		return 6
	return 8


## How large an idle army has to get before the AI commits it to an attack.
## Raid civs send smaller, more frequent raiding parties (their income
## doesn't depend on winning a siege, just on landing hits); civs with a
## move-speed bonus can commit a bit sooner since they can disengage and
## regroup faster.
func _attack_threshold(ps: PlayerState) -> int:
	var civ: Dictionary = ps.civ_data()
	var threshold: float = 6.0
	if not civ.get("raid_bonus", {}).is_empty():
		threshold *= 0.5
	threshold /= float(civ.get("move_speed_bonus", 1.0))
	return max(3, int(round(threshold)))


func _assign_idle_villagers(ps: PlayerState) -> void:
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type == "villager" and u.state == RTSUnit.State.IDLE:
			var node = _find_nearest_resource(u.global_position)
			if node:
				u.order_gather(node)


func _find_nearest_resource(from_pos: Vector2):
	var best = null
	var best_d := INF
	for r in get_tree().get_nodes_in_group("resources") as Array:
		if not is_instance_valid(r):
			continue
		var d: float = from_pos.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


func _maybe_train_villager(ps: PlayerState, reserved: Dictionary) -> void:
	var tc = ps.town_center()
	if not tc:
		return
	var villager_count := 0
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type == "villager":
			villager_count += 1
	if villager_count >= _target_villagers(ps) or tc.train_queue.size() >= 2:
		return
	var cost: Dictionary = GameData.get_unit_stats("villager").get("cost", {})
	if _can_afford_with_reserve(ps, cost, reserved):
		tc.queue_train("villager")
	else:
		_reserve(reserved, cost)


func _maybe_build_house(ps: PlayerState, reserved: Dictionary) -> void:
	if ps.population_cap - ps.population_used > 2:
		return
	var cost: Dictionary = GameData.get_building_stats("house").get("cost", {})
	if _can_afford_with_reserve(ps, cost, reserved):
		_build_building(ps, "house")
	else:
		_reserve(reserved, cost)


func _maybe_build_barracks(ps: PlayerState, reserved: Dictionary) -> void:
	for b in ps.buildings:
		if is_instance_valid(b) and b.building_type == "barracks":
			return
	var cost: Dictionary = GameData.get_building_stats("barracks").get("cost", {})
	if _can_afford_with_reserve(ps, cost, reserved):
		_build_building(ps, "barracks")
	else:
		_reserve(reserved, cost)


## Keeps roughly one Farm per four villagers so food income scales with the
## workforce. Placement is biased toward a lake shore when this civ actually
## benefits from that (the Egyptian water bonus) -- otherwise it's just a
## normal spot near the Town Center, same as a House or Barracks.
func _maybe_build_farm(ps: PlayerState, reserved: Dictionary) -> void:
	var farm_count := 0
	var villager_count := 0
	for b in ps.buildings:
		if is_instance_valid(b) and b.building_type == "farm":
			farm_count += 1
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type == "villager":
			villager_count += 1
	var desired_farms: int = int(ceil(villager_count / 4.0))
	if farm_count >= desired_farms:
		return
	var cost: Dictionary = GameData.get_building_stats("farm").get("cost", {})
	if _can_afford_with_reserve(ps, cost, reserved):
		var tc = ps.town_center()
		var base_pos: Vector2 = tc.global_position if tc else Vector2.ZERO
		_build_building(ps, "farm", _pick_farm_position(ps, base_pos))
	else:
		_reserve(reserved, cost)


## Returns a build spot near the nearest lake shore if this civ has a
## water-gathering bonus for food and a lake exists; otherwise a normal
## random spot near `base_pos`, same style as House/Barracks placement.
func _pick_farm_position(ps: PlayerState, base_pos: Vector2) -> Vector2:
	var civ: Dictionary = ps.civ_data()
	if civ.get("water_gather_bonus", {}).has("food") and not GameManager.water_regions.is_empty():
		var best_region = null
		var best_d := INF
		for region in GameManager.water_regions:
			var d: float = base_pos.distance_to(region.center)
			if d < best_d:
				best_d = d
				best_region = region
		if best_region != null:
			var angle: float = randf() * TAU
			var dist_from_center: float = best_region.radius + GameManager.WATER_PROXIMITY_MARGIN * 0.5
			return best_region.center + Vector2(cos(angle), sin(angle)) * dist_from_center
	return base_pos + Vector2(randf_range(-160, 160), randf_range(-160, 160))


func _build_building(ps: PlayerState, building_type: String, pos_override: Vector2 = Vector2.INF) -> void:
	# Prefer an idle villager; otherwise pull one off gathering duty -- but
	# never steal a villager that is already constructing something else,
	# or two buildings queued in the same think tick would fight over one
	# builder and the first building would sit abandoned forever.
	var builder = null
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type == "villager" and u.state != RTSUnit.State.CONSTRUCT:
			if u.state == RTSUnit.State.IDLE:
				builder = u
				break
			elif builder == null:
				builder = u
	if builder == null or world_root == null:
		return
	var pos: Vector2
	if is_finite(pos_override.x):
		pos = pos_override
	else:
		var tc = ps.town_center()
		var base_pos: Vector2 = tc.global_position if tc else builder.global_position
		pos = base_pos + Vector2(randf_range(-160, 160), randf_range(-160, 160))
	var stats: Dictionary = GameData.get_building_stats(building_type)
	ps.spend(stats.get("cost", {}))
	var b: RTSBuilding = RTSBuilding.new()
	world_root.add_child(b)
	b.global_position = pos
	b.setup(building_type, player_id, true)
	builder.order_construct(b)


## Lowest priority spender: only trains with whatever's left after every
## higher-priority need above has staked its claim on `reserved`.
func _maybe_train_military(ps: PlayerState, reserved: Dictionary) -> void:
	for b in ps.buildings:
		if is_instance_valid(b) and b.building_type == "barracks" and not b.under_construction:
			if b.train_queue.size() < 2:
				var options: Array = GameData.trainable_units_for_building("barracks", ps.civ_id)
				options = options.filter(func(unit_type: String) -> bool:
					var cost: Dictionary = GameData.get_unit_stats(unit_type).get("cost", {})
					return _can_afford_with_reserve(ps, cost, reserved)
				)
				if options.size() > 0:
					var pick: String = options[randi() % options.size()]
					b.queue_train(pick)


func _maybe_attack(ps: PlayerState) -> void:
	var army: Array = []
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type != "villager" and u.state != RTSUnit.State.ATTACK:
			army.append(u)
	if army.size() < _attack_threshold(ps):
		return
	var enemy: PlayerState = GameManager.get_player(GameManager.enemy_of(player_id))
	if not enemy:
		return
	var target = null
	if not enemy.buildings.is_empty():
		target = enemy.buildings[0]
	elif not enemy.units.is_empty():
		target = enemy.units[0]
	if target:
		for u in army:
			u.order_attack(target)
