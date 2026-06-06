extends RefCounted
class_name EnemyDefs

static var _loaded := false
static var types: Dictionary = {}
static var catalog: Dictionary = {}

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file = FileAccess.open("res://enemy_catalog.json", FileAccess.READ)
	if file == null:
		push_error("EnemyDefs: failed to load enemy_catalog.json")
		return
	var json = JSON.parse_string(file.get_as_text())
	if json == null:
		push_error("EnemyDefs: invalid JSON")
		return
	types.clear()
	for k in json.get("types", {}):
		types[int(k)] = json["types"][k]
	catalog = json.get("catalog", {})

static func lookup(enemy_id: String) -> Dictionary:
	_load()
	var entry = catalog.get(enemy_id)
	if entry == null:
		push_warning("EnemyDefs: unknown enemy_id '", enemy_id, "'")
		return { "type": types.keys().front() if types.size() > 0 else 0 }
	return entry

static func data_of(type_id: int) -> Dictionary:
	_load()
	return types.get(type_id, {})

static func battle_name_of(enemy_id: String) -> String:
	_load()
	var entry = catalog.get(enemy_id)
	if entry == null:
		return enemy_id
	return entry.get("battle_name", enemy_id)

static func is_dodge(enemy_id: String) -> bool:
	_load()
	var entry = catalog.get(enemy_id)
	return entry.get("is_dodge", false) if entry else false

static func battle_bgm_of(type_id: int) -> String:
	_load()
	var tdata = types.get(type_id)
	return tdata.get("battle_BGM", "") if tdata else ""

static func sprite_texture_of(enemy_id: String) -> String:
	_load()
	var entry = catalog.get(enemy_id)
	return entry.get("sprite_texture", "") if entry else ""

static func sprite_scale_of(enemy_id: String) -> float:
	_load()
	var entry = catalog.get(enemy_id)
	return entry.get("sprite_scale", 0.07) if entry else 0.07
