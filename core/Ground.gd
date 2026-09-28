extends Node2D
class_name Ground
## Simple procedural checkerboard terrain so the map isn't a flat void.

var map_size: Vector2 = Vector2(3000, 3000)
var tile_size: float = 100.0


func setup(p_map_size: Vector2) -> void:
	map_size = p_map_size
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
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.12, 0.12, 0.12), false, 6.0)
