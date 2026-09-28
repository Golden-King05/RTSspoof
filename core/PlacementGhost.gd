extends Node2D
class_name PlacementGhost
## Translucent preview square shown while placing a building.

var building_type: String = ""
var radius: float = 30.0
var valid: bool = true


func _draw() -> void:
	var col: Color = Color(0.25, 0.9, 0.3, 0.35) if valid else Color(0.9, 0.2, 0.2, 0.35)
	var line_col: Color = Color(0.25, 0.9, 0.3, 0.9) if valid else Color(0.9, 0.2, 0.2, 0.9)
	var r := radius
	draw_rect(Rect2(-r, -r, r * 2, r * 2), col)
	draw_rect(Rect2(-r, -r, r * 2, r * 2), line_col, false, 2.0)
