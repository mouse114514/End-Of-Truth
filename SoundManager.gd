extends Node

var sound_paths = {}
var loaded_streams = {}

const SFX_DIR = "res://music/sfx/"
const PACK1_DIR = SFX_DIR + "pack1/"
const PACK2_DIR = SFX_DIR + "pack2/"

func _ready():
	sound_paths = {
		"button": PACK1_DIR + "button.wav",
		"select": PACK1_DIR + "select.wav",
		"confirm": PACK1_DIR + "confirm.wav",
		"save": PACK1_DIR + "save.wav",
		"damage": PACK1_DIR + "damage.wav",
		"damage_c": PACK1_DIR + "damage_c.wav",
		"hurt": PACK2_DIR + "hurt.wav",
		"hurt_alt": PACK2_DIR + "hurt_alt.wav",
		"enemy_death": PACK1_DIR + "enemy_death.wav",
		"hit": PACK1_DIR + "hit.wav",
		"slash": PACK2_DIR + "slash.wav",
		"slash_alt": PACK2_DIR + "slash_alt.wav",
		"powerful_hit": PACK1_DIR + "powerful_hit.wav",
		"book_attack": PACK1_DIR + "book_attack.wav",
		"battle_start": PACK2_DIR + "battle_start.wav",
		"warning": PACK2_DIR + "warning.wav",
		"alert": PACK2_DIR + "alert.wav",
		"level_up": PACK2_DIR + "level_up.wav",
		"heal": PACK2_DIR + "heal.wav",
		"soul_shatter": PACK2_DIR + "soul_shatter.wav",
		"soul_shatter_alt": PACK2_DIR + "soul_shatter_alt.wav",
		"break": PACK2_DIR + "break.wav",
		"break_alt": PACK2_DIR + "break_alt.wav",
		"toriel_talk": PACK1_DIR + "toriel_talk.wav",
		"toriel_angry": PACK1_DIR + "toriel_angry.wav",
		"flowey_talk": PACK2_DIR + "flowey_talk.wav",
		"flowey_angry": PACK2_DIR + "flowey_angry.wav",
		"sans_talk": PACK1_DIR + "sans_talk.wav",
		"npc_talk": PACK1_DIR + "npc_talk.wav",
		"silent_talk": PACK1_DIR + "silent_talk.wav",
		"gaster_charge": PACK1_DIR + "gaster_charge.wav",
		"gaster_charge_2": PACK1_DIR + "gaster_charge_2.wav",
		"gaster_charge_loop": PACK1_DIR + "gaster_charge_loop.ogg",
		"gaster_fire": PACK1_DIR + "gaster_fire.wav",
		"gaster_blaster": PACK1_DIR + "gaster_blaster.wav",
		"flash": PACK1_DIR + "flash.wav",
		"elevator": PACK1_DIR + "elevator.wav",
		"bell": PACK2_DIR + "bell.wav",
		"bell_alt": PACK2_DIR + "bell_alt.wav",
		"phone": PACK2_DIR + "phone.wav",
		"mouse": PACK1_DIR + "mouse.wav",
		"stand_up": PACK1_DIR + "stand_up.wav",
		"flee": PACK1_DIR + "flee.wav",
		"logo": PACK1_DIR + "logo.ogg",
		"title_start": PACK1_DIR + "title_start.ogg",
		"settings": PACK1_DIR + "settings.ogg",
		"blackout": PACK2_DIR + "blackout.wav"
	}

func _get_stream(sound_name: String) -> AudioStream:
	if not sound_paths.has(sound_name):
		push_warning("SoundManager: sound '%s' not found" % sound_name)
		return null
	if loaded_streams.has(sound_name):
		return loaded_streams[sound_name]
	var stream = load(sound_paths[sound_name])
	if stream:
		loaded_streams[sound_name] = stream
	return stream

func play(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	var stream = _get_stream(sound_name)
	if not stream:
		return
	var scene = get_tree().current_scene
	if not scene or not is_instance_valid(scene):
		return
	var audio = AudioStreamPlayer.new()
	audio.volume_db = volume_db
	audio.pitch_scale = pitch_scale
	audio.stream = stream
	scene.add_child(audio)
	audio.play()
	await get_tree().create_timer(stream.get_length() + 0.1).timeout
	if is_instance_valid(audio):
		audio.queue_free()

func play_ui(sound_name: String = "confirm"):
	play(sound_name, -10.0)

func play_damage():
	play("damage", -5.0)
func play_enemy_death():
	play("enemy_death", -5.0)
func play_battle_start():
	play("battle_start", -5.0)
func play_hurt():
	play("hurt", -8.0)
func play_level_up():
	play("level_up", -5.0)
func play_heal():
	play("heal", -5.0)

func play_talk(npc_type: String = "npc_talk", fixed_pitch: float = -1.0):
	var pitch = fixed_pitch if fixed_pitch > 0 else (1.0 + randf() * 0.2)
	play(npc_type, -15.0, pitch)

func play_gaster_charge():
	play("gaster_charge", -5.0)
func play_gaster_fire():
	play("gaster_fire", -5.0)

func play_title_start() -> float:
	var stream = _get_stream("title_start")
	if stream:
		play("title_start", -5.0)
		return stream.get_length()
	return 5.12

var _bgm_player: AudioStreamPlayer

func play_bgm(path: String, volume_db: float = -8.0):
	if not _bgm_player:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.name = "BGMPlayer"
		add_child(_bgm_player)
	_bgm_player.stop()
	var s = load(path)
	if s == null:
		return
	_bgm_player.stream = s
	_bgm_player.volume_db = volume_db
	_bgm_player.finished.connect(_loop_bgm.bind(_bgm_player), CONNECT_ONE_SHOT)
	_bgm_player.play()

func _loop_bgm(player: AudioStreamPlayer):
	if is_instance_valid(player) and player.stream:
		player.play()
		player.finished.connect(_loop_bgm.bind(player), CONNECT_ONE_SHOT)

func stop_bgm():
	if _bgm_player and is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.stream = null
