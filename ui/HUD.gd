extends CanvasLayer
class_name HUD
## Resource bar, selection/build/train panel and game-over banner.

var selection_manager: SelectionManager
var player_id: int = 0

var _res_labels: Dictionary = {}
var _pop_label: Label
var _action_box: HBoxContainer
var _info_label: Label
var _bonus_label: Label
var _game_over_label: Label


func setup(sel_mgr: SelectionManager, p_player_id: int) -> void:
	selection_manager = sel_mgr
	player_id = p_player_id
	selection_manager.selection_changed.connect(_refresh_panel)
	GameManager.game_ended.connect(_on_game_ended)
	var ps: PlayerState = GameManager.get_player(player_id)
	if ps:
		ps.resources_changed.connect(_refresh_resources)
		ps.population_changed.connect(_refresh_resources)
	_build_ui()
	_refresh_resources()
	_refresh_panel()


func _build_ui() -> void:
	var top := PanelContainer.new()
	top.anchor_left = 0.0
	top.anchor_top = 0.0
	top.anchor_right = 1.0
	top.anchor_bottom = 0.0
	top.offset_bottom = 44
	add_child(top)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	top.add_child(hbox)
	for res_type in GameData.RESOURCE_TYPES:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)
		hbox.add_child(lbl)
		_res_labels[res_type] = lbl
	_pop_label = Label.new()
	_pop_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(_pop_label)

	_bonus_label = Label.new()
	_bonus_label.add_theme_font_size_override("font_size", 13)
	_bonus_label.anchor_left = 0.0
	_bonus_label.anchor_top = 0.0
	_bonus_label.offset_top = 46
	_bonus_label.offset_left = 8
	var ps: PlayerState = GameManager.get_player(player_id)
	if ps:
		var civ: Dictionary = ps.civ_data()
		_bonus_label.text = "%s: %s" % [civ.get("display_name", ""), civ.get("bonus_text", "")]
	add_child(_bonus_label)

	var bottom := PanelContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -96
	add_child(bottom)

	var vbox := VBoxContainer.new()
	bottom.add_child(vbox)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_info_label)
	_action_box = HBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_action_box)

	_game_over_label = Label.new()
	_game_over_label.add_theme_font_size_override("font_size", 44)
	_game_over_label.anchor_left = 0.5
	_game_over_label.anchor_right = 0.5
	_game_over_label.anchor_top = 0.35
	_game_over_label.anchor_bottom = 0.35
	_game_over_label.offset_left = -180
	_game_over_label.offset_right = 180
	_game_over_label.offset_top = -30
	_game_over_label.offset_bottom = 30
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.visible = false
	add_child(_game_over_label)


func _refresh_resources() -> void:
	var ps: PlayerState = GameManager.get_player(player_id)
	if not ps:
		return
	for res_type in GameData.RESOURCE_TYPES:
		var lbl: Label = _res_labels[res_type]
		lbl.text = "%s: %d" % [String(res_type).capitalize(), int(ps.resources[res_type])]
	_pop_label.text = "Pop: %d / %d" % [ps.population_used, ps.population_cap]


func _refresh_panel() -> void:
	for c in _action_box.get_children():
		c.queue_free()
	if not selection_manager.selected_units.is_empty():
		_show_unit_actions(selection_manager.selected_units)
	elif selection_manager.selected_building != null:
		_show_building_actions(selection_manager.selected_building)
	else:
		_info_label.text = "No selection"


func _show_unit_actions(units: Array) -> void:
	var type_counts: Dictionary = {}
	for u in units:
		if is_instance_valid(u):
			type_counts[u.unit_type] = type_counts.get(u.unit_type, 0) + 1
	var parts: Array = []
	for t in type_counts.keys():
		var dn: String = GameData.get_unit_stats(t).get("display_name", t)
		parts.append("%s x%d" % [dn, type_counts[t]])
	_info_label.text = ", ".join(parts)

	var can_build_any := false
	for u in units:
		if is_instance_valid(u) and u.can_build_flag:
			can_build_any = true
			break
	if can_build_any:
		var house_cost: Dictionary = GameData.get_building_stats("house").get("cost", {})
		var barracks_cost: Dictionary = GameData.get_building_stats("barracks").get("cost", {})
		var farm_cost: Dictionary = GameData.get_building_stats("farm").get("cost", {})
		_add_button("Build House (%s)" % _cost_str(house_cost), func() -> void: selection_manager.start_placement("house"))
		_add_button("Build Barracks (%s)" % _cost_str(barracks_cost), func() -> void: selection_manager.start_placement("barracks"))
		_add_button("Build Farm (%s)" % _cost_str(farm_cost), func() -> void: selection_manager.start_placement("farm"))


func _show_building_actions(building) -> void:
	if not is_instance_valid(building):
		_info_label.text = "No selection"
		return
	var stats: Dictionary = GameData.get_building_stats(building.building_type)
	var dn: String = stats.get("display_name", building.building_type)
	if building.under_construction:
		_info_label.text = "%s (under construction)" % dn
		return
	if building.is_farm:
		var near_water: bool = GameManager.is_near_water(building.global_position)
		var water_note: String = "  (near water)" if near_water else "  (build closer to water for the Egyptian bonus)"
		_info_label.text = "%s   Food %d/%d%s" % [dn, int(building.food_remaining), int(building.food_max), water_note if building.civ_id == "egyptian" else ""]
		return
	_info_label.text = "%s   HP %d/%d" % [dn, int(building.hp), int(building.max_hp)]
	var ps: PlayerState = GameManager.get_player(player_id)
	if not ps:
		return
	var trainable: Array = GameData.trainable_units_for_building(building.building_type, ps.civ_id)
	for unit_type in trainable:
		var captured_type: String = unit_type
		var u_stats: Dictionary = GameData.get_unit_stats(captured_type)
		var label_text: String = "Train %s (%s)" % [u_stats.get("display_name", captured_type), _cost_str(u_stats.get("cost", {}))]
		var captured_building = building
		_add_button(label_text, func() -> void: captured_building.queue_train(captured_type))


func _cost_str(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost.keys():
		parts.append("%d %s" % [int(cost[k]), String(k).capitalize()])
	if parts.is_empty():
		return "free"
	return ", ".join(parts)


func _add_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	_action_box.add_child(btn)


func _on_game_ended(winner_id: int) -> void:
	_game_over_label.visible = true
	if winner_id == player_id:
		_game_over_label.text = "VICTORY!"
		_game_over_label.modulate = Color(0.35, 1.0, 0.35)
	else:
		_game_over_label.text = "DEFEAT"
		_game_over_label.modulate = Color(1.0, 0.35, 0.35)
