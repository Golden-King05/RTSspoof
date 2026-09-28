extends Node
class_name AIController
## A small scripted opponent: keeps villagers gathering, expands houses,
## builds a barracks, trains an army, then attack-moves once strong enough.

var player_id: int = 1
var world_root: Node2D

var think_interval: float = 2.0
var _timer: float = 0.0

var target_villagers: int = 8
var target_army_before_attack: int = 6


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
	_assign_idle_villagers(ps)
	_maybe_train_villager(ps)
	_maybe_build_house(ps)
	_maybe_build_barracks(ps)
	_maybe_train_military(ps)
	_maybe_attack(ps)


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


func _maybe_train_villager(ps: PlayerState) -> void:
	var tc = ps.town_center()
	if not tc:
		return
	var villager_count := 0
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type == "villager":
			villager_count += 1
	if villager_count < target_villagers and tc.train_queue.size() < 2:
		tc.queue_train("villager")


func _maybe_build_house(ps: PlayerState) -> void:
	if ps.population_cap - ps.population_used > 2:
		return
	if not ps.can_afford(GameData.get_building_stats("house").get("cost", {})):
		return
	_build_building(ps, "house")


func _maybe_build_barracks(ps: PlayerState) -> void:
	for b in ps.buildings:
		if is_instance_valid(b) and b.building_type == "barracks":
			return
	if not ps.can_afford(GameData.get_building_stats("barracks").get("cost", {})):
		return
	_build_building(ps, "barracks")


func _build_building(ps: PlayerState, building_type: String) -> void:
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
	var tc = ps.town_center()
	var base_pos: Vector2 = tc.global_position if tc else builder.global_position
	var pos: Vector2 = base_pos + Vector2(randf_range(-160, 160), randf_range(-160, 160))
	var stats: Dictionary = GameData.get_building_stats(building_type)
	ps.spend(stats.get("cost", {}))
	var b: RTSBuilding = RTSBuilding.new()
	world_root.add_child(b)
	b.global_position = pos
	b.setup(building_type, player_id, true)
	builder.order_construct(b)


func _maybe_train_military(ps: PlayerState) -> void:
	for b in ps.buildings:
		if is_instance_valid(b) and b.building_type == "barracks" and not b.under_construction:
			if b.train_queue.size() < 2:
				var options: Array = GameData.trainable_units_for_building("barracks", ps.civ_id)
				if options.size() > 0:
					var pick: String = options[randi() % options.size()]
					b.queue_train(pick)


func _maybe_attack(ps: PlayerState) -> void:
	var army: Array = []
	for u in ps.units:
		if is_instance_valid(u) and u.unit_type != "villager" and u.state != RTSUnit.State.ATTACK:
			army.append(u)
	if army.size() < target_army_before_attack:
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
