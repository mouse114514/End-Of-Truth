extends CanvasLayer

@onready var black_background = $ColorRect
@onready var white_border = $ColorRect/ColorRect
@onready var black_content = $ColorRect/ColorRect/ColorRect
@onready var player_soul = $PlayerSoul

@onready var bullet_container = $ColorRect/BulletContainer
@onready var backgro = $ColorRect/background
@onready var enemy = $ColorRect/Enemy
@onready var sprite = $ColorRect/Sprite2D
@onready var player_health_bar = $PlayerHealthBar
@onready var player_health_label = $HealthLabel
@onready var hp_label = $HPLabel

var iftext: RichTextLabel

# 玩家回合系统变量
var is_player_turn: bool = true
var favor: int = 100
var current_selection: int = 0
var last_player_choice: int = -1  # 保存上一轮玩家选择，-1表示默认敌人回合
var current_sub_selection: int = 0
var is_in_submenu: bool = false

# 移动端输入变量
var last_mobile_input: Vector2 = Vector2.ZERO
var mobile_input_threshold: float = 0.5

# 图片菜单系统
var menu_sprites: Array = []
var submenu_labels: Array = []  # 现在是RichTextLabel数组

# 战斗状态变量
var battle_data: Dictionary = {}
var is_battle_active: bool = false

var world_snapshot_texture: Texture2D

# 敌人回合控制
var enemy_turn_count: int = 0
var last_detected_enemy_turn_state: bool = true

# 子菜单选项
var submenu_options: Array = [
	["敌人类型"],  # 战斗子菜单
	["快速背叛", "增加好感"],  # 行动子菜单
	["面包"],  # 物品子菜单
	["背叛", "逃跑"]  # 仁慈子菜单
]

# 战斗边界控制
var original_bounds_center: Vector2
var original_bounds_size: Vector2
var bounds_saved: bool = false
var is_first_turn: bool = true

# 战斗框动画参数
var original_box_size: Vector2
var original_box_position: Vector2
var player_turn_box_size: Vector2
var player_turn_box_position: Vector2
var is_animating: bool = false

# 血条相对于战斗框的偏移
var health_bar_offset: Vector2 = Vector2(10, -70)
var health_bar_enemy_turn_extra_offset: Vector2 = Vector2(0, 90)

var qte_system: Node = null
var qte_scene: PackedScene = null

func _ready():
	visible = false
	hide_all_elements()
	enemy.sprite = sprite
	
	# 预加载QTE场景
	qte_scene = preload("res://qte_system.tscn")
	
	# 创建文本标签
	iftext = RichTextLabel.new()
	iftext.name = "iftext"
	iftext.bbcode_enabled = true
	iftext.visible = false
	iftext.offset_left = 236
	iftext.offset_top = 278
	iftext.offset_right = 737
	iftext.offset_bottom = 390
	iftext.text = "* text"
	
	# 设置字体
	var iftext_font = load("res://font/main.ttf")
	if iftext_font:
		iftext.add_theme_font_override("normal_font", iftext_font)
	
	add_child(iftext)
	# 像素渲染优化设置
	setup_pixel_rendering()
	
	initialize_ui_elements()
	initialize_image_menu_system()
	initialize_text_submenus()
	
	# 记录原始战斗框尺寸和位置
	original_box_size = white_border.size
	original_box_position = white_border.position
	
	# 计算玩家回合的战斗框尺寸（宽度增加到2.7倍，高度减少）
	var viewport_size = get_viewport().get_visible_rect().size
	player_turn_box_size = Vector2(original_box_size.x * 2.7, original_box_size.y * 0.6)
	player_turn_box_position = Vector2(
		(viewport_size.x - player_turn_box_size.x) / 2,
		original_box_position.y + (original_box_size.y - player_turn_box_size.y) / 2
	)
	
	# 连接移动端按钮信号
	_connect_mobile_input_signals()

func _connect_mobile_input_signals():
	var mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input:
		if mobile_input.has_signal("close_dialog_pressed"):
			mobile_input.close_dialog_pressed.connect(_on_mobile_close_dialog_pressed)
	else:
		await get_tree().create_timer(1.0).timeout
		_connect_mobile_input_signals()

func _on_mobile_close_dialog_pressed():
	if is_battle_active and is_in_submenu and qte_system == null:
		show_main_menu()
		move_soul_directly_to_current_option()

func setup_pixel_rendering():
	"""设置像素完美渲染"""
	# 设置Viewport为像素完美渲染
	get_viewport().msaa_2d = Viewport.MSAA_DISABLED  # 关闭多重采样
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED  # 关闭屏幕空间抗锯齿
	get_viewport().scaling_3d_scale = 1.0  # 确保没有缩放

func initialize_ui_elements():
	var viewport_size = get_viewport().get_visible_rect().size
	black_background.size = viewport_size
	print(viewport_size)
	black_background.color = Color.BLACK

	backgro.position = Vector2(597, 446)
	
	# 将战斗框的Y轴大小从275改为220，调小了20%
	var battle_box_size = Vector2(275, 220)  # 原为Vector2(275, 275)
	
	white_border.size = battle_box_size
	white_border.position = (viewport_size - battle_box_size) / 2
	white_border.color = Color.WHITE
	black_content.size = battle_box_size - Vector2(6, 6)
	black_content.position = Vector2(3, 3)
	black_content.color = Color.BLACK
	
	# 计算血条相对于战斗框的偏移
	health_bar_offset = Vector2(10, white_border.size.y - 70)
	update_health_bar_position()
	customize_player_health_bar_style()
	update_player_health_display()

func update_health_bar_position():
	var extra_offset = Vector2.ZERO
	if not is_player_turn:
		extra_offset = health_bar_enemy_turn_extra_offset
	var base_pos = white_border.position + health_bar_offset + extra_offset + Vector2(300, 0)
	player_health_bar.position = base_pos
	player_health_label.position = base_pos + Vector2(85, 5)
	hp_label.position = base_pos + Vector2(-40, 5)

func initialize_text_submenus():
	"""使用RichTextLabel实现纵向排列 - 像素字体优化"""
	
	submenu_labels.clear()
	
	var viewport_size = get_viewport().get_visible_rect().size
	var submenu_position = Vector2(viewport_size.x * 0.22, viewport_size.y * 0.42)
	var submenu_size = Vector2(200, 120)  # 足够高度显示多行
	
	for i in range(4):
		var rich_label = RichTextLabel.new()
		rich_label.name = "RichSubmenu_%d" % i
		rich_label.global_position = submenu_position  # 使用全局坐标
		rich_label.size = submenu_size
		rich_label.bbcode_enabled = true
		rich_label.scroll_active = false
		rich_label.fit_content = true
		rich_label.visible = false
		
		# 设置Z-index层级，让子菜单在灵魂后面
		rich_label.z_index = 50
		rich_label.z_as_relative = false
		
		# 应用您的自定义字体
		var custom_font = load("res://font/main.ttf")
		if custom_font:
			rich_label.add_theme_font_override("normal_font", custom_font)
		
		# 像素字体关键设置
		rich_label.add_theme_font_size_override("normal_font_size", 22)
		
		# RichTextLabel正确的像素优化设置
		rich_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 最近邻过滤
		
		# 对于RichTextLabel的正确设置
		rich_label.meta_underlined = false
		
		# 添加到场景根节点，不受战斗框变形影响
		add_child(rich_label)
		submenu_labels.append(rich_label)

func customize_player_health_bar_style():
	var background_style = StyleBoxFlat.new()
	background_style.bg_color = Color(0.5, 0.1, 0.1, 1)
	
	player_health_bar.add_theme_stylebox_override("background", background_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1, 0.9, 0.2)
	
	player_health_bar.add_theme_stylebox_override("fill", fill_style)
	
	var font = load("res://font/wdnrh.ttf")
	if font:
		player_health_label.add_theme_font_override("font", font)
		hp_label.add_theme_font_override("font", font)
	player_health_label.add_theme_font_size_override("font_size", 24)
	player_health_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_font_size_override("font_size", 24)
	hp_label.add_theme_color_override("font_color", Color.WHITE)

func update_player_health_display():
	if player_soul and is_instance_valid(player_soul):
		player_health_bar.max_value = player_soul.max_health
		player_health_bar.value = player_soul.current_health
		player_health_label.text = str(player_soul.current_health) + "/" + str(player_soul.max_health)

func initialize_image_menu_system():
	"""初始化图片菜单系统 - 横向排列，使用固定屏幕位置"""
	
	menu_sprites.clear()
	
	var img_size = Vector2(145, 135) 
	var viewport_size = get_viewport().get_visible_rect().size
	var base_y = viewport_size.y - 150  # 屏幕底部固定位置
	
	# 使用固定的屏幕位置，不依赖战斗框
	var menu_positions = [
		Vector2(viewport_size.x * 0.23, base_y + 10),   # 战斗
		Vector2(viewport_size.x * 0.41, base_y + 10),   # 行动
		Vector2(viewport_size.x * 0.59, base_y + 10),   # 物品
		Vector2(viewport_size.x * 0.76, base_y + 10)    # 仁慈
	]
	
	for i in range(4):
		var sprite = Sprite2D.new()
		sprite.name = "MenuSprite_" + str(i)
		sprite.global_position = menu_positions[i]  # 使用全局坐标
		sprite.visible = false
		
		# 设置Z-index层级，让菜单在灵魂后面
		sprite.z_index = 50
		sprite.z_as_relative = false
		
		var texture_path = get_menu_texture_path(i, false)
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			sprite.texture = texture
			
			var scale_x = img_size.x / texture.get_width()
			var scale_y = img_size.y / texture.get_height()
			sprite.scale = Vector2(scale_x, scale_y)
		else:
			sprite.texture = load("res://player/batt/EAIM/n_fig.png")
		
		# 添加到场景根节点，不受战斗框变形影响
		add_child(sprite)
		menu_sprites.append(sprite)

func get_menu_texture_path(index: int, is_selected: bool) -> String:
	var prefix = "l_" if is_selected else "n_"
	var texture_name = ""
	
	match index:
		0: texture_name = "fig"  # 战斗
		1: texture_name = "act"  # 行动
		2: texture_name = "ite"  # 物品
		3: texture_name = "mer"  # 仁慈
		_: texture_name = "fig"   # 默认
	
	return "res://player/batt/EAIM/" + prefix + texture_name + ".png"

func hide_all_elements():
	black_background.visible = false
	white_border.visible = false
	black_content.visible = false
	player_soul.visible = false
	enemy.visible = false
	backgro.visible = false
	player_health_bar.visible = false
	
	# 隐藏菜单选项
	for sprite in menu_sprites:
		if is_instance_valid(sprite):
			sprite.visible = false
	for label in submenu_labels:
		if is_instance_valid(label):
			label.visible = false

func hide_all_menu_sprites():
	for sprite in menu_sprites:
		if is_instance_valid(sprite):
			sprite.visible = false
	
	for label in submenu_labels:
		if is_instance_valid(label):
			label.visible = false
	
	if is_instance_valid(iftext):
		iftext.visible = false

func play_black_flash_with_ui():
	visible = true
	black_background.visible = true
	white_border.visible = false
	black_content.visible = false
	enemy.visible = false
	backgro.visible = false
	sprite.visible = false
	player_health_bar.visible = false
	player_health_label.visible = false
	hp_label.visible = false
	
	await get_tree().create_timer(0.1).timeout
	for i in 3:
		black_background.visible = false
		await get_tree().create_timer(0.05).timeout
		SoundManager.play("blackout")
		black_background.visible = true
		if i < 2:
			await get_tree().create_timer(0.05).timeout
	
	await get_tree().create_timer(0.05).timeout
	show_all_battle_ui()

func start_battle(data: Dictionary):
	battle_data = data
	is_battle_active = true
	is_first_turn = true
	
	var start_with_enemy = data.get("start_with_enemy_turn", false)
	enemy.is_player_turn = not start_with_enemy
	is_player_turn = not start_with_enemy
	last_detected_enemy_turn_state = enemy.is_player_turn
	
	current_selection = 0
	current_sub_selection = 0
	is_in_submenu = false
	enemy_turn_count = 0
	bounds_saved = false
	
	main_menu_char_index = 0
	
	await play_black_flash_with_ui()
	_play_battle_bgm()

func _play_battle_bgm():
	var bgm_path = EnemyDefs.battle_bgm_of(enemy.enemy_type)
	if bgm_path != "":
		SoundManager.play_bgm(bgm_path)

func show_all_battle_ui():
	SoundManager.play_battle_start()
	black_background.visible = true
	white_border.visible = true
	black_content.visible = true
	#player_soul.visible = false
	enemy.visible = true
	backgro.visible = true
	sprite.visible = true
	player_health_bar.visible = true
	player_health_label.visible = true
	hp_label.visible = true
	bullet_container.z_index = 200
	show_main_menu()
	
	if player_soul:
		# 设置灵魂可见
		player_soul.visible = true
		# 设置灵魂Z-index高于菜单
		player_soul.z_index = 100
		player_soul.z_as_relative = false
		player_soul.set_process_input(true)
		player_soul.set_physics_process(true)
		
	
	set_battle_bounds()
	initialize_player_soul()
	initialize_enemy()

	if is_first_turn:
		if is_player_turn:
			on_player_turn_started()
		else:
			on_enemy_turn_started()
		is_first_turn = false

func set_battle_bounds():
	if player_soul and player_soul.has_method("set_battle_bounds"):
		var battle_area_center = black_content.global_position + black_content.size / 2
		var battle_area_size = black_content.size
		
		original_bounds_center = battle_area_center
		original_bounds_size = battle_area_size
		bounds_saved = true
		
		player_soul.set_battle_bounds(battle_area_center, battle_area_size)

func remove_battle_bounds():
	if player_soul and player_soul.has_method("set_battle_bounds") and bounds_saved:
		var viewport_size = get_viewport().get_visible_rect().size
		player_soul.set_battle_bounds(viewport_size / 2, viewport_size * 10)

func restore_battle_bounds():
	if player_soul and player_soul.has_method("set_battle_bounds") and bounds_saved:
		player_soul.set_battle_bounds(original_bounds_center, original_bounds_size)

func initialize_player_soul():
	if player_soul and player_soul.has_method("set_soul_type"):
		var soul_type = battle_data.get("soul_type", "determination")
		player_soul.set_soul_type(soul_type)
		
		var soul_position = Vector2(black_content.size.x / 2, black_content.size.y / 2)
		player_soul.position = black_content.global_position + soul_position
		
		player_soul.set_health_bar(player_health_bar, player_health_label)
		player_soul.health_bar = player_health_bar
		player_soul.health_label = player_health_label
		
		# 设置灵魂Z-index高于菜单
		player_soul.z_index = 100
		player_soul.z_as_relative = false
		
		# 确保血条可见
		player_health_bar.visible = true
		update_player_health_display()

func initialize_enemy():
	if enemy and enemy.has_method("setup_enemy"):
		enemy.setup_enemy(battle_data)

		var tex_path = EnemyDefs.sprite_texture_of(enemy.enemy_id)
		if tex_path != "" and ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
		var s = EnemyDefs.sprite_scale_of(enemy.enemy_id)
		sprite.scale = Vector2(s, s)

		var enemy_position = Vector2(black_content.size.x / 2, 80)

		if enemy.has_method("set_scale"):
			enemy.set_scale(Vector2(1.5, 1.5))
		elif enemy.has_property("scale"):
			enemy.scale = Vector2(1.5, 1.5)

		enemy.position = black_content.global_position + enemy_position

func _process(delta):
	if not is_battle_active:
		return
	
	# 每帧更新血条位置（跟随战斗框动画）
	if is_animating:
		update_health_bar_position()
	
	# 打字机动画
	if main_menu_char_index < main_menu_text.length():
		main_menu_timer += delta
		if main_menu_timer >= 0.05:
			main_menu_timer = 0
			main_menu_char_index += 1
			if is_instance_valid(iftext):
				iftext.text = main_menu_text.substr(0, main_menu_char_index)
	
	# 更新玩家血量显示
	update_player_health_display()
	
	if enemy.is_player_turn != last_detected_enemy_turn_state:
		last_detected_enemy_turn_state = enemy.is_player_turn
		is_player_turn = enemy.is_player_turn
		
		if is_player_turn:
			on_player_turn_started()
		else:
			on_enemy_turn_started()
	
	process_player_input()

func on_player_turn_started():
	# 清除所有弹幕
	_clear_all_bullets()
	
	player_soul.lock_position_temporally(Vector2(222, 476), 0.5)
	# 动画：战斗框变形为玩家回合状态
	animate_battle_box_to_player_turn()
	
	remove_battle_bounds()
	show_main_menu()
	
	if player_soul and player_soul.has_method("set_movement_enabled"):
		player_soul.set_movement_enabled(false)
	
	# 确保灵魂Z-index高于菜单
	if player_soul:
		player_soul.z_index = 100
		player_soul.z_as_relative = false
	
	move_soul_directly_to_current_option()

func _clear_all_bullets():
	# 清除主战斗框的弹幕
	if bullet_container:
		for bullet in bullet_container.get_children():
			if is_instance_valid(bullet):
				bullet.queue_free()
	
	# 清除敌人的弹幕
	if enemy and enemy.has_method("clear_bullets"):
		enemy.clear_bullets()
	
	black_background.visible = true
	white_border.visible = true
	black_content.visible = true
	player_soul.visible = true
	enemy.visible = true
	backgro.visible = true
	player_health_bar.visible = true

func on_enemy_turn_started():
	# 检查是否只打一回合
	var end_after_one = battle_data.get("end_after_one_turn", false)
	if end_after_one and enemy_turn_count >= 1:
		end_battle(true)
		return
	
	# 确保灵魂可见
	if player_soul:
		player_soul.visible = true
	
	# 动画：战斗框恢复为正常状态
	animate_battle_box_to_normal()
	
	restore_battle_bounds()
	hide_all_menu_sprites()
	
	if player_soul and player_soul.has_method("set_movement_enabled"):
		player_soul.set_movement_enabled(true)
	
	# 确保灵魂Z-index高于菜单
	if player_soul:
		player_soul.z_index = 100
		player_soul.z_as_relative = false
	
	var battle_center = black_content.global_position + black_content.size / 2
	player_soul.position = battle_center
	
	notify_enemy_turn_started()
	enemy_turn_count += 1

func animate_battle_box_to_player_turn():
	"""动画：战斗框变形为玩家回合状态 - 菜单选项保持不动"""
	if is_animating:
		return
	
	is_animating = true
	var tween = create_tween()
	tween.set_parallel(true)  # 并行执行所有动画
	
	# 只动画战斗框相关节点，菜单选项保持不动
	tween.tween_property(white_border, "size", player_turn_box_size, 0.3)
	tween.tween_property(white_border, "position", player_turn_box_position, 0.3)
	tween.tween_property(black_content, "size", player_turn_box_size - Vector2(6, 6), 0.3)
	tween.tween_property(black_content, "position", Vector2(3, 3), 0.3)
	tween.tween_property(backgro, "position", Vector2(597, 196), 0.3)
	
	# 调整敌人位置
	if enemy:
		var new_enemy_y = 10  # 敌人位置上移
		tween.tween_property(enemy, "position:y", black_content.global_position.y + new_enemy_y, 0.3)
	
	# 血条跟随战斗框移动
	update_health_bar_position()
	
	# 菜单选项不参与动画，保持原位置不动
	
	tween.finished.connect(_on_player_turn_animation_finished)

func animate_battle_box_to_normal():
	"""动画：战斗框恢复为正常状态 - 菜单选项保持不动"""
	if is_animating:
		return
	
	is_animating = true
	var tween = create_tween()
	tween.set_parallel(true)  # 并行执行所有动画
	
	# 只动画战斗框相关节点
	tween.tween_property(white_border, "size", original_box_size, 0.3)
	tween.tween_property(white_border, "position", original_box_position, 0.3)
	tween.tween_property(black_content, "size", original_box_size - Vector2(6, 6), 0.3)
	tween.tween_property(black_content, "position", Vector2(3, 3), 0.3)
	tween.tween_property(backgro, "position", Vector2(597, 246), 0.3)
	
	# 恢复敌人位置
	if enemy:
		var original_enemy_y = 80  # 恢复为新的敌人位置
		tween.tween_property(enemy, "position:y", black_content.global_position.y + original_enemy_y, 0.3)
	
	# 血条跟随战斗框移动
	update_health_bar_position()
	
	# 菜单选项保持不动
	
	tween.finished.connect(_on_enemy_turn_animation_finished)

func _on_player_turn_animation_finished():
	is_animating = false
	# 更新血条位置
	update_health_bar_position()
	# 菜单选项保持原位置，不需要任何调整
	set_battle_bounds_after_animation()
	# 动画完成后显示主菜单文本
	_show_main_menu_with_typewriter()

var main_menu_text: String = "* 选择行动"
var main_menu_char_index: int = 0
var main_menu_timer: float = 0.0
var main_menu_font_size: int = 27

func _show_main_menu_with_typewriter():
	if not is_instance_valid(iftext):
		return
	main_menu_text = "* 选择行动"
	main_menu_char_index = 0
	iftext.text = ""
	var custom_font = load("res://font/main.ttf")
	if custom_font:
		iftext.add_theme_font_override("normal_font", custom_font)
	iftext.add_theme_font_size_override("normal_font_size", main_menu_font_size)
	iftext.add_theme_color_override("font_color", Color.WHITE)
	iftext.add_theme_constant_override("outline_size", 0)
	iftext.visible = true

func _on_enemy_turn_animation_finished():
	is_animating = false
	# 更新血条位置
	update_health_bar_position()
	# 菜单选项保持原位置，不需要任何调整
	set_battle_bounds_after_animation()

func set_battle_bounds_after_animation():
	"""动画后重新设置战斗边界"""
	if player_soul and player_soul.has_method("set_battle_bounds"):
		var battle_area_center = black_content.global_position + black_content.size / 2
		var battle_area_size = black_content.size
		
		player_soul.set_battle_bounds(battle_area_center, battle_area_size)

func notify_enemy_turn_started():
	if enemy and enemy.has_method("on_enemy_turn_started"):
		enemy.on_enemy_turn_started()
	elif enemy and enemy.has_method("set_turn_started"):
		enemy.set_turn_started(true)
	elif enemy and enemy.has_method("start_attacking"):
		enemy.start_attacking()

func move_soul_directly_to_current_option():
	if not player_soul:
		return
	
	if is_in_submenu:
		move_soul_to_submenu_option()
	else:
		# 基于black_content的相对位置
		var menu_positions = [
			Vector2(15, black_content.size.y + 90),   # 战斗
			Vector2(220, black_content.size.y + 90),  # 行动
			Vector2(430, black_content.size.y + 90),  # 物品
			Vector2(625, black_content.size.y + 90)   # 仁慈
		]
		print(Vector2(15, black_content.size.y + 80))
		if current_selection < menu_positions.size():
			var soul_position = menu_positions[current_selection]
			player_soul.position = black_content.global_position + soul_position

func move_soul_to_submenu_option():
	"""移动灵魂到当前子菜单选项的位置"""
	if not player_soul or not is_in_submenu:
		return
	
	if current_selection < submenu_labels.size():
		var rich_label = submenu_labels[current_selection]
		if is_instance_valid(rich_label):
			var option_height = 35
			var soul_offset_y = current_sub_selection * option_height
			
			# 使用子菜单的全局坐标
			var soul_position = Vector2(
				rich_label.global_position.x - 30,
				rich_label.global_position.y + soul_offset_y + option_height / 2
			)
			
			player_soul.global_position = soul_position

func show_main_menu():
	is_in_submenu = false
	current_selection = 0
	SoundManager.play_ui("button")
	
	# 隐藏所有子菜单标签
	for label in submenu_labels:
		if is_instance_valid(label):
			label.visible = false
	
	# 重置打字机动画并显示文本
	main_menu_char_index = 0
	if is_instance_valid(iftext):
		iftext.text = ""
		var custom_font = load("res://font/main.ttf")
		if custom_font:
			iftext.add_theme_font_override("normal_font", custom_font)
		iftext.add_theme_font_size_override("normal_font_size", main_menu_font_size)
		iftext.add_theme_color_override("font_color", Color.WHITE)
		iftext.add_theme_constant_override("outline_size", 0)
		iftext.visible = true
	
	# 显示所有图片菜单
	for i in range(menu_sprites.size()):
		var sprite = menu_sprites[i]
		if is_instance_valid(sprite):
			sprite.visible = true
			var texture_path = get_menu_texture_path(i, i == current_selection)
			if ResourceLoader.exists(texture_path):
				sprite.texture = load(texture_path)
func show_submenu():
	is_in_submenu = true
	current_sub_selection = 0
	SoundManager.play_ui("select")
	
	# 隐藏主菜单提示
	if is_instance_valid(iftext):
		iftext.visible = false
	
	# 隐藏所有图片菜单
	for sprite in menu_sprites:
		if is_instance_valid(sprite):
			sprite.visible = false
	
	# 显示当前选择的子菜单
	if current_selection < submenu_labels.size():
		var label = submenu_labels[current_selection]
		if is_instance_valid(label):
			label.visible = true
			update_submenu_display()

func update_submenu_display():
	if is_in_submenu and current_selection < submenu_labels.size():
		var rich_label = submenu_labels[current_selection]
		if is_instance_valid(rich_label):
			var options = get_submenu_options(current_selection)
			var bbcode_text = ""
			
			for i in range(options.size()):
				if i == current_sub_selection:
					bbcode_text += options[i] + "\n"
				else:
					bbcode_text += options[i] + "\n"
			
			rich_label.text = bbcode_text
			move_soul_to_submenu_option()

func get_submenu_options(menu_index: int) -> Array:
	match menu_index:
		0: return [EnemyDefs.battle_name_of(enemy.enemy_id)]
		1: return ["快速背叛", "增加好感"]
		2: return ["面包"]
		3: return ["背叛", "逃跑"]
		_: return []

func process_player_input():
	if not is_battle_active or not is_player_turn:
		return
	
	# 敌人回合选择输入处理
	if is_in_enemy_choice:
		handle_enemy_choice_input()
		return
	
	# 键盘输入处理
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_right"):
		if is_in_submenu:
			var options = get_submenu_options(current_selection)
			current_sub_selection = (current_sub_selection + 1) % options.size()
			update_submenu_display()
			SoundManager.play_ui("select")
		else:
			current_selection = (current_selection + 1) % 4
			update_main_menu_display()
			move_soul_directly_to_current_option()
			SoundManager.play_ui("select")
	
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_left"):
		if is_in_submenu:
			var options = get_submenu_options(current_selection)
			current_sub_selection = (current_sub_selection - 1) % options.size()
			if current_sub_selection < 0:
				current_sub_selection = options.size() - 1
			update_submenu_display()
			SoundManager.play_ui("select")
		else:
			current_selection = (current_selection - 1) % 4
			if current_selection < 0:
				current_selection = 3
			update_main_menu_display()
			move_soul_directly_to_current_option()
			SoundManager.play_ui("select")
	
	elif Input.is_action_just_pressed("investigate") and qte_system == null:
		execute_player_choice()
		SoundManager.play_ui("confirm")
	
	elif Input.is_action_just_pressed("close_dialog") and is_in_submenu and qte_system == null:
		show_main_menu()
		move_soul_directly_to_current_option()

func process_mobile_input(input_vec: Vector2):
	if not is_battle_active or not is_player_turn:
		return
	
	if input_vec.x > mobile_input_threshold and last_mobile_input.x <= mobile_input_threshold:
		if is_in_submenu:
			var options = get_submenu_options(current_selection)
			current_sub_selection = (current_sub_selection + 1) % options.size()
			update_submenu_display()
			SoundManager.play_ui("select")
		else:
			current_selection = (current_selection + 1) % 4
			update_main_menu_display()
			move_soul_directly_to_current_option()
			SoundManager.play_ui("select")
	elif input_vec.x < -mobile_input_threshold and last_mobile_input.x >= -mobile_input_threshold:
		if is_in_submenu:
			var options = get_submenu_options(current_selection)
			current_sub_selection = (current_sub_selection - 1) % options.size()
			if current_sub_selection < 0:
				current_sub_selection = options.size() - 1
			update_submenu_display()
			SoundManager.play_ui("select")
		else:
			current_selection = (current_selection - 1) % 4
			if current_selection < 0:
				current_selection = 3
			update_main_menu_display()
			move_soul_directly_to_current_option()
			SoundManager.play_ui("select")
	elif input_vec.y > mobile_input_threshold and last_mobile_input.y <= mobile_input_threshold:
		if is_in_submenu:
			var options = get_submenu_options(current_selection)
			current_sub_selection = (current_sub_selection + 1) % options.size()
			update_submenu_display()
			SoundManager.play_ui("select")
		else:
			SoundManager.play_ui("confirm")
			execute_player_choice()
	elif input_vec.y < -mobile_input_threshold and last_mobile_input.y >= -mobile_input_threshold:
		if is_in_submenu:
			var options = get_submenu_options(current_selection)
			current_sub_selection = (current_sub_selection - 1) % options.size()
			if current_sub_selection < 0:
				current_sub_selection = options.size() - 1
			update_submenu_display()
			SoundManager.play_ui("select")
	
	last_mobile_input = input_vec

func update_main_menu_display():
	for i in range(menu_sprites.size()):
		var sprite = menu_sprites[i]
		if is_instance_valid(sprite):
			var texture_path = get_menu_texture_path(i, i == current_selection)
			if ResourceLoader.exists(texture_path):
				sprite.texture = load(texture_path)

func execute_player_choice():
	if is_in_submenu:
		match current_selection:
			0: execute_fight_choice()
			1: execute_act_choice()
			2: execute_item_choice()
			3: execute_mercy_choice()
	else:
		show_submenu()
		move_soul_directly_to_current_option()

func execute_fight_choice():
	player_attack()
	SoundManager.play("hit", -5.0)

func execute_act_choice():
	match current_sub_selection:
		0:  # 快速背叛：快速将好感度设为100，用于达到背叛门槛
			favor = 100
			switch_to_enemy_turn()
		1:  # 增加好感：每次增加10好感度
			favor += 10
			favor = min(favor, 100)
			switch_to_enemy_turn()

func execute_item_choice():
	if player_soul and "current_health" in player_soul and "max_health" in player_soul:
		var heal_amount = 10
		var new_health = player_soul.current_health + heal_amount
		player_soul.current_health = min(new_health, player_soul.max_health)
		SoundManager.play_heal()
	switch_to_enemy_turn()

func execute_mercy_choice():
	match current_sub_selection:
		0: 
			if favor >= 100:
				SoundManager.play_level_up()
				await get_tree().create_timer(0.3).timeout
				end_battle(true)
				return  # 战斗结束，不再切换回合
		1: 
			var escape_roll = randi() % 101
			if escape_roll <= favor:
				SoundManager.play("flee", -5.0)
				await get_tree().create_timer(0.3).timeout
				end_battle(true)
				return  # 战斗结束，不再切换回合
			else:
				switch_to_enemy_turn()

func player_attack():
	# 隐藏战斗UI
	hide_all_menu_sprites()
	if is_instance_valid(iftext):
		iftext.visible = false
	
	# 隐藏战斗框和灵魂
	white_border.visible = false
	black_content.visible = false
	if player_soul:
		player_soul.visible = false
	
	# 禁用玩家控制
	if player_soul and player_soul.has_method("set_movement_enabled"):
		player_soul.set_movement_enabled(false)
	
	# 启动QTE系统
	_start_qte()

func _start_qte():
	if qte_scene:
		qte_system = qte_scene.instantiate()
		add_child(qte_system)
		qte_system.qte_finished.connect(_on_qte_finished)
		qte_system.start_qte()

func _on_qte_finished(multiplier: float):
	if qte_system:
		var qs = qte_system
		qte_system = null
		if is_instance_valid(qs):
			qs.queue_free()

	if EnemyDefs.is_dodge(enemy.enemy_id):
		multiplier = 0.0

	var base_damage = 10
	var damage = int(base_damage * multiplier)

	if damage > 0 and enemy and enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	
	# 恢复战斗UI（进入敌人回合时）
	white_border.visible = true
	black_content.visible = true
	if player_soul:
		player_soul.visible = true
	
	# 伤害结算后进入敌人回合
	await get_tree().create_timer(0.5).timeout
	switch_to_enemy_turn()

func switch_to_enemy_turn():
	enemy.is_player_turn = false
	print("switch_to_enemy_turn: current_selection=", current_selection)
	# 只有玩家做了有效选择（>=0）才保存
	# -1表示默认敌人回合（开局），0-3是有效选择
	if current_selection >= 0:
		last_player_choice = current_selection
	current_selection = 0  # 重置玩家选择

func switch_to_player_turn():
	enemy.is_player_turn = true
	current_selection = 0  # 重置玩家选择
	# last_player_choice 不在这里重置，留给敌人回合使用

func end_battle(victory: bool):
	is_battle_active = false
	SoundManager.stop_bgm()
	
	if not victory:
		is_player_turn = false
		enemy.is_player_turn = true
	
	restore_battle_bounds()
	
	if not victory:
		animate_battle_box_to_normal()
	
	if player_soul:
		player_soul.set_process_input(false)
		player_soul.set_physics_process(false)
	
	if victory:
		await _show_victory_sequence()
	else:
		visible = false
		hide_all_elements()
	
	var battle_manager = get_node("/root/BattleManager")
	if battle_manager and battle_manager.has_method("end_battle"):
		battle_manager.end_battle(victory)
	else:
		handle_battle_end_directly(victory)

func handle_battle_end_directly(victory: bool):
	visible = false
	hide_all_elements()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.visible = true
		player.set_process_input(true)
		player.set_physics_process(true)

func _show_victory_sequence():
	# 保持当前战斗框样式，隐藏其他元素
	visible = true
	black_background.visible = true
	black_content.visible = true
	white_border.visible = true
	iftext.text = ""
	
	# 如果是敌人回合触发的胜利，显式改为玩家回合样式
	if not is_player_turn:
		animate_battle_box_to_player_turn()
		await get_tree().create_timer(0.3).timeout  # 等待动画完成
	
	# 隐藏其他战斗元素
	player_soul.visible = false
	enemy.visible = false
	backgro.visible = false
	player_health_bar.visible = false
	player_health_label.visible = false
	sprite.visible = false
	
	# 隐藏菜单选项
	hide_all_menu_sprites()
	
	# 显示胜利文本（在hide_all_menu_sprites之后，因为它会隐藏iftext）
	iftext.visible = true
	
	# 设置胜利消息
	var eid = enemy.enemy_id if is_instance_valid(enemy) else ""
	var victory_text = "* 你胜利啦！你打败了 " + EnemyDefs.battle_name_of(eid)
	
	# 手动打字机效果
	for i in range(victory_text.length() + 1):
		iftext.text = victory_text.substr(0, i)
		await get_tree().create_timer(0.05).timeout
	
	# 等待0.3秒让玩家阅读
	await get_tree().create_timer(0.3).timeout
	
	# 淡入黑色（0.5秒）
	var fade_rect = await _fade_to_black(0.5)
	
	# 淡出黑色/淡入亮（0.5秒）
	await _fade_to_bright(0.5, fade_rect)
	
	visible = false
	hide_all_elements()

func _wait_for_typewriter_complete():
	# 等待打字机动画完成
	while main_menu_char_index < main_menu_text.length():
		await get_tree().process_frame

func _fade_to_black(duration: float):
	# 创建全屏黑色覆盖，添加到根节点而非当前场景
	var fade_rect = ColorRect.new()
	fade_rect.name = "VictoryFadeRect"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(fade_rect)
	
	# 逐渐变暗
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	await tween.finished
	return fade_rect

func _fade_to_bright(duration: float, fade_rect: ColorRect):
	# 淡出黑色/淡入亮
	if fade_rect and is_instance_valid(fade_rect):
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, duration)
		await tween.finished
		fade_rect.queue_free()

func _input(event):
	if event.is_action_pressed("ui_accept") and not is_battle_active:
		var test_data = {
			"soul_type": "determination",
			"enemy_health": 100,
			"patterns": ["circle", "spiral"]
		}
		start_battle(test_data)
	
	if event.is_action_pressed("ui_cancel") and is_battle_active:
		end_battle(true)
	
	if event.is_action_pressed("ui_page_up") and is_battle_active and is_player_turn:
		switch_to_enemy_turn()
	
	if event.is_action_pressed("ui_page_down") and is_battle_active and not is_player_turn:
		switch_to_player_turn()

# ==================== 敌人回合选择UI ====================

var enemy_choice_options: Array = []
var enemy_choice_selected: int = 0
var is_in_enemy_choice: bool = false
var enemy_choice_resolved: bool = false
var enemy_choice_label: RichTextLabel = null

func show_enemy_choice_ui(options: Array) -> int:
	enemy_choice_options = options
	enemy_choice_selected = 0
	is_in_enemy_choice = true
	enemy_choice_resolved = false
	
	# 创建选项显示标签
	if not is_instance_valid(enemy_choice_label):
		enemy_choice_label = RichTextLabel.new()
		enemy_choice_label.name = "EnemyChoiceLabel"
		enemy_choice_label.bbcode_enabled = true
		enemy_choice_label.custom_minimum_size = Vector2(200, 150)
		enemy_choice_label.position = Vector2(100, 100)
		enemy_choice_label.visible = true
		add_child(enemy_choice_label)
	
	# 显示在战斗框中
	enemy_choice_label.visible = true
	update_enemy_choice_display()
	
	# 等待玩家选择
	while not enemy_choice_resolved:
		await get_tree().create_timer(0.1).timeout
	
	# 隐藏选项
	enemy_choice_label.visible = false
	is_in_enemy_choice = false
	
	return enemy_choice_selected

func update_enemy_choice_display():
	if is_instance_valid(enemy_choice_label):
		var bbcode_text = ""
		for i in range(enemy_choice_options.size()):
			if i == enemy_choice_selected:
				bbcode_text += "[color=yellow]> " + enemy_choice_options[i] + " <[/color]\n"
			else:
				bbcode_text += "  " + enemy_choice_options[i] + "\n"
		enemy_choice_label.text = bbcode_text

func handle_enemy_choice_input():
	if not is_in_enemy_choice:
		return
	
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_right"):
		enemy_choice_selected = (enemy_choice_selected + 1) % enemy_choice_options.size()
		update_enemy_choice_display()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_left"):
		enemy_choice_selected = (enemy_choice_selected - 1 + enemy_choice_options.size()) % enemy_choice_options.size()
		update_enemy_choice_display()
	elif Input.is_action_pressed("investigate") or Input.is_action_pressed("ui_accept"):
		enemy_choice_resolved = true
