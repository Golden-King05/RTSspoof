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
	# Aging up is checked before even villager training claims anything, or
	# its reservation would never actually hold onto enough to afford the
	# advance -- villager training alone can absorb food indefinitely (the
	# target keeps rising with population cap), so left any later in the
	# order it would starve the age-up forever rather than just slow it.
	_maybe_advance_age(ps, reserved)
	_maybe_train_villager(ps, reserved)
	_maybe_train_town_center_unique(ps, reserved)
	_maybe_build_house(ps, reserved)
	_maybe_build_barracks(ps, reserved)
	_maybe_build_stable(ps, reserved)
	_maybe_build_tower(ps, reserved)
	_maybe_build_fort(ps, reserved)
	_maybe_build_farm(ps, reserved)
	_maybe_build_resource_camps(ps, reserved)
	_maybe_train_military(ps, reserved)
	_maybe_research_upgrades(ps, reserved)
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


## Trains whatever civ-specific unit(s) the Town Center offers besides
## Villager (e.g. the Roman Aquilifer) -- not hardcoded to Romans, so this
## keeps working if another civ ever gets a town_center_unique too. Only
## keeps one of each at a time, since these are support units, not an army.
func _maybe_train_town_center_unique(ps: PlayerState, reserved: Dictionary) -> void:
	var tc = ps.town_center()
	if not tc:
		return
	for unit_type in GameData.trainable_units_for_building("town_center", ps.civ_id):
		if unit_type == "villager":
			continue
		var have := false
		for u in ps.units:
			if is_instance_valid(u) and u.unit_type == unit_type:
				have = true
				break
		if have or tc.train_queue.size() >= 2:
			continue
		var cost: Dictionary = GameData.get_unit_stats(unit_type).get("cost", {})
		if _can_afford_with_reserve(ps, cost, reserved):
			tc.queue_train(unit_type)
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
	if not ps.building_unlocked("barracks"):
		return
	for b in ps.buildings:
		if is_instance_valid(b) and b.building_type == "barracks":
			return
	var cost: Dictionary = GameData.get_building_stats("barracks").get("cost", {})
	if _can_afford_with_reserve(ps, cost, reserved):
		_build_building(ps, "barracks")
	else:
		_reserve(reserved, cost)


func _maybe_build_stable(ps: PlayerState, reserved: Dictionary) -> void:
	if not ps.building_unlocked("stable"):
		return
	for b in ps.buildings:
		if is_instance_valid(b) and b.building_type == "stable":
			return
	var cost: Dictionary = GameData.get_building_stats("stable").get("cost", {})
	if _can_afford_with_reserve(ps, cost, reserved):
		_build_building(ps, "stable")
	else:
		_reserve(reserved, cost)


## Advancing an age is the single biggest force multiplier available (it's
## what unlocks Barracks/Stable/Tower, then the Fort, then every upgrade),
## so it's checked right alongside the essential economy buildings rather
## than left to whatever's left over after discretionary spending.
func _maybe_advance_age(ps: PlayerState, reserved: Dictionary) -> void:
	if not ps.can_advance_age() or not ps.research_queue.is_empty():
		return
	# Reserving a big, ever-growing age-up cost (Age III alone needs 400
	## food) before the economy can actually support it would starve villager
	# training indefinitely -- food is the resource both compete for, and
	# villager training is what makes the reservation ever payable in the
	# first place. So aging up isn't even attempted until the current
	# villager count clears a bar that rises with age, matching "Age I is
	# essentially all economic" -- a light workforce before Feudal, more
	# before Castle, and so on.
	var villager_count := 0
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type == "villager":
			villager_count += 1
	if villager_count < 5 + (ps.current_age - 1) * 2:
		return
	var cost: Dictionary = ps.next_age_cost()
	if _can_afford_with_reserve(ps, cost, reserved):
		ps.queue_age_advance()
	else:
		_reserve(reserved, cost)


func _maybe_build_tower(ps: PlayerState, reserved: Dictionary) -> void:
	if not ps.building_unlocked("tower"):
		return
	for b in ps.buildings:
		if is_instance_valid(b) and b.building_type == "tower":
			return
	var cost: Dictionary = GameData.get_building_stats("tower").get("cost", {})
	if _can_afford_with_reserve(ps, cost, reserved):
		_build_building(ps, "tower")
	else:
		_reserve(reserved, cost)


## Builds a Fort, or a Castle directly once forts_to_castles is researched
## (building_unlocked() hides "fort" and shows "castle" at that point --
## see BUILDING_STATS' obsoleted_by/requires_tech). Only ever wants one.
func _maybe_build_fort(ps: PlayerState, reserved: Dictionary) -> void:
	var building_type: String = "castle" if ps.building_unlocked("castle") else "fort"
	if not ps.building_unlocked(building_type):
		return
	for b in ps.buildings:
		if is_instance_valid(b) and (b.building_type == "fort" or b.building_type == "castle"):
			return
	var cost: Dictionary = GameData.get_building_stats(building_type).get("cost", {})
	if _can_afford_with_reserve(ps, cost, reserved):
		_build_building(ps, building_type)
	else:
		_reserve(reserved, cost)


## Opportunistic, lowest-priority research: at most one attempt per tick, so
## it never competes with economy/army spending for more than its own cost.
func _maybe_research_upgrades(ps: PlayerState, reserved: Dictionary) -> void:
	if not ps.research_queue.is_empty():
		return
	for upgrade_id in GameData.UPGRADES.keys():
		if ps.has_upgrade(upgrade_id):
			continue
		var upg: Dictionary = GameData.UPGRADES[upgrade_id]
		if int(upg.get("required_age", 1)) > ps.current_age:
			continue
		var prereq: String = upg.get("requires", "")
		if prereq != "" and not ps.has_upgrade(prereq):
			continue
		var cost: Dictionary = ps.upgrade_cost(upgrade_id)
		if _can_afford_with_reserve(ps, cost, reserved):
			ps.queue_upgrade(upgrade_id)
		else:
			_reserve(reserved, cost)
		return


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
	if not ps.building_unlocked(building_type):
		return
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


const MILITARY_BUILDING_TYPES := ["barracks", "stable", "fort", "castle"]


## Lowest priority spender: only trains with whatever's left after every
## higher-priority need above has staked its claim on `reserved`.
func _maybe_train_military(ps: PlayerState, reserved: Dictionary) -> void:
	for b in ps.buildings:
		if is_instance_valid(b) and MILITARY_BUILDING_TYPES.has(b.building_type) and not b.under_construction:
			if b.train_queue.size() < 2:
				var options: Array = GameData.trainable_units_for_building(b.building_type, ps.civ_id)
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
	var enemy_ids: Array = GameManager.enemies_of(player_id)
	if enemy_ids.is_empty():
		return
	var home_tc: Node = ps.town_center()
	var home: Vector2 = home_tc.global_position if home_tc else Vector2.ZERO
	var enemy: PlayerState = null
	var best_dist := INF
	for eid in enemy_ids:
		var e: PlayerState = GameManager.get_player(eid)
		if not e:
			continue
		var ref_pos: Vector2 = home
		var ref_tc: Node = e.town_center()
		if ref_tc:
			ref_pos = ref_tc.global_position
		elif not e.buildings.is_empty():
			ref_pos = e.buildings[0].global_position
		var d: float = home.distance_squared_to(ref_pos)
		if d < best_dist:
			best_dist = d
			enemy = e
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
