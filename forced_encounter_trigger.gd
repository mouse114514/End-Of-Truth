extends Area2D

@export var enemy_scene: PackedScene

var has_triggered: bool = false
var is_processing_trigger: bool = false
var trigger_id: String = ""
var is_fixed_trigger: bool = false

func _ready():
	trigger_id = str(get_instance_id())
	add_to_group("battle_trigger")
	if not is_in_group("random_battle_trigger"):
		is_fixed_trigger = true
		add_to_group("fixed_battle_trigger")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if has_triggered or is_processing_trigger:
		return
	if not body.is_in_group("player"):
		return
	if BattleManager and BattleManager.is_in_battle:
		return
	has_triggered = true
	is_processing_trigger = true
	set_deferred("monitoring", false)
	call_deferred("_deferred_trigger_battle")

func _deferred_trigger_battle():
	if not has_triggered or not is_processing_trigger:
		_cleanup_trigger()
		return
	if BattleManager and BattleManager.is_in_battle:
		_cleanup_trigger()
		return
	if BattleManager and BattleManager.has_method("start_forced_encounter"):
		BattleManager.start_forced_encounter(enemy_scene, {})
	else:
		_cleanup_trigger()

func _cleanup_trigger():
	has_triggered = false
	is_processing_trigger = false
	if is_instance_valid(self):
		queue_free()

func _exit_tree():
	is_processing_trigger = false
