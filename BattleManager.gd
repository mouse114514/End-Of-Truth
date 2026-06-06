extends Node

signal battle_ended

var current_battle: Node = null
var is_in_battle: bool = false
var world_state: Dictionary = {}

func _ready():
	print("BattleManager 初始化完成")

func start_forced_encounter(enemy_scene: PackedScene, battle_data: Dictionary):
	if is_in_battle:
		return
		
	is_in_battle = true
	
	# 重要：在开始战斗前清理所有触发器
	cleanup_all_triggers()
	
	# 保存世界状态
	save_world_state()
	
	# 禁用玩家
	disable_player()
	
	# 加载战斗场景
	current_battle = enemy_scene.instantiate()
	get_tree().current_scene.add_child(current_battle)
	current_battle.visible = false
	
	# 开始三重闪黑序列
	start_triple_flash_sequence(battle_data)

func cleanup_all_triggers():
	"""清理所有战斗触发器（包括固定和随机触发器）"""
	
	# 清理所有战斗触发器
	var battle_triggers = get_tree().get_nodes_in_group("battle_trigger")
	var fixed_triggers = get_tree().get_nodes_in_group("fixed_battle_trigger")
	var random_triggers = get_tree().get_nodes_in_group("random_battle_trigger")
	
	var total_cleaned = 0
	
	# 清理普通战斗触发器
	for trigger in battle_triggers:
		if is_instance_valid(trigger):
			trigger.queue_free()
			total_cleaned += 1
	
	# 清理固定触发器
	for trigger in fixed_triggers:
		if is_instance_valid(trigger):
			trigger.queue_free()
			total_cleaned += 1
	
	# 清理随机触发器
	for trigger in random_triggers:
		if is_instance_valid(trigger):
			trigger.queue_free()
			total_cleaned += 1

func save_world_state():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		world_state["player_position"] = player.global_position
		world_state["player_visible"] = player.visible
		world_state["player_process_input"] = player.is_processing_input()
		world_state["player_physics_process"] = player.is_physics_processing()
		world_state["player_process"] = player.process_mode

func disable_player():
	"""禁用玩家"""
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 使用直接调用，确保立即生效
		player.visible = false
		player.set_process_input(false)
		player.set_physics_process(false)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		
		# 同时调用玩家的战斗状态方法
		if player.has_method("set_battle_state"):
			player.set_battle_state(true)


func start_triple_flash_sequence(battle_data: Dictionary):
	
	if not current_battle or not current_battle.has_method("play_black_flash"):
		direct_start_battle(battle_data)
		return
	
	current_battle.play_black_flash(0.1, 0.1, 
		func(): 
			current_battle.play_black_flash(0.1, 0.1,
				func():
					current_battle.play_black_flash(0.1, 0.1,
						func():
							if current_battle.has_method("start_battle"):
								current_battle.start_battle(battle_data)
							else:
								direct_start_battle(battle_data)
					)
			)
	)

func direct_start_battle(battle_data: Dictionary):
	if current_battle and current_battle.has_method("start_battle"):
		current_battle.start_battle(battle_data)
		current_battle.visible = true
	else:
		# 如果战斗场景无法启动，恢复世界状态
		restore_world_state()
		is_in_battle = false

func end_battle(victory: bool):
	
	if current_battle:
		var battle = current_battle
		current_battle = null
		if is_instance_valid(battle):
			battle.queue_free()
	
	is_in_battle = false
	restore_world_state()
	
	on_battle_victory() if victory else on_battle_defeat()
	
	battle_ended.emit()

func restore_world_state():
	"""恢复世界状态"""
	var player = get_tree().get_first_node_in_group("player")
	if player and world_state.has("player_position"):
		# 先恢复位置（所有路径都需要）
		if world_state.has("player_position"):
			player.global_position = world_state["player_position"]
		if world_state.has("player_visible"):
			player.visible = world_state["player_visible"]
		if world_state.has("player_process_input"):
			player.set_process_input(world_state["player_process_input"])
		if world_state.has("player_physics_process"):
			player.set_physics_process(world_state["player_physics_process"])
		if world_state.has("player_process"):
			player.process_mode = world_state["player_process"]
		
		# 使用玩家提供的状态恢复方法
		if player.has_method("restore_state_after_battle"):
			player.restore_state_after_battle()
		elif player.has_method("set_battle_state"):
			player.set_battle_state(false)
		elif player.has_method("return_from_battle"):
			player.return_from_battle()
		
		# 重置战斗状态
		if player.has_method("reset_transient_state"):
			player.reset_transient_state()

func _restore_player_state_directly(player: Node):
	"""直接恢复玩家状态（备用方案）"""
	if world_state.has("player_position"):
		player.global_position = world_state["player_position"]
	
	if world_state.has("player_visible"):
		player.visible = world_state["player_visible"]
	
	if world_state.has("player_process_input"):
		player.set_process_input(world_state["player_process_input"])
	
	if world_state.has("player_physics_process"):
		player.set_physics_process(world_state["player_physics_process"])
	
	if world_state.has("player_process"):
		player.process_mode = world_state["player_process"]
	
	# 重要：重置玩家脚本中的战斗状态
	if player.has_method("set_battle_state"):
		player.set_battle_state(false)
	elif player.has_method("return_from_battle"):
		player.return_from_battle()
	else:
		# 如果玩家脚本没有相应方法，则直接设置变量
		player.set("is_in_battle", false)
	
	# 重置瞬态数据
	if player.has_method("reset_transient_state"):
		player.reset_transient_state()

func on_battle_victory():
	print("战斗胜利")

func on_battle_defeat():
	print("战斗失败")
