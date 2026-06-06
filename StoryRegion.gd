extends Area2D

@export var region_id: String = ""
@export var story_script: GDScript = null
@export var trigger_once: bool = true
@export var auto_trigger: bool = true
@export var debug_visible: bool = false

var _triggered: bool = false
var _debug_rect: ColorRect = null

func _ready():
	body_entered.connect(_on_body_entered)
	
	if debug_visible:
		_create_debug_rect()

func _create_debug_rect() -> void:
	var shape = $CollisionShape2D.shape
	if shape is RectangleShape2D:
		_debug_rect = ColorRect.new()
		_debug_rect.color = Color(1, 1, 0, 0.3)
		_debug_rect.size = shape.size
		_debug_rect.position = -shape.size / 2
		add_child(_debug_rect)

func _on_body_entered(body: Node) -> void:
	print("StoryRegion: 触发 - ", name)
	if not body.is_in_group("player"):
		print("  不是玩家")
		return
	
	if not auto_trigger:
		return
	
	# 开发者模式/战斗模式：跳过所有主世界剧情
	if GameSettings.developer_mode or GameSettings.battle_mode:
		print("  开发者/战斗模式，跳过剧情")
		return
	
	if StoryManager.is_playing:
		print("  剧情正在播放")
		return
	
	if trigger_once and _triggered:
		print("  已触发过")
		return
	
	var final_region_id = region_id
	if final_region_id == "":
		final_region_id = name
	print("  region_id: ", final_region_id)
	
	if trigger_once and final_region_id != "" and StoryManager.is_story_triggered(final_region_id):
		print("  已记录触发")
		return
	
	_triggered = true
	
	if final_region_id != "":
		StoryManager.mark_story_triggered(final_region_id)
	
	StoryManager.start_story_by_region(story_script, final_region_id)
