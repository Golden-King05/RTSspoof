extends Node
## Match/player state coordinator. Autoloaded as "GameManager".

const HUMAN_ID := 0
const AI_ID := 1

var players: Array = [] # Array[PlayerState]
var match_started: bool = false
var game_over: bool = false

## Water bodies for the current map, as {"center": Vector2, "radius": float}.
## Registered by Main.gd once the map is generated; queried by
## PlayerState.gather_multiplier() for water-adjacency bonuses (e.g. the
## Egyptian farm bonus).
var water_regions: Array = []
const WATER_PROXIMITY_MARGIN := 160.0

signal match_began
signal game_ended(winner_id: int)


func start_match(human_civ: String) -> void:
	var ai_civ: String = GameData.other_civ(human_civ)
	players = []
	players.append(PlayerState.new(HUMAN_ID, human_civ, false))
	players.append(PlayerState.new(AI_ID, ai_civ, true))
	match_started = true
	game_over = false
	match_began.emit()


func register_water_regions(regions: Array) -> void:
	water_regions = regions


func is_near_water(pos: Vector2) -> bool:
	for region in water_regions:
		if pos.distance_to(region.center) <= region.radius + WATER_PROXIMITY_MARGIN:
			return true
	return false


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
