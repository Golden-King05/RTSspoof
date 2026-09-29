extends Button
class_name CostButton
## A Button for a build/train action with a resource cost: tints itself red
## when the player can't currently afford it, and shows a hover tooltip
## breaking the cost down with the specific short resource(s) in red.
## Godot's default tooltip is plain text and can't render color, hence the
## `_make_custom_tooltip` override.

const SHORT_COLOR := Color(1.0, 0.36, 0.36)

var cost: Dictionary = {}
var player_state: PlayerState


func refresh_afford_state() -> void:
	var can_afford: bool = cost.is_empty() or (player_state != null and player_state.can_afford(cost))
	modulate = Color(1.0, 1.0, 1.0) if can_afford else Color(1.0, 0.55, 0.55)


func _make_custom_tooltip(_for_text: String) -> Object:
	if cost.is_empty():
		return null
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.custom_minimum_size = Vector2(10, 10)
	rtl.add_theme_font_size_override("normal_font_size", 13)
	var parts: Array = []
	for res_type in cost.keys():
		var need: float = cost[res_type]
		var have: float = player_state.resources.get(res_type, 0.0) if player_state else 0.0
		var label: String = "%d %s" % [int(need), String(res_type).capitalize()]
		if player_state and have < need:
			parts.append("[color=#%s]%s[/color]" % [SHORT_COLOR.to_html(false), label])
		else:
			parts.append(label)
	rtl.text = "Cost: %s" % ", ".join(parts)
	return rtl
