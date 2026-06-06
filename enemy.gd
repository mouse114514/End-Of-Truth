extends Node2D
# 节点引用
var sprite: Sprite2D
var health_bar: ProgressBar
var bullet_container: Node2D
var bullet_pattern: Node2D

var health: int = 100
var max_health: int = 100
var attack_patterns: Array = []
var current_pattern: String = ""
var is_attacking: bool = false
var attack_timer: Timer

var enemy_type: int = 0
var bullet_tick = 0
var att_type = 0
var turn_type = 0
var enemy_id: String = ""

# 子弹场景
var bullet_scene: PackedScene
var boomerang_bullet_scene: PackedScene  

# 发射点数组
var muzzle_positions: Array = [Vector2.ZERO]
var current_muzzle_index: int = 0

# 发射方向调整变量
var direction_offset: float = 0.0
var direction_offset_mode: int = 0

# 重要：敌人是主控方，自己设置回合状态
var is_player_turn: bool = true

# 气泡对话框变量
var current_bubble: Sprite2D = null
var bubble_timer: Timer = null
var typewriter_tween: Tween = null
var current_bubble_label: Label = null

# 精灵偏移变量
var sprite_offset: Vector2 = Vector2.ZERO
var original_sprite_position: Vector2 = Vector2.ZERO

# 新增：弹幕样式变量
var bullet_v: int = 0

func _ready():
	# 初始化子弹场景
	bullet_scene = preload("res://bullet.tscn")
	boomerang_bullet_scene = preload("res://boomerang_bullet.tscn")
	
	# 安全地初始化节点引用
	initialize_nodes()
	attack_timer = Timer.new()
	add_child(attack_timer)
	
	# 初始化气泡计时器
	bubble_timer = Timer.new()
	bubble_timer.one_shot = true
	add_child(bubble_timer)
	bubble_timer.timeout.connect(_on_bubble_timeout)
	
	# typewriter_tween 在 show_speech_bubble 里创建，这里不需要提前创建
	
	if health_bar:
		health_bar.max_value = max_health
		update_health_bar()

func initialize_nodes():
	if has_node("HealthBar"):
		health_bar = $HealthBar
	
	# 【关键修改】只有当 bullet_container 没有被外部设置时才初始化
	if not is_instance_valid(bullet_container):
		if has_node("BulletContainer"):
			bullet_container = $BulletContainer
			print("[Enemy] 使用场景中的 BulletContainer: ", bullet_container.get_path())
		else:
			bullet_container = Node2D.new()
			bullet_container.name = "BulletContainer"
			add_child(bullet_container)
			print("[Enemy] 创建新的 BulletContainer")
	else:
		print("[Enemy] 保留外部设置的 bullet_container: ", bullet_container.get_path())
	
	if has_node("BulletPattern"):
		bullet_pattern = $BulletPattern
	
	# 保存精灵原始位置
	if sprite and original_sprite_position == Vector2.ZERO:
		original_sprite_position = sprite.position


func clear_bullets():
	if bullet_container:
		for bullet in bullet_container.get_children():
			if is_instance_valid(bullet):
				bullet.queue_free()

func setup_enemy(data: Dictionary):
	enemy_id = data.get("enemy_id", "")
	if enemy_id != "":
		var entry = EnemyDefs.lookup(enemy_id)
		enemy_type = entry.get("type", 0)
	else:
		enemy_type = data.get("enemy_type", 0)
	var tdata = EnemyDefs.data_of(enemy_type)

	health = data.get("enemy_health", tdata.base_hp)
	max_health = data.get("enemy_max_health", tdata.max_hp)
	attack_patterns = data.get("patterns", ["circle"])
	bullet_v = data.get("bullet_v", tdata.bullet_v)
	turn_type = data.get("turn_type", 0)

	if attack_patterns.size() < 10:
		var default_patterns = ["circle", "spiral", "aimed", "random", "boomerang", "none", "pulse_single_point", "pulse_single_direction", "cycle_multi_point", "cycle_multi_direction"]
		for i in range(10):
			if i >= attack_patterns.size():
				var pattern_to_add = default_patterns[i]
				attack_patterns.append(pattern_to_add)
	
	if health_bar:
		health_bar.max_value = max_health
		update_health_bar()

# === 修改后的气泡对话框函数 ===
func show_speech_bubble(text: String, duration: float = 3.0, off = Vector2(100, -170)) -> Signal:
	
	# 清除现有气泡
	if current_bubble:
		current_bubble.queue_free()
		current_bubble = null
		current_bubble_label = null
	
	# 创建气泡容器 - 使用Sprite2D加载图片
	current_bubble = Sprite2D.new()
	current_bubble.name = "SpeechBubble"
	current_bubble.texture = load("res://player/batt/bubble.png")
	current_bubble.position = off
	current_bubble.z_index = 1000
	current_bubble.visible = true
	
	# 添加到当前场景
	add_child(current_bubble)
	
	# 创建文本标签
	current_bubble_label = Label.new()
	current_bubble_label.name = "BubbleText"
	current_bubble_label.text = "" 
	current_bubble_label.position = Vector2(-120, -50)
	current_bubble_label.size = Vector2(240, 40)
	current_bubble_label.add_theme_font_size_override("font_size", 14)
	current_bubble_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	current_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var font = load("res://font/main.ttf")
	if font:
		current_bubble_label.add_theme_font_override("font", font)
	
	# 设置自动换行
	if current_bubble_label.has_method("set_autowrap_mode"):
		current_bubble_label.autowrap_mode = 3
	else:
		current_bubble_label.autowrap = true
	
	current_bubble_label.visible = true
	current_bubble.add_child(current_bubble_label)
	
	# 强制更新显示
	current_bubble.show()
	current_bubble_label.show()
	
	# 启动打字机效果
	start_typewriter_effect(text, duration)
	
	# 返回气泡关闭信号，供 await 使用
	return bubble_timer.timeout

func start_typewriter_effect(full_text: String, total_duration: float):
	if full_text.is_empty():
		return
	
	if not is_instance_valid(current_bubble) or not is_instance_valid(current_bubble_label):
		return
	
	# 计算打字机效果参数
	var text_length = full_text.length()
	var characters_per_second = 20.0
	var typewriter_duration = text_length / characters_per_second
	
	# 确保打字时间不超过总时间的一半，留出显示时间
	typewriter_duration = min(typewriter_duration, total_duration * 0.7)
	var display_duration = total_duration - typewriter_duration
	
	# 打字时间过短，直接显示全文
	if typewriter_duration < 0.05:
		current_bubble_label.text = full_text
		bubble_timer.wait_time = max(display_duration, 0.1)
		bubble_timer.start()
		return
	
	# 停止之前的Tween
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	
	# 创建新的Tween，先暂停防止自动启动
	typewriter_tween = create_tween()
	typewriter_tween.set_parallel(false)
	typewriter_tween.pause()
	
	# 打字机效果：逐个字符显示
	typewriter_tween.tween_method(
		func(progress: float):
			if is_instance_valid(current_bubble_label):
				var chars_to_show = int(text_length * progress)
				current_bubble_label.text = full_text.substr(0, chars_to_show)
			,
		0.0,
		1.0,
		typewriter_duration
	)
	
	# 设置气泡隐藏计时器（打字完成后开始计算显示时间）
	typewriter_tween.tween_callback(func():
		if is_instance_valid(bubble_timer):
			bubble_timer.wait_time = max(display_duration, 0.1)
			bubble_timer.start()
	)
	
	# 所有插值添加完毕后才启动
	typewriter_tween.play()

func _on_bubble_timeout():
	if current_bubble:
		# 直接移除气泡，去掉渐隐动画
		current_bubble.queue_free()
		current_bubble = null
		current_bubble_label = null

# === 原有战斗系统功能 ===
func switch_to_player_turn():
	is_player_turn = true
	stop_attacking()

func switch_to_enemy_turn():
	is_player_turn = false
	randomize()
	var tdata = EnemyDefs.data_of(enemy_type)
	turn_type = randi() % tdata.get("turn_types", 1)
	bullet_tick = 0
	start_attacking()

func set_direction_offset_mode(mode: int, offset_degrees: float = 0.0):
	direction_offset_mode = mode
	direction_offset = deg_to_rad(offset_degrees)

func apply_direction_offset(base_direction: Vector2, is_aiming: bool = false) -> Vector2:
	if direction_offset_mode == 0:
		return base_direction
	elif direction_offset_mode == 1:
		if is_aiming:
			return base_direction
		else:
			return base_direction.rotated(direction_offset)
	else:
		return base_direction.rotated(direction_offset)

func apply_target_offset(target_position: Vector2, spawn_position: Vector2) -> Vector2:
	if direction_offset_mode == 1:
		var base_direction = (target_position - spawn_position).normalized()
		var offset_direction = base_direction.rotated(direction_offset)
		var offset_distance = spawn_position.distance_to(target_position)
		return spawn_position + offset_direction * offset_distance
	else:
		return target_position

func get_player_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("soul")
	if player:
		return player.global_position
	return Vector2(400, 300)

func start_attacking():
	if not is_player_turn:
		is_attacking = true
		bullet_tick = -1  # 从-1开始，这样第一轮实际是0
		start_pattern_timer()

func stop_attacking():
	is_attacking = false
	if attack_timer:
		attack_timer.stop()

func start_pattern_timer():
	if attack_timer and not is_player_turn:
		if attack_timer.timeout.is_connected(execute_attack_pattern):
			attack_timer.timeout.disconnect(execute_attack_pattern)
		
		attack_timer.wait_time = get_pattern_interval(current_pattern)
		attack_timer.timeout.connect(execute_attack_pattern)
		attack_timer.start()

func get_pattern_interval(pattern: String) -> float:
	match pattern:
		"circle": return 0.5
		"spiral": return 0.6
		"aimed": return 0.4
		"random": return 0.2
		"boomerang": return 0.3
		"none": return 1.0
		"pulse_single_point": return 0.8
		"pulse_single_direction": return 0.8
		"cycle_multi_point": return 1.2
		"cycle_multi_direction": return 1.2
		_: return 1.5

func execute_attack_pattern():
	if not is_attacking or is_player_turn:
		return
	
	# 使用AttackPatterns执行AI逻辑
	AttackPatterns.execute_turn(self)

func get_next_muzzle_position() -> Vector2:
	if muzzle_positions.size() == 0:
		return global_position
	
	if current_muzzle_index >= muzzle_positions.size():
		current_muzzle_index = 0
	
	var relative_pos = muzzle_positions[current_muzzle_index]
	current_muzzle_index = (current_muzzle_index + 1) % muzzle_positions.size()
	return global_position + relative_pos

# 弹幕模式函数
func shoot_circle_pattern():
	var bullet_count = 10
	for i in range(bullet_count):
		var angle = (2 * PI * i) / bullet_count
		var direction = Vector2(cos(angle), sin(angle))
		direction = apply_direction_offset(direction, false)
		var spawn_position = get_next_muzzle_position()
		create_bullet(spawn_position, direction, 80.0, Color.WHITE)

func shoot_spiral_pattern():
	var time = Time.get_ticks_msec() / 1000.0
	var angle = time * 3.0
	
	for i in range(15):
		var bullet_angle = angle + (2 * PI * i) / 15
		var direction = Vector2(cos(bullet_angle), sin(bullet_angle))
		direction = apply_direction_offset(direction, false)
		var spawn_position = get_next_muzzle_position()
		create_bullet(spawn_position, direction, 100.0, Color.WHITE)

func shoot_aimed_pattern():
	var player = get_tree().get_first_node_in_group("soul")
	if player:
		var spawn_position = get_next_muzzle_position()
		var target_position = player.global_position
		
		if direction_offset_mode == 1:
			target_position = apply_target_offset(target_position, spawn_position)
		
		var direction = (target_position - spawn_position).normalized()
		direction = apply_direction_offset(direction, true)
		create_bullet(spawn_position, direction, 120.0, Color.WHITE)
		
		for i in range(10):
			var spread_angle = PI/8 * (i+1)
			var left_dir = direction.rotated(-spread_angle)
			var right_dir = direction.rotated(spread_angle)
			left_dir = apply_direction_offset(left_dir, true)
			right_dir = apply_direction_offset(right_dir, true)
			var left_spawn = get_next_muzzle_position()
			var right_spawn = get_next_muzzle_position()
			create_bullet(left_spawn, left_dir, 120.0, Color.WHITE)
			create_bullet(right_spawn, right_dir, 120.0, Color.WHITE)

func shoot_random_pattern():
	for i in range(25):
		var random_angle = randf() * 2 * PI
		var direction = Vector2(cos(random_angle), sin(random_angle))
		direction = apply_direction_offset(direction, false)
		var random_speed = randf_range(60.0, 100.0)
		var spawn_position = get_next_muzzle_position()
		create_bullet(spawn_position, direction, random_speed, Color.WHITE)

func shoot_boomerang_pattern():
	var player = get_tree().get_first_node_in_group("soul")
	var bullet_count = 7
	var spread_angle = PI/4
	
	for i in range(bullet_count):
		var angle_offset = (i - (bullet_count - 1) / 2.0) * spread_angle
		
		var base_direction
		var target_pos
		
		if player:
			var spawn_position = get_next_muzzle_position()
			target_pos = player.global_position
			
			if direction_offset_mode == 1:
				target_pos = apply_target_offset(target_pos, spawn_position)
			
			base_direction = (target_pos - spawn_position).normalized()
		else:
			base_direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()
			target_pos = global_position + base_direction * 1000
		
		var final_direction = base_direction.rotated(angle_offset)
		final_direction = apply_direction_offset(final_direction, true)
		
		if player:
			var spawn_position = get_next_muzzle_position()
			target_pos = spawn_position + final_direction * 1000
		
		var spawn_position = get_next_muzzle_position()
		create_boomerang_bullet(spawn_position, target_pos, Color.WHITE, 100.0)

func shoot_none_pattern():
	pass

func shoot_pulse_single_point():
	var start_pos = get_next_muzzle_position()
	var target_pos = Vector2(400, 300)
	var direction = (target_pos - start_pos).normalized()
	direction = apply_direction_offset(direction, false)
	create_bullet(start_pos, direction, 120.0, Color.YELLOW)

func shoot_pulse_single_direction():
	var start_pos = get_next_muzzle_position()
	var direction = Vector2(0, 1)
	direction = apply_direction_offset(direction, false)
	create_bullet(start_pos, direction, 100.0, Color.CYAN)

func shoot_cycle_multi_point():
	var start_pos = get_next_muzzle_position()
	var target_points = [
		Vector2(200, 200),   # 左上
		Vector2(600, 200),   # 右上  
		Vector2(200, 400),   # 左下
		Vector2(600, 400)    # 右下
	]
	
	for target_pos in target_points:
		var direction = (target_pos - start_pos).normalized()
		direction = apply_direction_offset(direction, false)
		create_bullet(start_pos, direction, 80.0, Color.GREEN)

func shoot_cycle_multi_direction():
	var start_pos = get_next_muzzle_position()
	var directions = []
	var bullet_count = 12
	
	for i in range(bullet_count):
		var angle = (2 * PI * i) / bullet_count
		var direction = Vector2(cos(angle), sin(angle))
		directions.append(direction)
	
	for direction in directions:
		direction = apply_direction_offset(direction, false)
		create_bullet(start_pos, direction, 90.0, Color.MAGENTA)

# 修改子弹创建函数，传递样式变量
func create_bullet(spawn_position: Vector2, direction: Vector2, speed: float, color: Color):
	if not bullet_scene:
		print("ERROR: bullet_scene is null!")
		return
		
	var bullet = bullet_scene.instantiate()
	
	if bullet_container:
		bullet_container.add_child(bullet)
		print("Bullet added to bullet_container: ", bullet_container.name)
	else:
		add_child(bullet)
		print("Bullet added to enemy directly")
	
	bullet.global_position = spawn_position
	
	if bullet.has_method("setup_bullet"):
		bullet.setup_bullet(direction, speed, color, bullet_v)  # 传递样式变量
		print("Bullet created at: ", spawn_position, " direction: ", direction, " speed: ", speed)
	else:
		print("ERROR: bullet missing setup_bullet method!")

# 修改回旋镖子弹创建函数，传递样式变量
func create_boomerang_bullet(start_pos: Vector2, target_pos: Vector2, color: Color, speed: float):
	if not boomerang_bullet_scene:
		return
		
	var bullet = boomerang_bullet_scene.instantiate()
	
	if bullet_container:
		bullet_container.add_child(bullet)
	else:
		add_child(bullet)
	
	bullet.global_position = start_pos
	
	if bullet.has_method("setup_boomerang"):
		bullet.setup_boomerang(start_pos, target_pos, color, speed, bullet_v)  # 传递样式变量

func take_damage(amount: int):
	health -= amount
	SoundManager.play("hurt", -8.0)
	update_health_bar()
	if health <= 0:
		die()

func update_health_bar():
	if health_bar:
		health_bar.value = health

func set_sprite_offset(offset: Vector2) -> void:
	sprite_offset = offset
	if sprite:
		sprite.position = original_sprite_position + sprite_offset

func reset_sprite_offset() -> void:
	sprite_offset = Vector2.ZERO
	if sprite:
		sprite.position = original_sprite_position

func die():
	is_attacking = false
	SoundManager.play_enemy_death()
	
	if attack_timer:
		attack_timer.stop()
	
	if get_parent() and get_parent().has_method("end_battle"):
		get_parent().end_battle(true)

func get_bullet_container() -> Node2D:
	return bullet_container
