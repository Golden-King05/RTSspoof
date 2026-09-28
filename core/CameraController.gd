extends Camera2D
class_name RTSCamera
## RTS-style camera: WASD/arrow pan, edge-of-screen scroll, wheel zoom.

@export var pan_speed: float = 900.0
@export var edge_margin: float = 18.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.2
@export var zoom_step: float = 0.1

var map_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(3000, 3000))
var edge_scroll_enabled: bool = true


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("cam_left"):
		dir.x -= 1
	if Input.is_action_pressed("cam_right"):
		dir.x += 1
	if Input.is_action_pressed("cam_up"):
		dir.y -= 1
	if Input.is_action_pressed("cam_down"):
		dir.y += 1

	if edge_scroll_enabled and dir == Vector2.ZERO:
		var vp := get_viewport()
		if vp:
			var mouse_pos: Vector2 = vp.get_mouse_position()
			var size: Vector2 = vp.get_visible_rect().size
			if vp.get_window():
				if mouse_pos.x <= edge_margin:
					dir.x -= 1
				elif mouse_pos.x >= size.x - edge_margin:
					dir.x += 1
				if mouse_pos.y <= edge_margin:
					dir.y -= 1
				elif mouse_pos.y >= size.y - edge_margin:
					dir.y += 1

	if dir != Vector2.ZERO:
		global_position += dir.normalized() * pan_speed * zoom.x * delta
		_clamp_to_bounds()


func _clamp_to_bounds() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var half_view: Vector2 = (vp.get_visible_rect().size * zoom) / 2.0
	var min_pos: Vector2 = map_bounds.position + half_view
	var max_pos: Vector2 = map_bounds.position + map_bounds.size - half_view
	if max_pos.x < min_pos.x:
		max_pos.x = min_pos.x
	if max_pos.y < min_pos.y:
		max_pos.y = min_pos.y
	global_position.x = clamp(global_position.x, min_pos.x, max_pos.x)
	global_position.y = clamp(global_position.y, min_pos.y, max_pos.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(zoom_step)


func _zoom_by(delta_zoom: float) -> void:
	var z: float = clamp(zoom.x + delta_zoom, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	_clamp_to_bounds()
