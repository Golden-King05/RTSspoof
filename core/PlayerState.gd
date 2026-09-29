extends RefCounted
class_name PlayerState
## Per-player economy & army bookkeeping. Not a Node; plain data + logic.

var player_id: int
var civ_id: String
var is_ai: bool = false
var team: int = 0

var resources: Dictionary = {"wood": 0, "food": 0, "gold": 0, "stone": 0}
var population_used: int = 0
var population_cap: int = 0

var units: Array = []
var buildings: Array = []

var current_age: int = 1
var researched_upgrades: Array = [] # Array[String] of GameData.UPGRADES keys
## At most one entry: {"kind": "age"|"upgrade", "id": String, "time_left":
## float, "total_time": float}. Ticked every frame by GameManager (a Node,
## unlike this RefCounted class) via tick_research() -- see
## GameManager._process(). Only one research at a time, matching the single
## train_queue slot buildings already use.
var research_queue: Array = []

signal resources_changed
signal population_changed
## Fired when an age-advance or upgrade finishes researching -- the HUD
## refreshes its build/train panel and age display off this rather than
## resources_changed, since aging up unlocks buildings without necessarily
## changing any resource total.
signal tech_changed


func _init(p_id: int, p_civ: String, p_is_ai: bool) -> void:
	player_id = p_id
	civ_id = p_civ
	is_ai = p_is_ai
	for res_type in GameData.RESOURCE_TYPES:
		resources[res_type] = GameData.STARTING_RESOURCES[res_type]
	var civ: Dictionary = GameData.get_civ_data(civ_id)
	for res_type in civ.get("starting_bonus", {}).keys():
		resources[res_type] += civ["starting_bonus"][res_type]


func civ_data() -> Dictionary:
	return GameData.get_civ_data(civ_id)


func can_afford(cost: Dictionary) -> bool:
	for res_type in cost.keys():
		if resources.get(res_type, 0) < cost[res_type]:
			return false
	return true


func spend(cost: Dictionary) -> void:
	for res_type in cost.keys():
		resources[res_type] -= cost[res_type]
	resources_changed.emit()


func add_resource(res_type: String, amount: float) -> void:
	resources[res_type] += amount
	resources_changed.emit()


func has_pop_room(pop_cost: int = 1) -> bool:
	return population_used + pop_cost <= population_cap


func register_unit(unit) -> void:
	units.append(unit)
	var stats: Dictionary = GameData.get_unit_stats(unit.unit_type)
	population_used += int(stats.get("pop_cost", 1))
	population_changed.emit()


func unregister_unit(unit) -> void:
	units.erase(unit)
	var stats: Dictionary = GameData.get_unit_stats(unit.unit_type)
	population_used -= int(stats.get("pop_cost", 1))
	population_changed.emit()


func register_building(building) -> void:
	buildings.append(building)
	var stats: Dictionary = GameData.get_building_stats(building.building_type)
	population_cap += int(stats.get("provides_pop", 0))
	var civ: Dictionary = civ_data()
	if building.building_type == "house":
		population_cap += int(civ.get("house_pop_bonus", 0))
	population_changed.emit()


func unregister_building(building) -> void:
	buildings.erase(building)
	var stats: Dictionary = GameData.get_building_stats(building.building_type)
	population_cap -= int(stats.get("provides_pop", 0))
	var civ: Dictionary = civ_data()
	if building.building_type == "house":
		population_cap -= int(civ.get("house_pop_bonus", 0))
	population_changed.emit()


## `world_pos` is the resource/farm being gathered from -- some bonuses
## (e.g. the Egyptian farm bonus) only apply when it's near water.
func gather_multiplier(res_type: String, world_pos: Vector2 = Vector2.INF) -> float:
	var civ: Dictionary = civ_data()
	var mult: float = civ.get("gather_bonus", {}).get(res_type, 1.0)
	var water_bonus: Dictionary = civ.get("water_gather_bonus", {})
	if water_bonus.has(res_type) and is_finite(world_pos.x) and GameManager.is_near_water(world_pos):
		mult *= float(water_bonus[res_type])
	return mult


func range_multiplier() -> float:
	var civ: Dictionary = civ_data()
	return civ.get("ranged_range_bonus", 1.0)


func move_speed_multiplier() -> float:
	var civ: Dictionary = civ_data()
	return civ.get("move_speed_bonus", 1.0)


func construction_speed_multiplier() -> float:
	var civ: Dictionary = civ_data()
	return civ.get("construction_speed_bonus", 1.0)


func building_hp_multiplier() -> float:
	var civ: Dictionary = civ_data()
	return civ.get("building_hp_bonus", 1.0)


func town_center() -> Node:
	for b in buildings:
		if is_instance_valid(b) and b.building_type == "town_center" and not b.under_construction:
			return b
	return null


## Nearest building that accepts `resource_type` (Town Center takes all
## four; Lumberjack/Mine/Windmill only the type(s) they're built for).
func nearest_dropoff(from_pos: Vector2, resource_type: String) -> Node:
	var best: Node = null
	var best_dist := INF
	for b in buildings:
		if not is_instance_valid(b) or b.under_construction:
			continue
		var stats: Dictionary = GameData.get_building_stats(b.building_type)
		var drop_types: Array = stats.get("drop_off_types", [])
		if not drop_types.has(resource_type):
			continue
		var d: float = from_pos.distance_squared_to(b.global_position)
		if d < best_dist:
			best_dist = d
			best = b
	return best


## True if `building_type` is buildable right now: its age requirement is
## met, any tech it requires (e.g. the Castle needing forts_to_castles) has
## been researched, and it hasn't been superseded by one that has (e.g. the
## Fort, once forts_to_castles is done).
func building_unlocked(building_type: String) -> bool:
	var stats: Dictionary = GameData.get_building_stats(building_type)
	if int(stats.get("required_age", 1)) > current_age:
		return false
	var req_tech: String = stats.get("requires_tech", "")
	if req_tech != "" and not has_upgrade(req_tech):
		return false
	var obsoleted_by: String = stats.get("obsoleted_by", "")
	if obsoleted_by != "" and has_upgrade(obsoleted_by):
		return false
	return true


func can_advance_age() -> bool:
	return current_age < GameData.MAX_AGE


func next_age_cost() -> Dictionary:
	if not can_advance_age():
		return {}
	return GameData.AGES.get(current_age + 1, {}).get("advance_cost", {})


func has_upgrade(upgrade_id: String) -> bool:
	return researched_upgrades.has(upgrade_id)


## Flat bonus to `stat` ("attack" or "armor") from every upgrade this player
## has researched -- read by Unit.effective_attack()/effective_armor() for
## every unit except villagers.
func upgrade_bonus(stat: String) -> float:
	var total := 0.0
	for upg_id in researched_upgrades:
		var upg: Dictionary = GameData.UPGRADES.get(upg_id, {})
		total += float(upg.get("effect", {}).get(stat, 0.0))
	return total


## `forts_to_castles`'s Stone cost scales with how many Forts this player
## already owns: half a fresh Castle's Stone cost, per existing Fort, on
## top of the upgrade's flat base cost (e.g. 5 Forts and a 50-Stone Castle
## cost means +125 Stone). Every other upgrade just returns its flat cost.
func upgrade_cost(upgrade_id: String) -> Dictionary:
	var upg: Dictionary = GameData.UPGRADES.get(upgrade_id, {})
	var cost: Dictionary = upg.get("cost", {}).duplicate()
	if upgrade_id == "forts_to_castles":
		var fort_count := 0
		for b in buildings:
			if is_instance_valid(b) and b.building_type == "fort":
				fort_count += 1
		var castle_stone_cost: float = float(GameData.get_building_stats("castle").get("cost", {}).get("stone", 0.0))
		cost["stone"] = float(cost.get("stone", 0.0)) + fort_count * (castle_stone_cost / 2.0)
	return cost


func queue_age_advance() -> bool:
	if not can_advance_age() or not research_queue.is_empty():
		return false
	var cost: Dictionary = next_age_cost()
	if not can_afford(cost):
		return false
	spend(cost)
	var next_age: int = current_age + 1
	var advance_time: float = float(GameData.AGES.get(next_age, {}).get("advance_time", 30.0))
	research_queue.append({"kind": "age", "id": str(next_age), "time_left": advance_time, "total_time": advance_time})
	return true


func queue_upgrade(upgrade_id: String) -> bool:
	if has_upgrade(upgrade_id) or not research_queue.is_empty():
		return false
	var upg: Dictionary = GameData.UPGRADES.get(upgrade_id, {})
	if upg.is_empty() or int(upg.get("required_age", 1)) > current_age:
		return false
	var prereq: String = upg.get("requires", "")
	if prereq != "" and not has_upgrade(prereq):
		return false
	var cost: Dictionary = upgrade_cost(upgrade_id)
	if not can_afford(cost):
		return false
	spend(cost)
	var research_time: float = float(upg.get("research_time", 30.0))
	research_queue.append({"kind": "upgrade", "id": upgrade_id, "time_left": research_time, "total_time": research_time})
	return true


## Called every frame by GameManager._process() for every player in the
## match (this class is plain RefCounted, not a Node, so it can't tick
## itself).
func tick_research(delta: float) -> void:
	if research_queue.is_empty():
		return
	var entry: Dictionary = research_queue[0]
	entry["time_left"] = float(entry["time_left"]) - delta
	research_queue[0] = entry
	if entry["time_left"] <= 0.0:
		research_queue.pop_front()
		_complete_research(entry)


func _complete_research(entry: Dictionary) -> void:
	if entry["kind"] == "age":
		current_age = int(entry["id"])
	elif entry["kind"] == "upgrade":
		var upgrade_id: String = entry["id"]
		researched_upgrades.append(upgrade_id)
		if upgrade_id == "forts_to_castles":
			_convert_forts_to_castles()
	tech_changed.emit()


func _convert_forts_to_castles() -> void:
	for b in buildings.duplicate():
		if is_instance_valid(b) and b.building_type == "fort":
			b.convert_to_castle()
