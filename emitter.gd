class_name BulletEmitter
extends RefCounted

# 发射器核心数据
var emitter_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
# 坐标模式: "absolute" 绝对坐标, "relative" 相对敌人位置
var target_selector: String = "absolute"
var special_tags: Array[String] = []

# 内部常量
const TRAVEL_TIME: float = 1.2  # 子弹固定1.2秒到达（降低速度）
const ARC_BULLET_COUNTS: Dictionary = {
	"圆": 20,
	"180弧": 10,
	"120弧": 8,
	"60弧": 4,
	"30弧": 2
}
const ARC_ANGLES: Dictionary = {
	"圆": 360,
	"180弧": 180,
	"120弧": 120,
	"60弧": 60,
	"30弧": 30
}
const SPIRAL_BULLET_COUNT: int = 30
const SPIRAL_INTERVAL: float = 0.04

func _init(em_pos: Vector2, target_pos: Vector2, tags: Array = []):
	emitter_position = em_pos
	target_position = target_pos
	special_tags = []
	for t in tags:
		special_tags.append(str(t))

# 主执行方法
func execute(enemy, bullet_container):
	var is_spiral = special_tags.has("螺旋")
	var is_boomerang = special_tags.has("回旋镖")
	var is_reverse = special_tags.has("反向")
	var is_arc = _get_arc_tag() != ""
	
	# 根据坐标模式计算实际位置
	var actual_emitter = _resolve_position(enemy, emitter_position)
	var actual_target = _resolve_position(enemy, target_position)
	
	if is_spiral and is_arc:
		await _execute_spiral(enemy, bullet_container, actual_emitter, actual_target, is_reverse, is_boomerang)
	elif is_arc:
		_execute_arc(enemy, bullet_container, actual_emitter, actual_target, is_reverse, is_boomerang)
	else:
		_execute_single(enemy, bullet_container, actual_emitter, actual_target, is_reverse, is_boomerang)

# 解析坐标：根据target_selector决定是绝对还是相对
func _resolve_position(enemy, pos: Vector2) -> Vector2:
	if target_selector == "relative":
		return enemy.global_position + pos
	else:
		return pos

# 获取当前使用的弧标签（优先级：圆 > 180弧 > 120弧 > 60弧 > 30弧）
func _get_arc_tag() -> String:
	for tag in ["圆", "180弧", "120弧", "60弧", "30弧"]:
		if special_tags.has(tag):
			return tag
	return ""

# 计算速度：距离/0.5秒
func _calculate_speed(distance: float) -> float:
	if distance <= 0:
		return 100.0
	return distance / TRAVEL_TIME

# 获取弧线角度范围（以目标方向为基准）
func _get_arc_angles(arc_tag: String) -> Array:
	var half_angle: float = deg_to_rad(ARC_ANGLES[arc_tag] / 2.0)
	var result: Array = []
	var count: int = ARC_BULLET_COUNTS[arc_tag]
	for i in range(count):
		var t: float = float(i) / float(count - 1) if count > 1 else 0.5
		result.append(-half_angle + half_angle * 2.0 * t)
	return result

# 执行单发子弹（无弧/圆标签）
func _execute_single(enemy, bullet_container, emitter_pos: Vector2, target_pos: Vector2, is_reverse: bool, is_boomerang: bool):
	var direction = (target_pos - emitter_pos).normalized()
	var distance = emitter_pos.distance_to(target_pos)
	var speed = _calculate_speed(distance)
	
	if is_reverse:
		if is_boomerang:
			enemy.create_boomerang_bullet(target_pos, emitter_pos, Color.WHITE, speed)
		else:
			enemy.create_bullet(target_pos, -direction, speed, Color.WHITE)
	else:
		if is_boomerang:
			enemy.create_boomerang_bullet(emitter_pos, target_pos, Color.WHITE, speed)
		else:
			enemy.create_bullet(emitter_pos, direction, speed, Color.WHITE)

# 执行弧线弹幕（圆/180弧/120弧/60弧/30弧）
func _execute_arc(enemy, bullet_container, emitter_pos: Vector2, target_pos: Vector2, is_reverse: bool, is_boomerang: bool):
	var arc_tag = _get_arc_tag()
	if arc_tag == "":
		return
	
	var base_direction = (target_pos - emitter_pos).normalized()
	var base_angle = base_direction.angle()
	var arc_offsets = _get_arc_angles(arc_tag)
	var distance = emitter_pos.distance_to(target_pos)
	var speed = _calculate_speed(distance)
	
	for offset in arc_offsets:
		var final_angle = base_angle + offset
		var dir = Vector2.from_angle(final_angle)
		
		if is_reverse:
			var spawn_pos = emitter_pos + dir * distance
			var fly_dir = -dir
			if is_boomerang:
				enemy.create_boomerang_bullet(spawn_pos, emitter_pos, Color.WHITE, speed)
			else:
				enemy.create_bullet(spawn_pos, fly_dir, speed, Color.WHITE)
		else:
			if is_boomerang:
				enemy.create_boomerang_bullet(emitter_pos, emitter_pos + dir * distance, Color.WHITE, speed)
			else:
				enemy.create_bullet(emitter_pos, dir, speed, Color.WHITE)

# 执行螺旋弹幕（需搭配圆/弧标签）
func _execute_spiral(enemy, bullet_container, emitter_pos: Vector2, target_pos: Vector2, is_reverse: bool, is_boomerang: bool):
	var arc_tag = _get_arc_tag()
	if arc_tag == "":
		return  # 螺旋必须有圆/弧标签
	
	var base_direction = (target_pos - emitter_pos).normalized()
	var base_angle = base_direction.angle()
	var distance = emitter_pos.distance_to(target_pos)
	var speed = _calculate_speed(distance)
	
	var total_angle = deg_to_rad(ARC_ANGLES[arc_tag])
	var half_angle = total_angle / 2.0
	
	for i in range(SPIRAL_BULLET_COUNT):
		var progress = float(i) / SPIRAL_BULLET_COUNT
		var current_angle = base_angle - half_angle + total_angle * progress
		var dir = Vector2.from_angle(current_angle)
		
		if is_reverse:
			var spawn_pos = emitter_pos + dir * distance
			var fly_dir = -dir
			if is_boomerang:
				enemy.create_boomerang_bullet(spawn_pos, emitter_pos, Color.WHITE, speed)
			else:
				enemy.create_bullet(spawn_pos, fly_dir, speed, Color.WHITE)
		else:
			if is_boomerang:
				enemy.create_boomerang_bullet(emitter_pos, emitter_pos + dir * distance, Color.WHITE, speed)
			else:
				enemy.create_bullet(emitter_pos, dir, speed, Color.WHITE)
		
		# 只有最后一颗子弹不等待
		if i < SPIRAL_BULLET_COUNT - 1:
			await enemy.get_tree().create_timer(SPIRAL_INTERVAL).timeout

# 辅助方法：从JSON数据创建发射器
static func from_dict(data: Dictionary) -> BulletEmitter:
	var em_pos = Vector2.ZERO
	var target_pos = Vector2.ZERO
	var tags: Array[String] = []
	var mode = "absolute"
	
	if data.has("emitter_pos") and data["emitter_pos"] is Array:
		var pos_arr = data["emitter_pos"]
		if pos_arr.size() >= 2:
			em_pos = Vector2(pos_arr[0], pos_arr[1])
	
	if data.has("target_pos") and data["target_pos"] is Array:
		var pos_arr = data["target_pos"]
		if pos_arr.size() >= 2:
			target_pos = Vector2(pos_arr[0], pos_arr[1])
	
	if data.has("target_selector"):
		mode = str(data["target_selector"])
	
	if data.has("tags") and data["tags"] is Array:
		for t in data["tags"]:
			tags.append(str(t))
	
	var emitter = BulletEmitter.new(em_pos, target_pos, tags)
	emitter.target_selector = mode
	return emitter

# 转换为JSON可序列化的字典
func to_dict() -> Dictionary:
	return {
		"type": "emit",
		"emitter_pos": [emitter_position.x, emitter_position.y],
		"target_pos": [target_position.x, target_position.y],
		"target_selector": target_selector,
		"tags": special_tags.duplicate()
	}
