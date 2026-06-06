extends Area2D

@onready var sprite = $Sprite2D

# 灵魂属性
var soul_color: Color = Color.WHITE
var move_speed: float = 150.0

# 移动相关
var velocity: Vector2 = Vector2.ZERO
var input_vector: Vector2 = Vector2.ZERO
var movement_enabled: bool = true  # 新增：移动控制开关

# 战斗属性
var max_health: int = 20
var current_health: int = 20
var is_invulnerable: bool = false

# 死亡动画相关
var is_dying: bool = false
var death_animation_complete: bool = false
var game_over_label: Label
var skip_prompt_label: Label

# 战斗边界
var battle_bounds: Rect2 = Rect2()

# 位置锁定
var is_position_locked: bool = false
var locked_position: Vector2 = Vector2.ZERO

# 使用Godot自带的UI输入映射
var move_actions = {
	"left": "ui_left",
	"right": "ui_right", 
	"up": "ui_up",
	"down": "ui_down",
	"dece" : "close_dialog"
}

var mobile_input_vector: Vector2 = Vector2.ZERO
var use_mobile_input: bool = false

func _ready():
	initialize_soul()
	setup_collision()
	add_to_group("player")
	add_to_group("player_soul")
	
	# 初始化时隐藏同级别的BlackRect
	hide_black_rect()
	
	# 连接移动端按钮信号
	_connect_mobile_input_signals()
	
	print("玩家灵魂初始化完成")

func _connect_mobile_input_signals():
	var mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input:
		if mobile_input.has_signal("investigate_pressed"):
			mobile_input.investigate_pressed.connect(_on_mobile_investigate_pressed)
	else:
		await get_tree().create_timer(1.0).timeout
		_connect_mobile_input_signals()

func _on_mobile_investigate_pressed():
	if is_dying:
		if death_animation_complete:
			end_battle_after_death()
		else:
			skip_death_animation()

func set_movement_enabled(enabled: bool):
	"""设置是否允许移动"""
	movement_enabled = enabled
	
	# 如果禁用移动，重置速度
	if not enabled:
		velocity = Vector2.ZERO
		input_vector = Vector2.ZERO

func lock_position_temporally(position: Vector2, duration: float):
	"""临时锁定玩家灵魂位置"""
	is_position_locked = true
	locked_position = position
	self.position = position
	
	get_tree().create_timer(duration).timeout.connect(
		func():
			is_position_locked = false
			print("玩家灵魂位置锁定解除")
	)

func initialize_soul():
	# 确保有精灵节点
	if not sprite:
		return
	
	# 保留您原有的材质设置
	sprite.modulate = soul_color
	
	# 确保碰撞形状存在
	if not $CollisionShape2D.shape:
		var circle = CircleShape2D.new()
		circle.radius = 8.0
		$CollisionShape2D.shape = circle

func setup_collision():
	# 设置碰撞层和掩码
	collision_layer = 2  # 玩家灵魂层
	collision_mask = 4   # 检测弹幕层
	
	# 连接碰撞信号
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

var health_bar: ProgressBar
var health_label: Label

func set_health_bar(bar: ProgressBar, label: Label):
	health_bar = bar
	health_label = label
	update_health_bar()



func set_soul_type(soul_type: String):
	
	match soul_type:
		"determination":
			soul_color = Color.WHITE
		"patience":
			soul_color = Color.CYAN
		"bravery":
			soul_color = Color.ORANGE
		"justice":
			soul_color = Color.YELLOW
		"kindness":
			soul_color = Color.GREEN
		"integrity":
			soul_color = Color.BLUE
		"perseverance":
			soul_color = Color.PURPLE
		_:
			soul_color = Color.WHITE
			print("⚠️ 未知灵魂类型，使用默认")
	
	current_health = max_health
	
	# 应用颜色
	if sprite:
		sprite.modulate = soul_color
	
	# 更新生命值条
	update_health_bar()

func _input(event):
	# 确保只有战斗中的灵魂处理输入
	for action in move_actions.values():
		if event.is_action_pressed(action) or event.is_action_released(action):
			get_viewport().set_input_as_handled()

	if is_dying and event.is_action_pressed("investigate"):
		if death_animation_complete:
			end_battle_after_death()
		else:
			# 跳过死亡动画
			skip_death_animation()

func _physics_process(delta):
	if current_health > max_health:
		current_health = max_health
	if not is_inside_tree():
		return
	
	handle_input()
	handle_movement(delta)

func handle_input():
	input_vector = Vector2.ZERO
	
	# 检查是否在战斗中且是玩家回合
	var is_player_turn_in_battle = _is_player_turn_in_battle()
	
	# 优先使用移动端输入
	if use_mobile_input and mobile_input_vector != Vector2.ZERO:
		if not is_player_turn_in_battle:
			# 只有敌人回合才允许移动端移动
			input_vector = mobile_input_vector
		# 移动端输入时强制启用移动
		movement_enabled = true
	else:
		if not is_player_turn_in_battle:
			# 只有敌人回合才允许键盘移动
			if Input.is_action_pressed(move_actions["right"]):
				input_vector.x += 1
			if Input.is_action_pressed(move_actions["left"]):
				input_vector.x -= 1
			if Input.is_action_pressed(move_actions["down"]):
				input_vector.y += 1
			if Input.is_action_pressed(move_actions["up"]):
				input_vector.y -= 1
			# 键盘输入时也启用移动
			if input_vector != Vector2.ZERO:
				movement_enabled = true
	
	if Input.is_action_pressed(move_actions["dece"]):
		move_speed = 75
	else: move_speed = 225
	
	velocity = input_vector.normalized() * move_speed

func _is_player_turn_in_battle() -> bool:
	var battle_manager = get_node_or_null("/root/BattleManager")
	if battle_manager and battle_manager.is_in_battle:
		var battle = battle_manager.current_battle
		if battle and battle.get("is_player_turn") != null:
			return battle.is_player_turn
	return false

func handle_mobile_input(input_vec: Vector2):
	mobile_input_vector = input_vec
	use_mobile_input = input_vec != Vector2.ZERO
	
	# 当有移动端输入时，强制启用移动
	if input_vec != Vector2.ZERO:
		movement_enabled = true

func _has_keyboard_input() -> bool:
	return Input.is_action_pressed(move_actions["right"]) or \
		   Input.is_action_pressed(move_actions["left"]) or \
		   Input.is_action_pressed(move_actions["up"]) or \
		   Input.is_action_pressed(move_actions["down"])

func handle_movement(delta):
	# 位置锁定优先
	if is_position_locked:
		position = locked_position
		return
	
	# 检查是否允许移动
	if not movement_enabled:
		return
	
	if velocity != Vector2.ZERO:
		var new_position = position + velocity * delta
		
		# 应用边界限制
		if battle_bounds.has_area():
			new_position.x = clamp(new_position.x, battle_bounds.position.x, battle_bounds.end.x)
			new_position.y = clamp(new_position.y, battle_bounds.position.y, battle_bounds.end.y)
		
		position = new_position

func _on_area_entered(area: Area2D):
	# 检测弹幕碰撞
	if area.is_in_group("bullet"):
		if area.has_method("get_damage"):
			take_damage(area.get_damage())
			SoundManager.play_damage()
		# 可选：销毁弹幕
		if area.has_method("on_hit"):
			area.on_hit()

func _on_body_entered(body: Node2D):
	# 处理与其他物体的碰撞（如果需要）
	pass

func take_damage(amount: int):
	if is_invulnerable or is_dying:
		return
	current_health -= amount
	SoundManager.play_hurt()
	
	# 更新生命值条
	update_health_bar()
	
	# 受伤特效
	play_hurt_effect()
	
	# 进入无敌状态
	is_invulnerable = true
	
	# 无敌时间后恢复
	get_tree().create_timer(1).timeout.connect(
		func(): 
			is_invulnerable = false
			sprite.modulate = soul_color
	)
	
	if current_health <= 0:
		die()

func update_health_bar():
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
		update_health_label()  # 同时更新标签


func update_health_label():
	if health_label:
		# 显示格式：当前值/最大值
		health_label.text = str(current_health) + "/" + str(max_health)

func play_hurt_effect():
	var flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.BLACK, 0.05)
	flash_tween.tween_property(sprite, "modulate", soul_color, 0.05)
	flash_tween.tween_property(sprite, "modulate", Color.BLACK, 0.05)
	flash_tween.tween_property(sprite, "modulate", soul_color, 0.05)

func hide_black_rect():
	# 隐藏同级别的BlackRect
	var black_rect = get_parent().get_node_or_null("BlackRect")
	if black_rect:
		black_rect.visible = false

func show_black_rect():
	# 显示同级别的BlackRect
	var black_rect = get_parent().get_node_or_null("BlackRect")
	if black_rect:
		black_rect.visible = true

func die():
	
	# 设置死亡状态
	is_dying = true
	death_animation_complete = false
	
	SoundManager.play("soul_shatter", -5.0)
	
	# 停止所有移动
	velocity = Vector2.ZERO
	
	# 隐藏生命值条
	if health_bar and is_instance_valid(health_bar):
		health_bar.visible = false
	
	# 显示同级别的BlackRect
	show_black_rect()
	
	# 开始死亡动画
	play_death_animation()

func play_death_animation():
	
	# 1. 灵魂破裂效果
	play_soul_shatter_effect()
	
	# 2. 延迟后显示GAME OVER
	get_tree().create_timer(1.0).timeout.connect(
		func():
			if is_dying and not death_animation_complete:
				show_game_over()
	)
	
	# 3. 动画完成后设置标志
	get_tree().create_timer(3.0).timeout.connect(
		func():
			if is_dying and not death_animation_complete:
				death_animation_complete = true
				show_skip_prompt()
	)

func play_soul_shatter_effect():
	# 灵魂破裂动画
	var shatter_tween = create_tween()
	shatter_tween.set_parallel(true)
	
	# 缩放和旋转效果
	shatter_tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.5)
	shatter_tween.tween_property(sprite, "rotation", PI * 2, 0.5)
	
	# 颜色闪烁和透明度变化
	shatter_tween.tween_property(sprite, "modulate", Color(soul_color, 0.7), 0.3)
	shatter_tween.tween_property(sprite, "modulate", Color(soul_color, 0.3), 0.2)
	shatter_tween.tween_property(sprite, "modulate", Color(soul_color, 0.0), 0.5)
	
	# 最后隐藏精灵
	shatter_tween.tween_callback(
		func(): 
			sprite.visible = false
	).set_delay(1.0)

func show_game_over():
	# 创建GAME OVER标签
	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置字体样式
	var font = load("res://font/main.ttf")
	if font:
		game_over_label.add_theme_font_override("font", font)
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_color", Color.WHITE)
	game_over_label.add_theme_color_override("font_outline_color", Color.BLACK)
	game_over_label.add_theme_constant_override("outline_size", 2)
	
	# 设置位置（屏幕中央）
	var viewport_size = get_viewport().get_visible_rect().size
	game_over_label.position = Vector2(viewport_size.x / 2 - 150, viewport_size.y / 2 - 50)
	game_over_label.size = Vector2(300, 100)
	
	# 初始透明
	game_over_label.modulate = Color(1, 1, 1, 0)
	
	# 添加到场景
	get_parent().add_child(game_over_label)
	
	# 渐显动画
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(game_over_label, "modulate", Color(1, 1, 1, 1), 1.5)
	fade_in_tween.tween_callback(
		func(): 
			print("GAME OVER显示完成")
	)

func show_skip_prompt():
	# 显示跳过提示
	skip_prompt_label = Label.new()
	skip_prompt_label.text = "按Z键继续"
	skip_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置字体样式
	var font = load("res://font/main.ttf")
	if font:
		skip_prompt_label.add_theme_font_override("font", font)
	skip_prompt_label.add_theme_font_size_override("font_size", 24)
	skip_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	skip_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	skip_prompt_label.add_theme_constant_override("outline_size", 1)
	
	# 设置位置（GAME OVER下方）
	var viewport_size = get_viewport().get_visible_rect().size
	skip_prompt_label.position = Vector2(viewport_size.x / 2 - 75, viewport_size.y / 2 + 50)
	skip_prompt_label.size = Vector2(150, 50)
	
	# 添加到场景
	get_parent().add_child(skip_prompt_label)


func skip_death_animation():
	
	# 停止所有tween
	var tweens = get_tree().get_nodes_in_group("tween")
	for tween in tweens:
		if tween is Tween:
			tween.kill()
	
	# 立即完成灵魂破裂效果
	sprite.scale = Vector2(1.5, 1.5)
	sprite.rotation = PI * 2
	sprite.modulate = Color(soul_color, 0.0)
	sprite.visible = false
	
	# 移除可能存在的GAME OVER标签
	if game_over_label and is_instance_valid(game_over_label):
		game_over_label.queue_free()
	
	# 创建并立即显示GAME OVER
	show_game_over()
	
	# 移除可能存在的跳过提示
	if skip_prompt_label and is_instance_valid(skip_prompt_label):
		skip_prompt_label.queue_free()
	
	# 显示跳过提示
	show_skip_prompt()
	
	# 标记动画完成
	death_animation_complete = true

func end_battle_after_death():
	
	# 清理UI元素
	if game_over_label and is_instance_valid(game_over_label):
		game_over_label.queue_free()
	
	if skip_prompt_label and is_instance_valid(skip_prompt_label):
		skip_prompt_label.queue_free()
	
	# 通知战斗结束
	var battle_scene = get_parent()
	if battle_scene and battle_scene.has_method("end_battle"):
		battle_scene.end_battle(false)
	else:
		# 备选方案：直接通过BattleManager
		var battle_manager = get_node("/root/BattleManager")
		if battle_manager and battle_manager.has_method("end_battle"):
			battle_manager.end_battle(false)

func set_battle_bounds(battle_area_center: Vector2, battle_area_size: Vector2):
	# 计算移动边界（留出边距）
	var margin = 10.0
	var half_size = battle_area_size / 2 - Vector2(margin, margin)
	
	battle_bounds = Rect2(
		battle_area_center - half_size,
		half_size * 2
	)
	
	# 立即应用边界限制
	position.x = clamp(position.x, battle_bounds.position.x, battle_bounds.end.x)
	position.y = clamp(position.y, battle_bounds.position.y, battle_bounds.end.y)
