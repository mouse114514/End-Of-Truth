extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

var speed: int = 350
var active_direction = "d"
var pressed_keys = {}

var mobile_input_vector: Vector2 = Vector2.ZERO
var use_mobile_input: bool = false

# 战斗遭遇系统变量
var steps_since_last_encounter: int = 0
var next_encounter_step: int = 0
var base_encounter_step: int = 50
var area_encounter_modifier: float = 1.0
var is_in_battle: bool = false
var forced_encounter_scene = preload("res://forced_encounter_trigger.tscn")

# 调查系统变量
@onready var dialog_ui = preload("res://InvestigationDialog.tscn").instantiate()
var nearby_investigation_areas = []
var nearby_tell_areas = []  # 专门存储tell区域

# 和平区域检测
var is_in_peace_region: bool = false

# 输入屏蔽标志
var is_input_blocked: bool = false

# Tell系统变量
var current_tell_area = null  # 当前正在处理的tell区域
var triggered_tell_areas = {}  # 记录已触发的tell区域（防止重复触发）

var just_closed_dialog: bool = false

func _ready():
	# 调查系统初始化
	get_tree().root.add_child.call_deferred(dialog_ui)
	add_to_group("player")
	
	# 连接对话框关闭信号
	if dialog_ui.has_signal("dialog_closed"):
		dialog_ui.dialog_closed.connect(_on_dialog_closed)
	
	# 连接移动端按钮信号
	_connect_mobile_input_signals()
	
	# 确保检测器信号连接
	if has_node("InvestigationDetector"):
		var detector = $InvestigationDetector
		if not detector.area_entered.is_connected(_on_area_entered):
			detector.area_entered.connect(_on_area_entered)
		if not detector.area_exited.is_connected(_on_area_exited):
			detector.area_exited.connect(_on_area_exited)
	
	set_process_input(true)
	set_physics_process(true)
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	reset_encounter_counter()
	
	# 战斗模式/剧情模式：显示设置界面
	_setup_battle_mode()
	_setup_story_mode()

func _connect_mobile_input_signals():
	var mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input:
		if mobile_input.has_signal("investigate_pressed"):
			mobile_input.investigate_pressed.connect(_on_mobile_investigate_pressed)
	else:
		await get_tree().create_timer(1.0).timeout
		_connect_mobile_input_signals()

func _on_mobile_investigate_pressed():
	if is_input_blocked or is_in_battle or dialog_ui.is_showing:
		return
	
	# 优先处理tell区域
	if nearby_tell_areas.size() > 0 and not dialog_ui.is_showing:
		var tell_area = nearby_tell_areas[0]
		_trigger_tell_area(tell_area)
	elif nearby_investigation_areas.size() > 0 and not dialog_ui.is_showing:
		var random_area = nearby_investigation_areas[randi() % nearby_investigation_areas.size()]
		_trigger_investigation_area(random_area)

func _input(event):
	# 防止刚关闭对话框后的输入
	if just_closed_dialog:
		just_closed_dialog = false
		return
	
	# 如果输入被屏蔽，直接返回
	if is_input_blocked or is_in_battle or dialog_ui.is_showing:
		return
		
	if event.is_action_pressed("investigate"):
		# 优先处理tell区域（如果有的话）
		if nearby_tell_areas.size() > 0 and not dialog_ui.is_showing:
			var tell_area = nearby_tell_areas[0]  # 取第一个tell区域
			_trigger_tell_area(tell_area)
		# 如果没有tell区域，处理普通调查区域
		elif nearby_investigation_areas.size() > 0 and not dialog_ui.is_showing:
			var random_area = nearby_investigation_areas[randi() % nearby_investigation_areas.size()]
			_trigger_investigation_area(random_area)
		
	if event is InputEventKey:
		var direction = ""
		match event.keycode:
			KEY_D: direction = "r"
			KEY_A: direction = "l"
			KEY_S: direction = "d"
			KEY_W: direction = "u"
		
		if direction != "":
			if event.pressed:
				pressed_keys[event.keycode] = direction
			else:
				pressed_keys.erase(event.keycode)

func _physics_process(_delta: float) -> void:
	# 如果输入被屏蔽，停止移动
	if is_input_blocked or is_in_battle:
		velocity = Vector2.ZERO
		if animated_sprite.is_playing():
			animated_sprite.stop()
		animated_sprite.frame = 0
		return
	
	# 对话框显示时也停止移动
	if dialog_ui.is_showing:
		velocity = Vector2.ZERO
		if animated_sprite.is_playing():
			animated_sprite.stop()
		animated_sprite.frame = 0
		return
		
	# 速度模式：提高玩家移动速度
	var current_speed = 1000 if GameSettings.speed_mode else speed
	
	var is_moving = false
	var move_vector = Vector2.ZERO
	velocity = Vector2.ZERO
	
	# 优先使用移动端输入
	if use_mobile_input and mobile_input_vector != Vector2.ZERO:
		is_moving = true
		move_vector = mobile_input_vector
		velocity = move_vector * current_speed
		
		# 根据输入方向更新动画方向
		if abs(mobile_input_vector.x) > abs(mobile_input_vector.y):
			active_direction = "r" if mobile_input_vector.x > 0 else "l"
		else:
			active_direction = "d" if mobile_input_vector.y > 0 else "u"
	elif pressed_keys.size() > 0:
		var first_key = pressed_keys.keys()[0]
		active_direction = pressed_keys[first_key]
		is_moving = true
		
		if Input.is_key_pressed(KEY_D): move_vector.x += 1
		if Input.is_key_pressed(KEY_A): move_vector.x -= 1
		if Input.is_key_pressed(KEY_S): move_vector.y += 1
		if Input.is_key_pressed(KEY_W): move_vector.y -= 1
		
		if move_vector != Vector2.ZERO:
			move_vector = move_vector.normalized()
			velocity = move_vector * current_speed
	
	move_and_slide()
	
	if is_moving and not is_in_battle and not is_in_peace_region:
		check_for_random_encounter()
	
	if is_moving:
		if animated_sprite.animation != active_direction or not animated_sprite.is_playing():
			animated_sprite.play(active_direction)
	else:
		if animated_sprite.is_playing():
			animated_sprite.stop()
		animated_sprite.frame = 0

# 触发tell区域的统一方法
func _trigger_tell_area(area):
	# 开发者模式/战斗模式：跳过所有主世界剧情
	if GameSettings.developer_mode or GameSettings.battle_mode:
		return
	
	# 检查是否已经触发过（使用节点路径作为唯一标识）
	var area_path = area.get_path()
	if triggered_tell_areas.has(area_path):
		return
	
	if area.has_method("get_tell_text") and not dialog_ui.is_showing:
		# 标记为已触发
		triggered_tell_areas[area_path] = true
		# 屏蔽输入并停止移动
		_block_input_and_stop_movement()
		# 保存当前tell区域
		current_tell_area = area
		# 显示第一条文本
		_show_next_tell_text()

# 显示下一条tell文本
func _show_next_tell_text():
	if current_tell_area and current_tell_area.has_method("get_tell_text"):
		var text_result = current_tell_area.get_tell_text()
		var display_text = _get_display_text(text_result)
		dialog_ui.show_text(display_text)

# 触发调查区域的统一方法
func _trigger_investigation_area(area):
	if area.has_method("get_random_text") and not dialog_ui.is_showing:
		# 屏蔽输入并停止移动
		_block_input_and_stop_movement()
		
		var text_result = area.get_random_text()
		var display_text = _get_display_text(text_result)
		dialog_ui.show_text(display_text)

# 屏蔽输入并停止移动
func _block_input_and_stop_movement():
	is_input_blocked = true
	pressed_keys.clear()
	velocity = Vector2.ZERO
	if animated_sprite.is_playing():
		animated_sprite.stop()
	animated_sprite.frame = 0

# 恢复输入
func _restore_input():
	is_input_blocked = false
	pressed_keys.clear()

# 对话框关闭时的回调
func _on_dialog_closed():
	# 检查是否有下一条tell文本
	if current_tell_area and current_tell_area.has_method("has_next_text") and current_tell_area.has_method("next_text"):
		if current_tell_area.has_next_text():
			# 移动到下一条文本并显示
			current_tell_area.next_text()
			_show_next_tell_text()
			return  # 不恢复输入，继续显示下一条
	
	# 没有更多文本，恢复输入
	just_closed_dialog = true
	_restore_input()
	current_tell_area = null  # 清空当前tell区域
	
	# 延迟清除标志
	await get_tree().create_timer(0.1).timeout
	just_closed_dialog = false

# 辅助函数：处理文本转换
func _get_display_text(text_result) -> String:
	if text_result is Array:
		if text_result.size() > 0:
			return str(text_result[0])
		else:
			return "没有文本内容"
	elif text_result is String:
		return text_result
	else:
		return str(text_result)

func _on_area_entered(area):
	# 检测tell区域
	if area.has_method("get_tell_text"):
		if not nearby_tell_areas.has(area):
			nearby_tell_areas.append(area)
		
		# 关键区别：tell区域进入后立即触发
		if not dialog_ui.is_showing and not is_input_blocked:
			_trigger_tell_area(area)
	
	# 检测普通调查区域
	elif area.has_method("get_random_text"):
		if not nearby_investigation_areas.has(area):
			nearby_investigation_areas.append(area)
		# 注意：普通调查区域不会立即触发，需要按调查键
	
	# 战斗触发器检测
	if area.has_method("trigger_battle"):
		call_deferred("_deferred_trigger_battle_from_area", area)
	
	# 和平区域检测
	if area.name == "PeaceRegion":
		is_in_peace_region = true

func _on_area_exited(area):
	# 离开tell区域
	if area.has_method("get_tell_text"):
		nearby_tell_areas.erase(area)
	
	# 离开调查区域
	elif area.has_method("get_random_text"):
		nearby_investigation_areas.erase(area)
	
	# 离开和平区域
	if area.name == "PeaceRegion":
		is_in_peace_region = false

func _deferred_trigger_battle_from_area(area):
	if area.has_method("trigger_battle"):
		area.trigger_battle(self)

func check_for_random_encounter():
	if is_in_battle or is_in_peace_region or is_input_blocked:
		return
	
	steps_since_last_encounter += 1
	
	if steps_since_last_encounter >= next_encounter_step:
		trigger_random_encounter()

func trigger_random_encounter():
	reset_encounter_counter()
	spawn_forced_encounter_trigger()

func spawn_forced_encounter_trigger():
	var existing_triggers = get_tree().get_nodes_in_group("random_battle_trigger")
	if existing_triggers.size() > 0:
		return
	
	var encounter_trigger = forced_encounter_scene.instantiate()
	get_parent().add_child(encounter_trigger)
	encounter_trigger.global_position = global_position
	encounter_trigger.add_to_group("random_battle_trigger")

func start_battle_sequence():
	if is_in_battle:
		return
	
	is_in_battle = true
	reset_encounter_counter()
	animated_sprite.stop()
	animated_sprite.frame = 0
	_disable_player_immediately()
	_start_battle_via_battle_manager()

func _disable_player_immediately():
	set_deferred("visible", false)
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	set_process_input(false)
	set_physics_process(false)

func _start_battle_via_battle_manager():
	var battle_manager = get_node("/root/BattleManager")
	if battle_manager and battle_manager.has_method("start_forced_encounter"):
		var enemy_scene = preload("res://bullet_hell_scene.tscn")
		var battle_data = {"enemy_id": "st_flw"}
		battle_manager.start_forced_encounter(enemy_scene, battle_data)
	else:
		load_battle_scene_directly()

func load_battle_scene_directly():
	var enemy_scene = preload("res://bullet_hell_scene.tscn")
	var battle_instance = enemy_scene.instantiate()
	get_tree().current_scene.add_child(battle_instance)
	var battle_data = {"enemy_id": "st_flw"}
	if battle_instance.has_method("start_battle"):
		battle_instance.start_battle(battle_data)

func return_from_battle():
	is_in_battle = false
	reset_encounter_counter()
	call_deferred("_deferred_restore_player_state")

func _deferred_restore_player_state():
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	set_process_input(true)
	set_physics_process(true)
	# 战斗系统自己会恢复，这里不处理输入恢复
	reset_transient_state()

func set_battle_state(in_battle: bool):
	is_in_battle = in_battle
	if in_battle:
		set_deferred("visible", false)
		process_mode = Node.PROCESS_MODE_DISABLED
		set_process_input(false)
		set_physics_process(false)
	else:
		call_deferred("_deferred_exit_battle_state")

func _deferred_exit_battle_state():
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	set_process_input(true)
	set_physics_process(true)
	# 战斗系统自己会恢复，这里不处理输入恢复
	reset_transient_state()

func stop_moving_immediately():
	pressed_keys.clear()
	velocity = Vector2.ZERO
	if animated_sprite.is_playing():
		animated_sprite.stop()
	animated_sprite.frame = 0

func reset_transient_state():
	pressed_keys.clear()
	velocity = Vector2.ZERO
	active_direction = "d"
	mobile_input_vector = Vector2.ZERO
	use_mobile_input = false
	if animated_sprite.is_playing():
		animated_sprite.stop()
	animated_sprite.frame = 0

func set_encounter_chance(modifier: float):
	area_encounter_modifier = modifier

func reset_encounter_counter():
	steps_since_last_encounter = 0
	var random_factor = randf_range(20.0, 55.5)
	next_encounter_step = int(base_encounter_step * area_encounter_modifier * random_factor)

var battle_setup_canvas: CanvasLayer = null
var battle_setup_enemy_input: LineEdit = null
var battle_setup_turn_input: LineEdit = null

var story_setup_canvas: CanvasLayer = null
var story_setup_func_input: LineEdit = null

func handle_mobile_input(input_vec: Vector2):
	mobile_input_vector = input_vec
	use_mobile_input = input_vec != Vector2.ZERO
	if input_vec != Vector2.ZERO:
		is_input_blocked = false

func _setup_battle_mode():
	if not GameSettings.battle_mode:
		return
	
	_block_input_and_stop_movement()
	await get_tree().process_frame
	_show_battle_setup_ui()

func _show_battle_setup_ui():
	if battle_setup_canvas:
		battle_setup_canvas.show()
		return
	
	battle_setup_canvas = CanvasLayer.new()
	battle_setup_canvas.layer = 128
	get_tree().current_scene.add_child(battle_setup_canvas)
	
	var vs = get_viewport().size
	var cx = vs.x / 2
	var w = min(300, vs.x * 0.8)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_setup_canvas.add_child(bg)
	
	var title = Label.new()
	title.text = "战斗设置"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, vs.y * 0.08)
	title.size = Vector2(vs.x, 50)
	bg.add_child(title)
	
	var enemy_label = Label.new()
	enemy_label.text = "敌人类型:"
	enemy_label.add_theme_font_size_override("font_size", 24)
	enemy_label.position = Vector2(cx - w / 2, vs.y * 0.25)
	enemy_label.size = Vector2(w, 30)
	bg.add_child(enemy_label)
	
	battle_setup_enemy_input = LineEdit.new()
	battle_setup_enemy_input.text = "0"
	battle_setup_enemy_input.placeholder_text = "输入敌人类型 (0, 1, 2...)"
	battle_setup_enemy_input.position = Vector2(cx - w / 2, vs.y * 0.25 + 40)
	battle_setup_enemy_input.size = Vector2(w, 40)
	battle_setup_enemy_input.add_theme_font_size_override("font_size", 24)
	battle_setup_enemy_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(battle_setup_enemy_input)
	
	var turn_label = Label.new()
	turn_label.text = "回合类型:"
	turn_label.add_theme_font_size_override("font_size", 24)
	turn_label.position = Vector2(cx - w / 2, vs.y * 0.42)
	turn_label.size = Vector2(w, 30)
	bg.add_child(turn_label)
	
	battle_setup_turn_input = LineEdit.new()
	battle_setup_turn_input.text = "0"
	battle_setup_turn_input.placeholder_text = "输入回合类型 (0, 1, 2...)"
	battle_setup_turn_input.position = Vector2(cx - w / 2, vs.y * 0.42 + 40)
	battle_setup_turn_input.size = Vector2(w, 40)
	battle_setup_turn_input.add_theme_font_size_override("font_size", 24)
	battle_setup_turn_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(battle_setup_turn_input)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "确定"
	confirm_btn.position = Vector2(cx - 100, vs.y * 0.62)
	confirm_btn.size = Vector2(200, 50)
	confirm_btn.add_theme_font_size_override("font_size", 28)
	confirm_btn.pressed.connect(_on_battle_setup_confirm)
	bg.add_child(confirm_btn)

func _on_battle_setup_confirm():
	var eid = battle_setup_enemy_input.text.strip_edges()
	var enemy_id = eid if eid != "" else "st_flw"
	var turn_type = int(battle_setup_turn_input.text) if battle_setup_turn_input.text.is_valid_int() else 0
	
	if battle_setup_canvas:
		battle_setup_canvas.hide()
	
	_start_battle_for_setup(enemy_id, turn_type)

func _start_battle_for_setup(enemy_id: String, turn_type: int):
	var battle_manager = get_node("/root/BattleManager")
	if not battle_manager:
		_show_battle_setup_ui()
		return
	
	var battle_data = {
		"enemy_id": enemy_id,
		"turn_type": turn_type,
		"start_with_enemy_turn": false,
		"end_after_one_turn": false
	}
	var enemy_scene = preload("res://bullet_hell_scene.tscn")
	battle_manager.start_forced_encounter(enemy_scene, battle_data)
	await battle_manager.battle_ended
	
	await get_tree().process_frame
	_show_battle_setup_ui()

func _setup_story_mode():
	if not GameSettings.story_mode:
		return
	_block_input_and_stop_movement()
	await get_tree().process_frame
	_show_story_setup_ui()

func _show_story_setup_ui():
	if story_setup_canvas:
		story_setup_canvas.show()
		return
	story_setup_canvas = CanvasLayer.new()
	story_setup_canvas.layer = 128
	get_tree().current_scene.add_child(story_setup_canvas)
	var vs = get_viewport().size
	var cx = vs.x / 2
	var w = min(300, vs.x * 0.8)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_setup_canvas.add_child(bg)
	var title = Label.new()
	title.text = "剧情设置"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, vs.y * 0.08)
	title.size = Vector2(vs.x, 50)
	bg.add_child(title)
	var func_label = Label.new()
	func_label.text = "剧情函数名:"
	func_label.add_theme_font_size_override("font_size", 24)
	func_label.position = Vector2(cx - w / 2, vs.y * 0.25)
	func_label.size = Vector2(w, 30)
	bg.add_child(func_label)
	story_setup_func_input = LineEdit.new()
	story_setup_func_input.text = "mostell"
	story_setup_func_input.placeholder_text = "输入剧情函数名 (mostell, flwhlw, bye...)"
	story_setup_func_input.position = Vector2(cx - w / 2, vs.y * 0.25 + 40)
	story_setup_func_input.size = Vector2(w, 40)
	story_setup_func_input.add_theme_font_size_override("font_size", 24)
	story_setup_func_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(story_setup_func_input)
	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.position = Vector2(cx + w / 2 + 10, vs.y * 0.25 + 40)
	help_btn.size = Vector2(40, 40)
	help_btn.add_theme_font_size_override("font_size", 24)
	help_btn.pressed.connect(_on_story_help_pressed)
	bg.add_child(help_btn)
	var confirm_btn = Button.new()
	confirm_btn.text = "确定"
	confirm_btn.position = Vector2(cx - 100, vs.y * 0.62)
	confirm_btn.size = Vector2(200, 50)
	confirm_btn.add_theme_font_size_override("font_size", 28)
	confirm_btn.pressed.connect(_on_story_setup_confirm)
	bg.add_child(confirm_btn)

func _get_story_function_names() -> Array:
	var file = FileAccess.open("res://stories/all_stories.gd", FileAccess.READ)
	if not file:
		return []
	var result = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.begins_with("func ") and line.contains("("):
			var name = line.substr(5, line.find("(") - 5).strip_edges()
			if name.length() > 0 and not name.begins_with("_") and name != "execute":
				result.append(name)
	file.close()
	return result

func _on_story_help_pressed():
	var names = _get_story_function_names()
	if names.is_empty():
		_show_story_help_popup(["（无可用剧情函数）"])
	else:
		_show_story_help_popup(names)

func _show_story_help_popup(names: Array):
	if story_setup_canvas:
		var vs = get_viewport().size
		var pw = min(600, vs.x * 0.9)
		var ph = min(400, vs.y * 0.6)
		var popup = ColorRect.new()
		popup.color = Color(0.1, 0.1, 0.15, 0.95)
		popup.position = Vector2((vs.x - pw) / 2, vs.y * 0.12)
		popup.size = Vector2(pw, ph)
		story_setup_canvas.add_child(popup)
		var title = Label.new()
		title.text = "可用剧情函数"
		title.add_theme_font_size_override("font_size", 28)
		title.position = Vector2(20, 15)
		title.size = Vector2(pw - 40, 40)
		popup.add_child(title)
		var list_text = ""
		for n in names:
			list_text += "  " + n + "\n"
		var list_label = Label.new()
		list_label.text = list_text
		list_label.add_theme_font_size_override("font_size", 22)
		list_label.position = Vector2(20, 60)
		list_label.size = Vector2(pw - 40, ph - 110)
		popup.add_child(list_label)
		var close_btn = Button.new()
		close_btn.text = "关闭"
		close_btn.position = Vector2((pw - 100) / 2, ph - 50)
		close_btn.size = Vector2(100, 40)
		close_btn.add_theme_font_size_override("font_size", 22)
		close_btn.pressed.connect(func():
			popup.queue_free()
		)
		popup.add_child(close_btn)

func _on_story_setup_confirm():
	var func_name = story_setup_func_input.text.strip_edges()
	if func_name.is_empty():
		return
	if story_setup_canvas:
		story_setup_canvas.hide()
	_start_story_for_setup(func_name)

func _start_story_for_setup(func_name: String):
	var story_manager = get_node("/root/StoryManager")
	if not story_manager:
		_show_story_setup_ui()
		return
	var story_script = load("res://stories/all_stories.gd")
	_restore_input()
	await story_manager.start_story_by_function_name(story_script, func_name)
	await get_tree().process_frame
	_block_input_and_stop_movement()
	_show_story_setup_ui()
