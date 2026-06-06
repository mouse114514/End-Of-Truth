@tool
extends Control

var timeline_entries: Array = []
var current_tick: float = 0.0
var tick_width: float = 60.0

signal tick_clicked(tick: float)
signal action_dropped(type: String, tick: float)

var _dragging: bool = false
var _hover_tick: float = -1

var _action_colors := {
	"emit": Color(0.9, 0.4, 0.2),
	"text": Color(0.8, 0.3, 0.8),
	"await": Color(0.4, 0.4, 0.4),
	"set_pattern": Color(0.2, 0.8, 0.8),
	"set_muzzle": Color(0.8, 0.8, 0.2),
	"set_dir": Color(0.2, 0.8, 0.2),
	"end_turn": Color(0.3, 0.3, 0.9),
	"end_battle": Color(0.9, 0.1, 0.1),
	"guard_choice": Color(0.6, 0.3, 0.9),
	"get_choice": Color(0.3, 0.9, 0.6),
	"if": Color(0.9, 0.7, 0.3),
	"return": Color(0.4, 0.4, 0.4),
	"stats": Color(0.7, 0.5, 0.9),
	"set_pattern_from_list": Color(0.2, 0.7, 0.7),
}

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _get_minimum_size() -> Vector2:
	var max_tick = 40
	for e in timeline_entries:
		if e is Dictionary and e.has("tick"):
			max_tick = max(max_tick, e.tick + 3)
	return Vector2(max_tick * tick_width + 80, 90)

func _draw():
	var w = get_size().x
	var h = get_size().y
	var pad_x = 40.0
	var track_h = h - 30.0
	var track_y = 15.0
	
	# Background
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.05, 0.1, 1))
	
	# Track background
	draw_rect(Rect2(pad_x, track_y, w - pad_x * 2, track_h), Color(0.1, 0.1, 0.15, 1))
	
	# Calculate total ticks
	var total_ticks = 40
	for e in timeline_entries:
		if e is Dictionary and e.has("tick"):
			total_ticks = max(total_ticks, e.tick + 3)
	
	# Draw tick lines
	for i in range(total_ticks + 1):
		var x = pad_x + i * tick_width
		if x > w - pad_x: break
		
		var is_major = i % 5 == 0
		var col = Color(0.2, 0.2, 0.25, 1) if not is_major else Color(0.35, 0.35, 0.4, 1)
		draw_line(Vector2(x, track_y), Vector2(x, track_y + track_h), col, 1)
		
		if is_major:
			var f = get_theme_font("")
			draw_string(f, Vector2(x + 2, 10), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.6))
			draw_line(Vector2(x, track_y - 3), Vector2(x, track_y), Color(0.4, 0.4, 0.5, 1), 2)
	
	# Draw tick alternating background
	for i in range(total_ticks):
		var x = pad_x + i * tick_width
		if x > w - pad_x: break
		var a = 0.04 if i % 2 == 0 else 0.02
		draw_rect(Rect2(x, track_y, tick_width, track_h), Color(0.3, 0.5, 0.9, a))
	
	# Draw action blocks
	for e in timeline_entries:
		if e is Dictionary and e.has("tick") and e.has("actions"):
			var t = e.tick
			var acts = e.actions
			if not acts is Array: continue
			for j in range(acts.size()):
				var a = acts[j]
				if not a is Dictionary: continue
				var atype = a.get("type", "?")
				var offset = a.get("offset", 0.0)
				var x = pad_x + (t + offset) * tick_width
				var y = track_y + 4 + j * 16
				var bw = min(tick_width * 0.7, 55)
				var bh = 12
				var col = _action_colors.get(atype, Color(0.5, 0.5, 0.5))
				draw_rect(Rect2(x + 1, y, bw, bh), col)
				var label = atype
				if label.length() > 6: label = label.substr(0, 5) + "."
				var f = get_theme_font("")
				draw_string(f, Vector2(x + 2, y + bh - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	
	# Draw hover indicator
	if _hover_tick >= 0:
		var hx = pad_x + _hover_tick * tick_width
		draw_line(Vector2(hx, track_y), Vector2(hx, track_y + track_h), Color(1, 1, 1, 0.3), 1)
	
	# Draw playhead
	var head_x = pad_x + current_tick * tick_width
	var pts = PackedVector2Array([Vector2(head_x, track_y - 8), Vector2(head_x - 8, track_y - 2), Vector2(head_x + 8, track_y - 2)])
	draw_colored_polygon(pts, Color(1, 1, 0, 0.9))
	draw_line(Vector2(head_x, track_y), Vector2(head_x, track_y + track_h), Color(1, 1, 0, 0.8), 2)
	var f = get_theme_font("")
	draw_string(f, Vector2(head_x + 10, track_y + 14), "%.1f" % current_tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_set_tick_from_mouse(event.position)
			else:
				_dragging = false
	elif event is InputEventMouseMotion:
		_hover_tick = _get_tick_at(event.position)
		queue_redraw()
		if _dragging:
			_set_tick_from_mouse(event.position)

func _set_tick_from_mouse(pos: Vector2):
	var pad_x = 40.0
	var t = (pos.x - pad_x) / tick_width
	t = clamp(t, 0, 999)
	current_tick = t
	tick_clicked.emit(t)
	queue_redraw()

func _get_tick_at(pos: Vector2) -> float:
	var pad_x = 40.0
	return (pos.x - pad_x) / tick_width

func _can_drop_data(_pos, data) -> bool:
	return data is Dictionary and data.has("action_type")

func _drop_data(pos, data):
	if data is Dictionary and data.has("action_type"):
		var t = _get_tick_at(pos)
		action_dropped.emit(data.action_type, t)
