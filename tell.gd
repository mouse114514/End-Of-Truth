extends Area2D

# 可用的调查文本数组
var tell_texts = [
	"* Hi,我是金盏花",
	"* 等等,你是人类吗?",
	'* 点击左下角一口气看到大结局'
]

var current_text_index: int = 0
var has_been_triggered: bool = false

func _ready():
	# 添加到tell区域组
	add_to_group("tell_areas")
	
	# 连接信号
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area):
	# 开发者模式/战斗模式：跳过所有主世界剧情
	if GameSettings.developer_mode or GameSettings.battle_mode:
		print("开发者/战斗模式，跳过tell触发")
		return
	
	# 检查是否是玩家进入
	if area.is_in_group("player"):
		print("玩家进入tell区域")
		# 检查是否已经触发过
		if not has_been_triggered:
			# 标记为已触发
			has_been_triggered = true
			# 重置文本索引
			current_text_index = 0
			# 通知玩家触发tell区域
			if area.has_method("_trigger_tell_area"):
				area._trigger_tell_area(self)

func get_tell_text():
	# 返回当前索引的文本
	if current_text_index < tell_texts.size():
		return tell_texts[current_text_index]
	return ""

func has_next_text() -> bool:
	# 检查是否有下一条文本
	return current_text_index + 1 < tell_texts.size()

func next_text():
	# 移动到下一条文本
	if has_next_text():
		current_text_index += 1
		return true
	return false
