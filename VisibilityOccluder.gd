extends Area2D

var parent_node: Node

func _ready():
	parent_node = get_parent()
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	var player = body
	if body is CollisionShape2D or body is CollisionPolygon2D:
		player = body.get_parent()
	while player and not player.is_in_group("player"):
		player = player.get_parent()
	
	if player and player.is_in_group("player") and parent_node:
		parent_node.visible = false

func _on_body_exited(body: Node2D):
	var player = body
	if body is CollisionShape2D or body is CollisionPolygon2D:
		player = body.get_parent()
	while player and not player.is_in_group("player"):
		player = player.get_parent()
	
	if player and player.is_in_group("player") and parent_node:
		parent_node.visible = true
