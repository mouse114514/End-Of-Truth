extends Control

# ==================== 数据 ====================
var timelines_data: Dictionary = {}
var current_key: String = "0_0"
var current_tick: int = 0
var timeline_keys: Array = []  # ["0_0", "0_1", ...]
var is_playing: bool = false
var is_paused: bool = false
var _stop_requested: bool = false

# ==================== 节点引用 ====================
# 顶部
@onready var time_slider: HSlider = $TopBar/TimeAxis
@onready var tick_label: Label = $TopBar/TickLabel
@onready var btn_play: Button = $TopBar/BtnPlay

# 左侧模板库
@onready var template_container: VBoxContainer = $LeftPanel/ScrollContainer/VBoxContainer

# 中间预览区
@onready var preview_rect: ColorRect = $CenterPreview/BattleBox
@onready var enemy_sprite: Sprite2D = $CenterPreview/BattleBox/EnemySprite
@onready var muzzle_markers: Node2D = $CenterPreview/BattleBox/MuzzleMarkers
@onready var bullet_container: Node2D = $CenterPreview/BattleBox/BulletContainer

# 右侧检查器
@onready var inspector_container: VBoxContainer = $RightPanel/ScrollContainer/VBoxContainer
@onready var inspector_type_label: Label = $RightPanel/ScrollContainer/VBoxContainer/LblActionType
var current_editing_action: Dictionary = {}
var current_action_index: int = -1

# 底部树
@onready var tree_timeline: Tree = $BottomBar/TreeTimeline

# ==================== 常量 ====================
const ACTION_TYPES = ["pass", "stats", "text", "await", "set_pattern", "set_muzzle", "set_dir",
	"emit", "emit_continuous",
	"set_pattern_from_list", "get_choice", "guard_choice", "if", "end_turn", "end_battle"]

const BULLET_TEXTURES = {
	"bt0": "res://bullets/bt0.png"
}

# ==================== 生命周期 ====================
func _ready():
	load_timelines()  # 桌面优先，保留编辑数据
	build_tree()
	build_template_buttons()
	connect_signals()
	select_key("0_0")
	update_preview()
	# 让 BattleBox 不拦截鼠标事件，Area2D 标记点才能接收输入
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _exit_tree():
	save_timelines()

# ==================== 数据读写 ====================
func _working_path() -> String:
	return OS.get_environment("USERPROFILE") + "/Desktop/au_timelines.json"

func _project_path() -> String:
	return ProjectSettings.globalize_path("res://timelines.json")

func load_timelines(force_project := false):
	if force_project:
		# 强制从项目文件读取（启动时使用，绕过 VFS 缓存）
		var project = _project_path()
		var pf = FileAccess.open(project, FileAccess.READ)
		if not pf:
			push_error("无法加载项目文件: " + project)
			return
		var json_text = pf.get_as_text()
		pf.close()
		var json = JSON.new()
		var r = json.parse(json_text)
		if r != OK:
			push_error("项目文件解析失败: " + json.get_error_message())
			return
		timelines_data = json.data as Dictionary
		# 覆盖桌面副本
		var desk = _working_path()
		var out = FileAccess.open(desk, FileAccess.WRITE)
		if out:
			out.store_string(json_text)
			out.close()
		print("[TimelineEditor] 从项目文件加载并同步到桌面: " + desk)
	else:
		# 桌面文件优先（保留当前编辑会话的数据）
		var desk = _working_path()
		var df = FileAccess.open(desk, FileAccess.READ)
		if df:
			var json_text = df.get_as_text()
			df.close()
			var json = JSON.new()
			var r = json.parse(json_text)
			if r == OK:
				timelines_data = json.data as Dictionary
				print("[TimelineEditor] 从桌面加载: " + desk)
			else:
				push_error("桌面文件解析失败，回退到项目文件: " + json.get_error_message())
				load_timelines(true)
				return
		else:
			# 桌面不存在则从项目文件加载
			print("[TimelineEditor] 桌面文件不存在，从项目加载")
			load_timelines(true)
			return
	
	timeline_keys = timelines_data.keys()
	timeline_keys.sort()

func save_timelines():
	var path = _working_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("无法写入工作文件: " + path)
		return
	var json_str = JSON.stringify(timelines_data, "\t")
	file.store_string(json_str)
	file.close()
	
	# 写入后立即读取验证
	var verify = FileAccess.open(path, FileAccess.READ)
	if verify:
		var text = verify.get_as_text()
		verify.close()
		var json = JSON.new()
		if json.parse(text) == OK:
			var data = json.data as Dictionary
			var total_actions = 0
			var sample_key = ""
			var sample_count = 0
			for key in data.keys():
				var tick_count = data[key].size()
				if sample_key == "":
					sample_key = key
					sample_count = tick_count
				for tick in data[key]:
					total_actions += tick.get("actions", []).size()
			print("[TimelineEditor] 已保存到桌面: " + path)
			print("[TimelineEditor] 验证: " + str(data.size()) + " 条时间线, " + str(total_actions) + " 个动作")
			print("[TimelineEditor] 样本: " + sample_key + " = " + str(sample_count) + " 个 tick")

func save_to_project():
	# 将数据写入项目文件（res://）
	var json_str = JSON.stringify(timelines_data, "\t")
	var path = _project_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		# 回退到 res:// 路径
		file = FileAccess.open("res://timelines.json", FileAccess.WRITE)
		if not file:
			push_error("无法写入项目 timelines.json")
			return
	file.store_string(json_str)
	file.close()
	# 通知编辑器刷新
	if Engine.is_editor_hint():
		var filesystem = EditorInterface.get_resource_filesystem()
		if filesystem:
			filesystem.update_file("res://timelines.json")
	print("[TimelineEditor] 已写入项目文件: " + path)

# ==================== 树状结构 ====================
func build_tree():
	tree_timeline.clear()
	var root = tree_timeline.create_item()
	for key in timeline_keys:
		var parts = key.split("_")
		var enemy_type = parts[0]
		var turn_type = parts[1]
		
		# 查找或创建敌人类型节点
		var enemy_item = _find_tree_item(root, "enemy_" + enemy_type)
		if not enemy_item:
			enemy_item = tree_timeline.create_item(root)
			enemy_item.set_text(0, "敌人 " + enemy_type)
			enemy_item.set_meta("key_prefix", enemy_type + "_")
		
		# 创建回合类型节点
		var turn_item = tree_timeline.create_item(enemy_item)
		turn_item.set_text(0, "回合 " + turn_type)
		turn_item.set_meta("key", key)
		turn_item.set_meta("enemy_type", int(enemy_type))
		turn_item.set_meta("turn_type", int(turn_type))
		
		# 展开，添加 tick 子项
		var timeline_data = timelines_data[key]
		if timeline_data is Array:
			for entry in timeline_data:
				var tick = entry.tick
				var tick_item = tree_timeline.create_item(turn_item)
				tick_item.set_text(0, "tick " + str(tick))
				tick_item.set_meta("key", key)
				tick_item.set_meta("tick", tick)

func _find_tree_item(parent, name: String):
	for child in parent.get_children():
		if child.get_text(0) == name:
			return child
		var found = _find_tree_item(child, name)
		if found:
			return found
	return null

func _on_tree_item_selected():
	var item = tree_timeline.get_selected()
	if not item:
		return
	if item.has_meta("key"):
		var key = item.get_meta("key")
		var tick = item.get_meta("tick", -1)
		select_key(key, tick)
	elif item.has_meta("key_prefix"):
		# 敌人类型节点，展开/折叠
		item.collapsed = not item.collapsed

# ==================== 模板库 ====================
func build_template_buttons():
	for action_type in ACTION_TYPES:
		var btn = Button.new()
		btn.text = action_type
		btn.add_theme_font_size_override("font_size", 14)
		btn.set_meta("action_type", action_type)
		btn.pressed.connect(_on_template_button_pressed.bind(action_type))
		btn.gui_input.connect(_on_template_button_gui_input.bind(action_type))
		template_container.add_child(btn)

func _on_template_button_pressed(action_type: String):
	await add_action_to_current_tick(action_type)

func _on_template_button_gui_input(event: InputEvent, action_type: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 开始拖拽
		if not event.double_click:
			start_drag_template(action_type, event)

var dragging_template: String = ""
var drag_start_pos: Vector2 = Vector2.ZERO

func start_drag_template(action_type: String, event: InputEventMouseButton):
	dragging_template = action_type
	drag_start_pos = event.global_position
	# 设置鼠标样式
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)

# ==================== 时间轴 ====================
func _on_time_slider_changed(value: float):
	current_tick = int(value)
	tick_label.text = "tick: " + str(current_tick) + " / " + str(get_max_tick())
	update_inspector_for_tick()
	await update_preview()

func get_max_tick() -> int:
	if not timelines_data.has(current_key):
		return 0
	var data = timelines_data[current_key] as Array
	var max_tick = 0
	for entry in data:
		max_tick = max(max_tick, entry.tick)
	return max_tick

# ==================== 选择时间线 ====================
func select_key(key: String, tick: int = 0):
	current_key = key
	if timelines_data.has(key):
		var data = timelines_data[key] as Array
		if data.size() > 0:
			current_tick = tick if tick >= 0 else data[0].tick
		else:
			current_tick = 0
	else:
		current_tick = 0
	
	# 更新时间轴
	time_slider.max_value = max(get_max_tick(), 1)
	time_slider.value = current_tick
	tick_label.text = "tick: " + str(current_tick) + " / " + str(get_max_tick())
	
	await update_preview()
	update_inspector_for_tick()

# ==================== 预览区 ====================
func update_preview():
	# 如果正在播放预览，不更新预览（避免干扰播放）
	if is_playing:
		print("[update_preview] ⚠️ 正在播放预览，跳过更新！is_playing=", is_playing)
		return
	
	# 清除旧子弹
	for child in bullet_container.get_children():
		child.queue_free()
	
	# 清除旧发射点标记
	for child in muzzle_markers.get_children():
		child.queue_free()
	
	# 获取当前 tick 的数据
	if not timelines_data.has(current_key):
		return
	
	var timeline_data = timelines_data[current_key] as Array
	var tick_data = null
	for entry in timeline_data:
		if entry.tick == current_tick:
			tick_data = entry
			break
	
	if not tick_data:
		return
	
	# 如果正在播放预览，不执行 preview_tick（避免重复创建敌人）
	if is_playing:
		print("[preview_tick] 正在播放预览，忽略此次调用")
		return
	
	# 执行该 tick 的 actions（用于预览状态）
	var actions = tick_data.actions as Array
	
	# 调试：打印所有 emit action 的核心值
	for a in actions:
		if a.type == "emit":
			print("[preview] emit action: emitter_pos=", a.get("emitter_pos", "MISSING"), " target_pos=", a.get("target_pos", "MISSING"), " tags=", a.get("tags", []))
	
	# 设置临时敌人来预览
	var temp_enemy = Node2D.new()
	temp_enemy.set_script(load("res://enemy.gd"))
	temp_enemy.name = "TempEnemyPreview"
	
	# 【关键】在 add_child 之前就设置 bullet_container
	var target_container = get_node("/root/TimelineEditor/CenterPreview/BattleBox/BulletContainer") as Node2D
	if target_container:
		temp_enemy.bullet_container = target_container
		print("[preview_tick] 在 add_child 之前设置 bullet_container = ", target_container.get_path())
	
	preview_rect.add_child(temp_enemy)  # 这里会触发 _ready()
	
	# 设置敌人 Sprite
	var sprite = preview_rect.get_node("EnemySprite") as Sprite2D
	if sprite and sprite.texture:
		temp_enemy.add_child(sprite.duplicate())
	
	# 【关键】设置敌人位置和缩放，参考 bullet_hell_scene.gd:452-462
	# 敌人位置：在 BattleBox 中心偏上 80 像素（局部坐标）
	var enemy_position = Vector2(preview_rect.size.x / 2, 80)
	temp_enemy.position = enemy_position
	
	# 设置敌人缩放（参考 bullet_hell_scene.gd:455-460）
	temp_enemy.scale = Vector2(1.5, 1.5)
	
	# 应用 tick 状态：设置 pattern、muzzle 等
	for action in actions:
		var atype = action.type
		match atype:
			"set_pattern":
				temp_enemy.current_pattern = action.pattern
			"set_muzzle":
				if action.has("pos"):
					var pos_arr = []
					for p in action.pos:
						if p is Array and p.size() >= 2:
							pos_arr.append(Vector2(p[0], p[1]))
						else:
							print("[WARN] update_preview set_muzzle: 跳过无效坐标: ", p)
					if pos_arr.size() > 0:
						temp_enemy.muzzle_positions = pos_arr
						temp_enemy.current_muzzle_index = 0
			"set_dir":
				temp_enemy.set_direction_offset_mode(action.get("mode", 0), action.get("deg", 0.0))
			"emit_continuous":
				var ce = ContinuousBulletEmitter.from_dict(action)
				var emit_container = get_node("/root/TimelineEditor/CenterPreview/BattleBox/BulletContainer") as Node2D
				if emit_container:
					temp_enemy.bullet_container = emit_container
				# 设置全局偏移，使子弹位置与标记位置一致
				ce.global_offset = Vector2(0, preview_rect.size.y/2 - 80)
				preview_rect.add_child(ce)
				ce.start(temp_enemy, emit_container)
			_:
				# emit 类型直接调用 BulletEmitter
				if atype == "emit":
					var emitter = BulletEmitter.from_dict(action)
					var emit_container = get_node("/root/TimelineEditor/CenterPreview/BattleBox/BulletContainer") as Node2D
					if emit_container:
						temp_enemy.bullet_container = emit_container
					await emitter.execute(temp_enemy, emit_container)
	
	# 显示发射点标记
	_refresh_muzzle_markers(actions)
	
	# 清理临时敌人
	temp_enemy.queue_free()

func _refresh_muzzle_markers(actions: Array):
	for child in muzzle_markers.get_children():
		child.queue_free()
	for ai in range(actions.size()):
		var action = actions[ai]
		var atype = action.type
		if atype.begins_with("att_") and action.has("pos"):
			for pos_arr in action.pos:
				if pos_arr is Array and pos_arr.size() >= 2:
					create_muzzle_marker(Vector2(pos_arr[0], pos_arr[1]), ai)
		elif atype == "set_muzzle" and action.has("pos"):
			for pos_arr in action.pos:
				if pos_arr is Array and pos_arr.size() >= 2:
					create_muzzle_marker(Vector2(pos_arr[0], pos_arr[1]), ai)
		elif atype == "emit_continuous" and action.has("start_pos"):
			var sp = Vector2(action.start_pos[0], action.start_pos[1])
			var kps = []
			if action.has("key_positions"):
				for p in action.key_positions:
					if p is Array and p.size() >= 2:
						kps.append(Vector2(p[0], p[1]))
			var kts = []
			if action.has("key_targets"):
				for p in action.key_targets:
					if p is Array and p.size() >= 2:
						kts.append(Vector2(p[0], p[1]))
			# 发射点标记
			var muzzles = []
			muzzles.append(create_ce_muzzle_marker(sp, ai, kts[0] if kts.size() > 0 else sp, "start_pos", 0))
			for pi in range(kps.size()):
				var kt = kts[pi + 1] if pi + 1 < kts.size() else (kts[pi] if pi < kts.size() else sp)
				muzzles.append(create_ce_muzzle_marker(kps[pi], ai, kt, "key_positions", pi))
			# 路径线：直接用标记点位置连线
			for pi in range(muzzles.size() - 1):
				_draw_line_local(muzzles[pi].position, muzzles[pi + 1].position, Color(0.6, 1, 0.6, 0.5))
			# 目标标记 + 目标线
			for ti in range(kts.size()):
				var pos = sp if ti == 0 else kps[ti - 1]
				var tm = create_ce_target_marker(kts[ti], pos, ai, "key_targets", ti)
				_draw_line_local(muzzles[ti].position, tm.position, Color(0.8, 0.8, 0.2, 0.3))
		elif atype == "emit" and action.has("emitter_pos"):
			var ep = Vector2(action.emitter_pos[0], action.emitter_pos[1])
			var tp = Vector2(action.target_pos[0], action.target_pos[1]) if action.has("target_pos") else ep
			create_muzzle_marker(ep, ai, tp)
			if action.has("target_pos"):
				create_target_marker(tp, ep, ai)
				create_emitter_line(ep, tp)

func create_ce_muzzle_marker(pos: Vector2, action_index: int, target_pos: Vector2, ce_key: String, ce_index: int) -> Area2D:
	create_muzzle_marker(pos, action_index, target_pos)
	var marker = muzzle_markers.get_child(muzzle_markers.get_child_count() - 1) as Area2D
	marker.set_meta("ce_key", ce_key)
	marker.set_meta("ce_index", ce_index)
	return marker

func create_ce_target_marker(pos: Vector2, emitter_pos: Vector2, action_index: int, ce_key: String, ce_index: int) -> Area2D:
	var marker = Area2D.new()
	marker.z_index = 101
	marker.position = Vector2(
		preview_rect.size.x/2 + pos.x,
		preview_rect.size.y/2 - pos.y
	)
	marker.set_meta("pos", pos)
	marker.set_meta("emitter_pos", emitter_pos)
	marker.set_meta("draggable", true)
	marker.set_meta("action_index", action_index)
	marker.set_meta("ce_key", ce_key)
	marker.set_meta("ce_index", ce_index)
	
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	collision.shape = circle
	marker.add_child(collision)
	
	var dot = ColorRect.new()
	dot.size = Vector2(10, 10)
	dot.color = Color(1, 0.2, 0.2, 0.9)
	dot.position = Vector2(-5, -5)
	marker.add_child(dot)
	muzzle_markers.add_child(marker)
	return marker

func create_muzzle_marker(pos: Vector2, action_index: int = -1, target_pos: Vector2 = Vector2.INF):
	var marker = Area2D.new()
	marker.z_index = 101
	marker.position = Vector2(
		preview_rect.size.x/2 + pos.x,
		preview_rect.size.y/2 - pos.y
	)
	marker.set_meta("pos", pos)
	marker.set_meta("draggable", true)
	marker.set_meta("action_index", action_index)
	
	# 添加碰撞形状用于输入检测
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 15.0
	collision.shape = circle
	marker.add_child(collision)
	
	# 红色三角形箭头，指向目标方向
	var tri = Polygon2D.new()
	tri.polygon = PackedVector2Array([
		Vector2(12, 0),
		Vector2(-8, -8),
		Vector2(-8, 8)
	])
	tri.color = Color(1, 0.2, 0.2, 1)
	if target_pos != Vector2.INF and target_pos != pos:
		var dir = (target_pos - pos).normalized()
		tri.rotation = Vector2(dir.x, -dir.y).angle()
	marker.add_child(tri)
	muzzle_markers.add_child(marker)

func create_target_marker(pos: Vector2, emitter_pos: Vector2, action_index: int = -1):
	var marker = Area2D.new()
	marker.z_index = 101
	marker.position = Vector2(
		preview_rect.size.x/2 + pos.x,
		preview_rect.size.y/2 - pos.y
	)
	marker.set_meta("pos", pos)
	marker.set_meta("emitter_pos", emitter_pos)
	marker.set_meta("draggable", true)
	marker.set_meta("action_index", action_index)
	
	# 碰撞形状
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	collision.shape = circle
	marker.add_child(collision)
	
	# 蓝色空心圆
	var dot = Polygon2D.new()
	var pts = PackedVector2Array()
	var r = 8.0
	var seg = 24
	for s in range(seg):
		var a = 2.0 * PI * float(s) / float(seg)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	dot.polygon = pts
	dot.color = Color(0.2, 0.6, 1.0, 0.6)
	marker.add_child(dot)
	
	var inner = Polygon2D.new()
	pts = PackedVector2Array()
	r = 4.0
	for s in range(seg):
		var a = 2.0 * PI * float(s) / float(seg)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	inner.polygon = pts
	inner.color = Color(0.2, 0.6, 1.0, 1)
	marker.add_child(inner)
	muzzle_markers.add_child(marker)

func create_emitter_line(from_pos: Vector2, to_pos: Vector2):
	var line = Line2D.new()
	line.add_point(Vector2(
		preview_rect.size.x/2 + from_pos.x,
		preview_rect.size.y/2 - from_pos.y
	))
	line.add_point(Vector2(
		preview_rect.size.x/2 + to_pos.x,
		preview_rect.size.y/2 - to_pos.y
	))
	line.default_color = Color(0.8, 0.8, 0.2, 0.3)
	line.width = 2.0
	line.z_index = 100
	muzzle_markers.add_child(line)

func _draw_line_local(from: Vector2, to: Vector2, color: Color):
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.default_color = color
	line.width = 2.0
	line.z_index = 100
	muzzle_markers.add_child(line)

func _find_marker_at(pos: Vector2) -> Area2D:
	for child in muzzle_markers.get_children():
		if child is Area2D and child.has_meta("pos"):
			var dist = (child.global_position - pos).length()
			if dist < 20.0:
				return child
	return null

func _input(event):
	# 模板拖拽逻辑（原有）
	if not dragging_template.is_empty():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var box_rect = Rect2(preview_rect.global_position.x, preview_rect.global_position.y, preview_rect.size.x, preview_rect.size.y)
			if box_rect.has_point(get_global_mouse_position()):
				var local_pos = get_local_mouse_position() - preview_rect.global_position
				var enemy_pos = Vector2(preview_rect.size.x / 2, 80)
				var rel_pos = local_pos - enemy_pos
				add_action_to_current_tick(dragging_template, {"pos": [[rel_pos.x, rel_pos.y]]})
			dragging_template = ""
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	
	# 标记点拖拽
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			var marker = _find_marker_at(get_global_mouse_position())
			if marker:
				dragging_marker = marker
				drag_marker_offset = get_global_mouse_position() - marker.global_position
				# 从标记点读取 action 索引，确保拖拽更新到正确的 action
				if marker.has_meta("action_index"):
					current_action_index = marker.get_meta("action_index")
				# 记录当前状态供撤销
				_current_drag_undo = _capture_action_state()
		else:
			dragging_marker = null
			if not _current_drag_undo.is_empty():
				_undo_stack.append(_current_drag_undo)
				_current_drag_undo = {}
			save_timelines()
			await update_preview()
	
	# Ctrl+Z 撤销
	if event is InputEventKey and event.pressed and event.keycode == KEY_Z and event.ctrl_pressed:
		_undo()

var dragging_marker: Area2D = null
var drag_marker_offset: Vector2 = Vector2.ZERO
var _undo_stack: Array[Dictionary] = []
var _current_drag_undo: Dictionary = {}

func _process(delta):
	if dragging_marker:
		var target_pos = get_viewport().get_mouse_position() - drag_marker_offset
		dragging_marker.global_position = target_pos
		
		# 更新 meta 位置（转换为战斗框坐标）
		var local_pos = target_pos - preview_rect.global_position
		var battle_pos = Vector2(
			local_pos.x - preview_rect.size.x/2,
			-(local_pos.y - preview_rect.size.y/2)
		)
		dragging_marker.set_meta("pos", battle_pos)
		
		# 同步更新当前选中的 action 的 pos
		if current_action_index >= 0 and timelines_data.has(current_key):
			var timeline_data = timelines_data[current_key] as Array
			for entry in timeline_data:
				if entry.tick == current_tick:
					var actions = entry.actions as Array
					if current_action_index < actions.size():
						var action = actions[current_action_index] as Dictionary
						if dragging_marker.has_meta("ce_key"):
							var ce_key = dragging_marker.get_meta("ce_key") as String
							var ce_idx = dragging_marker.get_meta("ce_index") as int
							match ce_key:
								"start_pos":
									action["start_pos"] = [battle_pos.x, battle_pos.y]
									# 更新对应目标的 emitter_pos 让连线跟随
									var ai = dragging_marker.get_meta("action_index")
									for m in muzzle_markers.get_children():
										if m is Area2D and m.has_meta("ce_key") and m.get_meta("ce_key") == "key_targets" and m.get_meta("ce_index") == 0 and m.get_meta("action_index") == ai:
											m.set_meta("emitter_pos", battle_pos)
								"key_positions":
									if not action.has("key_positions"):
										action["key_positions"] = []
									while action["key_positions"].size() <= ce_idx:
										action["key_positions"].append([0, 0])
									action["key_positions"][ce_idx] = [battle_pos.x, battle_pos.y]
									# 更新对应目标的 emitter_pos 让连线跟随
									var paired_kt_idx = ce_idx + 1
									var ai = dragging_marker.get_meta("action_index")
									for m in muzzle_markers.get_children():
										if m is Area2D and m.has_meta("ce_key") and m.get_meta("ce_key") == "key_targets" and m.get_meta("ce_index") == paired_kt_idx and m.get_meta("action_index") == ai:
											m.set_meta("emitter_pos", battle_pos)
								"key_targets":
									if not action.has("key_targets"):
										action["key_targets"] = []
									while action["key_targets"].size() <= ce_idx:
										action["key_targets"].append([0, 0])
									action["key_targets"][ce_idx] = [battle_pos.x, battle_pos.y]
						else:
							var is_target = dragging_marker.has_meta("emitter_pos")
							if is_target:
								action["target_pos"] = [battle_pos.x, battle_pos.y]
							else:
								action["emitter_pos"] = [battle_pos.x, battle_pos.y]
		
		# 更新连接线
		_redraw_emitter_lines()


func _redraw_emitter_lines():
	for child in muzzle_markers.get_children():
		if child is Line2D:
			child.queue_free()
	
	# 单次发射器：用 emitter_pos meta 找配对画线
	for child in muzzle_markers.get_children():
		if child is Area2D and child.has_meta("emitter_pos") and not child.has_meta("ce_key"):
			var ep = child.get_meta("emitter_pos") as Vector2
			var from_pos = Vector2(preview_rect.size.x/2 + ep.x, preview_rect.size.y/2 - ep.y)
			_draw_line_local(from_pos, child.position, Color(0.8, 0.8, 0.2, 0.3))
	
	# 连续发射器：用标记点位置直接连线
	var ce_muzzles = {}
	var ce_targets = {}
	for child in muzzle_markers.get_children():
		if child is Area2D and child.has_meta("ce_key"):
			var ck = child.get_meta("ce_key") as String
			var aidx = child.get_meta("action_index")
			if ck in ["start_pos", "key_positions"]:
				if not ce_muzzles.has(aidx):
					ce_muzzles[aidx] = []
				ce_muzzles[aidx].append(child)
			elif ck == "key_targets":
				if not ce_targets.has(aidx):
					ce_targets[aidx] = {}
				ce_targets[aidx][child.get_meta("ce_index")] = child
	for aidx in ce_muzzles:
		var group = ce_muzzles[aidx]
		group.sort_custom(func(a, b):
			var ka = a.get_meta("ce_key")
			var kb = b.get_meta("ce_key")
			if ka != kb:
				return ka == "start_pos"
			return a.get_meta("ce_index") < b.get_meta("ce_index")
		)
		var targets = ce_targets.get(aidx, {})
		for gi in range(group.size() - 1):
			_draw_line_local(group[gi].position, group[gi + 1].position, Color(0.6, 1, 0.6, 0.5))
		for gi in range(group.size()):
			if targets.has(gi):
				_draw_line_local(group[gi].position, targets[gi].position, Color(0.8, 0.8, 0.2, 0.3))

func _capture_action_state() -> Dictionary:
	if current_action_index < 0 or not timelines_data.has(current_key):
		return {}
	var timeline_data = timelines_data[current_key] as Array
	for entry in timeline_data:
		if entry.tick == current_tick:
			var actions = entry.actions as Array
			if current_action_index < actions.size():
				var action = actions[current_action_index] as Dictionary
				var state = {
					"key": current_key,
					"tick": current_tick,
					"action_index": current_action_index,
					"emitter_pos": [],
					"target_pos": [],
					"start_pos": [],
					"key_positions": [],
					"key_targets": []
				}
				if action.has("emitter_pos"):
					state.emitter_pos = action.emitter_pos.duplicate()
				if action.has("target_pos"):
					state.target_pos = action.target_pos.duplicate()
				if action.has("start_pos"):
					state.start_pos = action.start_pos.duplicate()
				if action.has("key_positions"):
					state.key_positions = action.key_positions.duplicate()
				if action.has("key_targets"):
					state.key_targets = action.key_targets.duplicate()
				return state
	return {}

func _undo():
	if _undo_stack.is_empty():
		return
	var state = _undo_stack.pop_back()
	if not timelines_data.has(state.key):
		return
	var timeline_data = timelines_data[state.key] as Array
	for entry in timeline_data:
		if entry.tick == state.tick:
			var actions = entry.actions as Array
			if state.action_index < actions.size():
				var a = actions[state.action_index] as Dictionary
				if not state.emitter_pos.is_empty():
					a["emitter_pos"] = state.emitter_pos.duplicate()
				if not state.target_pos.is_empty():
					a["target_pos"] = state.target_pos.duplicate()
				if not state.start_pos.is_empty():
					a["start_pos"] = state.start_pos.duplicate()
				if not state.key_positions.is_empty():
					a["key_positions"] = state.key_positions.duplicate()
				if not state.key_targets.is_empty():
					a["key_targets"] = state.key_targets.duplicate()
	save_timelines()
	current_key = state.key
	current_tick = state.tick
	current_action_index = state.action_index
	update_inspector_for_tick()
	await select_key(state.key, state.tick)


# ==================== 检查器 ====================
func update_inspector_for_tick():
	# 清除旧控件（保留标题）
	for child in inspector_container.get_children():
		if child != inspector_type_label:
			child.queue_free()
	
	if not timelines_data.has(current_key):
		return
	
	var timeline_data = timelines_data[current_key] as Array
	var tick_data = null
	for entry in timeline_data:
		if entry.tick == current_tick:
			tick_data = entry
			break
	
	if not tick_data:
		inspector_type_label.text = "tick " + str(current_tick) + " - 无数据"
		return
	
	var actions = tick_data.actions as Array
	inspector_type_label.text = "tick " + str(current_tick) + " - " + str(actions.size()) + " 个动作"
	
	# 列出所有动作，可点击编辑
	for i in range(actions.size()):
		var action = actions[i]
		var btn = Button.new()
		btn.text = str(i) + ": " + action.type
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_action_selected.bind(i))
		inspector_container.add_child(btn)

func _on_action_selected(index: int):
	current_action_index = index
	if not timelines_data.has(current_key):
		return
	var timeline_data = timelines_data[current_key] as Array
	var tick_data = null
	for entry in timeline_data:
		if entry.tick == current_tick:
			tick_data = entry
			break
	if not tick_data:
		return
	
	if index >= tick_data.actions.size():
		print("[WARN] _on_action_selected: index ", index, " 超出范围，actions 大小: ", tick_data.actions.size())
		current_action_index = -1
		return
	
	var action = tick_data.actions[index] as Dictionary
	current_action_index = index
	current_editing_action = action
	show_action_inspector(action)

func show_action_inspector(action: Dictionary):
	# 清除旧动态控件
	for child in inspector_container.get_children():
		if child != inspector_type_label and not (child is Button):
			child.queue_free()
	
	var atype = action.type
	inspector_type_label.text = "编辑: " + atype
	print("[show_inspector] ", atype, " emitter_pos=", action.get("emitter_pos", "?"), " target_pos=", action.get("target_pos", "?"), " tags=", action.get("tags", []))
	
	# 根据类型创建编辑控件
	match atype:
		"text":
			_add_text_edit("txt", action.get("txt", ""), "文本")
			_add_float_edit("dur", action.get("dur", 3.0), "持续时间")
			_add_vector2_edit("off", action.get("off", [100, -130]), "偏移")
		"await":
			_add_float_edit("time", action.get("time", 1.0), "等待时间")
		"set_pattern":
			_add_pattern_select("pattern", action.get("pattern", "circle"))
		"set_muzzle":
			_add_vector2_array_edit("pos", action.get("pos", [[0,0]]), "发射点")
		"set_dir":
			_add_int_edit("mode", action.get("mode", 0), "模式")
			_add_float_edit("deg", action.get("deg", 0.0), "角度")
		"stats":
			_add_int_edit("hp", action.get("hp", 50), "生命值")
			_add_int_edit("max_hp", action.get("max_hp", 50), "最大生命")
		"pass":
			pass  # 无参数
		"end_turn":
			pass  # 无参数
		"end_battle":
			_add_bool_edit("victory", action.get("victory", true), "胜利？")
		"get_choice":
			pass  # 无参数
		"guard_choice":
			_add_int_edit("not", action.get("not", -1), "not 值")
			_add_json_edit("then", action.get("then", []), "then 分支")
		"if":
			_add_cond_select("cond", action.get("cond", "eq_0"))
			_add_json_edit("then", action.get("then", []), "then 分支")
		"set_pattern_from_list":
			_add_int_edit("index", action.get("index", 0), "索引")
		"emit":
			_add_target_selector("target_selector", action.get("target_selector", "absolute"))
			_add_vector2_edit("emitter_pos", action.get("emitter_pos", [0, 0]), "发射器位置")
			_add_vector2_edit("target_pos", action.get("target_pos", [0, -200]), "目标位置")
			_add_tag_select("tags", action.get("tags", []))
		"emit_continuous":
			_add_target_selector("target_selector", action.get("target_selector", "absolute"))
			_add_vector2_edit("start_pos", action.get("start_pos", [0, 0]), "起点坐标")
			_add_float_edit("move_duration", action.get("move_duration", 2.0), "移动时间")
			_add_int_edit("emit_count", action.get("emit_count", 10), "发射次数")
			_add_vector2_array_edit("key_positions", action.get("key_positions", []), "关键坐标")
			_add_vector2_array_edit("key_targets", action.get("key_targets", []), "关键目标")
			_add_tag_select("tags", action.get("tags", []))
	
	# 应用按钮
	var btn_apply = Button.new()
	btn_apply.text = "应用修改"
	btn_apply.pressed.connect(_on_apply_action_edit)
	inspector_container.add_child(btn_apply)
	
	# 删除按钮
	var btn_delete = Button.new()
	btn_delete.text = "删除此动作"
	btn_delete.modulate = Color(1, 0.5, 0.5)
	btn_delete.pressed.connect(_on_delete_action)
	inspector_container.add_child(btn_delete)
	
	# 调试：检查容器内的控件数量（是否累计了重复按钮？）
	print("[show_inspector] inspector_container 子控件数: ", inspector_container.get_child_count())

# ==================== 检查器控件生成 ====================
func _add_text_edit(key: String, value: String, label: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label + ": "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var te = TextEdit.new()
	te.text = value
	te.custom_minimum_size.y = 60
	te.set_meta("key", key)
	hbox.add_child(te)
	inspector_container.add_child(hbox)

func _add_float_edit(key: String, value: float, label: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label + ": "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var le = LineEdit.new()
	le.text = str(value)
	le.set_meta("key", key)
	hbox.add_child(le)
	inspector_container.add_child(hbox)

func _add_int_edit(key: String, value: int, label: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label + ": "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var le = LineEdit.new()
	le.text = str(value)
	le.set_meta("key", key)
	hbox.add_child(le)
	inspector_container.add_child(hbox)

func _add_vector2_edit(key: String, value, label: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label + ": "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var le = LineEdit.new()
	if value is Array and value.size() >= 2:
		le.text = str(value[0]) + ", " + str(value[1])
	else:
		le.text = "0, 0"
	le.set_meta("key", key)
	le.placeholder_text = "x, y"
	hbox.add_child(le)
	inspector_container.add_child(hbox)

func _add_cond_select(key: String, value: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "条件: "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var ob = OptionButton.new()
	ob.add_item("lt_0")
	ob.add_item("eq_0")
	ob.add_item("eq_1")
	ob.add_item("eq_2_or_3")
	ob.select(["lt_0", "eq_0", "eq_1", "eq_2_or_3"].find(value))
	ob.set_meta("key", key)
	hbox.add_child(ob)
	inspector_container.add_child(hbox)

func _add_pattern_select(key: String, value: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "图案: "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var ob = OptionButton.new()
	ob.add_item("circle")
	ob.add_item("spiral")
	ob.add_item("aimed")
	ob.add_item("random")
	ob.add_item("boomerang")
	ob.add_item("none")
	ob.select(["circle", "spiral", "aimed", "random", "boomerang", "none"].find(value))
	ob.set_meta("key", key)
	hbox.add_child(ob)
	inspector_container.add_child(hbox)

func _add_bool_edit(key: String, value: bool, label: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label + ": "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var cb = CheckBox.new()
	cb.button_pressed = value
	cb.set_meta("key", key)
	hbox.add_child(cb)
	inspector_container.add_child(hbox)

func _add_target_selector(key: String, value: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "坐标模式: "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var ob = OptionButton.new()
	ob.add_item("绝对坐标")
	ob.add_item("相对坐标")
	ob.select(1 if value == "relative" else 0)
	ob.set_meta("key", key)
	hbox.add_child(ob)
	inspector_container.add_child(hbox)

const EMITTER_TAGS = ["反向", "圆", "180弧", "120弧", "60弧", "30弧", "螺旋", "回旋镖", "存在于单帧"]

func _add_tag_select(key: String, value: Array):
	var vbox = VBoxContainer.new()
	vbox.set_meta("key", key)
	var lbl = Label.new()
	lbl.text = "特殊标签:"
	vbox.add_child(lbl)
	
	var tag_container = VBoxContainer.new()
	for tag in EMITTER_TAGS:
		var cb = CheckBox.new()
		cb.text = tag
		cb.button_pressed = value.has(tag)
		cb.set_meta("tag_value", tag)
		tag_container.add_child(cb)
	vbox.add_child(tag_container)
	
	inspector_container.add_child(vbox)

func _add_json_edit(key: String, value, label: String):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label + ": "
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var te = TextEdit.new()
	te.text = JSON.stringify(value, "  ")
	te.custom_minimum_size.y = 100
	te.set_meta("key", key)
	hbox.add_child(te)
	inspector_container.add_child(hbox)

func _add_vector2_array_edit(key: String, value: Array, label: String):
	var vbox = VBoxContainer.new()
	vbox.set_meta("key", key)
	var lbl = Label.new()
	lbl.text = label + ":"
	vbox.add_child(lbl)
	for i in range(value.size()):
		var row = HBoxContainer.new()
		var le = LineEdit.new()
		var v = value[i]
		if v is Array and v.size() >= 2:
			le.text = str(v[0]) + ", " + str(v[1])
		else:
			le.text = "0, 0"
		le.custom_minimum_size.x = 120
		le.set_meta("arr_idx", i)
		row.add_child(le)
		var btn_del = Button.new()
		btn_del.text = "✕"
		btn_del.custom_minimum_size.x = 24
		btn_del.pressed.connect(_on_remove_array_element.bind(key, i, vbox))
		row.add_child(btn_del)
		vbox.add_child(row)
	var btn_add = Button.new()
	btn_add.text = "+ 添加 " + label
	btn_add.pressed.connect(_on_add_array_element.bind(key, vbox))
	vbox.add_child(btn_add)
	inspector_container.add_child(vbox)

func _on_add_array_element(key: String, vbox: VBoxContainer):
	if not timelines_data.has(current_key):
		return
	var timeline_data = timelines_data[current_key] as Array
	var tick_data = null
	for entry in timeline_data:
		if entry.tick == current_tick:
			tick_data = entry
			break
	if not tick_data or current_action_index < 0 or current_action_index >= tick_data.actions.size():
		return
	var action = tick_data.actions[current_action_index] as Dictionary
	if not action.has(key):
		action[key] = []
	action[key].append([0, 0])
	save_timelines()
	update_inspector_for_tick()
	await update_preview()

func _on_remove_array_element(key: String, index: int, vbox: VBoxContainer):
	if not timelines_data.has(current_key):
		return
	var timeline_data = timelines_data[current_key] as Array
	var tick_data = null
	for entry in timeline_data:
		if entry.tick == current_tick:
			tick_data = entry
			break
	if not tick_data or current_action_index < 0 or current_action_index >= tick_data.actions.size():
		return
	var action = tick_data.actions[current_action_index] as Dictionary
	if action.has(key) and action[key] is Array and index < action[key].size():
		action[key].remove_at(index)
	save_timelines()
	update_inspector_for_tick()
	await update_preview()

# ==================== 应用修改 ====================
func _on_apply_action_edit():
	if current_action_index < 0 or not timelines_data.has(current_key):
		return
	
	var timeline_data = timelines_data[current_key] as Array
	var tick_data = null
	for entry in timeline_data:
		if entry.tick == current_tick:
			tick_data = entry
			break
	if not tick_data:
		return
	
	var action = tick_data.actions[current_action_index] as Dictionary
	
	# 调试：打印修改前的 action
	print("[apply] 修改前 action: type=", action.type, " emitter_pos=", action.get("emitter_pos", "?"), " target_pos=", action.get("target_pos", "?"), " tags=", action.get("tags", []))
	
	# 从检查器读取并应用修改
	for child in inspector_container.get_children():
		if child is HBoxContainer:
			for grandchild in child.get_children():
				if grandchild.has_meta("key"):
					var key = grandchild.get_meta("key")
					if grandchild is LineEdit:
						var txt = grandchild.text
						match key:
							"txt", "pattern", "cond":
								action[key] = txt
							"dur", "time", "deg", "move_duration":
								action[key] = txt.to_float()
							"hp", "max_hp", "mode", "index", "not", "emit_count":
								action[key] = txt.to_int()
							"off", "pos", "emitter_pos", "target_pos", "start_pos":
								var parts = txt.split(",")
								if parts.size() >= 2:
									action[key] = [parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float()]
					elif grandchild is TextEdit:
						var txt = grandchild.text
						if key in ["then", "key_positions", "key_targets"]:
							var json = JSON.new()
							if json.parse(txt) == OK:
								action[key] = json.data
						else:
							action[key] = txt
					elif grandchild is CheckBox:
						action[key] = grandchild.button_pressed
					elif grandchild is OptionButton:
						var selected_text = grandchild.get_item_text(grandchild.selected)
						if key == "target_selector":
							action[key] = "absolute" if selected_text == "绝对坐标" else "relative"
						else:
							action[key] = selected_text
		elif child is VBoxContainer and child.has_meta("key"):
			var key = child.get_meta("key")
			if key in ["key_positions", "key_targets"]:
				var arr = []
				for grandchild in child.get_children():
					if grandchild is HBoxContainer:
						for item in grandchild.get_children():
							if item is LineEdit:
								var parts = item.text.split(",")
								if parts.size() >= 2:
									arr.append([parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float()])
								else:
									arr.append([0, 0])
				action[key] = arr
			elif key == "tags":
				var tags = []
				for grandchild in child.get_children():
					if grandchild is VBoxContainer:
						for cb in grandchild.get_children():
							if cb is CheckBox and cb.button_pressed:
								tags.append(cb.get_meta("tag_value"))
				action[key] = tags
	
	# 调试：打印修改后的 action
	print("[apply] 修改后 action: type=", action.type, " emitter_pos=", action.get("emitter_pos", "?"), " target_pos=", action.get("target_pos", "?"), " tags=", action.get("tags", []))
	
	save_timelines()
	await update_preview()
	print("[TimelineEditor] 已应用修改到 " + current_key + " tick " + str(current_tick))

func _on_delete_action():
	if current_action_index < 0 or not timelines_data.has(current_key):
		return
	
	var timeline_data = timelines_data[current_key] as Array
	var tick_data = null
	for entry in timeline_data:
		if entry.tick == current_tick:
			tick_data = entry
			break
	if not tick_data:
		return
	
	tick_data.actions.remove_at(current_action_index)
	current_action_index = -1
	save_timelines()
	update_inspector_for_tick()
	await update_preview()
	print("[TimelineEditor] 已删除动作")

# ==================== 添加动作 ====================
func add_action_to_current_tick(action_type: String, extra_params: Dictionary = {}):
	if not timelines_data.has(current_key):
		return
	
	if not timelines_data[current_key] is Array:
		timelines_data[current_key] = []
	
	var timeline_data = timelines_data[current_key] as Array
	
	# 查找或创建当前 tick 的数据
	var tick_data = null
	for entry in timeline_data:
		if entry.tick == current_tick:
			tick_data = entry
			break
	
	if not tick_data:
		tick_data = {"tick": current_tick, "actions": []}
		timeline_data.append(tick_data)
		timeline_data.sort_custom(func(a, b): return a.tick < b.tick)
	
	# 创建新动作
	var new_action = {"type": action_type}
	
	# 根据类型设置默认值
	match action_type:
		"text":
			new_action["txt"] = "新文本"
			new_action["dur"] = 3.0
			new_action["off"] = [100, -130]
		"await":
			new_action["time"] = 1.0
		"set_pattern":
			new_action["pattern"] = "circle"
		"set_muzzle":
			new_action["pos"] = extra_params.get("pos", [[0,0]])
		"set_dir":
			new_action["mode"] = 0
			new_action["deg"] = 0.0
		"stats":
			new_action["hp"] = 50
			new_action["max_hp"] = 50
		"end_battle":
			new_action["victory"] = true
		"guard_choice":
			new_action["not"] = -1
			new_action["then"] = []
		"if":
			new_action["cond"] = "eq_0"
			new_action["then"] = []
		"set_pattern_from_list":
			new_action["index"] = 0
		"emit":
			var drop_pos = extra_params.get("pos", [[0, 0]])
			new_action["emitter_pos"] = drop_pos[0] if drop_pos.size() > 0 else [0, 0]
			new_action["target_pos"] = [0, -200]
			new_action["target_selector"] = "absolute"
			new_action["tags"] = []
		"emit_continuous":
			var drop_pos = extra_params.get("pos", [[0, 0]])
			new_action["start_pos"] = drop_pos[0] if drop_pos.size() > 0 else [0, 0]
			new_action["key_positions"] = [[100, 0]]
			new_action["key_targets"] = [[100, -200], [300, -200]]
			new_action["move_duration"] = 2.0
			new_action["emit_count"] = 10
			new_action["target_selector"] = "absolute"
			new_action["tags"] = []
	
	# 合并额外参数
	for key in extra_params:
		new_action[key] = extra_params[key]
	
	tick_data.actions.append(new_action)
	save_timelines()
	update_inspector_for_tick()
	await update_preview()
	print("[TimelineEditor] 已添加动作: " + action_type + " 到 " + current_key + " tick " + str(current_tick))

# ==================== 信号连接 ====================
func connect_signals():
	time_slider.value_changed.connect(_on_time_slider_changed)
	btn_play.pressed.connect(_on_play_toggle)
	var btn_replay = Button.new()
	btn_replay.text = "重播"
	btn_replay.tooltip_text = "从头重新播放当前时间线"
	btn_replay.pressed.connect(_on_replay_pressed)
	$TopBar.add_child(btn_replay)
	tree_timeline.item_selected.connect(_on_tree_item_selected)
	tree_timeline.item_mouse_selected.connect(_on_tree_rmb_selected)
	
	# 底部按钮
	var btn_save = $BottomBar/BtnSave
	var btn_add_tl = $BottomBar/BtnAddTimeline
	var btn_add_tick = $BottomBar/BtnAddTick
	btn_save.pressed.connect(_on_save_pressed)
	btn_add_tl.pressed.connect(_on_add_timeline_pressed)
	btn_add_tick.pressed.connect(_on_add_tick_pressed)
	# 新增"写入项目"按钮
	var btn_to_project = Button.new()
	btn_to_project.text = "写入项目"
	btn_to_project.tooltip_text = "将当前数据写入项目 res:// 文件"
	btn_to_project.pressed.connect(save_to_project)
	$BottomBar.add_child(btn_to_project)
	# 新增"从项目重新加载"按钮
	var btn_reload = Button.new()
	btn_reload.text = "从项目重载"
	btn_reload.tooltip_text = "放弃当前编辑，重新从项目文件加载"
	btn_reload.pressed.connect(_on_reload_from_project)
	$BottomBar.add_child(btn_reload)

func _on_save_pressed():
	save_timelines()
	# 也保存到备份
	var file = FileAccess.open("res://timelines_backup.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(timelines_data, "\t"))
		file.close()
		print("[TimelineEditor] 已保存到工作文件和项目备份")

func _on_reload_from_project():
	load_timelines(true)
	build_tree()
	update_inspector_for_tick()
	update_preview()
	print("[TimelineEditor] 已从项目文件重新加载")

func _on_add_timeline_pressed():
	# 简单弹窗输入（用 _dialog 或直接在场景里加）
	var enemy_type = 0
	var turn_type = 0
	# 找到下一个可用的编号
	var max_enemy = 0
	var max_turn = {}
	for key in timeline_keys:
		var parts = key.split("_")
		var e = int(parts[0])
		var t = int(parts[1])
		if e > max_enemy:
			max_enemy = e
		if not max_turn.has(str(e)):
			max_turn[str(e)] = 0
		if t > max_turn[str(e)]:
			max_turn[str(e)] = t
	# 默认给当前敌人类型新增一个回合
	if current_key != "":
		var parts = current_key.split("_")
		enemy_type = int(parts[0])
		turn_type = max_turn.get(str(enemy_type), 0) + 1
	else:
		enemy_type = max_enemy + 1
	
	var new_key = str(enemy_type) + "_" + str(turn_type)
	if not timelines_data.has(new_key):
		timelines_data[new_key] = []
		timeline_keys = timelines_data.keys()
		timeline_keys.sort()
		build_tree()
		select_key(new_key)
		print("[TimelineEditor] 新增回合: " + new_key)

func _on_add_tick_pressed():
	if current_key == "" or not timelines_data.has(current_key):
		print("[TimelineEditor] 请先选择一个回合")
		return
	add_action_to_current_tick("pass")
	# 重新选中，滚动到新 tick
	select_key(current_key, current_tick + 1)

func _on_tree_rmb_selected(item: TreeItem, pos: Vector2, button_index: int):
	# 右键菜单
	if item.has_meta("key"):
		_show_timeline_context_menu(item, pos)
	elif item.has_meta("key_prefix"):
		_show_enemy_context_menu(item, pos)

func _show_timeline_context_menu(item: TreeItem, pos: Vector2):
	# 简化：直接删除
	var key = item.get_meta("key")
	var popup = PopupMenu.new()
	popup.add_item("删除回合")
	popup.id_pressed.connect(func(id):
		timelines_data.erase(key)
		timeline_keys = timelines_data.keys()
		timeline_keys.sort()
		build_tree()
		popup.queue_free()
	)
	get_tree().root.add_child(popup)
	popup.position = pos
	popup.popup()

func _show_enemy_context_menu(item: TreeItem, pos: Vector2):
	var popup = PopupMenu.new()
	popup.add_item("新增回合")
	popup.id_pressed.connect(func(id):
		var prefix = item.get_meta("key_prefix")
		var new_turn = 0
		for k in timeline_keys:
			if k.begins_with(prefix):
				var t = int(k.split("_")[1])
				if t >= new_turn:
					new_turn = t + 1
		var new_key = prefix + str(new_turn)
		timelines_data[new_key] = []
		timeline_keys = timelines_data.keys()
		timeline_keys.sort()
		build_tree()
		popup.queue_free()
	)
	get_tree().root.add_child(popup)
	popup.position = pos
	popup.popup()

# ==================== 播放/暂停/重播 ====================
func _on_play_toggle():
	if is_playing:
		is_paused = not is_paused
		btn_play.text = "继续" if is_paused else "暂停"
	elif btn_play.text == "重播":
		_on_replay_pressed()
	else:
		_stop_requested = false
		is_paused = false
		btn_play.text = "暂停"
		_on_play_preview()

func _on_replay_pressed():
	if not timelines_data.has(current_key):
		return
	var tl = timelines_data[current_key] as Array
	if tl.is_empty():
		return
	if is_playing:
		_stop_requested = true
		await get_tree().process_frame
		_stop_requested = false
	current_tick = tl[0].tick
	btn_play.text = "暂停"
	is_playing = false
	is_paused = false
	_on_play_preview()

func _on_play_preview():
	if is_playing:
		return
	is_playing = true
	
	print("[TimelineEditor] 开始预览 " + current_key + " 从 tick " + str(current_tick))
	if not timelines_data.has(current_key):
		is_playing = false
		return
	
	var target_container = get_node("/root/TimelineEditor/CenterPreview/BattleBox/BulletContainer") as Node2D
	
	var temp_enemy = Node2D.new()
	temp_enemy.set_script(load("res://enemy.gd"))
	temp_enemy.name = "TempEnemy"
	
	if target_container:
		temp_enemy.bullet_container = target_container
	else:
		print("❌ 找不到 BulletContainer！预览场景结构可能有问题")
	
	preview_rect.add_child(temp_enemy)
	await get_tree().process_frame
	
	temp_enemy.set_meta("last_player_choice", -1)
	
	var sprite = preview_rect.get_node("EnemySprite") as Sprite2D
	if sprite and sprite.texture:
		var new_sprite = sprite.duplicate()
		temp_enemy.add_child(new_sprite)
	
	var enemy_position = Vector2(preview_rect.size.x / 2, 80)
	temp_enemy.position = enemy_position
	temp_enemy.scale = Vector2(1.5, 1.5)
	
	AttackPatterns._set_context(temp_enemy)
	
	if not timelines_data.has(current_key):
		AttackPatterns._set_context(null)
		temp_enemy.queue_free()
		is_playing = false
		btn_play.text = "播放"
		return
	
	var timeline_data = timelines_data[current_key] as Array
	
	var start_index = 0
	for i in range(timeline_data.size()):
		if timeline_data[i].tick >= current_tick:
			start_index = i
			break
	
	for i in range(start_index, timeline_data.size()):
		if _stop_requested:
			break
		
		while is_paused and not _stop_requested:
			await get_tree().process_frame
		if _stop_requested:
			break
		
		var entry = timeline_data[i]
		current_tick = entry.tick
		
		time_slider.set_block_signals(true)
		time_slider.value = current_tick
		time_slider.set_block_signals(false)
		tick_label.text = "tick: " + str(current_tick) + " / " + str(get_max_tick())
		
		var actions = entry.actions as Array
		_refresh_muzzle_markers(actions)
		
		for action in actions:
			var atype = action.type
			match atype:
				"set_pattern":
					temp_enemy.current_pattern = action.pattern
				"set_muzzle":
					if action.has("pos"):
						var pos_arr = []
						for p in action.pos:
							if p is Array and p.size() >= 2:
								pos_arr.append(Vector2(p[0], p[1]))
							else:
								print("[WARN] set_muzzle: 跳过无效坐标: ", p)
						if pos_arr.size() > 0:
							temp_enemy.muzzle_positions = pos_arr
							temp_enemy.current_muzzle_index = 0
				"set_dir":
					temp_enemy.set_direction_offset_mode(action.get("mode", 0), action.get("deg", 0.0))
				"set_bullet_v":
					if action.has("v"):
						temp_enemy.bullet_v = action.v
				"emit":
					var emitter = BulletEmitter.from_dict(action)
					await emitter.execute(temp_enemy, target_container)
				"emit_continuous":
					var emitter = ContinuousBulletEmitter.from_dict(action)
					emitter.global_offset = Vector2(0, preview_rect.size.y/2 - 80)
					preview_rect.add_child(emitter)
					emitter.start(temp_enemy, target_container)
					if emitter.special_tags.has("存在于单帧"):
						await emitter.finished
		
		await get_tree().create_timer(0.5).timeout
	
	# 清理仍在运行的后台连续发射器
	for child in preview_rect.get_children():
		if child is ContinuousBulletEmitter:
			child.queue_free()
	AttackPatterns._set_context(null)
	temp_enemy.queue_free()
	is_playing = false
	is_paused = false
	if _stop_requested:
		btn_play.text = "播放"
	else:
		btn_play.text = "重播"
	await update_preview()
	_stop_requested = false
	print("[TimelineEditor] 预览结束")

# ==================== 右键菜单（树） ====================
func _on_tree_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var item = tree_timeline.get_item_at_position(event.position)
		if item:
			_show_tree_context_menu(item, event.position)

func _show_tree_context_menu(item, pos: Vector2):
	# TODO: 实现右键菜单：新增回合、删除回合、新增 tick
	pass
