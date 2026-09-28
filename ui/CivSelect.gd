extends CanvasLayer
class_name CivSelectScreen
## Pre-match screen: pick a civilization from GameData.CIV_DATA.

signal civ_chosen(civ_id: String)


func _ready() -> void:
	layer = 50
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.05, 0.88)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -230
	vbox.offset_right = 230
	vbox.offset_top = -230
	vbox.offset_bottom = 230
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	var title := Label.new()
	title.text = "RTSspoof\nChoose Your Civilization"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for civ_id in GameData.CIV_DATA.keys():
		var civ: Dictionary = GameData.CIV_DATA[civ_id]
		var btn := Button.new()
		btn.text = "Play as %s" % civ.get("display_name", civ_id)
		btn.custom_minimum_size = Vector2(440, 42)
		var captured_id: String = civ_id
		btn.pressed.connect(func() -> void: civ_chosen.emit(captured_id))
		vbox.add_child(btn)

		var desc := Label.new()
		desc.text = civ.get("bonus_text", "")
		desc.add_theme_font_size_override("font_size", 13)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(440, 0)
		vbox.add_child(desc)

	var hint := Label.new()
	hint.text = "WASD/arrows or edge-scroll to pan, wheel to zoom, drag to box-select, right-click to move/attack/gather."
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(hint)
