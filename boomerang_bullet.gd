extends Area2D

# 弹幕属性
var speed: float = 100.0
var damage: int = 1
var direction: Vector2 = Vector2.ZERO
var color: Color = Color.CYAN
var bullet_style: int = 0  # 新增：弹幕样式变量

var launch_duration: float = 4  # 飞出
var return_duration: float = 4.5  # 返回
var launch_time: float = 0.0
var is_returning: bool = false
var origin_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO

# 节点引用
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	# 设置碰撞层：弹幕应该在特定层，并检测玩家层
	collision_layer = 4  # 弹幕层
	collision_mask = 2   # 检测玩家层
	
	# 添加到弹幕组
	add_to_group("bullets")
	
	# 设置外观
	if sprite:
		sprite.modulate = color
	
	# 连接碰撞信号
	area_entered.connect(_on_area_entered)

	
	# 自动销毁计时器（安全措施）
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 15.0  # 比总飞行时间长一些
	timer.timeout.connect(_on_lifetime_end)
	timer.start()

func setup_boomerang(start_pos: Vector2, target_pos: Vector2, bullet_color: Color = Color.CYAN, bullet_speed: float = 100.0, style: int = 0):
	global_position = start_pos
	origin_position = start_pos
	target_position = target_pos
	color = bullet_color
	speed = bullet_speed
	bullet_style = style  # 设置样式
	
	# 应用样式纹理
	apply_style_texture(style)
	
	# 计算初始方向（朝向目标）
	direction = (target_pos - start_pos).normalized()
	
	# 设置外观
	if sprite:
		sprite.modulate = color

# 新增：应用样式纹理
func apply_style_texture(style: int):
	if sprite:
		# 根据样式编号加载对应的纹理
		var texture_path = "res://bullets/bt" + str(style) + ".png"
		if ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
		else:
			# 如果纹理不存在，使用默认纹理
			sprite.texture = load("res://bullets/bt0.png")

func _physics_process(delta):
	if not is_inside_tree():
		return
	
	launch_time += delta
	
	if not is_returning:
		# 飞出阶段
		if launch_time < launch_duration:
			# 继续向目标移动
			position += direction * speed * delta
		else:
			# 切换到返回阶段
			is_returning = true
			launch_time = 0.0
	else:
		# 返回阶段
		if launch_time < return_duration:
			# 计算返回方向（朝向发射者）
			var return_direction = (origin_position - global_position).normalized()
			position += return_direction * speed * delta
		else:
			# 返回时间结束，销毁弹幕
			queue_free()
	
	# 检查距离，如果太远也销毁（安全措施）
	if global_position.distance_to(origin_position) > 1000:
		queue_free()

func _on_area_entered(area):
	# 检测是否碰到玩家灵魂
	if area.is_in_group("player_soul") or area.is_in_group("player") or area.is_in_group("soul"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
			queue_free()

func _on_lifetime_end():
	# 生命周期结束，安全销毁
	queue_free()

func get_damage() -> int:
	return damage
