extends Area2D

@onready var sprite = $Sprite2D
var velocity: Vector2 = Vector2.ZERO
var speed: float = 100.0
var damage: int = 1
var bullet_color: Color = Color.WHITE
var bullet_style: int = 0  # 新增：弹幕样式变量

func _ready():
	process_mode = Node.PROCESS_MODE_INHERIT  # 确保处理不被禁用
	#print("Bullet ready, path:", get_path(), " velocity: ", velocity)
	# 设置碰撞层：弹幕应该在特定层，并检测玩家层
	collision_layer = 4  # 弹幕层
	collision_mask = 2   # 检测玩家层
	
	# 添加到弹幕组
	add_to_group("bullets")
	
	# 连接碰撞信号
	area_entered.connect(_on_area_entered)

func setup_bullet(direction: Vector2, bullet_speed: float, color: Color = Color.WHITE, style: int = 0):
	velocity = direction.normalized() * bullet_speed
	#print("Bullet setup: velocity=", velocity, " speed=", bullet_speed)
	bullet_color = color
	bullet_style = style  # 设置样式
	
	# 应用样式纹理
	apply_style_texture(style)
	
	if sprite:
		sprite.modulate = color
	
	# 自动销毁
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 10.0
	timer.timeout.connect(queue_free)
	timer.start()

# 新增：应用样式纹理
func apply_style_texture(style: int):
	if sprite:
		# 根据样式编号加载对应的纹理
		var texture_path = "res://bullets/bt" + str(style) + ".png"
		if ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
			#print("✅ 加载弹幕纹理: ", texture_path)
		else:
			print("❌ 纹理不存在: ", texture_path)
			# 如果纹理不存在，使用默认纹理
			sprite.texture = load("res://bullets/bt0.png")

func _process(delta):
	if velocity.length() > 0:
		position += velocity * delta
		# 调试输出（每60帧输出一次）
		#if Engine.get_frames_drawn() % 60 == 0:
			#print("Bullet moving: pos=", position, " vel=", velocity)

func _on_area_entered(area):
	# 检测是否碰到玩家灵魂
	if area.is_in_group("player_soul") or area.is_in_group("player"):
		print("💥 弹幕击中玩家，样式:", bullet_style)
		if area.has_method("take_damage"):
			area.take_damage(damage)
			queue_free()
