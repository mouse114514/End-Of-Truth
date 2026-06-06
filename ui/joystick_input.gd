extends Control

signal direction_changed(vector: Vector2)

var base: Panel
var knob: Panel
var is_dragging: bool = false
var max_dist: float = 50.0

func _ready():
	base = $Base
	knob = $Knob
	mouse_filter = MOUSE_FILTER_STOP

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				_update_knob(event.position)
			else:
				is_dragging = false
				_reset_knob()
	elif event is InputEventMouseMotion and is_dragging:
		_update_knob(event.position)

func _update_knob(local_pos):
	var center = base.size / 2
	var offset = local_pos - center
	var dist = offset.length()
	var clamped = min(dist, max_dist)
	var dir = offset.normalized() if dist > 0 else Vector2.ZERO
	
	knob.position = center + dir * clamped - knob.size / 2
	direction_changed.emit(dir)

func _reset_knob():
	knob.position = base.size / 2 - knob.size / 2
	direction_changed.emit(Vector2.ZERO)
