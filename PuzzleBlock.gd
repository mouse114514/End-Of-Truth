extends RigidBody2D

@export var puzzle_id: String = ""
@export var block_id: String = ""
@export var target_position: Vector2 = Vector2.ZERO
@export var snap_threshold: float = 20.0

var is_placed: bool = false
var player_pushing: bool = false

func _ready():
	add_to_group("puzzle_block")
	add_to_group("puzzle_element")
	freeze = false
	print("方块初始化: ", puzzle_id, "/", block_id)

func _physics_process(delta):
	if not is_placed and target_position != Vector2.ZERO:
		var dist = global_position.distance_to(target_position)
		if dist < snap_threshold:
			snap_to_target()

func snap_to_target():
	is_placed = true
	global_position = target_position
	freeze = true
	_notify_puzzle_manager()
	print("方块到位: ", block_id)

func _notify_puzzle_manager():
	if puzzle_id != "" and block_id != "":
		var pm = get_node_or_null("/root/PuzzleManager")
		if pm:
			pm.set_puzzle_state(puzzle_id, block_id, is_placed)
			if is_placed and _check_all_blocks_placed():
				pm.complete_puzzle(puzzle_id)

func _check_all_blocks_placed() -> bool:
	var pm = get_node_or_null("/root/PuzzleManager")
	if pm and puzzle_id != "":
		var puzzle_data = pm.active_puzzles.get(puzzle_id, {})
		var expected_blocks = puzzle_data.get("blocks", [])
		for block_id_check in expected_blocks:
			if not pm.get_puzzle_state(puzzle_id, block_id_check, false):
				return false
		return true
	return false
