extends StaticBody2D

enum DoorType {DOOR, PLATFORM, GATE}
@export var door_type: DoorType = DoorType.DOOR

@export var puzzle_id: String = ""
@export var door_id: String = ""
@export var required_state_key: String = ""
@export var required_state_value = true

@export var locked_color: Color = Color(0.3, 0.3, 0.3)
@export var unlocked_color: Color = Color(0.3, 0.8, 0.3)

var is_locked: bool = true

@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var collision = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready():
	add_to_group("puzzle_door")
	add_to_group("puzzle_element")
	_setup_visual()
	print("解谜门初始化: ", door_id)

func _setup_visual():
	if sprite:
		sprite.modulate = locked_color

func _process(delta):
	if is_locked and puzzle_id != "":
		_check_unlock_condition()

func _check_unlock_condition():
	var pm = get_node_or_null("/root/PuzzleManager")
	if pm and required_state_key != "":
		var current_value = pm.get_puzzle_state(puzzle_id, required_state_key, false)
		if current_value == required_state_value:
			unlock()

func unlock():
	if not is_locked:
		return
	
	is_locked = false
	_update_visual()
	print("解谜门解锁: ", door_id)
	
	_play_unlock_animation()

func lock():
	if is_locked:
		return
	
	is_locked = true
	_update_visual()
	_play_lock_animation()

func _update_visual():
	if sprite:
		sprite.modulate = unlocked_color if not is_locked else locked_color

func _play_unlock_animation():
	if sprite:
		var tween = create_tween()
		if door_type == DoorType.DOOR or door_type == DoorType.GATE:
			tween.tween_property(sprite, "position", sprite.position + Vector2(0, 50), 0.5)
		elif door_type == DoorType.PLATFORM:
			tween.tween_property(self, "position", position + Vector2(0, 100), 0.5)
		tween.tween_callback(func(): if collision: collision.set_deferred("disabled", true))

func _play_lock_animation():
	if collision:
		collision.set_deferred("disabled", false)
	if sprite:
		var tween = create_tween()
		if door_type == DoorType.DOOR or door_type == DoorType.GATE:
			tween.tween_property(sprite, "position", sprite.position - Vector2(0, 50), 0.5)
		elif door_type == DoorType.PLATFORM:
			tween.tween_property(self, "position", position - Vector2(0, 100), 0.5)
