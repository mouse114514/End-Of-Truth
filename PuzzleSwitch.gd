extends Area2D

enum SwitchType {BUTTON, TOGGLE, PLATFORM}
@export var switch_type: SwitchType = SwitchType.BUTTON

@export var puzzle_id: String = ""
@export var switch_id: String = ""
@export var required_state: bool = true

@export var on_color: Color = Color.GREEN
@export var off_color: Color = Color.RED

var is_active: bool = false
var player_in_area: bool = false
var base_scale: Vector2 = Vector2.ONE

@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var collision = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready():
	add_to_group("puzzle_switch")
	add_to_group("puzzle_element")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if sprite:
		base_scale = sprite.scale
	_setup_visual()
	_connect_mobile_input_signals()
	print("开关初始化: ", puzzle_id, "/", switch_id)

func _connect_mobile_input_signals():
	var mobile_input = get_node_or_null("/root/MobileInput")
	print("DEBUG: 连接移动端信号, mobile_input=", mobile_input)
	if mobile_input:
		if mobile_input.has_signal("investigate_pressed"):
			mobile_input.investigate_pressed.connect(_on_mobile_investigate_pressed)
	else:
		print("DEBUG: MobileInput 未找到，重试...")
		await get_tree().create_timer(1.0).timeout
		_connect_mobile_input_signals()

func _on_mobile_investigate_pressed():
	if player_in_area:
		trigger_switch()

func _setup_visual():
	if sprite:
		sprite.modulate = off_color

func _process(delta):
	if player_in_area and Input.is_action_just_pressed("investigate"):
		trigger_switch()

func _on_body_entered(body):
	if body.is_in_group("player") or body.is_in_group("player_soul"):
		player_in_area = true

func _on_body_exited(body):
	if body.is_in_group("player") or body.is_in_group("player_soul"):
		player_in_area = false

func trigger_switch():
	if switch_type == SwitchType.TOGGLE:
		is_active = not is_active
	elif switch_type == SwitchType.BUTTON:
		is_active = required_state
	elif switch_type == SwitchType.PLATFORM:
		is_active = true
	
	_update_visual()
	_notify_puzzle_manager()
	print("开关触发: ", switch_id, " 状态: ", is_active)

func _update_visual():
	if sprite:
		sprite.modulate = on_color if is_active else off_color

func _notify_puzzle_manager():
	if puzzle_id != "" and switch_id != "":
		var pm = get_node_or_null("/root/PuzzleManager")
		if pm:
			pm.set_puzzle_state(puzzle_id, switch_id, is_active)

func set_state(new_state: bool):
	is_active = new_state
	_update_visual()
