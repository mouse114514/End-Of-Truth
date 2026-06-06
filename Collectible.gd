extends Area2D

@export var puzzle_id: String = ""
@export var collectible_id: String = ""
@export var item_name: String = ""
@export var item_description: String = ""

var is_collected: bool = false
var base_scale: Vector2 = Vector2.ONE

@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var collision = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready():
	add_to_group("collectible")
	add_to_group("puzzle_element")
	body_entered.connect(_on_body_entered)
	if sprite:
		base_scale = sprite.scale

func _process(delta):
	if not is_collected:
		_rotate_pulse(delta)

func _rotate_pulse(delta):
	if sprite:
		sprite.rotation += delta * 2
		var scale_base = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.1
		sprite.scale = base_scale * scale_base

func collect():
	if is_collected:
		return
	
	is_collected = true
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
		tween.tween_callback(queue_free)
	
	_notify_puzzle_manager()
	_show_collect_feedback()

func _notify_puzzle_manager():
	if puzzle_id != "" and collectible_id != "":
		var pm = get_node_or_null("/root/PuzzleManager")
		if pm:
			pm.set_puzzle_state(puzzle_id, collectible_id, true)
			if _check_all_collected():
				pm.complete_puzzle(puzzle_id)

func _check_all_collected() -> bool:
	var pm = get_node_or_null("/root/PuzzleManager")
	if pm and puzzle_id != "":
		var puzzle_data = pm.active_puzzles.get(puzzle_id, {})
		var required_items = puzzle_data.get("required_items", [])
		for item_id in required_items:
			if not pm.get_puzzle_state(puzzle_id, item_id, false):
				return false
		return true
	return false

func _show_collect_feedback():
	var label = Label.new()
	label.text = item_name
	var font = load("res://font/main.ttf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.position = global_position - Vector2(50, 50)
	label.modulate = Color(1, 1, 1, 0)
	get_tree().current_scene.add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.3)
	tween.tween_property(label, "position", label.position - Vector2(0, 30), 1.0)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5).set_delay(0.5)
	tween.tween_callback(label.queue_free)

func _on_body_entered(body):
	if body.is_in_group("player") or body.is_in_group("player_soul"):
		collect()
