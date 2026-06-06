class_name AttackPatterns
extends RefCounted

# ==================== 敌人上下文（用于无参数行为函数） ====================

static var _current_enemy_ref: WeakRef = null

static func _set_context(enemy: Node) -> void:
	if is_instance_valid(enemy):
		_current_enemy_ref = weakref(enemy)
	else:
		_current_enemy_ref = null

static func _enemy() -> Node:
	if _current_enemy_ref and _current_enemy_ref.get_ref():
		return _current_enemy_ref.get_ref()
	return null

# ==================== 弹幕发射函数 ====================

# ==================== 行为函数（无enemy参数） ====================

static func text(tick: int, txt: String, dur: float = 3.0, off = Vector2(100, -130)) -> Signal:
	var e = _enemy()
	if not is_instance_valid(e):
		# 返回一个永远不会触发的 Signal 作为占位
		var dummy_timer = Timer.new()
		dummy_timer.wait_time = 0.001
		dummy_timer.one_shot = true
		e.add_child(dummy_timer)
		dummy_timer.start()
		return dummy_timer.timeout
	return e.show_speech_bubble(txt, dur, off)

static func stats(tick: int, hp: int, max_hp: int) -> void:
	var e = _enemy()
	if not is_instance_valid(e): return
	e.health = hp
	e.max_health = max_hp
	if e.has_method("update_health_bar"): e.update_health_bar()

static func end_turn(tick: int) -> void:
	var e = _enemy()
	if not is_instance_valid(e): return
	e.is_player_turn = true

static func _battle_scene() -> Node:
	var e = _enemy()
	if is_instance_valid(e):
		var parent = e.get_parent()
		if is_instance_valid(parent):
			var grandparent = parent.get_parent()
			if is_instance_valid(grandparent) and "last_player_choice" in grandparent:
				return grandparent
		# 编辑器模式：返回敌人本身，让 get_player_choice 从 meta 读取
		return e
	return null

# ==================== 时间线（JSON文件驱动） ====================

static func _load_timelines() -> Dictionary:
	var path = OS.get_environment("USERPROFILE") + "/Desktop/au_timelines.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[AttackPatterns] 无法加载桌面时间线: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[AttackPatterns] 桌面时间线解析失败: " + json.get_error_message())
		return {}
	
	var data = json.data as Dictionary
	var total_actions = 0
	var sample_key = ""
	for key in data.keys():
		if sample_key == "":
			sample_key = key
		for tick in data[key]:
			total_actions += tick.get("actions", []).size()
	print("[AttackPatterns] 读取桌面时间线: " + path)
	print("[AttackPatterns] 数据: " + str(data.size()) + " 条时间线, " + str(total_actions) + " 个动作, 样本: " + sample_key)
	return data

# 构建时间线：将 JSON 数据转为 tick 函数数组
static func _build_timeline(data: Array) -> Array:
	var tl = []
	for entry in data:
		var tick = entry.tick
		var actions = entry.actions
		tl.append(_build_tick_func(tick, actions))
	return tl

# 将单个 tick 的 actions 构建为函数
static func _build_tick_func(tick_val, actions) -> Callable:
	return func(tick):
		var e = _enemy()
		if not is_instance_valid(e):
			return
		var bs = _battle_scene()
		var choice = -1

		# 辅助函数：转换 off 参数为 Vector2
		var to_vec2 = func(v, default_val = Vector2(100, -130)):
			if v is Vector2:
				return v
			if v is Array and v.size() >= 2:
				return Vector2(v[0], v[1])
			return default_val

		for action in actions:
			var atype = action.type
			match atype:
				"pass":
					pass
				"stats":
					stats(tick, action.hp, action.max_hp)
				"text":
					var off = to_vec2.call(action.get("off"), Vector2(100, -130))
					var sig = text(tick, action.txt, action.get("dur", 3.0), off)
					if sig:
						await sig
				"await":
					await e.get_tree().create_timer(action.time).timeout
				"emit":
					var emitter = BulletEmitter.from_dict(action)
					var bc = null
					if is_instance_valid(e) and e.has_method("get_bullet_container"):
						bc = e.get_bullet_container()
					await emitter.execute(e, bc)
				"emit_continuous":
					var ce = ContinuousBulletEmitter.from_dict(action)
					var bc = null
					if is_instance_valid(e) and e.has_method("get_bullet_container"):
						bc = e.get_bullet_container()
					e.add_child(ce)
					ce.start(e, bc)
					if ce.special_tags.has("存在于单帧"):
						await ce.finished
						if is_instance_valid(ce):
							ce.queue_free()
				"set_pattern_from_list":
					if e.attack_patterns.size() > action.index:
						e.current_pattern = e.attack_patterns[action.index]
				"get_choice":
					choice = get_player_choice(bs)
					print("[DEBUG] get_choice: choice=" + str(choice) + " last_player_choice=" + str(get_player_choice(bs)))
				"guard_choice":
					if action.has("not"):
						var not_val = action.not
						var raw = get_player_choice(bs)
						print("[DEBUG] guard_choice: not_val=" + str(not_val) + " raw=" + str(raw) + " last=" + str(get_player_choice(bs)))
						if raw != not_val:
							print("[DEBUG] guard_choice: HIT -> exec then")
							for a in action.then:
								var t = a.type
								print("[DEBUG]   then action: " + str(t))
								match t:
									"text":
										var off = to_vec2.call(a.get("off"), Vector2(100, -130))
										var sig = text(tick, a.txt, a.get("dur", 3.0), off)
										if sig:
											await sig
									"end_battle":
										if bs and bs.has_method("end_battle"):
											e.is_attacking = false
											if e.attack_timer:
												e.attack_timer.stop()
											bs.end_battle(a.get("victory", true))
										return
									"return":
										print("[DEBUG] guard_choice: return from tick")
										return
							return
						else:
							print("[DEBUG] guard_choice: NOT HIT, skip then")
				"if":
					var c = choice if choice != -1 else get_player_choice(bs)
					print("[DEBUG] if: cond=" + str(action.cond) + " c=" + str(c) + " last=" + str(get_player_choice(bs)))
					var condition_met = false
					match action.cond:
						"lt_0":
							condition_met = (c < 0)
						"eq_0":
							condition_met = (c == 0)
						"eq_1":
							condition_met = (c == 1)
						"eq_2_or_3":
							condition_met = (c == 2 or c == 3)
					print("[DEBUG] if: condition_met=" + str(condition_met))
					if condition_met:
						print("[DEBUG] if: HIT -> exec then")
						for a in action.then:
							var t = a.type
							print("[DEBUG]   then action: " + str(t))
							match t:
								"text":
									var off = to_vec2.call(a.get("off"), Vector2(100, -130))
									var sig = text(tick, a.txt, a.get("dur", 3.0), off)
									if sig:
										await sig
								"end_battle":
									if bs and bs.has_method("end_battle"):
										e.is_attacking = false
										if e.attack_timer:
											e.attack_timer.stop()
										bs.end_battle(a.get("victory", true))
									return
								"return":
									print("[DEBUG] if: return from tick")
									return
						return
					else:
						print("[DEBUG] if: NOT HIT")
				"end_turn":
					print("[DEBUG] end_turn called")
					end_turn(tick)
					return
				"end_battle":
					print("[DEBUG] end_battle called victory=" + str(action.get("victory", true)))
					if bs and bs.has_method("end_battle"):
						e.is_attacking = false
						if e.attack_timer:
							e.attack_timer.stop()
						bs.end_battle(action.get("victory", true))
					return

static func _vec2_array(raw) -> Array:
	var result = []
	for p in raw:
		result.append(Vector2(p[0], p[1]))
	return result

static func _timeline(enemy_type: int, turn_type: int) -> Array:
	var key = str(enemy_type) + "_" + str(turn_type)
	var data = _load_timelines()
	if data.has(key):
		return _build_timeline(data[key])
	return []

# ==================== 主入口 ====================

static func execute_turn(enemy):
	if not is_instance_valid(enemy): return
	if not enemy.is_attacking or enemy.is_player_turn:
		return
	
	# 设置敌人上下文
	_set_context(enemy)
	
	# 停止计时器防止重入
	if enemy.attack_timer: enemy.attack_timer.stop()
	
	enemy.bullet_tick += 1
	var tick = enemy.bullet_tick
	
	var timeline = _timeline(enemy.enemy_type, enemy.turn_type)
	
	if tick >= 0 and tick < timeline.size():
		await timeline[tick].call(tick)
	
	# 清理上下文
	_set_context(null)
	
	# 重启计时器
	if is_instance_valid(enemy) and enemy.is_attacking and not enemy.is_player_turn:
		enemy.start_pattern_timer()

# ==================== 设置敌人初始状态 ====================

static func setup_enemy_turn(enemy):
	if enemy.attack_patterns.size() > 0:
		enemy.current_pattern = enemy.attack_patterns[0]
		enemy.start_pattern_timer()

# ==================== 对话气泡 ====================

static func show_speech_bubble(enemy, text: String, duration: float = 3.0, off = Vector2(100, -170)):
	enemy.show_speech_bubble(text, duration, off)

# ==================== 方向设置 ====================

static func set_direction_offset(enemy, mode: int, offset_degrees: float = 0.0):
	enemy.set_direction_offset_mode(mode, offset_degrees)

# ==================== 发射点设置 ====================

static func set_muzzle_positions(enemy, positions: Array):
	enemy.muzzle_positions = positions
	enemy.current_muzzle_index = 0

# ==================== 敌人属性设置 ====================

static func set_enemy_attributes(enemy, health: int, max_health: int):
	enemy.health = health
	enemy.max_health = max_health
	if enemy.has_method("update_health_bar"):
		enemy.update_health_bar()

# ==================== 回合控制 ====================

static func end_enemy_turn(enemy):
	enemy.is_player_turn = true

# ==================== 敌人精灵移动 ====================

static func move_enemy_sprite(enemy, offset: Vector2) -> void:
	if enemy.has_method("set_sprite_offset"):
		enemy.set_sprite_offset(offset)

static func reset_enemy_sprite(enemy) -> void:
	if enemy.has_method("reset_sprite_offset"):
		enemy.reset_sprite_offset()
	elif enemy.has_method("set_sprite_offset"):
		enemy.set_sprite_offset(Vector2.ZERO)

# ==================== 敌人回合选择 ====================

static func show_enemy_choice(enemy, battle_scene: Node, options: Array) -> int:
	# 暂停敌人攻击计时器
	enemy.is_attacking = false
	if enemy.attack_timer:
		enemy.attack_timer.stop()
	
	# 显示选项让玩家选择
	var choice = await battle_scene.show_enemy_choice_ui(options)
	
	# 恢复敌人攻击计时器
	enemy.is_attacking = true
	enemy.start_pattern_timer()
	
	return choice

# ==================== 屏幕效果 ====================

static func flash_white(enemy, duration: float = 0.2):
	var rect = ColorRect.new()
	rect.color = Color.WHITE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0
	enemy.get_tree().current_scene.add_child(rect)
	var tween = enemy.get_tree().create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration / 2)
	tween.tween_property(rect, "modulate:a", 0.0, duration / 2)
	await tween.finished
	rect.queue_free()

static func flash_black(enemy, duration: float = 0.2):
	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0
	enemy.get_tree().current_scene.add_child(rect)
	var tween = enemy.get_tree().create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration / 2)
	tween.tween_property(rect, "modulate:a", 0.0, duration / 2)
	await tween.finished
	rect.queue_free()

# ==================== 音效播放 ====================

static func play_sound(enemy, sound_name: String, volume_db: float = 0.0):
	SoundManager.play(sound_name, volume_db)

# ==================== 玩家选择获取 ====================

static func get_player_choice(battle_scene: Node) -> int:
	# 统一从 enemy 节点的 meta 读取（游戏和编辑器模式都适用）
	var e = _enemy()
	if is_instance_valid(e) and e.has_meta("last_player_choice"):
		return e.get_meta("last_player_choice")
	# 兼容旧逻辑：从 battle_scene 读取（如果存在）
	if battle_scene and "last_player_choice" in battle_scene:
		return battle_scene.last_player_choice
	return -1
