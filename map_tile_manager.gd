@tool
extends Node2D

const COLS := 6
const ROWS := 6
const TILE_W := 1773
const TILE_H := 640
const LAST_COL_W := 1777
const LAST_ROW_H := 644
const IMG_W := 10642
const IMG_H := 3844
const SCALE := 3
const ORIGIN := Vector2(15860.5, -3799)
const LOAD_MARGIN := 1
const UNLOAD_MARGIN := 3

var tile_sprites: Array[Sprite2D] = []
var tile_paths: Array[String] = []
var tile_loaded: Array[bool] = []
var tile_centers: Array[Vector2] = []
var tile_half_sizes: Array[Vector2] = []

func _ready():
	if Engine.is_editor_hint():
		var preview = Sprite2D.new()
		preview.texture = load("res://map/map0_look.png")
		preview.position = Vector2(15538, -3844)
		preview.scale = Vector2(3, 3)
		preview.z_index = -2
		preview.name = "EditorPreview"
		add_child(preview)
		return
	var img_center = Vector2(IMG_W / 2.0, IMG_H / 2.0)
	for r in ROWS:
		for c in COLS:
			var tw = LAST_COL_W if c == COLS - 1 else TILE_W
			var th = LAST_ROW_H if r == ROWS - 1 else TILE_H
			var path = "res://map/tiles/map0_look_tile_%d_%d.png" % [r, c]
			tile_paths.append(path)
			tile_loaded.append(false)
			var sprite = Sprite2D.new()
			sprite.scale = Vector2(SCALE, SCALE)
			sprite.centered = true
			sprite.name = "Tile_%d_%d" % [r, c]
			var local_center = Vector2(c * TILE_W + tw / 2.0, r * TILE_H + th / 2.0)
			var offset = (local_center - img_center) * SCALE
			var world_pos = ORIGIN + offset
			sprite.position = world_pos
			tile_centers.append(world_pos)
			tile_half_sizes.append(Vector2(tw * SCALE, th * SCALE) / 2.0)
			add_child(sprite)
			tile_sprites.append(sprite)
	await get_tree().process_frame
	var cam = get_viewport().get_camera_2d()
	if cam:
		_update_visibility(cam.global_position)

func _process(_delta):
	if Engine.is_editor_hint():
		return
	var cam = get_viewport().get_camera_2d()
	if cam:
		_update_visibility(cam.global_position)

func _update_visibility(cam_pos: Vector2):
	var screen = get_viewport().size
	var visible_half = screen * 0.5
	var load_margin = Vector2(TILE_W * SCALE, TILE_H * SCALE) * LOAD_MARGIN
	var unload_margin = Vector2(TILE_W * SCALE, TILE_H * SCALE) * UNLOAD_MARGIN
	for i in ROWS * COLS:
		var pos = tile_centers[i]
		var half = tile_half_sizes[i]
		var in_near = (
			pos.x + half.x > cam_pos.x - visible_half.x - load_margin.x and
			pos.x - half.x < cam_pos.x + visible_half.x + load_margin.x and
			pos.y + half.y > cam_pos.y - visible_half.y - load_margin.y and
			pos.y - half.y < cam_pos.y + visible_half.y + load_margin.y
		)
		var in_far = (
			pos.x + half.x > cam_pos.x - visible_half.x - unload_margin.x and
			pos.x - half.x < cam_pos.x + visible_half.x + unload_margin.x and
			pos.y + half.y > cam_pos.y - visible_half.y - unload_margin.y and
			pos.y - half.y < cam_pos.y + visible_half.y + unload_margin.y
		)
		if in_near:
			if not tile_loaded[i]:
				tile_sprites[i].texture = load(tile_paths[i])
				tile_loaded[i] = true
			tile_sprites[i].visible = true
		else:
			tile_sprites[i].visible = false
			if not in_far and tile_loaded[i]:
				tile_sprites[i].texture = null
				tile_loaded[i] = false
