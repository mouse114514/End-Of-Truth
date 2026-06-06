extends Node

signal story_finished
signal battle_ended
signal branch_selected(index: int)

var is_playing: bool = false
var current_story: GDScript = null
var player_node: Node = null
var player_input_blocked: bool = false
var triggered_stories: Array[String] = []
var _player_saved_state: Dictionary = {}
var _npcs: Dictionary = {}
var _npc_avatar_paths: Dictionary = {}
var _npc_bgm: Dictionary = {}
var _current_npc_bgm: String = ""

var _branch_actions: Dictionary = {}
var _current_branch_id: int = -1
var _active_branch_code: Array = []
var _current_branch_index: int = -1

var _skip_branch_code: bool = false
var _branch_stack: Array = []

@export var default_story_script: GDScript = null

func _ready():
	print("StoryManager 初始化完成")
	if default_story_script == null:
		default_story_script = load("res://stories/all_stories.gd")
		print("  已加载默认剧情脚本: ", default_story_script)

func start_story(story_script: GDScript) -> void:
	if is_playing:
		return
	
	if get_tree() == null:
		push_warning("StoryManager: get_tree() is null")
		return
	
	is_playing = true
	current_story = story_script
	
	_block_player_input()
	
	var story_instance = story_script.new()
	if story_instance.has_method("execute"):
		await story_instance.execute(self)
	else:
		push_warning("StoryManager: story script missing execute method")
	story_instance.queue_free()
	
	_on_story_finished()

func start_story_by_function_name(story_script: GDScript, function_name: String) -> void:
	if is_playing:
		return
	if get_tree() == null:
		push_warning("StoryManager: get_tree() is null")
		return
	var script_to_use = story_script if story_script != null else default_story_script
	if script_to_use == null:
		push_warning("StoryManager: no story script available")
		return
	is_playing = true
	current_story = script_to_use
	_block_player_input()
	var story_instance = script_to_use.new()
	if story_instance.has_method(function_name):
		await story_instance.call(function_name, self)
	else:
		push_warning("StoryManager: story script missing function: " + function_name)
	story_instance.queue_free()
	_on_story_finished()

func start_story_by_region(story_script: GDScript, region_id: String) -> void:
	print("StoryManager: start_story_by_region - ", region_id)
	
	# 开发者模式/战斗模式：跳过所有主世界剧情
	if GameSettings.developer_mode or GameSettings.battle_mode:
		print("  开发者/战斗模式，跳过剧情")
		return
	
	if is_playing:
		print("  已有剧情在播放")
		return
	
	if get_tree() == null:
		push_warning("StoryManager: get_tree() is null")
		return
	
	var script_to_use = story_script
	if script_to_use == null:
		script_to_use = default_story_script
		print("  使用默认脚本: ", default_story_script)
	
	if script_to_use == null:
		push_warning("StoryManager: no story script available")
		return
	
	is_playing = true
	current_story = script_to_use
	
	_block_player_input()
	
	print("  执行剧情")
	var story_instance = script_to_use.new()
	if story_instance.has_method("execute"):
		await _call_story_execute(story_instance, region_id)
	else:
		push_warning("StoryManager: story script missing execute method")
	story_instance.queue_free()
	
	_on_story_finished()

func _call_story_execute(story_instance, region_id) -> void:
	var method = Callable(story_instance, "execute")
	await method.call(self, region_id)

func _block_player_input() -> void:
	print("StoryManager: 锁定玩家输入")
	if get_tree() == null:
		push_warning("StoryManager: get_tree() is null in _block_player_input")
		return
	player_node = get_tree().get_first_node_in_group("player")
	print("  player_node: ", player_node)
	if player_node:
		_player_saved_state["process_mode"] = player_node.process_mode
		_player_saved_state["process_input"] = player_node.is_processing_input()
		_player_saved_state["physics_process"] = player_node.is_physics_processing()
		_player_saved_state["global_position"] = player_node.global_position
		
		# 清除移动状态，停止动画
		if player_node.has_method("stop_moving_immediately"):
			player_node.stop_moving_immediately()
		
		player_node.process_mode = Node.PROCESS_MODE_DISABLED
		
		player_input_blocked = true

func _unblock_player_input() -> void:
	if player_node and is_instance_valid(player_node):
		if _player_saved_state.has("process_mode"):
			player_node.process_mode = _player_saved_state["process_mode"]
		if _player_saved_state.has("process_input"):
			player_node.set_process_input(_player_saved_state["process_input"])
		if _player_saved_state.has("physics_process"):
			player_node.set_physics_process(_player_saved_state["physics_process"])
		if _player_saved_state.has("global_position"):
			player_node.global_position = _player_saved_state["global_position"]
		
		# 恢复玩家状态
		if player_node.has_method("reset_transient_state"):
			player_node.reset_transient_state()
	
	_player_saved_state.clear()
	player_input_blocked = false

func _on_story_finished() -> void:
	print("StoryManager: _on_story_finished called!")
	is_playing = false
	current_story = null
	if _current_npc_bgm != "":
		_current_npc_bgm = ""
		SoundManager.stop_bgm()
	_unblock_player_input()
	story_finished.emit()

func is_story_triggered(story_id: String) -> bool:
	return story_id in triggered_stories

func mark_story_triggered(story_id: String) -> void:
	if story_id not in triggered_stories:
		triggered_stories.append(story_id)

func load_npc(texture_path: String, position: Vector2, npc_id: String, scale: float = 1.0, speaker_name: String = "", avatar_path: String = "", npc_bgm: String = "") -> void:
	var sprite = Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.global_position = position
	sprite.scale = Vector2(scale, scale)
	sprite.name = "NPC_" + npc_id
	get_tree().current_scene.add_child(sprite)
	_npcs[npc_id] = sprite
	if speaker_name != "":
		if avatar_path != "":
			_npc_avatar_paths[speaker_name] = avatar_path
		else:
			_npc_avatar_paths[speaker_name] = texture_path
		if npc_bgm != "":
			_npc_bgm[speaker_name] = npc_bgm

func _get_target(target: String) -> Node:
	target = target.strip_edges()
	if target.begins_with("@$"):
		var selector = target.substr(2)
		match selector:
			"P":
				return get_tree().get_first_node_in_group("player")
			_:
				push_warning("StoryManager: Unknown selector: " + selector)
				return null
	elif target.begins_with("@"):
		var npc_id = target.substr(1)
		if _npcs.has(npc_id):
			return _npcs[npc_id]
		push_warning("StoryManager: NPC not found: " + npc_id)
		return null
	return null

func _parse_position(pos_str: String) -> Vector2:
	pos_str = pos_str.strip_edges()
	if not pos_str.begins_with("@"):
		return Vector2.ZERO
	
	var plus_idx = pos_str.find("+")
	var target_str: String
	var offset_str: String
	
	if plus_idx > 0:
		target_str = pos_str.substr(1, plus_idx - 1)
		offset_str = pos_str.substr(plus_idx + 1)
	else:
		target_str = pos_str.substr(1)
		offset_str = ""
	
	var target = _get_target("@" + target_str)
	if target == null:
		push_warning("StoryManager: Target not found: " + target_str)
		return Vector2.ZERO
	
	var offset = _parse_offset(offset_str)
	return target.global_position + offset

func _parse_offset(offset_str: String) -> Vector2:
	offset_str = offset_str.strip_edges()
	if offset_str == "":
		return Vector2.ZERO
	if offset_str.begins_with("+"):
		offset_str = offset_str.substr(1).strip_edges()
	var parts = offset_str.split(",")
	if parts.size() >= 2:
		var x = float(parts[0].strip_edges())
		var y = float(parts[1].strip_edges())
		return Vector2(x, y)
	return Vector2.ZERO

func move_npc(npc_id: String, target_pos: Vector2, duration: float = 1.0) -> void:
	if not _npcs.has(npc_id):
		push_warning("StoryManager: NPC not found: " + npc_id)
		return
	var npc = _npcs[npc_id]
	if not is_instance_valid(npc):
		push_warning("StoryManager: NPC is invalid: " + npc_id)
		return
	
	var tween = create_tween()
	tween.tween_property(npc, "global_position", target_pos, duration)
	await tween.finished

func move_npc_to(npc_id: String, target_str: String, duration: float = 1.0) -> void:
	print("StoryManager: move_npc_to - ", npc_id, " -> ", target_str)
	if not _npcs.has(npc_id):
		push_warning("StoryManager: NPC not found: " + npc_id)
		return
	var npc = _npcs[npc_id]
	if not is_instance_valid(npc):
		push_warning("StoryManager: NPC is invalid: " + npc_id)
		return
	
	var final_pos = _parse_position(target_str)
	print("  目标位置: ", final_pos)
	if final_pos == Vector2.ZERO:
		push_warning("StoryManager: Failed to parse position: " + target_str)
		return
	
	var tween = create_tween()
	tween.tween_property(npc, "global_position", final_pos, duration)
	await tween.finished
	print("  移动完成")

func unload_npc(npc_id: String) -> void:
	if not _npcs.has(npc_id):
		return
	var npc = _npcs[npc_id]
	if is_instance_valid(npc):
		npc.queue_free()
	_npcs.erase(npc_id)

func show_dialog(speaker: String, text: String) -> void:
	print("StoryManager: show_dialog - speaker='", speaker, "' text='", text, "'")
	var canvas = null
	
	if get_tree() and get_tree().current_scene:
		var scene = get_tree().current_scene
		canvas = scene.get_node_or_null("InvestigationDialog")
		if not canvas:
			canvas = scene.get_node_or_null("CanvasC")
		if not canvas:
			for child in scene.get_children():
				if child is CanvasLayer and child.has_method("show_text"):
					canvas = child
					break
		
		print("  canvas: ", canvas)
	if canvas:
		print("  显示对话框")
		var texture: Texture2D = null
		
		# 如果没有提供纹理，尝试从NPC配置获取
		if speaker != "":
			if _npc_avatar_paths.has(speaker):
				texture = load(_npc_avatar_paths[speaker])
			if _npc_bgm.has(speaker):
				var bgm = _npc_bgm[speaker]
				if bgm != _current_npc_bgm:
					_current_npc_bgm = bgm
					SoundManager.play_bgm(bgm)
		
		canvas.waiting_for_close = true
		
		canvas.show_text(text, speaker, texture)
		print("  等待对话框关闭, is_playing: ", is_playing)
		await canvas.dialog_closed
		print("  对话框已关闭, is_playing: ", is_playing)
	else:
		push_warning("CanvasC not found, skipping dialog")

func wait(seconds: float) -> void:
	if get_tree() != null:
		await get_tree().create_timer(seconds).timeout

func flash_white(duration: float = 0.2) -> void:
	var rect = ColorRect.new()
	rect.color = Color.WHITE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0
	get_tree().current_scene.add_child(rect)
	
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration / 2)
	tween.tween_property(rect, "modulate:a", 0.0, duration / 2)
	await tween.finished
	rect.queue_free()

func flash_black(duration: float = 0.2) -> void:
	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0
	get_tree().current_scene.add_child(rect)
	
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration / 2)
	tween.tween_property(rect, "modulate:a", 0.0, duration / 2)
	await tween.finished
	rect.queue_free()

func transition_white(duration: float = 1.0) -> void:
	var rect = ColorRect.new()
	rect.color = Color.WHITE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0
	get_tree().current_scene.add_child(rect)
	
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration / 2)
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration / 2)
	await tween.finished
	rect.queue_free()

func transition_black(duration: float = 1.0) -> void:
	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0
	get_tree().current_scene.add_child(rect)
	
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration / 2)
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration / 2)
	await tween.finished
	rect.queue_free()

func play_audio(audio_path: String, volume_db: float = 0.0) -> void:
	SoundManager.play(audio_path, volume_db)

func wait_for_battle() -> void:
	var battle_manager = get_node("/root/BattleManager")
	await battle_manager.battle_ended

func start_battle(enemy_id: String, turn_type: int = 0, start_with_enemy_turn: bool = false, end_after_one_turn: bool = false) -> void:
	var battle_manager = get_node("/root/BattleManager")
	var battle_data = {
		"enemy_id": enemy_id,
		"turn_type": turn_type,
		"start_with_enemy_turn": start_with_enemy_turn,
		"end_after_one_turn": end_after_one_turn
	}
	var enemy_scene = preload("res://bullet_hell_scene.tscn")
	battle_manager.start_forced_encounter(enemy_scene, battle_data)
	await battle_manager.battle_ended

func branch_talk(speaker: String, text: String, options: Array) -> int:
	var canvas = _get_dialog_canvas()
	if canvas and canvas.has_method("show_text_with_options"):
		var texture = null
		if speaker != "":
			if _npc_avatar_paths.has(speaker):
				texture = load(_npc_avatar_paths[speaker])
			if _npc_bgm.has(speaker):
				var bgm = _npc_bgm[speaker]
				if bgm != _current_npc_bgm:
					_current_npc_bgm = bgm
					SoundManager.play_bgm(bgm)
		var result = await canvas.show_text_with_options(text, speaker, texture, options)
		_current_branch_index = result
		return result
	return -1

func _get_dialog_canvas():
	if get_tree() and get_tree().current_scene:
		var scene = get_tree().current_scene
		var canvas = scene.get_node_or_null("InvestigationDialog")
		if not canvas:
			canvas = scene.get_node_or_null("CanvasC")
		if not canvas:
			for child in scene.get_children():
				if child is CanvasLayer and child.has_method("show_text"):
					canvas = child
					break
		return canvas
	return null

func branch_do(branch_id: int) -> bool:
	_current_branch_id = branch_id
	_branch_stack.append(branch_id)
	return branch_id == _current_branch_index

func branch_od(branch_id: int):
	if not _branch_stack.is_empty():
		_branch_stack.pop_back()

func branch_goto(branch_id: int):
	if branch_id == _current_branch_index:
		return true
	return false

func _is_in_active_branch() -> bool:
	return not _branch_stack.is_empty() and _branch_stack.back() != _current_branch_index
