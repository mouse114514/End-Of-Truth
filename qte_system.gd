extends CanvasLayer

var target_sprites: Array = []
var player_sprite: Sprite2D
var circle_center: Vector2
var circle_dots: Array = []

var radius: float = 120.0
var line_length: float = 80.0

var hit_count: int = 0
var triggered_indices: Array = []  # 已触发（命中或未命中）的线
var miss_indices: Array = []  # 未命中的线（标记为miss）
var is_qte_active: bool = false

var box_size: float = 350.0
var battle_box: ColorRect
var inner_box: ColorRect
var damage_label: Label

var base_damage: int = 10

var target_angles: Array = []
var player_angle: float = 0.0
var player_rotation_speed: float = 180.0
var rotation_direction: int = 1

var angle_tolerance: float = 15.0

# 限制
var max_rotations: int = 1  # 最多1圈
var max_time: float = 5.0  # 最多5秒
var current_rotations: float = 0.0
var current_time: float = 0.0
var has_tried_to_finish: bool = false

signal qte_finished(damage_multiplier: float)

func _ready():
	visible = false
	_connect_mobile_input()

func _connect_mobile_input():
	var mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input:
		if mobile_input.has_signal("investigate_pressed"):
			mobile_input.investigate_pressed.connect(_on_mobile_investigate_pressed)
	else:
		await get_tree().create_timer(0.5).timeout
		_connect_mobile_input()

func _on_mobile_investigate_pressed():
	if is_qte_active:
		_check_hit()

func start_qte():
	visible = true
	hit_count = 0
	triggered_indices.clear()
	miss_indices.clear()
	has_tried_to_finish = false
	current_rotations = 0.0
	current_time = 0.0
	player_angle = 0.0
	
	var viewport_size = get_viewport().get_visible_rect().size
	circle_center = viewport_size / 2
	
	target_angles = _generate_random_angles(3)
	
	_create_battle_box()
	_create_circle()
	_create_lines()
	
	rotation_direction = 1 if randf() > 0.5 else -1
	
	is_qte_active = true

func _generate_random_angles(count: int) -> Array:
	var angles: Array = []
	var used_angles: Array = []
	
	while angles.size() < count:
		var angle = randf() * 360.0
		var too_close = false
		for used in used_angles:
			if abs(angle - used) < 60.0:
				too_close = true
				break
		
		if not too_close:
			angles.append(angle)
			used_angles.append(angle)
	
	return angles

func _create_battle_box():
	var viewport_size = get_viewport().get_visible_rect().size
	var box_pos = (viewport_size - Vector2(box_size, box_size)) / 2
	
	battle_box = ColorRect.new()
	battle_box.size = Vector2(box_size, box_size)
	battle_box.position = box_pos
	battle_box.color = Color.WHITE
	add_child(battle_box)
	
	inner_box = ColorRect.new()
	inner_box.size = Vector2(box_size - 6, box_size - 6)
	inner_box.position = box_pos + Vector2(3, 3)
	inner_box.color = Color.BLACK
	add_child(inner_box)

func _create_circle():
	var segments = 36
	
	for i in range(segments):
		var angle = deg_to_rad(i * 360.0 / segments)
		var x = circle_center.x + cos(angle) * radius
		var y = circle_center.y + sin(angle) * radius
		
		var dot = ColorRect.new()
		dot.size = Vector2(4, 4)
		dot.position = Vector2(x, y) - Vector2(2, 2)
		dot.color = Color(0.5, 0.5, 0.5)
		dot.z_index = 5
		add_child(dot)
		circle_dots.append(dot)

func _create_lines():
	# 创建黄色目标线（按角度排序，最上面的是1）
	var sorted_indices = _get_sorted_angle_indices()
	
	for i in range(3):
		var idx = sorted_indices[i]
		var sprite = _create_line_sprite(target_angles[idx], Color(1, 1, 0), i + 1)
		target_sprites.append(sprite)
	
	# 创建玩家白色线
	player_angle = randf() * 360.0
	player_sprite = _create_line_sprite(player_angle, Color.WHITE, 0)

func _get_sorted_angle_indices() -> Array:
	# 返回按角度排序的索引（从小到大，0-360度）
	var pairs = []
	for i in range(3):
		pairs.append({"index": i, "angle": target_angles[i]})
	
	pairs.sort_custom(func(a, b): return a.angle < b.angle)
	
	var result = []
	for pair in pairs:
		result.append(pair.index)
	
	return result

func _create_line_sprite(angle_deg: float, color: Color, order_num: int) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.z_index = 10
	
	var img = Image.create(int(line_length), 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	
	sprite.modulate = color
	
	var angle_rad = deg_to_rad(angle_deg)
	var start_x = circle_center.x + cos(angle_rad) * radius
	var start_y = circle_center.y + sin(angle_rad) * radius
	sprite.position = Vector2(start_x, start_y)
	sprite.rotation = deg_to_rad(angle_deg + 90)
	
	sprite.set_meta("angle", angle_deg)
	sprite.set_meta("order", order_num)
	
	add_child(sprite)
	
	# 添加序号标签
	if order_num > 0:
		var label = Label.new()
		label.text = str(order_num)
		label.z_index = 15
		
		var font = load("res://font/main.ttf")
		if font:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.BLACK)
		
		# 标签位置在线的上方
		var label_offset = Vector2(-5, -25)
		label.position = sprite.position + label_offset
		
		label.set_meta("parent_sprite", sprite)
		add_child(label)
	
	return sprite

func _update_label_positions():
	for child in get_children():
		if child is Label and child.has_meta("parent_sprite"):
			var sprite = child.get_meta("parent_sprite")
			if is_instance_valid(sprite):
				child.position = sprite.position + Vector2(-5, -25)

func _process(delta):
	if not is_qte_active:
		return
	
	# 记录时间
	current_time += delta
	if current_time >= max_time:
		is_qte_active = false
		_mark_remaining_as_miss()
		_finish_qte()
		return
	
	# 记录旋转圈数
	var rotation_delta = player_rotation_speed * rotation_direction * delta
	current_rotations += abs(rotation_delta) / 360.0
	
	# 一圈跑完时结束
	if current_rotations >= 1.0:
		is_qte_active = false
		_mark_remaining_as_miss()
		_finish_qte()
		return
	
	# 旋转白线
	player_angle += rotation_delta
	if player_angle >= 360.0:
		player_angle -= 360.0
	elif player_angle < 0.0:
		player_angle += 360.0
	
	var angle_rad = deg_to_rad(player_angle)
	var start_x = circle_center.x + cos(angle_rad) * radius
	var start_y = circle_center.y + sin(angle_rad) * radius
	player_sprite.position = Vector2(start_x, start_y)
	player_sprite.rotation = deg_to_rad(player_angle + 90)
	
	# 更新标签位置
	_update_label_positions()

func _mark_remaining_as_miss():
	for i in range(target_sprites.size()):
		if i in triggered_indices:
			continue
		target_sprites[i].modulate = Color(1, 0.3, 0.3)
		triggered_indices.append(i)
		miss_indices.append(i)

func _fail_qte(reason: String):
	pass  # 不再使用

func _input(event):
	if not is_qte_active:
		return
	
	if event.is_action_pressed("investigate"):
		_check_hit()

func _check_hit():
	var any_hit = false
	
	# 先检查有没有命中任何线
	for i in range(target_sprites.size()):
		if i in triggered_indices:
			continue
		
		var sprite = target_sprites[i]
		var target_angle = sprite.get_meta("angle")
		
		var diff = abs(player_angle - target_angle)
		if diff > 180.0:
			diff = 360.0 - diff
		
		if diff <= angle_tolerance:
			# 命中！变绿
			sprite.modulate = Color(0, 1, 0)
			triggered_indices.append(i)
			hit_count += 1
			any_hit = true
	
	if any_hit:
		pass  # 不反转，继续跑完这一圈
	else:
		# 找出最近的未处理线并标记为miss
		var closest_idx = -1
		var closest_diff = 360.0
		
		for i in range(target_sprites.size()):
			if i in triggered_indices:
				continue
			
			var sprite = target_sprites[i]
			var target_angle = sprite.get_meta("angle")
			var diff = abs(player_angle - target_angle)
			if diff > 180.0:
				diff = 360.0 - diff
			
			if diff < closest_diff:
				closest_diff = diff
				closest_idx = i
		
		if closest_idx >= 0:
			# 标记为miss（红色）
			target_sprites[closest_idx].modulate = Color(1, 0.3, 0.3)
			triggered_indices.append(closest_idx)
			miss_indices.append(closest_idx)

func _finish_qte():
	is_qte_active = false
	
	# 伤害计算：只计算命中的线
	# 0条 = Miss, 1条 = 0.5倍, 2条 = 1倍, 3条 = 1.5倍
	var multiplier: float = 0.0
	match hit_count:
		0: multiplier = 0.0
		1: multiplier = 0.5
		2: multiplier = 1.0
		3: multiplier = 1.5
	
	if multiplier > 0:
		SoundManager.play("slash", -5.0)
	else:
		SoundManager.play("warning", -5.0)
	
	var damage = int(base_damage * multiplier)
	_show_damage(damage, multiplier > 0)
	
	await get_tree().create_timer(1.0).timeout
	_cleanup()
	qte_finished.emit(multiplier)

func _show_damage(damage: int, show_number: bool):
	var enemy_pos = circle_center + Vector2(0, -80)
	
	damage_label = Label.new()
	damage_label.global_position = enemy_pos
	
	var font = load("res://font/wdnrh.ttf")
	if font:
		damage_label.add_theme_font_override("font", font)
	damage_label.add_theme_font_size_override("font_size", 32)
	
	if show_number:
		damage_label.text = str(damage)
		damage_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		damage_label.text = "Miss"
		damage_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	damage_label.z_index = 100
	add_child(damage_label)
	
	var tween = create_tween()
	tween.tween_property(damage_label, "position:y", enemy_pos.y - 50, 0.8)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.3)
	await tween.finished

func _cleanup():
	if battle_box:
		if is_instance_valid(battle_box):
			battle_box.queue_free()
		battle_box = null
	if inner_box:
		if is_instance_valid(inner_box):
			inner_box.queue_free()
		inner_box = null
	for sprite in target_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	target_sprites.clear()
	if player_sprite:
		if is_instance_valid(player_sprite):
			player_sprite.queue_free()
		player_sprite = null
	if damage_label:
		if is_instance_valid(damage_label):
			damage_label.queue_free()
		damage_label = null
	for dot in circle_dots:
		if is_instance_valid(dot):
			dot.queue_free()
	circle_dots.clear()
	visible = false
