extends Control

var current_selection: int = 0
var menu_options: Array = []
var menu_actions: Array = []
var menu_values: Array = []

@onready var vbox: VBoxContainer = $VBoxContainer

func _ready():
	_setup_menu()
	_connect_mobile_input()
	update_selection()

func _setup_menu():
	for child in vbox.get_children():
		child.queue_free()
	
	menu_options.clear()
	menu_actions.clear()
	menu_values.clear()
	
	var font = load("res://font/main.ttf")
	
	var mobile_visible = true
	var mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input:
		mobile_visible = mobile_input.get_is_ui_visible()
	
	add_option("移动端界面", "mobile_visible", mobile_visible, font)
	add_option("开场动画", "full_opening", GameSettings.full_opening, font)
	add_option("速度模式", "speed_mode", GameSettings.speed_mode, font)
	add_option("开发者模式", "developer_mode", GameSettings.developer_mode, font)
	add_option("战斗模式", "battle_mode", GameSettings.battle_mode, font)
	add_option("剧情模式", "story_mode", GameSettings.story_mode, font)
	add_option("移动控制", "mobile_control_mode", GameSettings.mobile_control_mode, font)
	add_option("返回", "back", true, font)
	
	update_option_texts()

func add_option(text: String, action: String, value, font):
	var label = Label.new()
	label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(label)
	menu_options.append(label)
	menu_actions.append(action)
	menu_values.append(value)

func update_option_texts():
	for i in range(menu_options.size()):
		var text = menu_options[i].text
		match menu_actions[i]:
			"mobile_visible":
				var value_text = "开" if menu_values[i] else "关"
				menu_options[i].text = "移动端界面: " + value_text
			"full_opening":
				var value_text = "开" if menu_values[i] else "关"
				menu_options[i].text = "开场动画: " + value_text
			"speed_mode":
				var value_text = "开" if menu_values[i] else "关"
				menu_options[i].text = "速度模式: " + value_text
			"developer_mode":
				var value_text = "开" if menu_values[i] else "关"
				menu_options[i].text = "开发者模式: " + value_text

			"battle_mode":
				var value_text = "开" if menu_values[i] else "关"
				menu_options[i].text = "战斗模式: " + value_text
			"story_mode":
				var value_text = "开" if menu_values[i] else "关"
				menu_options[i].text = "剧情模式: " + value_text
			"mobile_control_mode":
				var value_text = "按钮" if menu_values[i] == "buttons" else "摇杆"
				menu_options[i].text = "移动控制: " + value_text
			"back":
					menu_options[i].text = "返回"

func _connect_mobile_input():
	var mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input:
		if mobile_input.has_signal("investigate_pressed"):
			mobile_input.investigate_pressed.connect(_on_confirm_pressed)
		if mobile_input.has_signal("direction_input"):
			mobile_input.direction_input.connect(_on_direction_input)
	else:
		await get_tree().create_timer(0.5).timeout
		_connect_mobile_input()

func _on_direction_input(dir: Vector2):
	if dir.y < 0 or dir.x < 0:
		current_selection = (current_selection - 1 + menu_options.size()) % menu_options.size()
		update_selection()
	elif dir.y > 0 or dir.x > 0:
		current_selection = (current_selection + 1) % menu_options.size()
		update_selection()

func _input(event):
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		current_selection = (current_selection + 1) % menu_options.size()
		update_selection()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		current_selection = (current_selection - 1 + menu_options.size()) % menu_options.size()
		update_selection()
	elif event.is_action_pressed("investigate"):
		_on_confirm_pressed()
	elif event.is_action_pressed("close_dialog"):
		_on_back_pressed()

func _on_confirm_pressed():
	match menu_actions[current_selection]:
		"mobile_visible":
			menu_values[current_selection] = not menu_values[current_selection]
			update_option_texts()
			_apply_settings()
		"full_opening", "speed_mode", "developer_mode", "battle_mode", "story_mode":
			menu_values[current_selection] = not menu_values[current_selection]
			update_option_texts()
			_apply_settings()
		"mobile_control_mode":
			if menu_values[current_selection] == "buttons":
				menu_values[current_selection] = "joystick"
			else:
				menu_values[current_selection] = "buttons"
			update_option_texts()
			_apply_settings()
		"back":
			_on_back_pressed()

func _on_back_pressed():
	SoundManager.play_ui("button")
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _apply_settings():
	var mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input:
		mobile_input.set_ui_visible(menu_values[0])
	
	for i in range(menu_options.size()):
		match menu_actions[i]:
			"full_opening":
				GameSettings.full_opening = menu_values[i]
			"speed_mode":
				GameSettings.speed_mode = menu_values[i]
			"developer_mode":
				GameSettings.developer_mode = menu_values[i]
			"battle_mode":
				GameSettings.battle_mode = menu_values[i]
			"story_mode":
				GameSettings.story_mode = menu_values[i]
			"mobile_control_mode":
				GameSettings.mobile_control_mode = menu_values[i]
				if mobile_input:
					mobile_input.set_control_mode(menu_values[i])

func update_selection():
	for i in range(menu_options.size()):
		if i == current_selection:
			menu_options[i].add_theme_color_override("font_color", Color(1, 1, 0))
		else:
			menu_options[i].add_theme_color_override("font_color", Color(1, 1, 1))
