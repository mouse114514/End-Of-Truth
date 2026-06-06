extends Control

signal direction_changed(vector: Vector2)

@export var joystick_radius: float = 60.0
@export var knob_radius: float = 25.0
@export var max_drag_distance: float = 50.0

var knob: TextureRect
var base: TextureRect
var is_dragging: bool = false
var input_vector: Vector2 = Vector2.ZERO

@onready var joystick_area = $ joystick_area

func _ready():
	_setup_joystick()

func _setup_joystick():
	base = $Base
	knob = $Knob
	
	if not base:
		base = TextureRect.new()
		base.name = "Base"
		base.set_anchors_preset(Control.PRESET_CENTER)
		base.custom_minimum_size = Vector2(joystick_radius * 2, joystick_radius * 2)
		add_child(base)
	
	if not knob:
		knob = TextureRect.new()
		knob.name = "Knob"
		knob.custom_minimum_size = Vector2(knob_radius * 2, knob_radius * 2)
		knob.position = Vector2(joystick_radius - knob_radius, joystick_radius - knob_radius)
		base.add_child(knob)

func _gui_input(event):
	if event is InputEventTouch:
		if event.pressed:
			is_dragging = true
			_update_knob_position(event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = false
			_reset_joystick()
	elif event is InputEventMouseMotion and is_dragging:
		_update_knob_position(event.position)

func _update_knob_position(touch_pos: Vector2):
	var base_rect = base.get_global_rect()
	var center = base_rect.get_center()
	
	var offset = touch_pos - center
	var clamped_offset = offset.normalized() * min(offset.length(), max_drag_distance)
	
	knob.position = Vector2(joystick_radius - knob_radius, joystick_radius - knob_radius) + clamped_offset
	
	input_vector = clamped_offset / max_drag_distance
	direction_changed.emit(input_vector)

func _reset_joystick():
	knob.position = Vector2(joystick_radius - knob_radius, joystick_radius - knob_radius)
	input_vector = Vector2.ZERO
	direction_changed.emit(input_vector)

func get_input_vector() -> Vector2:
	return input_vector
