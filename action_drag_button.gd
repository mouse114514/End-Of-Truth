@tool
extends Button

class_name ActionDragButton

signal drag_started(type: String)

var action_type: String = ""

func _init(t: String = ""):
	action_type = t
	text = t
	custom_minimum_size = Vector2(90, 28)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var pressed_style = _make_style(Color(0.4, 0.4, 0.6, 0.9))
	var hover_style = _make_style(Color(0.35, 0.35, 0.55, 0.9))
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("hover", hover_style)

func _make_style(col: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb

func _get_drag_data(_pos):
	# 创建拖拽预览
	var preview = ColorRect.new()
	preview.color = Color(0.3, 0.3, 0.5, 0.9)
	preview.custom_minimum_size = Vector2(80, 24)
	
	var label = Label.new()
	label.text = action_type
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	label.set_anchors_preset(Control.PRESET_CENTER)
	preview.add_child(label)
	
	set_drag_preview(preview)
	
	drag_started.emit(action_type)
	return {"action_type": action_type}

func _can_drop_data(_pos, _data) -> bool:
	return false
