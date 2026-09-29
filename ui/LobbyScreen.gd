extends CanvasLayer
class_name LobbyScreen
## Pre-match lobby: pick your civilization and team, add up to 8 total
## players (yourself plus scripted AI opponents), and preview game rules /
## map settings (currently placeholders -- there's only one map, and rules
## are a "coming soon" slot for a future update).

signal match_configured(player_configs: Array)

const MAX_PLAYERS := 8
const MIN_PLAYERS := 2
const TEAM_COUNT := 8

var _civ_ids: Array = []
var _rows: Array = [] # Array[Dictionary] -- one per player row, index 0 = human
var _rows_box: VBoxContainer
var _add_button: Button
var _info_label: Label
var _start_button: Button


func _ready() -> void:
	layer = 50
	_civ_ids = GameData.CIV_DATA.keys()

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.05, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.anchor_left = 0.5
	outer.anchor_right = 0.5
	outer.anchor_top = 0.5
	outer.anchor_bottom = 0.5
	outer.offset_left = -450
	outer.offset_right = 450
	outer.offset_top = -320
	outer.offset_bottom = 320
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)

	var title := Label.new()
	title.text = "RTSspoof\nMatch Setup"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)

	columns.add_child(_build_left_panel())
	columns.add_child(_build_right_panel())

	_start_button = Button.new()
	_start_button.text = "Start Match"
	_start_button.custom_minimum_size = Vector2(900, 44)
	_start_button.pressed.connect(_on_start_pressed)
	outer.add_child(_start_button)

	var hint := Label.new()
	hint.text = "Add up to 8 players total, assign teams (same team = allies), then Start Match."
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.8, 0.8, 0.8)
	outer.add_child(hint)

	# Default lineup: you + one AI opponent, each on their own team (FFA-style
	# by default; the team dropdowns let players group up instead).
	_add_row(true)
	_add_row(false)


func _build_left_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_constant_override("separation", 8)

	var header := Label.new()
	header.text = "Players"
	header.add_theme_font_size_override("font_size", 18)
	panel.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 400)
	panel.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

	_add_button = Button.new()
	_add_button.text = "+ Add AI Player"
	_add_button.pressed.connect(_on_add_ai_pressed)
	panel.add_child(_add_button)

	_info_label = Label.new()
	_info_label.text = "Click the \"i\" next to a civilization's name to see its bonus here."
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_label.custom_minimum_size = Vector2(560, 50)
	_info_label.modulate = Color(0.85, 0.85, 0.6)
	panel.add_child(_info_label)

	return panel


func _build_right_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_constant_override("separation", 8)

	var rules_header := Label.new()
	rules_header.text = "Game Rules"
	rules_header.add_theme_font_size_override("font_size", 18)
	panel.add_child(rules_header)

	var rules_note := Label.new()
	rules_note.text = "Coming soon -- victory conditions and match settings will be configurable here in a future update."
	rules_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	rules_note.custom_minimum_size = Vector2(280, 0)
	rules_note.modulate = Color(0.7, 0.7, 0.7)
	panel.add_child(rules_note)

	var sep := HSeparator.new()
	panel.add_child(sep)

	var map_header := Label.new()
	map_header.text = "Map"
	map_header.add_theme_font_size_override("font_size", 18)
	panel.add_child(map_header)

	var map_option := OptionButton.new()
	map_option.add_item("Grasslands & Lakes")
	map_option.selected = 0
	map_option.disabled = true # only one map exists right now
	panel.add_child(map_option)

	var map_note := Label.new()
	map_note.text = "Only one map is available right now; more may be added later."
	map_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	map_note.custom_minimum_size = Vector2(280, 0)
	map_note.add_theme_font_size_override("font_size", 12)
	map_note.modulate = Color(0.6, 0.6, 0.6)
	panel.add_child(map_note)

	return panel


func _add_row(is_human: bool) -> void:
	var index: int = _rows.size()
	var default_civ: String = _civ_ids[index % _civ_ids.size()]

	var row: Dictionary = {
		"is_human": is_human,
		"civ": default_civ,
		"container": null,
		"civ_button": null,
		"dropdown": null,
		"team_option": null,
		"remove_button": null,
	}

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	container.add_child(line)

	var name_label := Label.new()
	name_label.text = "You" if is_human else "AI"
	name_label.custom_minimum_size = Vector2(50, 0)
	line.add_child(name_label)

	var civ_button := Button.new()
	civ_button.custom_minimum_size = Vector2(210, 32)
	line.add_child(civ_button)
	row["civ_button"] = civ_button

	var team_option := OptionButton.new()
	for t in range(TEAM_COUNT):
		team_option.add_item("Team %d" % (t + 1))
	team_option.selected = index % TEAM_COUNT
	team_option.custom_minimum_size = Vector2(110, 32)
	line.add_child(team_option)
	row["team_option"] = team_option

	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.custom_minimum_size = Vector2(80, 32)
	remove_button.disabled = is_human
	remove_button.visible = not is_human
	line.add_child(remove_button)
	row["remove_button"] = remove_button

	var dropdown := VBoxContainer.new()
	dropdown.visible = false
	dropdown.add_theme_constant_override("separation", 2)
	container.add_child(dropdown)
	row["dropdown"] = dropdown

	for civ_id in _civ_ids:
		var civ_line := HBoxContainer.new()
		var civ: Dictionary = GameData.CIV_DATA[civ_id]
		var pick_button := Button.new()
		pick_button.text = civ.get("display_name", civ_id)
		pick_button.custom_minimum_size = Vector2(190, 28)
		pick_button.flat = true
		var captured_civ: String = civ_id
		pick_button.pressed.connect(func() -> void: _select_civ(row, captured_civ))
		civ_line.add_child(pick_button)

		var info_button := Button.new()
		info_button.text = "i"
		info_button.custom_minimum_size = Vector2(24, 24)
		info_button.tooltip_text = "Show info about %s" % civ.get("display_name", civ_id)
		info_button.pressed.connect(func() -> void: _show_civ_info(captured_civ))
		civ_line.add_child(info_button)

		dropdown.add_child(civ_line)

	civ_button.pressed.connect(func() -> void: dropdown.visible = not dropdown.visible)
	remove_button.pressed.connect(func() -> void: _remove_row(row))

	_rows_box.add_child(container)
	row["container"] = container
	_rows.append(row)

	_select_civ(row, default_civ)
	_update_add_button()


func _select_civ(row: Dictionary, civ_id: String) -> void:
	row["civ"] = civ_id
	var civ: Dictionary = GameData.CIV_DATA.get(civ_id, {})
	row["civ_button"].text = "Civ: %s" % civ.get("display_name", civ_id)
	row["dropdown"].visible = false


func _show_civ_info(civ_id: String) -> void:
	var civ: Dictionary = GameData.CIV_DATA.get(civ_id, {})
	_info_label.text = "%s -- %s" % [civ.get("display_name", civ_id), civ.get("bonus_text", "")]


func _remove_row(row: Dictionary) -> void:
	if row["is_human"] or _rows.size() <= MIN_PLAYERS:
		return
	_rows.erase(row)
	row["container"].queue_free()
	_renumber_rows()
	_update_add_button()


func _renumber_rows() -> void:
	var ai_count := 0
	for row in _rows:
		if not row["is_human"]:
			ai_count += 1
			var line: HBoxContainer = row["container"].get_child(0)
			var name_label: Label = line.get_child(0)
			name_label.text = "AI %d" % ai_count


func _update_add_button() -> void:
	_add_button.disabled = _rows.size() >= MAX_PLAYERS


func _on_add_ai_pressed() -> void:
	if _rows.size() < MAX_PLAYERS:
		_add_row(false)


func _on_start_pressed() -> void:
	var configs: Array = []
	for row in _rows:
		configs.append({
			"civ": row["civ"],
			"team": row["team_option"].selected,
			"is_ai": not row["is_human"],
		})
	match_configured.emit(configs)
