extends RefCounted
class_name MapGenerator
## Builds the map's terrain grid: which tiles are water, and which tiles
## hold which resource, as procedurally-grown clumps rather than fixed
## circles. Everything here works in grid cells (Vector2i); callers convert
## to world positions with cell_to_world().

const TILE_SIZE := 60.0

## count = how many separate clumps of this type exist on the map (one of
## them is guaranteed near each base; the rest are scattered). Trees grow
## as much bigger clumps than other resources so they read as forests.
const RESOURCE_CLUMPS := {
	"tree": {"count": 5, "min_size": 10, "max_size": 20},
	"gold_mine": {"count": 5, "min_size": 2, "max_size": 4},
	"stone_mine": {"count": 5, "min_size": 2, "max_size": 4},
	"berry_bush": {"count": 5, "min_size": 3, "max_size": 5},
}

## Angle (radians) each resource type prefers around a base, so the four
## guaranteed starting clumps spread out instead of overlapping.
const BASE_ANGLE := {
	"tree": -2.4,
	"gold_mine": -0.6,
	"stone_mine": 2.4,
	"berry_bush": 0.6,
}

const BASE_CLUMP_MIN_DIST_TILES := 4.0
const BASE_CLUMP_MAX_DIST_TILES := 8.0
const MIN_DIST_FROM_ANY_BASE := 220.0

var grid_w: int
var grid_h: int
var water_cells: Dictionary = {} # Vector2i -> true
var occupied_cells: Dictionary = {} # Vector2i -> true (water, a base, or a placed resource)
var rng: RandomNumberGenerator


func _init(map_size: Vector2, p_rng: RandomNumberGenerator) -> void:
	grid_w = int(map_size.x / TILE_SIZE)
	grid_h = int(map_size.y / TILE_SIZE)
	rng = p_rng


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE_SIZE)), int(floor(pos.y / TILE_SIZE)))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_w and cell.y < grid_h


## Keeps water/resources from ever growing into a starting base's footprint.
func reserve_base_area(base_pos: Vector2, radius_tiles: int = 3) -> void:
	var base_cell: Vector2i = world_to_cell(base_pos)
	for dy in range(-radius_tiles, radius_tiles + 1):
		for dx in range(-radius_tiles, radius_tiles + 1):
			occupied_cells[Vector2i(base_cell.x + dx, base_cell.y + dy)] = true


## `lake_specs`: Array of {"seed_world": Vector2, "size": int}.
func generate_water(lake_specs: Array) -> void:
	for spec in lake_specs:
		var seed_cell: Vector2i = world_to_cell(spec.seed_world)
		var blob: Array = _grow_blob(seed_cell, spec.size)
		for c in blob:
			water_cells[c] = true
			occupied_cells[c] = true


## Returns Array of {"type": String, "cell": Vector2i}, one entry per
## resource instance to spawn -- one clump of each type guaranteed near
## every position in `bases`, the rest scattered across the whole map.
func generate_resources(bases: Array) -> Array:
	var placements: Array = []
	for res_type in RESOURCE_CLUMPS.keys():
		var config: Dictionary = RESOURCE_CLUMPS[res_type]
		var remaining: int = config.count

		for base_pos in bases:
			if remaining <= 0:
				continue
			var seed_cell: Vector2i = _base_clump_seed(base_pos, res_type)
			var size: int = rng.randi_range(config.min_size, config.max_size)
			for c in _grow_blob(seed_cell, size):
				occupied_cells[c] = true
				placements.append({"type": res_type, "cell": c})
			remaining -= 1

		for i in range(remaining):
			var seed_cell = _random_free_seed(bases)
			if seed_cell == null:
				continue
			var size: int = rng.randi_range(config.min_size, config.max_size)
			for c in _grow_blob(seed_cell, size):
				occupied_cells[c] = true
				placements.append({"type": res_type, "cell": c})
	return placements


func _grow_blob(seed_cell: Vector2i, size: int) -> Array:
	var claimed: Array = []
	var claimed_set: Dictionary = {}
	var frontier: Array = [seed_cell]
	while claimed.size() < size and not frontier.is_empty():
		var idx: int = rng.randi() % frontier.size()
		var cell: Vector2i = frontier[idx]
		frontier.remove_at(idx)
		if claimed_set.has(cell) or occupied_cells.has(cell) or not in_bounds(cell):
			continue
		claimed_set[cell] = true
		claimed.append(cell)
		for n in _neighbors(cell):
			if not claimed_set.has(n):
				frontier.append(n)
	return claimed


func _neighbors(cell: Vector2i) -> Array:
	return [
		Vector2i(cell.x + 1, cell.y), Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1), Vector2i(cell.x, cell.y - 1),
	]


func _base_clump_seed(base_pos: Vector2, res_type: String) -> Vector2i:
	var base_cell: Vector2i = world_to_cell(base_pos)
	var angle: float = float(BASE_ANGLE.get(res_type, 0.0)) + rng.randf_range(-0.3, 0.3)
	var dist: float = rng.randf_range(BASE_CLUMP_MIN_DIST_TILES, BASE_CLUMP_MAX_DIST_TILES)
	var offset_x: int = int(round(cos(angle) * dist))
	var offset_y: int = int(round(sin(angle) * dist))
	return Vector2i(base_cell.x + offset_x, base_cell.y + offset_y)


func _random_free_seed(bases: Array):
	for attempt in range(40):
		var cell := Vector2i(rng.randi_range(2, grid_w - 3), rng.randi_range(2, grid_h - 3))
		if occupied_cells.has(cell):
			continue
		var too_close := false
		var world_pos: Vector2 = cell_to_world(cell)
		for base_pos in bases:
			if world_pos.distance_to(base_pos) < MIN_DIST_FROM_ANY_BASE:
				too_close = true
				break
		if not too_close:
			return cell
	return null
