extends Node
## Match/player state coordinator. Autoloaded as "GameManager".

const HUMAN_ID := 0
const AI_ID := 1

var players: Array = [] # Array[PlayerState]
var match_started: bool = false
var game_over: bool = false

## Water tile grid for the current map. Registered by Main.gd once the map
## is generated (see MapGenerator); queried by PlayerState.gather_multiplier()
## for water-adjacency bonuses (e.g. the Egyptian farm bonus) and by the AI
## for farm placement.
var grid_tile_size: float = 60.0
var water_cells: Dictionary = {} # Vector2i -> true
const WATER_PROXIMITY_TILES := 3

signal match_began
signal game_ended(winner_id: int)


func start_match(human_civ: String, forced_ai_civ: String = "") -> void:
	var ai_civ: String = forced_ai_civ if forced_ai_civ != "" else GameData.random_other_civ(human_civ)
	players = []
	players.append(PlayerState.new(HUMAN_ID, human_civ, false))
	players.append(PlayerState.new(AI_ID, ai_civ, true))
	match_started = true
	game_over = false
	match_began.emit()


func register_grid(tile_size: float, cells: Dictionary) -> void:
	grid_tile_size = tile_size
	water_cells = cells


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / grid_tile_size)), int(floor(pos.y / grid_tile_size)))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * grid_tile_size, (cell.y + 0.5) * grid_tile_size)


func is_near_water(pos: Vector2) -> bool:
	var c: Vector2i = world_to_cell(pos)
	for dy in range(-WATER_PROXIMITY_TILES, WATER_PROXIMITY_TILES + 1):
		for dx in range(-WATER_PROXIMITY_TILES, WATER_PROXIMITY_TILES + 1):
			if water_cells.has(Vector2i(c.x + dx, c.y + dy)):
				return true
	return false


## Spirals outward from `from_pos` to find the nearest non-water tile that
## still counts as "near water" -- lets the AI place a farm for the water
## bonus without needing to know lake geometry. Returns Vector2.INF if none
## is found within range.
func find_land_near_water(from_pos: Vector2, max_radius_cells: int = 25) -> Vector2:
	var start: Vector2i = world_to_cell(from_pos)
	for r in range(1, max_radius_cells):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var c := Vector2i(start.x + dx, start.y + dy)
				if water_cells.has(c):
					continue
				var pos: Vector2 = cell_to_world(c)
				if is_near_water(pos):
					return pos
	return Vector2.INF


func get_player(player_id: int) -> PlayerState:
	if player_id >= 0 and player_id < players.size():
		return players[player_id]
	return null


func enemy_of(player_id: int) -> int:
	return AI_ID if player_id == HUMAN_ID else HUMAN_ID


func check_defeat() -> void:
	if game_over or not match_started:
		return
	for p in players:
		if p.buildings.is_empty() and p.units.is_empty():
			game_over = true
			var winner: int = enemy_of(p.player_id)
			game_ended.emit(winner)
			return
