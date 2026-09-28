extends Node2D
class_name RTSResourceNode
## A harvestable world resource: tree, gold mine, stone mine or berry bush.
## Picking is done by distance query (see SelectionManager), so this needs
## no physics body -- only a NavigationObstacle2D so units steer around it.

var node_type: String = "tree"
var resource_type: String = "wood"
var amount: float = 100.0
var max_amount: float = 100.0
var radius: float = 14.0
var gather_multiplier: float = 1.0

const COLORS := {
	"wood": Color(0.20, 0.45, 0.16),
	"gold": Color(0.85, 0.72, 0.15),
	"stone": Color(0.55, 0.55, 0.58),
	"food": Color(0.75, 0.15, 0.20),
}

var _obstacle: NavigationObstacle2D


func setup(type_id: String) -> void:
	node_type = type_id
	var stats: Dictionary = GameData.RESOURCE_NODE_STATS.get(type_id, {})
	resource_type = stats.get("resource_type", "wood")
	amount = stats.get("amount", 100)
	max_amount = amount
	radius = stats.get("radius", 14.0)
	gather_multiplier = stats.get("gather_multiplier", 1.0)

	_obstacle = NavigationObstacle2D.new()
	_obstacle.radius = radius * 0.85
	_obstacle.avoidance_enabled = true
	add_child(_obstacle)

	add_to_group("resources")
	queue_redraw()


func is_depleted() -> bool:
	return amount <= 0.0


## Removes up to `requested` units of the resource and returns how much was granted.
func harvest(requested: float) -> float:
	var granted: float = min(requested, amount)
	amount -= granted
	queue_redraw()
	if amount <= 0.0:
		call_deferred("queue_free")
	return granted


func _draw() -> void:
	var col: Color = COLORS.get(resource_type, Color.WHITE)
	var fill_ratio: float = 1.0 if max_amount <= 0.0 else clamp(amount / max_amount, 0.0, 1.0)
	match node_type:
		"tree":
			draw_circle(Vector2.ZERO, radius, col.darkened(0.1))
			draw_circle(Vector2(-radius * 0.15, -radius * 0.1), radius * 0.7, col)
		"berry_bush":
			draw_circle(Vector2.ZERO, radius, Color(0.16, 0.35, 0.12))
			for i in range(5):
				var ang: float = TAU * float(i) / 5.0
				draw_circle(Vector2(cos(ang), sin(ang)) * radius * 0.55, radius * 0.32, col)
		_:
			var points := PackedVector2Array()
			var sides := 6
			for i in range(sides):
				var ang: float = TAU * float(i) / sides
				points.append(Vector2(cos(ang), sin(ang)) * radius)
			draw_colored_polygon(points, col)
			draw_polyline(points + PackedVector2Array([points[0]]), col.darkened(0.35), 2.0)
	# depletion ring
	draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU * fill_ratio, 24, Color(1, 1, 1, 0.6), 2.0)
