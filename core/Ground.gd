extends Node2D
class_name Ground
## Procedural checkerboard terrain sized to the world's tile grid, with
## water drawn as whole grid tiles (not smooth shapes) so everything reads
## as sitting on the same grid.

var map_size: Vector2 = Vector2(3000, 3000)
var tile_size: float = 60.0
var water_cells: Dictionary = {} # Vector2i -> true


func setup(p_map_size: Vector2) -> void:
	map_size = p_map_size
	queue_redraw()


## Water tiles are impassable (one NavigationObstacle2D per tile, snapped
## to the tile's exact bounds) and drawn on top of the grass grid.
func set_water_cells(cells: Dictionary, p_tile_size: float) -> void:
	water_cells = cells
	tile_size = p_tile_size
	var half: float = tile_size / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)
	])
	for cell in water_cells.keys():
		var obstacle := NavigationObstacle2D.new()
		obstacle.position = Vector2((cell.x + 0.5) * tile_size, (cell.y + 0.5) * tile_size)
		obstacle.vertices = square
		obstacle.avoidance_enabled = true
		add_child(obstacle)
	queue_redraw()


func _draw() -> void:
	var base := Color(0.30, 0.47, 0.22)
	var alt := Color(0.33, 0.50, 0.24)
	draw_rect(Rect2(Vector2.ZERO, map_size), base)
	var cols: int = int(ceil(map_size.x / tile_size))
	var rows: int = int(ceil(map_size.y / tile_size))
	for y in range(rows):
		for x in range(cols):
			if (x + y) % 2 == 0:
				continue
			draw_rect(Rect2(Vector2(x * tile_size, y * tile_size), Vector2(tile_size, tile_size)), alt)

	var water_col := Color(0.20, 0.42, 0.68)
	var shore_col := Color(0.75, 0.70, 0.52)
	# Shore: any grass tile touching a water tile, drawn before the water
	# tiles themselves so only the outer ring stays sand-colored.
	for cell in water_cells.keys():
		for n in [Vector2i(cell.x + 1, cell.y), Vector2i(cell.x - 1, cell.y), Vector2i(cell.x, cell.y + 1), Vector2i(cell.x, cell.y - 1)]:
			if not water_cells.has(n):
				draw_rect(Rect2(Vector2(n.x * tile_size, n.y * tile_size), Vector2(tile_size, tile_size)), shore_col)
	for cell in water_cells.keys():
		draw_rect(Rect2(Vector2(cell.x * tile_size, cell.y * tile_size), Vector2(tile_size, tile_size)), water_col)

	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.12, 0.12, 0.12), false, 6.0)
