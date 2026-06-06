@tool
extends Control

var bullet_container: Node2D

func _ready():
	if not has_node("BlackBG"):
		_create_battle_box()

func _create_battle_box():
	# Black background
	var bg = ColorRect.new()
	bg.name = "BlackBG"
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# White border (battle box)
	var border = ColorRect.new()
	border.name = "WhiteBorder"
	border.color = Color(1, 1, 1, 1)
	border.size = Vector2(275, 220)
	border.position = Vector2(50, 50)
	bg.add_child(border)
	
	# Black content
	var inner = ColorRect.new()
	inner.name = "BlackContent"
	inner.color = Color(0, 0, 0, 1)
	inner.size = Vector2(269, 214)
	inner.position = Vector2(3, 3)
	border.add_child(inner)
	
	# Enemy placeholder
	var enemy = ColorRect.new()
	enemy.name = "EnemySprite"
	enemy.color = Color(0.8, 0.2, 0.2, 1.0)
	enemy.size = Vector2(80, 80)
	enemy.position = Vector2(inner.size.x / 2.0 - 40, 30)
	inner.add_child(enemy)
	
	# Bullet container
	bullet_container = Node2D.new()
	bullet_container.name = "BulletContainer"
	inner.add_child(bullet_container)

func set_timeline_data(key: String, entries: Array):
	pass

func set_tick(t: float):
	_spawn_for_tick(t)

func _spawn_for_tick(t: float):
	if not bullet_container: return
	for b in bullet_container.get_children():
		b.queue_free()
	# Placeholder - spawn a test bullet
	var test = ColorRect.new()
	test.color = Color(1, 1, 0, 1)
	test.size = Vector2(8, 8)
	test.position = Vector2(137.5 - 4, 107.0 - 4)
	bullet_container.add_child(test)
