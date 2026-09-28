extends RefCounted
class_name PlayerState
## Per-player economy & army bookkeeping. Not a Node; plain data + logic.

var player_id: int
var civ_id: String
var is_ai: bool = false

var resources: Dictionary = {"wood": 0, "food": 0, "gold": 0, "stone": 0}
var population_used: int = 0
var population_cap: int = 0

var units: Array = []
var buildings: Array = []

signal resources_changed
signal population_changed


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


func gather_multiplier(res_type: String) -> float:
	var civ: Dictionary = civ_data()
	var bonuses: Dictionary = civ.get("gather_bonus", {})
	return bonuses.get(res_type, 1.0)


func range_multiplier() -> float:
	var civ: Dictionary = civ_data()
	return civ.get("ranged_range_bonus", 1.0)


func town_center() -> Node:
	for b in buildings:
		if is_instance_valid(b) and b.building_type == "town_center" and not b.under_construction:
			return b
	return null


func nearest_dropoff(from_pos: Vector2) -> Node:
	var best: Node = null
	var best_dist := INF
	for b in buildings:
		if not is_instance_valid(b):
			continue
		var stats: Dictionary = GameData.get_building_stats(b.building_type)
		if not stats.get("is_drop_off", false) or b.under_construction:
			continue
		var d: float = from_pos.distance_squared_to(b.global_position)
		if d < best_dist:
			best_dist = d
			best = b
	return best
