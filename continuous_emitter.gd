class_name ContinuousBulletEmitter
extends Node

signal finished

# 参数
var start_position: Vector2 = Vector2.ZERO
var key_positions: Array = []
var key_targets: Array = []
var move_duration: float = 1.0
var emit_count: int = 5
var special_tags: Array = []
var target_selector: String = "absolute"

# editor 预览时设置的全局偏移，使子弹位置与标记对齐
var global_offset: Vector2 = Vector2.ZERO

# 内部状态
var _enemy: Node
var _container: Node
var _current_emit: int = 0

const TRAVEL_TIME: float = 1.2

func start(enemy: Node, container: Node):
	_enemy = enemy
	_container = container
	_current_emit = 0
	
	if emit_count <= 0 or not is_instance_valid(enemy):
		_finish()
		return
	
	_do_emit()

func _do_emit():
	if not is_instance_valid(_enemy):
		_finish()
		return
	
	var progress = float(_current_emit) / float(emit_count)
	
	# 计算当前位置和目标
	var path_points = [start_position] + key_positions
	var pos: Vector2
	var target: Vector2
	
	if path_points.size() <= 1:
		pos = start_position
		target = key_targets[0] if key_targets.size() > 0 else start_position
	else:
		var total_length = _calculate_total_length(path_points)
		var dist = progress * total_length
		var idx = _find_segment(path_points, dist)
		var seg_progress = _segment_progress(path_points, idx, dist)
		pos = path_points[idx].lerp(path_points[idx + 1], seg_progress)
		target = key_targets[idx].lerp(key_targets[idx + 1], seg_progress) if idx + 1 < key_targets.size() else (key_targets[0] if key_targets.size() > 0 else pos)
	
	# 解析坐标
	var actual_emitter = _resolve_position(pos)
	var actual_target = _resolve_position(target)
	
	# 创建子弹
	var is_arc = _get_arc_tag() != ""
	
	if is_arc:
		_execute_arc(actual_emitter, actual_target)
	else:
		_execute_single(actual_emitter, actual_target)
	
	_current_emit += 1
	if _current_emit >= emit_count:
		_finish()
	else:
		var interval = move_duration / float(emit_count)
		var timer = Timer.new()
		timer.wait_time = interval
		timer.one_shot = true
		timer.timeout.connect(_do_emit)
		add_child(timer)
		timer.start()

func _finish():
	finished.emit()

func _calculate_total_length(points: Array) -> float:
	var total = 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	if total <= 0:
		total = 1.0
	return total

func _find_segment(points: Array, dist: float) -> int:
	var cum = 0.0
	for i in range(points.size() - 1):
		var seg = points[i].distance_to(points[i + 1])
		if dist <= cum + seg:
			return i
		cum += seg
	return points.size() - 2

func _segment_progress(points: Array, idx: int, dist: float) -> float:
	var cum = 0.0
	for i in range(idx):
		cum += points[i].distance_to(points[i + 1])
	var seg = points[idx].distance_to(points[idx + 1])
	if seg <= 0:
		return 0.0
	return (dist - cum) / seg

func _resolve_position(pos: Vector2) -> Vector2:
	if is_instance_valid(_enemy):
		return _enemy.global_position + Vector2(pos.x, -pos.y) + global_offset
	return pos

func _calculate_speed(distance: float) -> float:
	if distance <= 0:
		return 100.0
	return distance / TRAVEL_TIME

func _get_arc_tag() -> String:
	for tag in ["圆", "180弧", "120弧", "60弧", "30弧"]:
		if special_tags.has(tag):
			return tag
	return ""

func _execute_single(emitter_pos: Vector2, target_pos: Vector2):
	var direction = (target_pos - emitter_pos).normalized()
	var distance = emitter_pos.distance_to(target_pos)
	var speed = _calculate_speed(distance)
	
	var is_reverse = special_tags.has("反向")
	var is_boomerang = special_tags.has("回旋镖")
	
	if is_reverse:
		if is_boomerang:
			_enemy.create_boomerang_bullet(target_pos, emitter_pos, Color.WHITE, speed)
		else:
			_enemy.create_bullet(target_pos, -direction, speed, Color.WHITE)
	else:
		if is_boomerang:
			_enemy.create_boomerang_bullet(emitter_pos, target_pos, Color.WHITE, speed)
		else:
			_enemy.create_bullet(emitter_pos, direction, speed, Color.WHITE)

func _execute_arc(emitter_pos: Vector2, target_pos: Vector2):
	var arc_tag = _get_arc_tag()
	if arc_tag == "":
		return
	
	var base_direction = (target_pos - emitter_pos).normalized()
	var base_angle = base_direction.angle()
	var distance = emitter_pos.distance_to(target_pos)
	var speed = _calculate_speed(distance)
	
	var half_angle = deg_to_rad(BulletEmitter.ARC_ANGLES[arc_tag] / 2.0)
	var count = BulletEmitter.ARC_BULLET_COUNTS[arc_tag]
	var is_reverse = special_tags.has("反向")
	var is_boomerang = special_tags.has("回旋镖")
	
	for i in range(count):
		var t = float(i) / float(count - 1) if count > 1 else 0.5
		var offset = -half_angle + half_angle * 2.0 * t
		var dir = Vector2.from_angle(base_angle + offset)
		
		if is_reverse:
			var spawn_pos = emitter_pos + dir * distance
			var fly_dir = -dir
			if is_boomerang:
				_enemy.create_boomerang_bullet(spawn_pos, emitter_pos, Color.WHITE, speed)
			else:
				_enemy.create_bullet(spawn_pos, fly_dir, speed, Color.WHITE)
		else:
			if is_boomerang:
				_enemy.create_boomerang_bullet(emitter_pos, emitter_pos + dir * distance, Color.WHITE, speed)
			else:
				_enemy.create_bullet(emitter_pos, dir, speed, Color.WHITE)

# 从 JSON 创建
static func from_dict(data: Dictionary) -> ContinuousBulletEmitter:
	var emitter = ContinuousBulletEmitter.new()
	
	if data.has("start_pos") and data["start_pos"] is Array:
		var arr = data["start_pos"]
		if arr.size() >= 2:
			emitter.start_position = Vector2(arr[0], arr[1])
	
	if data.has("key_positions") and data["key_positions"] is Array:
		for p in data["key_positions"]:
			if p is Array and p.size() >= 2:
				emitter.key_positions.append(Vector2(p[0], p[1]))
	
	if data.has("key_targets") and data["key_targets"] is Array:
		for p in data["key_targets"]:
			if p is Array and p.size() >= 2:
				emitter.key_targets.append(Vector2(p[0], p[1]))
	
	emitter.move_duration = data.get("move_duration", 1.0)
	emitter.emit_count = data.get("emit_count", 5)
	emitter.target_selector = data.get("target_selector", "absolute")
	
	if data.has("tags") and data["tags"] is Array:
		for t in data["tags"]:
			emitter.special_tags.append(str(t))
	
	return emitter

func to_dict() -> Dictionary:
	var kp = []
	for p in key_positions:
		kp.append([p.x, p.y])
	var kt = []
	for p in key_targets:
		kt.append([p.x, p.y])
	
	return {
		"type": "emit_continuous",
		"start_pos": [start_position.x, start_position.y],
		"key_positions": kp,
		"key_targets": kt,
		"move_duration": move_duration,
		"emit_count": emit_count,
		"target_selector": target_selector,
		"tags": special_tags.duplicate()
	}
