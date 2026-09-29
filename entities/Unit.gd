extends Node2D
class_name RTSUnit
## Generic unit: villagers, military and civ unique units are all this
## scene, configured at spawn time via `setup()` from GameData.UNIT_STATS.

enum State { IDLE, MOVE, ATTACK, GATHER, RETURN, CONSTRUCT }

signal died(unit)

var unit_type: String = "villager"
var player_id: int = 0
var civ_id: String = ""
var state: int = State.IDLE

var max_hp: float = 25.0
var hp: float = 25.0
var attack: int = 0
var armor: int = 0
var attack_range: float = 14.0
var move_speed: float = 90.0
var attack_cooldown: float = 1.5
var is_ranged: bool = false
var radius: float = 9.0
var vision_range: float = 180.0
var gather_rate: float = 0.0
var carry_capacity: float = 0.0
var can_build_flag: bool = false
var can_gather_flag: bool = false

var attack_target = null
var gather_node = null # RTSResourceNode or a farm RTSBuilding -- both quack the same gather API
var carrying_type: String = ""
var carrying_amount: float = 0.0
var construct_target = null
var move_only_target: Vector2 = Vector2.ZERO
var last_gather_type: String = ""

var selected: bool = false

var _attack_timer: float = 0.0
var _gather_timer: float = 0.0
var _last_delta: float = 0.016

# Aquilifer aura: while a friendly Aquilifer is within its aura_radius,
# every non-villager ally (this unit included) gets these additive/
# multiplicative modifiers on top of its base combat stats. Recomputed
# periodically, not every frame -- see _aura_check_timer.
var aura_buff_armor: float = 0.0
var aura_buff_attack: float = 0.0
var aura_buff_atk_speed_mult: float = 1.0
var _aura_check_timer: float = 0.0
const AURA_CHECK_INTERVAL := 0.5

# Applied instead of the buff, to whoever was in range, the instant an
# Aquilifer dies -- a temporary morale break. Counts down in real time
# regardless of state.
var death_debuff_armor: float = 0.0
var death_debuff_attack: float = 0.0
var death_debuff_atk_speed_mult: float = 1.0
var death_debuff_timer: float = 0.0

const GATHER_INTERVAL := 1.0
const INTERACT_PAD := 8.0

var nav_agent: NavigationAgent2D


func setup(p_unit_type: String, p_player_id: int) -> void:
	unit_type = p_unit_type
	player_id = p_player_id
	var ps: PlayerState = GameManager.get_player(player_id)
	civ_id = ps.civ_id if ps else ""
	var stats: Dictionary = GameData.get_unit_stats(unit_type)
	max_hp = stats.get("max_hp", 25.0)
	hp = max_hp
	attack = stats.get("attack", 0)
	armor = stats.get("armor", 0)
	attack_range = stats.get("attack_range", 14.0)
	move_speed = stats.get("move_speed", 90.0)
	attack_cooldown = stats.get("attack_cooldown", 1.5)
	is_ranged = stats.get("is_ranged", false)
	radius = stats.get("radius", 9.0)
	vision_range = stats.get("vision_range", 180.0)
	gather_rate = stats.get("gather_rate", 0.0)
	carry_capacity = stats.get("carry_capacity", 0.0)
	can_build_flag = stats.get("can_build", false)
	can_gather_flag = stats.get("can_gather", false)
	if is_ranged and ps:
		attack_range *= ps.range_multiplier()
	if ps:
		move_speed *= ps.move_speed_multiplier()

	add_to_group("units")
	add_to_group("player_%d_units" % player_id)

	nav_agent = NavigationAgent2D.new()
	nav_agent.radius = radius
	nav_agent.avoidance_enabled = true
	nav_agent.max_speed = move_speed
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 6.0
	nav_agent.avoidance_priority = randf()
	add_child(nav_agent)
	nav_agent.velocity_computed.connect(_on_velocity_computed)

	if ps:
		ps.register_unit(self)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_last_delta = delta
	_update_death_debuff(delta)
	_aura_check_timer -= delta
	if _aura_check_timer <= 0.0:
		_aura_check_timer = AURA_CHECK_INTERVAL
		_update_aura_buff()
	match state:
		State.MOVE:
			_step_toward(move_only_target, delta)
			if global_position.distance_to(move_only_target) <= 8.0:
				state = State.IDLE
		State.ATTACK:
			_process_attack(delta)
		State.GATHER:
			_process_gather(delta)
		State.RETURN:
			_process_return(delta)
		State.CONSTRUCT:
			_process_construct(delta)
		_:
			pass


func _step_toward(target_pos: Vector2, _delta: float) -> void:
	nav_agent.target_position = target_pos
	if nav_agent.is_navigation_finished():
		return
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var desired: Vector2 = global_position.direction_to(next_pos) * move_speed
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired)
	else:
		_on_velocity_computed(desired)


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	global_position += safe_velocity * _last_delta
	if safe_velocity.length() > 1.0:
		rotation = safe_velocity.angle()
	queue_redraw()


func order_move(target_pos: Vector2) -> void:
	_clear_task()
	move_only_target = target_pos
	state = State.MOVE


func order_attack(target) -> void:
	if not is_instance_valid(target):
		return
	_clear_task()
	attack_target = target
	state = State.ATTACK


func order_gather(node) -> void:
	if not can_gather_flag or not is_instance_valid(node):
		return
	_clear_task()
	gather_node = node
	state = State.GATHER


func order_construct(building) -> void:
	if not can_build_flag or not is_instance_valid(building):
		return
	_clear_task()
	construct_target = building
	state = State.CONSTRUCT


func _clear_task() -> void:
	attack_target = null
	gather_node = null
	construct_target = null
	_attack_timer = 0.0
	_gather_timer = 0.0


func _update_death_debuff(delta: float) -> void:
	if death_debuff_timer <= 0.0:
		return
	death_debuff_timer -= delta
	if death_debuff_timer <= 0.0:
		death_debuff_timer = 0.0
		death_debuff_armor = 0.0
		death_debuff_attack = 0.0
		death_debuff_atk_speed_mult = 1.0
		queue_redraw()


## Villagers aren't "soldiers" and never carry or receive this aura.
## Re-derives the buff from scratch each check (rather than accumulating)
## so it correctly clears the moment this unit steps outside every living
## Aquilifer's radius.
func _update_aura_buff() -> void:
	if can_gather_flag:
		return
	var new_armor := 0.0
	var new_attack := 0.0
	var new_speed_mult := 1.0
	var ps: PlayerState = GameManager.get_player(player_id)
	if ps:
		var stats: Dictionary = GameData.get_unit_stats("aquilifer")
		var aura_radius: float = stats.get("aura_radius", 0.0)
		var buff: Dictionary = stats.get("aura_buff", {})
		for u in ps.units:
			if not is_instance_valid(u) or u == self or u.unit_type != "aquilifer":
				continue
			if global_position.distance_to(u.global_position) <= aura_radius:
				new_armor = float(buff.get("armor", 0.0))
				new_attack = float(buff.get("attack", 0.0))
				new_speed_mult = float(buff.get("attack_speed_mult", 1.0))
				break
	if new_armor != aura_buff_armor or new_attack != aura_buff_attack or new_speed_mult != aura_buff_atk_speed_mult:
		aura_buff_armor = new_armor
		aura_buff_attack = new_attack
		aura_buff_atk_speed_mult = new_speed_mult
		queue_redraw()


## Called on an Aquilifer's own death: everyone who was standing in its
## aura at that instant flips from being buffed to being debuffed.
func _apply_death_debuff_to_nearby() -> void:
	var ps: PlayerState = GameManager.get_player(player_id)
	if not ps:
		return
	var stats: Dictionary = GameData.get_unit_stats("aquilifer")
	var aura_radius: float = stats.get("aura_radius", 0.0)
	var debuff: Dictionary = stats.get("aura_debuff_on_death", {})
	var duration: float = stats.get("aura_debuff_duration", 0.0)
	for u in ps.units:
		if not is_instance_valid(u) or u == self or u.can_gather_flag:
			continue
		if global_position.distance_to(u.global_position) <= aura_radius:
			# Clear any live buff immediately rather than waiting for that
			# unit's own next periodic recheck (up to AURA_CHECK_INTERVAL
			# later) -- otherwise the stale buff and the fresh debuff
			# partially cancel out for a moment, masking the death penalty.
			u.aura_buff_armor = 0.0
			u.aura_buff_attack = 0.0
			u.aura_buff_atk_speed_mult = 1.0
			u.death_debuff_armor = float(debuff.get("armor", 0.0))
			u.death_debuff_attack = float(debuff.get("attack", 0.0))
			u.death_debuff_atk_speed_mult = float(debuff.get("attack_speed_mult", 1.0))
			u.death_debuff_timer = duration
			u.queue_redraw()


func effective_attack() -> float:
	return max(0.0, float(attack) + aura_buff_attack + death_debuff_attack)


func effective_armor() -> float:
	return max(0.0, float(armor) + aura_buff_armor + death_debuff_armor)


func effective_attack_cooldown() -> float:
	var speed_mult: float = aura_buff_atk_speed_mult * death_debuff_atk_speed_mult
	return attack_cooldown / max(0.1, speed_mult)


func _process_attack(delta: float) -> void:
	if not is_instance_valid(attack_target) or attack_target.hp <= 0:
		state = State.IDLE
		attack_target = null
		return
	var dist: float = global_position.distance_to(attack_target.global_position)
	var target_radius: float = attack_target.radius
	var reach: float = attack_range + target_radius
	if dist > reach:
		_step_toward(attack_target.global_position, delta)
	else:
		var desired_face: Vector2 = attack_target.global_position - global_position
		if desired_face.length() > 1.0:
			rotation = desired_face.angle()
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = effective_attack_cooldown()
			_deal_damage(attack_target)


func _deal_damage(target) -> void:
	var target_armor: float = target.effective_armor() if target.has_method("effective_armor") else float(target.armor)
	var dmg: float = max(1.0, effective_attack() - target_armor)
	target.hp -= dmg
	target.queue_redraw()
	if target.has_method("on_damaged"):
		target.on_damaged(dmg, self)
	if target.has_method("register_raid_damage"):
		target.register_raid_damage(dmg, player_id)
	if target.hp <= 0.0:
		if target.has_method("die"):
			target.die()


func _process_gather(delta: float) -> void:
	if not is_instance_valid(gather_node) or gather_node.is_depleted():
		gather_node = null
		if carrying_amount > 0.0:
			state = State.RETURN
		else:
			state = State.IDLE
		return
	var dist: float = global_position.distance_to(gather_node.global_position)
	var reach: float = INTERACT_PAD + gather_node.radius
	if dist > reach:
		_step_toward(gather_node.global_position, delta)
		return
	_gather_timer -= delta
	if _gather_timer <= 0.0:
		_gather_timer = GATHER_INTERVAL
		var ps: PlayerState = GameManager.get_player(player_id)
		var mult: float = ps.gather_multiplier(gather_node.resource_type, gather_node.global_position) if ps else 1.0
		var amount_wanted: float = gather_rate * gather_node.gather_multiplier * mult * GATHER_INTERVAL
		var granted: float = gather_node.harvest(amount_wanted)
		carrying_type = gather_node.resource_type
		carrying_amount += granted
		queue_redraw()
		if carrying_amount >= carry_capacity or gather_node.is_depleted():
			state = State.RETURN
			last_gather_type = carrying_type


func _process_return(delta: float) -> void:
	var ps: PlayerState = GameManager.get_player(player_id)
	if not ps:
		return
	var drop = ps.nearest_dropoff(global_position, carrying_type)
	if drop == null:
		state = State.IDLE
		return
	var dist: float = global_position.distance_to(drop.global_position)
	var reach: float = INTERACT_PAD + drop.radius
	if dist > reach:
		_step_toward(drop.global_position, delta)
		return
	ps.add_resource(carrying_type, carrying_amount)
	carrying_amount = 0.0
	queue_redraw()
	if is_instance_valid(gather_node) and not gather_node.is_depleted():
		state = State.GATHER
	else:
		state = State.IDLE


func _process_construct(delta: float) -> void:
	if not is_instance_valid(construct_target) or not construct_target.under_construction:
		construct_target = null
		state = State.IDLE
		return
	var dist: float = global_position.distance_to(construct_target.global_position)
	var reach: float = INTERACT_PAD + construct_target.radius
	if dist > reach:
		_step_toward(construct_target.global_position, delta)
		return
	construct_target.add_build_progress(delta)
	if not construct_target.under_construction:
		state = State.IDLE
		construct_target = null


func on_damaged(_dmg: float, attacker: Node) -> void:
	# Villagers/idle units auto-defend by retaliating when attacked.
	if state != State.ATTACK and state != State.CONSTRUCT and attack > 0:
		if is_instance_valid(attacker):
			order_attack(attacker)


var _dead: bool = false


func die() -> void:
	if _dead:
		return
	_dead = true
	if unit_type == "aquilifer":
		_apply_death_debuff_to_nearby()
	var ps: PlayerState = GameManager.get_player(player_id)
	if ps:
		ps.unregister_unit(self)
	died.emit(self)
	GameManager.check_defeat()
	queue_free()


func _draw() -> void:
	var civ: Dictionary = GameData.get_civ_data(civ_id)
	var col: Color = civ.get("color", Color.WHITE)
	if player_id == GameManager.AI_ID:
		col = col.darkened(0.15)

	# body
	if unit_type == "villager":
		draw_circle(Vector2.ZERO, radius, col)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 20, col.darkened(0.4), 2.0)
	elif is_ranged:
		var pts := PackedVector2Array([
			Vector2(radius, 0), Vector2(-radius * 0.6, radius * 0.7), Vector2(-radius * 0.6, -radius * 0.7)
		])
		draw_colored_polygon(pts, col)
	else:
		var r := radius
		draw_rect(Rect2(-r, -r, r * 2, r * 2), col)
		draw_rect(Rect2(-r, -r, r * 2, r * 2), col.darkened(0.4), false, 2.0)

	# facing indicator
	draw_line(Vector2.ZERO, Vector2(radius + 4, 0), Color(1, 1, 1, 0.7), 2.0)

	# selection ring
	if selected:
		draw_arc(Vector2.ZERO, radius + 6.0, 0, TAU, 24, Color(0.2, 1.0, 0.3), 2.0)
		if unit_type == "aquilifer":
			var aura_radius: float = GameData.get_unit_stats("aquilifer").get("aura_radius", 0.0)
			if aura_radius > 0.0:
				draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 48, Color(1.0, 0.85, 0.2, 0.8), 2.0)

	# a thin ring shows whether this unit is currently buffed by a nearby
	# Aquilifer (gold) or still suffering the morale-break debuff from one
	# dying (dark red) -- independent of whether it's selected
	if aura_buff_attack != 0.0 or aura_buff_armor != 0.0 or aura_buff_atk_speed_mult != 1.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 16, Color(1.0, 0.85, 0.2, 0.9), 1.5)
	elif death_debuff_timer > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 16, Color(0.5, 0.1, 0.1, 0.9), 1.5)

	# hp bar
	if hp < max_hp:
		var w := radius * 2.2
		var h := 4.0
		var top := Vector2(-w / 2.0, -radius - 12.0)
		draw_rect(Rect2(top, Vector2(w, h)), Color(0, 0, 0, 0.6))
		var ratio: float = clamp(hp / max_hp, 0.0, 1.0)
		var bar_col: Color = Color(0.9, 0.15, 0.15).lerp(Color(0.2, 0.9, 0.2), ratio)
		draw_rect(Rect2(top, Vector2(w * ratio, h)), bar_col)

	# carry indicator
	if carrying_amount > 0.0:
		var c: Color = GameData.resource_color(carrying_type)
		draw_circle(Vector2(0, radius + 8.0), 3.5, c)
