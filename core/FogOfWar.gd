extends Node2D
class_name FogOfWar
## Grid-based fog of war for one player: unexplored (opaque), explored
## (dimmed) and currently visible (clear), revealed by unit/building vision.

var map_size: Vector2 = Vector2(3000, 3000)
var player_id: int = 0
var cell_size: float = 40.0
var grid_w: int = 0
var grid_h: int = 0
var visibility_grid: PackedByteArray = PackedByteArray() # 0 unexplored, 1 explored, 2 visible

var update_interval: float = 0.25
var _timer: float = 0.0
var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D


func setup(p_map_size: Vector2, p_player_id: int) -> void:
	map_size = p_map_size
	player_id = p_player_id
	grid_w = int(ceil(map_size.x / cell_size))
	grid_h = int(ceil(map_size.y / cell_size))
	visibility_grid.resize(grid_w * grid_h)

	_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 1))
	_texture = ImageTexture.create_from_image(_image)

	_sprite = Sprite2D.new()
	_sprite.texture = _texture
	_sprite.centered = false
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2(cell_size, cell_size)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

	z_index = 100
	z_as_relative = false
	_update_visibility()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_update_visibility()


func _update_visibility() -> void:
	for i in range(visibility_grid.size()):
		if visibility_grid[i] == 2:
			visibility_grid[i] = 1

	var ps: PlayerState = GameManager.get_player(player_id)
	if ps:
		for u in ps.units:
			if is_instance_valid(u):
				_reveal(u.global_position, u.vision_range)
		for b in ps.buildings:
			if is_instance_valid(b):
				_reveal(b.global_position, b.vision_range)

	_redraw_texture()


func _reveal(world_pos: Vector2, radius: float) -> void:
	var cx: int = int(world_pos.x / cell_size)
	var cy: int = int(world_pos.y / cell_size)
	var cr: int = int(ceil(radius / cell_size)) + 1
	var cr2: int = cr * cr
	for dy in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			if dx * dx + dy * dy > cr2:
				continue
			var gx: int = cx + dx
			var gy: int = cy + dy
			if gx < 0 or gy < 0 or gx >= grid_w or gy >= grid_h:
				continue
			visibility_grid[gy * grid_w + gx] = 2


func _redraw_texture() -> void:
	for y in range(grid_h):
		for x in range(grid_w):
			var v: int = visibility_grid[y * grid_w + x]
			var a: float = 1.0
			if v == 2:
				a = 0.0
			elif v == 1:
				a = 0.55
			_image.set_pixel(x, y, Color(0, 0, 0, a))
	_texture.update(_image)


func is_world_pos_visible(world_pos: Vector2) -> bool:
	var gx: int = int(world_pos.x / cell_size)
	var gy: int = int(world_pos.y / cell_size)
	if gx < 0 or gy < 0 or gx >= grid_w or gy >= grid_h:
		return false
	return visibility_grid[gy * grid_w + gx] == 2
