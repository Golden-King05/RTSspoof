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
var ai_controller: AIController
var civ_select: CivSelectScreen
var main_menu: MainMenu
var map_gen: MapGenerator

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

	var ground := Ground.new()
	ground.setup(MAP_SIZE)
	world.add_child(ground)

	var map_rng := RandomNumberGenerator.new()
	map_rng.randomize()
	map_gen = MapGenerator.new(MAP_SIZE, map_rng)
	map_gen.reserve_base_area(HUMAN_START)
	map_gen.reserve_base_area(MAP_SIZE - HUMAN_START)
	map_gen.generate_water([
		{"seed_world": HUMAN_START + Vector2(-160, 420), "size": 28},
		{"seed_world": (MAP_SIZE - HUMAN_START) + Vector2(160, -420), "size": 28},
		{"seed_world": MAP_SIZE / 2.0 + Vector2(-400, 400), "size": 55},
	])
	ground.set_water_cells(map_gen.water_cells, MapGenerator.TILE_SIZE)
	GameManager.register_grid(MapGenerator.TILE_SIZE, map_gen.water_cells)

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
	civ_select = CivSelectScreen.new()
	add_child(civ_select)
	civ_select.civ_chosen.connect(_on_civ_chosen)


func _parse_debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autostart="):
			call_deferred("_on_civ_chosen", a.substr(len("--autostart=")))
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


func _on_civ_chosen(human_civ: String) -> void:
	if is_instance_valid(main_menu):
		main_menu.queue_free()
	if is_instance_valid(civ_select):
		civ_select.queue_free()
	GameManager.start_match(human_civ, _forced_ai_civ)

	fog = FogOfWar.new()
	fog.setup(MAP_SIZE, GameManager.HUMAN_ID)
	world.add_child(fog)

	_scatter_resources()
	_spawn_start_base(GameManager.HUMAN_ID, HUMAN_START)
	_spawn_start_base(GameManager.AI_ID, MAP_SIZE - HUMAN_START)

	camera.global_position = HUMAN_START

	hud.setup(selection_manager, GameManager.HUMAN_ID)

	ai_controller = AIController.new()
	ai_controller.setup(world, GameManager.AI_ID)
	add_child(ai_controller)


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
	var placements: Array = map_gen.generate_resources([HUMAN_START, MAP_SIZE - HUMAN_START])
	for p in placements:
		var pos: Vector2 = map_gen.cell_to_world(p.cell)
		var node := RTSResourceNode.new()
		world.add_child(node)
		node.global_position = pos
		node.setup(p.type)
