extends Node2D
## Wires up the whole match: world, camera, UI, civ pick, starting bases,
## resources and the AI opponent. Everything is built procedurally so there
## are no hand-authored sub-scenes to keep in sync.

const MAP_SIZE := Vector2(3000, 3000)
const HUMAN_START := Vector2(320, 320)

var world: Node2D
var camera: RTSCamera
var selection_manager: SelectionManager
var hud: HUD
var fog: FogOfWar
var ai_controllers: Array = [] # Array[AIController]
var lobby: LobbyScreen
var main_menu: MainMenu
var map_gen: MapGenerator
var ground: Ground
var _base_positions: Array = []

# Debug/automation hooks, e.g.: godot --path . -- --autostart=egyptian --screenshot=out.png --quit-after-seconds=5
var _screenshot_path: String = ""
var _quit_after_seconds: float = -1.0
var _elapsed: float = 0.0
var _debug_log: bool = false
var _debug_log_timer: float = 0.0
var _forced_ai_civ: String = ""


func _ready() -> void:
	randomize()

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	ground = Ground.new()
	ground.setup(MAP_SIZE)
	world.add_child(ground)

	var map_rng := RandomNumberGenerator.new()
	map_rng.randomize()
	map_gen = MapGenerator.new(MAP_SIZE, map_rng)
	# Water/resource generation depends on how many bases there are, which
	# isn't known until the lobby (or a debug --autostart) picks a lineup --
	# see _finalize_map(), called from _build_match().

	var nav_region := NavigationRegion2D.new()
	var nav_poly := NavigationPolygon.new()
	nav_poly.vertices = PackedVector2Array([
		Vector2.ZERO, Vector2(MAP_SIZE.x, 0), Vector2(MAP_SIZE.x, MAP_SIZE.y), Vector2(0, MAP_SIZE.y)
	])
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_polygon = nav_poly
	world.add_child(nav_region)

	camera = RTSCamera.new()
	camera.map_bounds = Rect2(Vector2.ZERO, MAP_SIZE)
	camera.zoom = Vector2(1.0, 1.0)
	add_child(camera)
	camera.global_position = HUMAN_START
	camera.make_current()

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	selection_manager = SelectionManager.new()
	selection_manager.world_root = world
	ui_layer.add_child(selection_manager)

	hud = HUD.new()
	add_child(hud)

	main_menu = MainMenu.new()
	add_child(main_menu)
	main_menu.play_pressed.connect(_on_play_pressed)

	_parse_debug_args()


func _on_play_pressed() -> void:
	if is_instance_valid(main_menu):
		main_menu.queue_free()
	lobby = LobbyScreen.new()
	add_child(lobby)
	lobby.match_configured.connect(_build_match)


func _parse_debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autostart="):
			call_deferred("_autostart_simple_match", a.substr(len("--autostart=")))
		elif a.begins_with("--screenshot="):
			_screenshot_path = a.substr(len("--screenshot="))
		elif a.begins_with("--quit-after-seconds="):
			_quit_after_seconds = float(a.substr(len("--quit-after-seconds=")))
		elif a.begins_with("--camera="):
			var parts: PackedStringArray = a.substr(len("--camera=")).split(",")
			if parts.size() == 2:
				call_deferred("_set_debug_camera", Vector2(float(parts[0]), float(parts[1])))
		elif a == "--debuglog":
			_debug_log = true
		elif a.begins_with("--ai-civ="):
			_forced_ai_civ = a.substr(len("--ai-civ="))
		elif a == "--simulate":
			call_deferred("_run_simulation")
		elif a.begins_with("--multitest="):
			call_deferred("_autostart_multi_test", int(a.substr(len("--multitest="))))
		elif a == "--open-lobby":
			call_deferred("_on_play_pressed")


func _set_debug_camera(pos: Vector2) -> void:
	camera.global_position = pos


## Exercises the real human-input code paths (box select, right-click order,
## building placement) without needing actual OS input events, so this can
## be checked headlessly. Only runs when --simulate is passed.
func _run_simulation() -> void:
	await get_tree().create_timer(1.0).timeout
	var ps: PlayerState = GameManager.get_player(GameManager.HUMAN_ID)
	print("[sim] selecting all human villagers")
	selection_manager._set_selected_units(ps.units.duplicate())
	selection_manager.selection_changed.emit()
	print("[sim] selected count=", selection_manager.selected_units.size())

	await get_tree().create_timer(0.5).timeout
	var res_node = null
	for r in get_tree().get_nodes_in_group("resources"):
		if is_instance_valid(r):
			res_node = r
			break
	if res_node:
		print("[sim] right-click ordering gather on a ", res_node.resource_type, " node")
		selection_manager._handle_right_click(res_node.global_position)
	else:
		print("[sim] no resource node found!")

	await get_tree().create_timer(1.0).timeout
	print("[sim] unit states after gather order: ", ps.units.map(func(u): return u.state if is_instance_valid(u) else -1))

	await get_tree().create_timer(1.0).timeout
	print("[sim] placing a house")
	selection_manager.start_placement("house")
	var tc = ps.town_center()
	var place_pos: Vector2 = tc.global_position + Vector2(150, 150)
	selection_manager._ghost.global_position = place_pos
	selection_manager._ghost.valid = true
	selection_manager._try_place_building()
	print("[sim] buildings now=", ps.buildings.size(), " wood=", ps.resources.wood)

	await get_tree().create_timer(4.0).timeout
	for b in ps.buildings:
		if is_instance_valid(b):
			print("[sim] building=", b.building_type, " hp=", b.hp, "/", b.max_hp, " under_construction=", b.under_construction)
	print("[sim] final unit count=", ps.units.size())

	# Water-gated gather bonus sanity check (should only matter for Egyptians).
	var near_water_pos: Vector2 = GameManager.find_land_near_water(HUMAN_START)
	var far_pos: Vector2 = HUMAN_START + Vector2(1200, 1200) # nowhere near any lake
	print("[sim] is_near_water(near)=", GameManager.is_near_water(near_water_pos), " is_near_water(far)=", GameManager.is_near_water(far_pos))
	print("[sim] %s gather_multiplier(food, near_water)=%s far=%s" % [ps.civ_id, ps.gather_multiplier("food", near_water_pos), ps.gather_multiplier("food", far_pos)])
	var enemy: PlayerState = GameManager.get_player(GameManager.enemy_of(GameManager.HUMAN_ID))
	print("[sim] %s gather_multiplier(food, near_water)=%s far=%s" % [enemy.civ_id, enemy.gather_multiplier("food", near_water_pos), enemy.gather_multiplier("food", far_pos)])

	# End-to-end farm test: place one near water, assign a villager, watch it harvest.
	var farm := RTSBuilding.new()
	world.add_child(farm)
	farm.global_position = near_water_pos
	farm.setup("farm", GameManager.HUMAN_ID, true)
	var farmer = ps.units[0]
	farmer.order_construct(farm)
	print("[sim] farm placed near water, food before=", ps.resources.food)

	await get_tree().create_timer(6.0).timeout
	print("[sim] farm under_construction=", farm.under_construction, " food_remaining=", farm.food_remaining)

	farmer.order_gather(farm)
	await get_tree().create_timer(4.0).timeout
	print("[sim] after gathering: player food=", ps.resources.food, " farm.food_remaining=", farm.food_remaining, " farmer.state=", farmer.state)

	# Viking raid-loot chunking test: drive register_raid_damage() directly
	# so the math is checked precisely regardless of real combat timing.
	if ps.civ_id == "viking":
		var dummy_barracks := RTSBuilding.new()
		world.add_child(dummy_barracks)
		dummy_barracks.global_position = HUMAN_START + Vector2(500, 0)
		dummy_barracks.setup("barracks", GameManager.enemy_of(GameManager.HUMAN_ID), false)
		print("[sim] raid test start: wood=", ps.resources.wood, " gold=", ps.resources.gold)
		dummy_barracks.register_raid_damage(6.0, GameManager.HUMAN_ID)
		print("[sim] +6 dmg (carry 6/10): wood=", ps.resources.wood, " gold=", ps.resources.gold, " (expect no change)")
		dummy_barracks.register_raid_damage(6.0, GameManager.HUMAN_ID)
		print("[sim] +6 dmg (total 12, 1 chunk, carry 2): wood=", ps.resources.wood, " gold=", ps.resources.gold, " (expect +1 wood, +0.5 gold)")
		dummy_barracks.register_raid_damage(28.0, GameManager.HUMAN_ID)
		print("[sim] +28 dmg (total 30, 3 chunks): wood=", ps.resources.wood, " gold=", ps.resources.gold, " (expect +3 wood, +1.5 gold more)")

	# Resource-specific drop-off test: a villager carrying wood should route
	# to a nearby Lumberjack rather than walking all the way back to the
	# Town Center, and a Lumberjack should never accept gold/stone/food.
	var lumberjack := RTSBuilding.new()
	world.add_child(lumberjack)
	lumberjack.global_position = HUMAN_START + Vector2(300, 300)
	lumberjack.setup("lumberjack", GameManager.HUMAN_ID, false)
	var nearest_for_wood = ps.nearest_dropoff(lumberjack.global_position + Vector2(10, 10), "wood")
	var nearest_for_gold = ps.nearest_dropoff(lumberjack.global_position + Vector2(10, 10), "gold")
	print("[sim] lumberjack accepts wood from beside it: ", nearest_for_wood == lumberjack, " (expect true)")
	print("[sim] lumberjack does NOT accept gold from beside it: ", nearest_for_gold == lumberjack, " (expect false)")

	var hauler = ps.units[1]
	hauler.global_position = lumberjack.global_position + Vector2(15, 0)
	hauler.carrying_type = "wood"
	hauler.carrying_amount = 7.0
	hauler.state = RTSUnit.State.RETURN
	var wood_before: float = ps.resources.wood
	await get_tree().create_timer(0.5).timeout
	print("[sim] wood after depositing at lumberjack: ", ps.resources.wood, " (expect +7 from ", wood_before, ")")

	# Aquilifer aura test (Roman-only mechanic): a nearby soldier should be
	# buffed while it lives, debuffed the instant it dies, and the debuff
	# should expire on its own after aura_debuff_duration seconds.
	if ps.civ_id == "roman":
		var aquilifer: RTSUnit = RTSUnit.new()
		world.add_child(aquilifer)
		aquilifer.global_position = HUMAN_START + Vector2(-400, -400)
		aquilifer.setup("aquilifer", GameManager.HUMAN_ID)

		var soldier: RTSUnit = RTSUnit.new()
		world.add_child(soldier)
		soldier.global_position = aquilifer.global_position + Vector2(50, 0) # well inside the 150 aura radius
		soldier.setup("legionary", GameManager.HUMAN_ID)

		await get_tree().create_timer(0.6).timeout # let the 0.5s aura-check tick run
		print("[sim] soldier in range: eff_attack=", soldier.effective_attack(), " eff_armor=", soldier.effective_armor(),
			" eff_cooldown=", soldier.effective_attack_cooldown(),
			" (base atk=", soldier.attack, " armor=", soldier.armor, " cooldown=", soldier.attack_cooldown, ", expect buffed)")

		soldier.global_position = aquilifer.global_position + Vector2(2000, 0) # far outside the aura
		await get_tree().create_timer(0.6).timeout
		print("[sim] soldier out of range: eff_attack=", soldier.effective_attack(), " eff_armor=", soldier.effective_armor(),
			" (expect back to base atk=", soldier.attack, " armor=", soldier.armor, ")")

		soldier.global_position = aquilifer.global_position + Vector2(50, 0) # back in range before the aquilifer dies
		await get_tree().create_timer(0.6).timeout
		aquilifer.die()
		print("[sim] soldier after aquilifer death: eff_attack=", soldier.effective_attack(), " eff_armor=", soldier.effective_armor(),
			" debuff_timer=", soldier.death_debuff_timer, " (expect debuffed, timer=600)")

		soldier._update_death_debuff(700.0) # fast-forward past the 600s debuff duration
		print("[sim] soldier after debuff expires: eff_attack=", soldier.effective_attack(), " eff_armor=", soldier.effective_armor(),
			" debuff_timer=", soldier.death_debuff_timer, " (expect back to base, timer=0)")

	print("[sim] DONE")


func _process(delta: float) -> void:
	if _debug_log and GameManager.match_started:
		_debug_log_timer += delta
		if _debug_log_timer >= 3.0:
			_debug_log_timer = 0.0
			for p in GameManager.players:
				var building_types: Array = []
				for b in p.buildings:
					if is_instance_valid(b):
						var note: String = ""
						if b.building_type == "farm":
							note = "@water" if GameManager.is_near_water(b.global_position) else "@land"
						building_types.append(b.building_type + note)
				print("[t=%.0f] P%d(%s) res=%s pop=%d/%d units=%d buildings=%s" % [
					_elapsed, p.player_id, p.civ_id, p.resources, p.population_used, p.population_cap,
					p.units.size(), building_types
				])
	if _quit_after_seconds > 0.0:
		_elapsed += delta
		if _elapsed >= _quit_after_seconds:
			if _screenshot_path != "":
				var img: Image = get_viewport().get_texture().get_image()
				img.save_png(_screenshot_path)
			get_tree().quit()


## Classic 2-player human-vs-one-AI path used by --autostart, bypassing the
## lobby entirely (kept for headless/regression testing).
func _autostart_simple_match(human_civ: String) -> void:
	var ai_civ: String = _forced_ai_civ if _forced_ai_civ != "" else GameData.random_other_civ(human_civ)
	_build_match([
		{"civ": human_civ, "team": 0, "is_ai": false},
		{"civ": ai_civ, "team": 1, "is_ai": true},
	])


## Debug hook for exercising the N-player/team lineup path (--multitest=<n>,
## n between 2 and GameManager.MAX_PLAYERS): 1 human + (n-1) AIs, split into
## two alternating teams so alliances actually get tested.
func _autostart_multi_test(count: int) -> void:
	count = clampi(count, 2, GameManager.MAX_PLAYERS)
	var civ_ids: Array = GameData.CIV_DATA.keys()
	var configs: Array = []
	for i in range(count):
		configs.append({
			"civ": civ_ids[i % civ_ids.size()],
			"team": i % 2,
			"is_ai": i != 0,
		})
	_build_match(configs)


## `player_configs` is an Array of Dictionaries: {civ, team, is_ai}. Entry 0
## is always the human. Builds the map, spawns every player's starting base,
## and creates one AIController per non-human slot.
func _build_match(player_configs: Array) -> void:
	if is_instance_valid(main_menu):
		main_menu.queue_free()
	if is_instance_valid(lobby):
		lobby.queue_free()

	_base_positions = _compute_base_positions(player_configs.size())
	_finalize_map(_base_positions)

	GameManager.start_match(player_configs)

	fog = FogOfWar.new()
	fog.setup(MAP_SIZE, GameManager.HUMAN_ID)
	world.add_child(fog)

	_scatter_resources()
	for i in range(player_configs.size()):
		_spawn_start_base(i, _base_positions[i])

	camera.global_position = _base_positions[GameManager.HUMAN_ID]

	hud.setup(selection_manager, GameManager.HUMAN_ID)

	ai_controllers = []
	for i in range(player_configs.size()):
		if player_configs[i].get("is_ai", false):
			var ai := AIController.new()
			ai.setup(world, i)
			add_child(ai)
			ai_controllers.append(ai)


## Two players keep the original fixed diagonal corners (so existing debug/
## --simulate tooling that hardcodes HUMAN_START keeps working unchanged);
## 3-8 players are arranged in a ring around the map center, with the human
## always at index 0.
func _compute_base_positions(count: int) -> Array:
	if count <= 2:
		var positions: Array = [HUMAN_START]
		if count == 2:
			positions.append(MAP_SIZE - HUMAN_START)
		return positions
	var center: Vector2 = MAP_SIZE / 2.0
	var radius: float = min(MAP_SIZE.x, MAP_SIZE.y) * 0.38
	var positions: Array = []
	for i in range(count):
		var ang: float = TAU * float(i) / float(count) - PI / 2.0
		positions.append(center + Vector2(cos(ang), sin(ang)) * radius)
	return positions


## Carves lake tiles now that every base position is known (one lake blob
## near each base, plus one contested lake in the map's center), and
## registers the resulting water grid with the ground renderer + GameManager.
func _finalize_map(base_positions: Array) -> void:
	var center: Vector2 = MAP_SIZE / 2.0
	for pos in base_positions:
		map_gen.reserve_base_area(pos)
	var lake_specs: Array = []
	for pos in base_positions:
		var away_from_center: Vector2 = (pos - center)
		var offset: Vector2 = away_from_center.normalized() * 220.0 if away_from_center.length() > 1.0 else Vector2(-160, 420)
		lake_specs.append({"seed_world": pos + offset, "size": 28})
	lake_specs.append({"seed_world": center + Vector2(-400, 400), "size": 55})
	map_gen.generate_water(lake_specs)
	ground.set_water_cells(map_gen.water_cells, MapGenerator.TILE_SIZE)
	GameManager.register_grid(MapGenerator.TILE_SIZE, map_gen.water_cells)


func _spawn_start_base(player_id: int, pos: Vector2) -> void:
	var tc := RTSBuilding.new()
	world.add_child(tc)
	tc.global_position = pos
	tc.setup("town_center", player_id, false)

	for i in range(3):
		var v := RTSUnit.new()
		world.add_child(v)
		var ang: float = TAU * float(i) / 3.0
		v.global_position = pos + Vector2(cos(ang), sin(ang)) * 70.0
		v.setup("villager", player_id)


## Resources are grown as grid-aligned clumps (see MapGenerator): one of
## each type guaranteed near every base, the rest -- trees included, as
## full forests -- scattered across the whole map.
func _scatter_resources() -> void:
	var placements: Array = map_gen.generate_resources(_base_positions)
	for p in placements:
		var pos: Vector2 = map_gen.cell_to_world(p.cell)
		var node := RTSResourceNode.new()
		world.add_child(node)
		node.global_position = pos
		node.setup(p.type)
