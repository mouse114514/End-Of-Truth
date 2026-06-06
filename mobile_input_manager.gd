extends Node

signal investigate_pressed
signal close_dialog_pressed
signal direction_input(dir: Vector2)

var joystick_node: Control = null
var joystick_base: Panel = null
var joystick_knob: Panel = null
var investigate_button: Control
var close_dialog_button: Control
var canvas: CanvasLayer

var player_node: Node = null
var player_soul_node: Node = null
var is_ui_created: bool = false
var is_ui_visible: bool = true
var toggle_button: Control = null

func _ready():
	get_tree().root.ready.connect(_on_scene_ready)

func _on_scene_ready():
	if is_ui_created:
		return
	_setup_mobile_ui()
	_connect_to_player()
	is_ui_created = true

func _setup_mobile_ui():
	canvas = CanvasLayer.new()
	canvas.name = "MobileUI"
	canvas.layer = 100
	
	get_tree().root.add_child(canvas)
	
	var btn = _create_virtual_button(0)
	investigate_button = btn
	canvas.add_child(btn)
	
	var btn2 = _create_virtual_button(1)
	close_dialog_button = btn2
	canvas.add_child(btn2)
	
	_create_directional_buttons()
	joystick_node = _create_joystick()
	canvas.add_child(joystick_node)
	
	# 根据当前设置显示对应的控制方式
	var mode = GameSettings.mobile_control_mode if "mobile_control_mode" in GameSettings else "buttons"
	_set_control_mode_internal(mode)
	
	_create_toggle_button()

var direction_buttons: Dictionary = {}

func _create_directional_buttons():
	var viewport_size = get_viewport().get_visible_rect().size
	var button_size = Vector2(60, 60)
	var base_pos = Vector2(100, viewport_size.y - 200)
	var spacing = 70
	
	# 方向布局: W(上), S(下), A(左), D(右)
	var directions = {
		"up": Vector2(0, -spacing),
		"down": Vector2(0, spacing),
		"left": Vector2(-spacing, 0),
		"right": Vector2(spacing, 0)
	}
	
	for dir_name in directions:
		var btn = Panel.new()
		btn.name = "Dir_" + dir_name
		btn.custom_minimum_size = button_size
		btn.position = base_pos + directions[dir_name]
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.4)
		style.corner_radius_top_left = 30
		style.corner_radius_top_right = 30
		style.corner_radius_bottom_left = 30
		style.corner_radius_bottom_right = 30
		btn.add_theme_stylebox_override("normal", style)
		
		var label = Label.new()
		label.text = dir_name.substr(0, 1).to_upper()
		label.set_anchors_preset(Control.PRESET_CENTER)
		var font = load("res://font/main.ttf")
		if font:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		btn.add_child(label)
		
		btn.gui_input.connect(_on_direction_button_input.bind(dir_name, btn))
		canvas.add_child(btn)
		direction_buttons[dir_name] = btn

var current_direction: Vector2 = Vector2.ZERO

func _on_direction_button_input(event, dir_name, btn):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_direction(dir_name)
			else:
				_release_direction(dir_name)

func _press_direction(dir_name: String):
	match dir_name:
		"up": current_direction.y = -1
		"down": current_direction.y = 1
		"left": current_direction.x = -1
		"right": current_direction.x = 1
	_apply_input_to_player(current_direction)
	direction_input.emit(current_direction)

func _release_direction(dir_name: String):
	match dir_name:
		"up": 
			if current_direction.y < 0: current_direction.y = 0
		"down": 
			if current_direction.y > 0: current_direction.y = 0
		"left": 
			if current_direction.x < 0: current_direction.x = 0
		"right": 
			if current_direction.x > 0: current_direction.x = 0
	_apply_input_to_player(current_direction)
	direction_input.emit(current_direction)

func _create_toggle_button():
	if not is_ui_visible:
		return  # 移动端GUI已关闭，不创建展开按钮
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	var btn = Button.new()
	btn.text = "<"
	btn.name = "ToggleButton"
	btn.position = Vector2(viewport_size.x - 40, viewport_size.y - 40)
	btn.size = Vector2(40, 40)
	btn.pressed.connect(_on_toggle_button_pressed)
	
	canvas.add_child(btn)
	toggle_button = btn

func _on_toggle_button_pressed():
	is_ui_visible = not is_ui_visible
	SoundManager.play_ui("button")
	
	# 只切换除toggle button外的其他UI元素
	var mode = GameSettings.mobile_control_mode if "mobile_control_mode" in GameSettings else "buttons"
	if mode == "buttons":
		for btn in direction_buttons.values():
			btn.visible = is_ui_visible
	else:
		if joystick_node:
			joystick_node.visible = is_ui_visible
	if investigate_button:
		investigate_button.visible = is_ui_visible
	if close_dialog_button:
		close_dialog_button.visible = is_ui_visible
	
	# 更新切换按钮文本: "<" = 收起UI, ">" = 展开UI
	toggle_button.text = "<" if is_ui_visible else ">"

func _set_ui_visible(visible: bool):
	var mode = GameSettings.mobile_control_mode if "mobile_control_mode" in GameSettings else "buttons"
	if mode == "buttons":
		for btn in direction_buttons.values():
			btn.visible = visible
	else:
		if joystick_node:
			joystick_node.visible = visible
	if investigate_button:
		investigate_button.visible = visible
	if close_dialog_button:
		close_dialog_button.visible = visible
	if toggle_button:
		toggle_button.visible = visible

func set_ui_visible(visible: bool):
	is_ui_visible = visible
	_set_ui_visible(visible)
	
	# 完全显示/隐藏移动端GUI（包括toggle button）
	if toggle_button:
		toggle_button.visible = visible
	
	# 如果UI可见且切换按钮不存在，创建它
	if visible and not toggle_button:
		_create_toggle_button()

func get_is_ui_visible() -> bool:
	return is_ui_visible

const JOYSTICK_TOUCH_RADIUS: float = 120.0
const JOYSTICK_MAX_DIST: float = 50.0
const JOYSTICK_DEADZONE: float = 10.0
const JOYSTICK_REPEAT_DELAY: float = 0.3
const JOYSTICK_REPEAT_RATE: float = 0.12
var joystick_dragging: bool = false
var joystick_touch_index: int = -1
var _last_discrete_dir: Vector2 = Vector2.ZERO
var _repeat_timer: float = 0.0
var _repeat_dir: Vector2 = Vector2.ZERO

func _create_joystick() -> Control:
	var viewport_size = get_viewport().get_visible_rect().size
	
	var container = Control.new()
	container.name = "VirtualJoystick"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.position = Vector2(30, viewport_size.y - 180)
	container.size = Vector2(150, 150)
	
	var base = Panel.new()
	base.name = "Base"
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.size = Vector2(120, 120)
	base.position = Vector2(15, 15)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.4)
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1, 1, 1, 0.8)
	base.add_theme_stylebox_override("normal", style)
	container.add_child(base)
	joystick_base = base
	
	var knob = Panel.new()
	knob.name = "Knob"
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.size = Vector2(50, 50)
	knob.position = Vector2(35, 35)
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(1, 1, 1, 0.8)
	knob_style.corner_radius_top_left = 25
	knob_style.corner_radius_top_right = 25
	knob_style.corner_radius_bottom_left = 25
	knob_style.corner_radius_bottom_right = 25
	knob.add_theme_stylebox_override("normal", knob_style)
	
	base.add_child(knob)
	joystick_knob = knob
	
	return container

func _create_virtual_button(action_type: int) -> Control:
	var viewport_size = get_viewport().get_visible_rect().size
	
	var panel = Panel.new()
	panel.name = "VirtualButton_" + str(action_type)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(80, 80)
	panel.size = Vector2(80, 80)
	
	# 右下角位置 - 调整更靠左
	var pos_x = viewport_size.x - 200 if action_type == 0 else viewport_size.x - 100
	panel.position = Vector2(pos_x, viewport_size.y - 100)
	
	# 样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.5)
	style.corner_radius_top_left = 40
	style.corner_radius_top_right = 40
	style.corner_radius_bottom_left = 40
	style.corner_radius_bottom_right = 40
	panel.add_theme_stylebox_override("normal", style)
	
	# 标签
	var label = Label.new()
	label.text = "Z" if action_type == 0 else "X"
	label.set_anchors_preset(Control.PRESET_CENTER)
	var font = load("res://font/main.ttf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	
	# 输入处理
	panel.gui_input.connect(_on_button_gui_input.bind(panel, "investigate" if action_type == 0 else "close_dialog"))
	
	return panel

func _on_button_gui_input(event, panel, action_name):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Input.action_press(action_name)
				if action_name == "investigate":
					investigate_pressed.emit()
				elif action_name == "close_dialog":
					close_dialog_pressed.emit()
			else:
				Input.action_release(action_name)

func _on_button_input_simple(event, btn, action_name):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Input.action_press(action_name)
			else:
				Input.action_release(action_name)

func _input(event):
	if not joystick_node or not joystick_node.visible:
		return
	if GameSettings.mobile_control_mode != "joystick":
		return

	var is_touch = event is InputEventScreenTouch or event is InputEventScreenDrag
	var is_mouse = event is InputEventMouseButton or event is InputEventMouseMotion
	if not is_touch and not is_mouse:
		return

	var ev_pos: Vector2
	var ev_index: int = -1
	var ev_is_press: bool = false
	var ev_is_release: bool = false
	var ev_is_drag: bool = false

	if event is InputEventScreenTouch:
		ev_pos = event.position
		ev_index = event.index
		ev_is_press = event.pressed
		ev_is_release = not event.pressed
	elif event is InputEventScreenDrag:
		ev_pos = event.position
		ev_index = event.index
		ev_is_drag = true
	elif event is InputEventMouseButton:
		ev_pos = event.position
		ev_index = -1
		if event.button_index == MOUSE_BUTTON_LEFT:
			ev_is_press = event.pressed
			ev_is_release = not event.pressed
	elif event is InputEventMouseMotion:
		ev_pos = event.position
		ev_index = -1
		ev_is_drag = true

	if not joystick_base:
		return

	var base_center = joystick_base.get_global_rect().get_center()
	var dist = ev_pos.distance_to(base_center)

	if not joystick_dragging:
		if ev_is_press and dist <= JOYSTICK_TOUCH_RADIUS:
			joystick_dragging = true
			joystick_touch_index = ev_index
			_update_joystick(ev_pos, base_center)
			get_viewport().set_input_as_handled()
	elif ev_index == joystick_touch_index or (joystick_touch_index < 0 and ev_index < 0):
		if ev_is_drag:
			_update_joystick(ev_pos, base_center)
			get_viewport().set_input_as_handled()
		elif ev_is_release:
			_reset_joystick(base_center)
			get_viewport().set_input_as_handled()

func _get_discrete_dir(vec: Vector2) -> Vector2:
	if abs(vec.x) < 0.01 and abs(vec.y) < 0.01:
		return Vector2.ZERO
	if abs(vec.x) > abs(vec.y):
		return Vector2(sign(vec.x), 0.0)
	else:
		return Vector2(0.0, sign(vec.y))

func _update_joystick(screen_pos: Vector2, base_center: Vector2):
	var offset = screen_pos - base_center
	var dist = offset.length()
	var base_size = joystick_base.size

	if dist < JOYSTICK_DEADZONE:
		joystick_knob.position = base_size / 2 - joystick_knob.size / 2
		_apply_input_to_player(Vector2.ZERO)
		_emit_discrete_if_changed(Vector2.ZERO)
		return

	var clamped_dist = min(dist, JOYSTICK_MAX_DIST)
	var dir = offset.normalized()

	joystick_knob.position = base_size / 2 + dir * clamped_dist - joystick_knob.size / 2

	var magnitude = clamp((dist - JOYSTICK_DEADZONE) / (JOYSTICK_MAX_DIST - JOYSTICK_DEADZONE), 0.0, 1.0)
	var analog = dir * magnitude
	_apply_input_to_player(analog)

	# 菜单导航：离散方向 + 自动连发
	var discrete = _get_discrete_dir(analog)
	if discrete != _last_discrete_dir:
		_last_discrete_dir = discrete
		_repeat_dir = discrete
		_repeat_timer = 0.0
		if discrete != Vector2.ZERO:
			direction_input.emit(discrete)
	elif discrete != Vector2.ZERO:
		var dt = get_process_delta_time()
		_repeat_timer += dt
		if _repeat_timer >= JOYSTICK_REPEAT_DELAY:
			var elapsed = _repeat_timer - JOYSTICK_REPEAT_DELAY
			var count = int(elapsed / JOYSTICK_REPEAT_RATE)
			if count > 0:
				_repeat_timer = JOYSTICK_REPEAT_DELAY + (count * JOYSTICK_REPEAT_RATE)
				direction_input.emit(discrete)

func _emit_discrete_if_changed(new_dir: Vector2):
	if new_dir != _last_discrete_dir:
		_last_discrete_dir = new_dir
		_repeat_dir = Vector2.ZERO
		_repeat_timer = 0.0

func _reset_joystick(base_center: Vector2):
	joystick_dragging = false
	joystick_touch_index = -1
	joystick_knob.position = joystick_base.size / 2 - joystick_knob.size / 2
	_apply_input_to_player(Vector2.ZERO)
	_emit_discrete_if_changed(Vector2.ZERO)

func _on_button_input(event, btn_ctrl, action_name):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Input.action_press(action_name)
		else:
			Input.action_release(action_name)

func _connect_to_player():
	await get_tree().create_timer(0.5).timeout
	player_node = get_tree().get_first_node_in_group("player")
	
	if not player_node:
		var bodies = get_tree().get_nodes_in_group("player_soul")
		if bodies.size() > 0:
			player_soul_node = bodies[0]

func _process(_delta):
	player_node = get_tree().get_first_node_in_group("player")
	
	# 先查找 player_soul 组，再查找 soul 组
	var souls = get_tree().get_nodes_in_group("player_soul")
	if souls.size() == 0:
		souls = get_tree().get_nodes_in_group("soul")
	if souls.size() > 0:
		player_soul_node = souls[0]

func _apply_input_to_player(input_vec: Vector2):
	# 战斗时使用 player_soul，野外使用 player
	var battle_manager = get_node_or_null("/root/BattleManager")
	var in_battle = battle_manager and battle_manager.is_in_battle
	
	if in_battle:
		var battle = battle_manager.current_battle
		if battle and battle.has_method("process_mobile_input"):
			# 直接访问 is_player_turn 变量（如果存在）
			var is_player_turn = true  # 默认当作玩家回合
			if battle.get("is_player_turn") != null:
				is_player_turn = battle.is_player_turn
			
			if is_player_turn:
				# 玩家回合：只处理菜单选择，不移动灵魂
				battle.process_mobile_input(input_vec)
			else:
				# 敌人回合：可以移动灵魂
				var souls = get_tree().get_nodes_in_group("player_soul")
				if souls.size() == 0:
					souls = get_tree().get_nodes_in_group("soul")
				if souls.size() > 0 and souls[0].has_method("handle_mobile_input"):
					souls[0].handle_mobile_input(input_vec)
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("handle_mobile_input"):
			player.handle_mobile_input(input_vec)

func set_control_mode(mode: String):
	GameSettings.mobile_control_mode = mode
	_set_control_mode_internal(mode)

func _set_control_mode_internal(mode: String):
	var buttons_visible = mode == "buttons"
	for btn in direction_buttons.values():
		btn.visible = buttons_visible
	if joystick_node:
		joystick_node.visible = not buttons_visible
