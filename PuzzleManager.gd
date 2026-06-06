extends Node

var active_puzzles: Dictionary = {}
var puzzle_completed_states: Dictionary = {}

var puzzle_states: Dictionary = {}

signal puzzle_started(puzzle_id: String)
signal puzzle_completed(puzzle_id: String)
signal puzzle_state_changed(puzzle_id: String, state: Dictionary)

func _ready():
	print("PuzzleManager 初始化完成")

func register_puzzle(puzzle_id: String, puzzle_data: Dictionary):
	active_puzzles[puzzle_id] = puzzle_data
	puzzle_states[puzzle_id] = puzzle_data.get("initial_state", {})
	print("解谜注册: ", puzzle_id)

func unregister_puzzle(puzzle_id: String):
	active_puzzles.erase(puzzle_id)
	puzzle_states.erase(puzzle_id)
	print("解谜注销: ", puzzle_id)

func start_puzzle(puzzle_id: String):
	if active_puzzles.has(puzzle_id):
		emit_signal("puzzle_started", puzzle_id)
		print("解谜开始: ", puzzle_id)

func complete_puzzle(puzzle_id: String):
	puzzle_completed_states[puzzle_id] = true
	emit_signal("puzzle_completed", puzzle_id)
	print("解谜完成: ", puzzle_id)

func is_puzzle_completed(puzzle_id: String) -> bool:
	return puzzle_completed_states.get(puzzle_id, false)

func set_puzzle_state(puzzle_id: String, key: String, value):
	if not puzzle_states.has(puzzle_id):
		puzzle_states[puzzle_id] = {}
	puzzle_states[puzzle_id][key] = value
	emit_signal("puzzle_state_changed", puzzle_id, puzzle_states[puzzle_id])

func get_puzzle_state(puzzle_id: String, key: String, default = null):
	return puzzle_states.get(puzzle_id, {}).get(key, default)

func reset_puzzle(puzzle_id: String):
	if active_puzzles.has(puzzle_id):
		puzzle_states[puzzle_id] = active_puzzles[puzzle_id].get("initial_state", {}).duplicate(true)
		puzzle_completed_states.erase(puzzle_id)
		print("解谜重置: ", puzzle_id)
