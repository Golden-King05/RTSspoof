extends Control
class_name SelectionManager
## Owns the human player's selection, box-select, move/attack/gather/build
## command routing, and building placement.

signal selection_changed
signal building_selected(building)
signal placement_started(building_type)
signal placement_cancelled

var world_root: Node2D

var selected_units: Array = []
var selected_building = null

var build_mode: bool = false
var build_type: String = ""
var _ghost: PlacementGhost = null

var dragging: bool = false
var drag_start_world: Vector2 = Vector2.ZERO
var drag_start_screen: Vector2 = Vector2.ZERO

const DRAG_THRESHOLD := 6.0
const PICK_PAD := 8.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _group(name: String) -> Array:
	return get_tree().get_nodes_in_group(name) as Array


## SelectionManager is a Control under a CanvasLayer, so its own canvas is
## screen-space; convert the mouse to world space via the active camera's
## canvas transform instead of using get_global_mouse_position().
func _world_mouse_pos() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


func start_placement(building_type: String) -> void:
	if not GameData.BUILDING_STATS.has(building_type):
		return
	var ps: PlayerState = GameManager.get_player(GameManager.HUMAN_ID)
	if ps and not ps.building_unlocked(building_type):
		return
	build_mode = true
	build_type = building_type
	_ensure_ghost()
	placement_started.emit(building_type)


func cancel_placement() -> void:
	build_mode = false
	build_type = ""
	if _ghost:
		_ghost.visible = false
	placement_cancelled.emit()


func _ensure_ghost() -> void:
	if _ghost == null and world_root:
		_ghost = PlacementGhost.new()
		_ghost.z_index = 50
		world_root.add_child(_ghost)


func _process(_delta: float) -> void:
	if build_mode and _ghost:
		var wp: Vector2 = _world_mouse_pos()
		wp = wp.snapped(Vector2(16, 16))
		_ghost.global_position = wp
		_ghost.visible = true
		var stats: Dictionary = GameData.get_building_stats(build_type)
		_ghost.radius = stats.get("radius", 30.0)
		var ps: PlayerState = GameManager.get_player(GameManager.HUMAN_ID)
		var affordable: bool = ps.can_afford(stats.get("cost", {})) if ps else false
		var unlocked: bool = ps.building_unlocked(build_type) if ps else false
		var clear: bool = _is_location_clear(wp, _ghost.radius)
		_ghost.valid = affordable and unlocked and clear
		_ghost.queue_redraw()


func _is_location_clear(pos: Vector2, radius: float) -> bool:
	for b in _group("buildings"):
		if is_instance_valid(b) and pos.distance_to(b.global_position) < radius + b.radius + 10.0:
			return false
	for r in _group("resources"):
		if is_instance_valid(r) and pos.distance_to(r.global_position) < radius + r.radius + 10.0:
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if build_mode:
					_try_place_building()
				else:
					dragging = true
					drag_start_world = _world_mouse_pos()
					drag_start_screen = get_viewport().get_mouse_position()
			else:
				if dragging:
					dragging = false
					_finish_left_drag()
					queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if build_mode:
				cancel_placement()
			else:
				_handle_right_click(_world_mouse_pos())
	elif event is InputEventMouseMotion and dragging:
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if build_mode:
			cancel_placement()


func _try_place_building() -> void:
	if _ghost == null or not _ghost.valid or world_root == null:
		return
	var wp: Vector2 = _ghost.global_position
	var stats: Dictionary = GameData.get_building_stats(build_type)
	var ps: PlayerState = GameManager.get_player(GameManager.HUMAN_ID)
	if not ps:
		return
	ps.spend(stats.get("cost", {}))
	var b: RTSBuilding = RTSBuilding.new()
	world_root.add_child(b)
	b.global_position = wp
	b.setup(build_type, GameManager.HUMAN_ID, true)
	for u in selected_units:
		if is_instance_valid(u) and u.can_build_flag:
			u.order_construct(b)
	cancel_placement()


func _finish_left_drag() -> void:
	var screen_end: Vector2 = get_viewport().get_mouse_position()
	if screen_end.distance_to(drag_start_screen) < DRAG_THRESHOLD:
		_click_select(drag_start_world)
	else:
		_box_select(drag_start_world, _world_mouse_pos())


func _click_select(world_pos: Vector2) -> void:
	var picked = _find_entity_at(world_pos)
	_clear_selection()
	if picked != null:
		if picked.type == "unit" and picked.node.player_id == GameManager.HUMAN_ID:
			_set_selected_units([picked.node])
		elif picked.type == "building" and picked.node.player_id == GameManager.HUMAN_ID:
			selected_building = picked.node
			building_selected.emit(picked.node)
	selection_changed.emit()


func _box_select(a: Vector2, b: Vector2) -> void:
	var rect := Rect2(a, Vector2.ZERO)
	rect = rect.expand(b)
	var found: Array = []
	for u in _group("player_%d_units" % GameManager.HUMAN_ID):
		if is_instance_valid(u) and rect.has_point(u.global_position):
			found.append(u)
	_clear_selection()
	if not found.is_empty():
		_set_selected_units(found)
	selection_changed.emit()


func _set_selected_units(list: Array) -> void:
	selected_units = list
	for u in selected_units:
		u.selected = true
		u.queue_redraw()


func _clear_selection() -> void:
	for u in selected_units:
		if is_instance_valid(u):
			u.selected = false
			u.queue_redraw()
	selected_units = []
	selected_building = null


func _handle_right_click(world_pos: Vector2) -> void:
	if selected_units.is_empty():
		return
	var picked = _find_entity_at(world_pos)

	if picked != null and (picked.type == "unit" or picked.type == "building") and GameManager.is_enemy(GameManager.HUMAN_ID, picked.node.player_id):
		for u in selected_units:
			if not is_instance_valid(u):
				continue
			if u.attack > 0:
				u.order_attack(picked.node)
			else:
				u.order_move(picked.node.global_position)
		return

	if picked != null and picked.type == "resource":
		for u in selected_units:
			if not is_instance_valid(u):
				continue
			if u.can_gather_flag:
				u.order_gather(picked.node)
			else:
				u.order_move(world_pos)
		return

	if picked != null and picked.type == "building" and picked.node.player_id == GameManager.HUMAN_ID and picked.node.is_farm and not picked.node.under_construction:
		for u in selected_units:
			if not is_instance_valid(u):
				continue
			if u.can_gather_flag:
				u.order_gather(picked.node)
			else:
				u.order_move(world_pos)
		return

	if picked != null and picked.type == "building" and picked.node.player_id == GameManager.HUMAN_ID and picked.node.under_construction:
		for u in selected_units:
			if not is_instance_valid(u):
				continue
			if u.can_build_flag:
				u.order_construct(picked.node)
			else:
				u.order_move(world_pos)
		return

	var n: int = selected_units.size()
	var cols: int = max(1, int(ceil(sqrt(n))))
	for i in range(n):
		var u = selected_units[i]
		if not is_instance_valid(u):
			continue
		var offset := Vector2.ZERO
		if n > 1:
			var row: int = i / cols
			var col: int = i % cols
			var rows: int = int(ceil(float(n) / cols))
			offset = Vector2((col - (cols - 1) / 2.0) * 26.0, (row - (rows - 1) / 2.0) * 26.0)
		u.order_move(world_pos + offset)


func _find_entity_at(world_pos: Vector2):
	var best = null
	var best_dist := INF
	for u in _group("units"):
		if not is_instance_valid(u):
			continue
		var d: float = world_pos.distance_to(u.global_position)
		if d <= u.radius + PICK_PAD and d < best_dist:
			best_dist = d
			best = {"type": "unit", "node": u}
	for b in _group("buildings"):
		if not is_instance_valid(b):
			continue
		var d: float = world_pos.distance_to(b.global_position)
		if d <= b.radius + PICK_PAD and d < best_dist:
			best_dist = d
			best = {"type": "building", "node": b}
	for r in _group("resources"):
		if not is_instance_valid(r):
			continue
		var d: float = world_pos.distance_to(r.global_position)
		if d <= r.radius + PICK_PAD and d < best_dist:
			best_dist = d
			best = {"type": "resource", "node": r}
	return best


func _draw() -> void:
	if dragging:
		var start: Vector2 = drag_start_screen
		var cur: Vector2 = get_viewport().get_mouse_position()
		var rect := Rect2(start, Vector2.ZERO)
		rect = rect.expand(cur)
		draw_rect(rect, Color(0.3, 1.0, 0.3, 0.15), true)
		draw_rect(rect, Color(0.3, 1.0, 0.3, 0.9), false, 1.5)
