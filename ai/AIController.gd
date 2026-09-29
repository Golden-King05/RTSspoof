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
	_maybe_build_resource_camps(ps, reserved)
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


## Villager count the AI aims to keep training. This deliberately has no
## hard ceiling: it reserves a fraction of population capacity for an army
## and puts the rest toward the workforce, so the villager (and therefore
## farm -- see _maybe_build_farm) count keeps growing right along with
## population cap instead of plateauing early. That matters most late game,
## once wild resources are picked over and farms carry most of the food
## income. Raid civs reserve a bigger army share since their income doesn't
## depend on a large workforce.
func _target_villagers(ps: PlayerState) -> int:
	var civ: Dictionary = ps.civ_data()
	var military_share: float = 0.35 if not civ.get("raid_bonus", {}).is_empty() else 0.2
	var military_reserve: int = max(4, int(ps.population_cap * military_share))
	return max(4, ps.population_cap - military_reserve)


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


## Resource clumps are now scattered at randomized distances/angles (see
## MapGenerator) rather than the old fixed layout, which happened to always
## put berries closest to a base and so kept a trickle of food coming in "by
## accident". Picking the globally nearest resource regardless of type can
## now leave a whole resource starved for a long stretch if that type just
## happens to be farthest this game. Instead, always steer new idle
## villagers toward whichever type currently has the fewest gatherers, so
## coverage stays roughly balanced across wood/food/gold/stone.
func _assign_idle_villagers(ps: PlayerState) -> void:
	var gather_counts: Dictionary = {"wood": 0, "food": 0, "gold": 0, "stone": 0}
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type == "villager" and u.state == RTSUnit.State.GATHER and is_instance_valid(u.gather_node):
			var rt: String = u.gather_node.resource_type
			gather_counts[rt] = gather_counts.get(rt, 0) + 1

	for u in ps.units:
		if is_instance_valid(u) and u.unit_type == "villager" and u.state == RTSUnit.State.IDLE:
			var target_type: String = _least_covered_resource_type(gather_counts)
			var node = _find_nearest_resource(u.global_position, ps, target_type)
			if node == null:
				node = _find_nearest_resource(u.global_position, ps, "")
			if node:
				u.order_gather(node)
				gather_counts[node.resource_type] = gather_counts.get(node.resource_type, 0) + 1


func _least_covered_resource_type(counts: Dictionary) -> String:
	var best_type: String = "wood"
	var best_count: int = 999999
	for t in counts.keys():
		if counts[t] < best_count:
			best_count = counts[t]
			best_type = t
	return best_type


## Searches wild resource nodes and, for food, this player's own finished
## Farms too (farms are buildings, not in the "resources" group, but are
## just as valid a gather target). `filter_type` == "" means any type.
func _find_nearest_resource(from_pos: Vector2, ps: PlayerState, filter_type: String = ""):
	var best = null
	var best_d := INF
	for r in get_tree().get_nodes_in_group("resources") as Array:
		if not is_instance_valid(r) or r.is_depleted():
			continue
		if filter_type != "" and r.resource_type != filter_type:
			continue
		var d: float = from_pos.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	if filter_type == "" or filter_type == "food":
		for b in ps.buildings:
			if is_instance_valid(b) and b.is_farm and not b.under_construction and not b.is_depleted():
				var d: float = from_pos.distance_to(b.global_position)
				if d < best_d:
					best_d = d
					best = b
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


## Keeps roughly one Farm per four villagers, with no upper limit -- as the
## workforce grows (see _target_villagers), so does the farm count, which is
## what keeps food income scaling into the late game once wild resources
## are picked clean. Placement is biased toward a lake shore when this civ
## actually benefits from that (the Egyptian water bonus) -- otherwise it's
## just a normal spot near the Town Center, same as a House or Barracks.
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


## Returns a build spot near the nearest water tile if this civ has a
## water-gathering bonus for food; otherwise a normal random spot near
## `base_pos`, same style as House/Barracks placement.
func _pick_farm_position(ps: PlayerState, base_pos: Vector2) -> Vector2:
	var civ: Dictionary = ps.civ_data()
	if civ.get("water_gather_bonus", {}).has("food"):
		var near_water_pos: Vector2 = GameManager.find_land_near_water(base_pos)
		if is_finite(near_water_pos.x):
			return near_water_pos
	return base_pos + Vector2(randf_range(-160, 160), randf_range(-160, 160))


## Resource-specific depots (Lumberjack/Mine/Windmill): each accepts only
## certain resource types, so unlike Farm/House there's no quantity target
## here -- just one of each, built beside whichever matching resource
## cluster sits closest to home, once affordable.
const RESOURCE_CAMP_TYPES := {
	"lumberjack": ["wood"],
	"mine_camp": ["stone", "gold"],
	"windmill": ["food"],
}


func _maybe_build_resource_camps(ps: PlayerState, reserved: Dictionary) -> void:
	for building_type in RESOURCE_CAMP_TYPES.keys():
		var already_built := false
		for b in ps.buildings:
			if is_instance_valid(b) and b.building_type == building_type:
				already_built = true
				break
		if already_built:
			continue
		var cost: Dictionary = GameData.get_building_stats(building_type).get("cost", {})
		if not _can_afford_with_reserve(ps, cost, reserved):
			_reserve(reserved, cost)
			continue
		var target = _find_nearest_resource_of_types(ps, RESOURCE_CAMP_TYPES[building_type])
		if target == null:
			continue
		var angle: float = randf() * TAU
		var pos: Vector2 = target.global_position + Vector2(cos(angle), sin(angle)) * 50.0
		_build_building(ps, building_type, pos)


## Nearest wild resource node (or, if "food" is one of `types`, this
## player's own finished Farms too) of a matching type, measured from home.
func _find_nearest_resource_of_types(ps: PlayerState, types: Array):
	var tc = ps.town_center()
	var from_pos: Vector2 = tc.global_position if tc else Vector2.ZERO
	var best = null
	var best_d := INF
	for r in get_tree().get_nodes_in_group("resources") as Array:
		if not is_instance_valid(r) or r.is_depleted():
			continue
		if not types.has(r.resource_type):
			continue
		var d: float = from_pos.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	if types.has("food"):
		for b in ps.buildings:
			if is_instance_valid(b) and b.is_farm and not b.under_construction and not b.is_depleted():
				var d: float = from_pos.distance_to(b.global_position)
				if d < best_d:
					best_d = d
					best = b
	return best


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
