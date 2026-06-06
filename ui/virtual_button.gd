extends Control

signal button_pressed(action_name: String)
signal button_released(action_name: String)

enum ButtonAction {
	INVESTIGATE,
	CLOSE_DIALOG
}

@export var button_action: ButtonAction = ButtonAction.INVESTIGATE
@export var button_size: Vector2 = Vector2(80, 80)
@export var button_color: Color = Color(1, 1, 1, 0.5)

var button: TextureRect
var is_pressed: bool = false
var touch_id: int = -1

var action_name: String

func _ready():
	_setup_button()
	_update_action_name()

func _setup_button():
	button = $Button
	
	if not button:
		button = TextureRect.new()
		button.name = "Button"
		button.set_anchors_preset(Control.PRESET_CENTER)
		button.custom_minimum_size = button_size
		button.position = -button_size / 2
		add_child(button)
	
	_create_button_style()

func _create_button_style():
	var style = StyleBoxFlat.new()
	style.bg_color = button_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	
	button.add_theme_stylebox_override("normal", style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = button_color.darkened(0.3)
	button.add_theme_stylebox_override("pressed", pressed_style)

func _update_action_name():
	match button_action:
		ButtonAction.INVESTIGATE:
			action_name = "investigate"
		ButtonAction.CLOSE_DIALOG:
			action_name = "close_dialog"

func _gui_input(event):
	if event is InputEventTouch:
		if event.pressed:
			if touch_id == -1:
				touch_id = event.device
				is_pressed = true
				button.add_theme_stylebox_override("normal", button.get_theme_stylebox("pressed"))
				button_pressed.emit(action_name)
				Input.action_press(action_name)
		elif event.device == touch_id:
			is_pressed = false
			touch_id = -1
			button.add_theme_stylebox_override("normal", button.get_theme_stylebox("normal"))
			button_released.emit(action_name)
			Input.action_release(action_name)

func set_action(new_action: ButtonAction):
	button_action = new_action
	_update_action_name()
