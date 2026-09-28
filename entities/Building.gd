extends Node2D
class_name RTSBuilding
## Generic building: Town Center, House, Barracks. Configured via `setup()`.

signal died(building)
signal unit_trained(unit)

var building_type: String = "house"
var player_id: int = 0
var civ_id: String = ""

var max_hp: float = 100.0
var hp: float = 100.0
var armor: float = 0.0
var radius: float = 30.0
var vision_range: float = 150.0
var is_drop_off: bool = false
var can_train: Array = []
var build_time: float = 10.0

var under_construction: bool = false
var _start_hp_fraction: float = 0.1

var train_queue: Array = [] # Array of {"unit_type": String, "time_left": float, "total_time": float}

# Farm-only: once built, a farm acts like a resource node (villagers gather
# food from it directly) rather than training anything.
var is_farm: bool = false
var resource_type: String = "food"
var gather_multiplier: float = 1.0
var food_remaining: float = 0.0
var food_max: float = 0.0

var _dead: bool = false
var _obstacle: NavigationObstacle2D

# Viking raiding: accumulated damage per attacking player_id, paid out in
# chunks once it crosses that civ's raid_bonus.damage_per_chunk threshold.
var _raid_damage_carry: Dictionary = {}


func setup(p_building_type: String, p_player_id: int, start_under_construction: bool = true) -> void:
	building_type = p_building_type
	player_id = p_player_id
	var ps: PlayerState = GameManager.get_player(player_id)
	civ_id = ps.civ_id if ps else ""
	var stats: Dictionary = GameData.get_building_stats(building_type)
	max_hp = stats.get("max_hp", 100.0)
	radius = stats.get("radius", 30.0)
	vision_range = stats.get("vision_range", 150.0)
	is_drop_off = stats.get("is_drop_off", false)
	build_time = max(stats.get("build_time", 10.0), 0.01)
	can_train = GameData.trainable_units_for_building(building_type, civ_id)

	is_farm = stats.get("is_farm", false)
	if is_farm:
		food_max = stats.get("food_amount", 175.0)
		food_remaining = food_max

	under_construction = start_under_construction
	hp = max_hp * _start_hp_fraction if under_construction else max_hp

	add_to_group("buildings")
	add_to_group("player_%d_buildings" % player_id)

	_obstacle = NavigationObstacle2D.new()
	_obstacle.radius = radius * 0.9
	_obstacle.avoidance_enabled = true
	add_child(_obstacle)

	if ps:
		ps.register_building(self)
	queue_redraw()


func add_build_progress(delta: float) -> void:
	if not under_construction:
		return
	var remaining_hp: float = max_hp * (1.0 - _start_hp_fraction)
	hp += (remaining_hp / build_time) * delta
	if hp >= max_hp:
		hp = max_hp
		under_construction = false
	queue_redraw()


func _process(delta: float) -> void:
	if under_construction or train_queue.is_empty():
		return
	var entry: Dictionary = train_queue[0]
	entry.time_left -= delta
	train_queue[0] = entry
	if entry.time_left <= 0.0:
		train_queue.pop_front()
		_spawn_unit(entry.unit_type)
	queue_redraw()


func queue_train(unit_type: String) -> bool:
	if under_construction or not can_train.has(unit_type):
		return false
	var ps: PlayerState = GameManager.get_player(player_id)
	if not ps:
		return false
	var stats: Dictionary = GameData.get_unit_stats(unit_type)
	var cost: Dictionary = stats.get("cost", {})
	if not ps.can_afford(cost):
		return false
	if not ps.has_pop_room(int(stats.get("pop_cost", 1))):
		return false
	ps.spend(cost)
	train_queue.append({"unit_type": unit_type, "time_left": stats.get("train_time", 10.0), "total_time": stats.get("train_time", 10.0)})
	return true


func _spawn_unit(unit_type: String) -> void:
	var unit: RTSUnit = RTSUnit.new()
	get_parent().add_child(unit)
	var angle: float = randf() * TAU
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * (radius + 30.0)
	unit.global_position = global_position + offset
	unit.setup(unit_type, player_id)
	unit_trained.emit(unit)


func on_damaged(_dmg: float, _attacker) -> void:
	pass


## Called for every hit this building takes; pays out Viking-style raid
## loot to the attacker if their civ has a raid_bonus configured. Damage
## that doesn't cross the chunk threshold carries over to the next hit.
func register_raid_damage(dmg: float, attacker_player_id: int) -> void:
	var attacker_ps: PlayerState = GameManager.get_player(attacker_player_id)
	if not attacker_ps:
		return
	var raid: Dictionary = attacker_ps.civ_data().get("raid_bonus", {})
	if raid.is_empty():
		return
	var chunk_damage: float = raid.get("damage_per_chunk", 10.0)
	var carry: float = _raid_damage_carry.get(attacker_player_id, 0.0) + dmg
	var chunks: int = int(carry / chunk_damage)
	if chunks > 0:
		var stats: Dictionary = GameData.get_building_stats(building_type)
		var loot_res: String = stats.get("raid_resource", "wood")
		attacker_ps.add_resource(loot_res, chunks * float(raid.get("resource_per_chunk", 1.0)))
		attacker_ps.add_resource("gold", chunks * float(raid.get("gold_per_chunk", 0.5)))
		carry -= chunks * chunk_damage
	_raid_damage_carry[attacker_player_id] = carry


func is_depleted() -> bool:
	return is_farm and food_remaining <= 0.0


## Farms quack like a RTSResourceNode so villagers can gather them the same
## way; non-farm buildings just don't get targeted for gathering.
func harvest(requested: float) -> float:
	if not is_farm:
		return 0.0
	var granted: float = min(requested, food_remaining)
	food_remaining -= granted
	queue_redraw()
	if food_remaining <= 0.0:
		call_deferred("die")
	return granted


func die() -> void:
	if _dead:
		return
	_dead = true
	var ps: PlayerState = GameManager.get_player(player_id)
	if ps:
		ps.unregister_building(self)
	died.emit(self)
	GameManager.check_defeat()
	queue_free()


func _draw() -> void:
	var civ: Dictionary = GameData.get_civ_data(civ_id)
	var col: Color = civ.get("color", Color.WHITE)
	if player_id == GameManager.AI_ID:
		col = col.darkened(0.15)
	if under_construction:
		col = col.lightened(0.35)
		col.a = 0.75

	var r: float = radius
	if is_farm:
		var furrow_col: Color = Color(0.55, 0.42, 0.22) if not under_construction else col
		draw_rect(Rect2(-r, -r, r * 2, r * 2), furrow_col)
		var rows := 5
		for i in range(rows):
			var y: float = -r + (r * 2) * (float(i) + 0.5) / rows
			draw_line(Vector2(-r + 3, y), Vector2(r - 3, y), furrow_col.darkened(0.35), 2.0)
		draw_rect(Rect2(-r, -r, r * 2, r * 2), col.darkened(0.45), false, 3.0)
		if not under_construction:
			var fill_ratio: float = 1.0 if food_max <= 0.0 else clamp(food_remaining / food_max, 0.0, 1.0)
			draw_arc(Vector2.ZERO, r + 6.0, 0, TAU * fill_ratio, 24, Color(1, 1, 1, 0.6), 2.0)
	else:
		draw_rect(Rect2(-r, -r, r * 2, r * 2), col)
		draw_rect(Rect2(-r, -r, r * 2, r * 2), col.darkened(0.45), false, 3.0)
		# roof accent triangle to read as a "building"
		var apex := Vector2(0, -r - r * 0.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), apex]), col.darkened(0.25))

	if under_construction:
		var ratio: float = clamp(hp / max_hp, 0.0, 1.0)
		var w := r * 2.2
		var top := Vector2(-w / 2.0, -r - r * 0.5 - 14.0)
		draw_rect(Rect2(top, Vector2(w, 5.0)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * ratio, 5.0)), Color(0.9, 0.75, 0.2))
	elif hp < max_hp:
		var ratio: float = clamp(hp / max_hp, 0.0, 1.0)
		var w := r * 2.2
		var top := Vector2(-w / 2.0, -r - r * 0.5 - 14.0)
		draw_rect(Rect2(top, Vector2(w, 5.0)), Color(0, 0, 0, 0.6))
		var bar_col: Color = Color(0.9, 0.15, 0.15).lerp(Color(0.2, 0.9, 0.2), ratio)
		draw_rect(Rect2(top, Vector2(w * ratio, 5.0)), bar_col)

	if not train_queue.is_empty():
		var e: Dictionary = train_queue[0]
		var ratio: float = 1.0 - clamp(float(e.time_left) / float(max(e.total_time, 0.01)), 0.0, 1.0)
		var w := r * 2.2
		var top := Vector2(-w / 2.0, r + r * 0.5 + 8.0)
		draw_rect(Rect2(top, Vector2(w, 5.0)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * ratio, 5.0)), Color(0.3, 0.7, 0.95))
