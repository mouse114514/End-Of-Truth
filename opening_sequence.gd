extends Node2D

const MAIN_FONT = preload("res://font/main.ttf")
const SOUL_TEX = preload("res://player/batt/soul.png")

enum Phase {
	ASCENT,
	SHATTER,
	FADE_IN,
	WALK,
	MV_SHOW,
	BRIGHTEN,
	REVEAL,
	FINALE,
	EXIT,
	VOID_CREDITS
}

var phase: Phase = Phase.ASCENT
var viewport_size: Vector2

# 公共
var camera: Camera2D
var fade_overlay: ColorRect
var white_cover: ColorRect

# ==================== 上浮阶段 ====================
var main_text: Label
var float_texts: Array[Label] = []
var triangle_sprite: Sprite2D
var ascent_text_y: float = 0.0
const ASCENT_SPEED: float = 150.0
var camera_ascent_y: float = 0.0
var ascend_started: bool = false
var _float_text_spawn_time: float = 0.0

# ==================== 行走阶段 ====================
var soul: Area2D
var soul_sprite: Sprite2D
var ground: ColorRect
var bg_rect: ColorRect
var world_x: float = 0.0
const WALK_SPEED: float = 120.0
var walk_started: bool = false
var controlled_mode: bool = false

# MV照片
var mv_texture_count: int = 0
var mv_photo_index: int = 0
var mv_trigger_x: Array[float] = []
var mv_display_sprite: Sprite2D
var mv_display_bg: ColorRect
var mv_caption_label: Label
var mv_captions: Array[String] = []
var mv_active: bool = false
var mv_pending_idx: int = -1
var mv_awake: bool = false

# 渐亮
var brighten_progress: float = 0.0
var brightening: bool = false

# 最终揭示
const FINAL_CONTINUE_X: float = 5500.0
var final_continue_label: Label
var final_continue_hitbox: Area2D
var soul_touching_text: bool = false

# 死区相关
var dead_zone_margin: float = 0.3

# 虚空 → 开发人员名单
const CREDITS_X_THRESHOLD: float = -150.0
const CREDITS_HOLD_TIME: float = 2.5
var void_enter_time: float = -1.0
var credits_active: bool = false
var credits_label: Label
var credits_bg: ColorRect

# UI叠层（用于MV等需要屏幕空间固定的元素）
var ui_layer: CanvasLayer

# 尘埃粒子
var dust_particles: Array[Sprite2D] = []
var mist_particles: Array[Sprite2D] = []

var _hit_triangle_triggered: bool = false
var mobile_dir: float = 0.0


func _ready():
	viewport_size = get_viewport().get_visible_rect().size
	_setup_overlays()
	_setup_camera()
	_setup_ascent()
	_mv_handler_loop()
	_start_mv_threaded_load()
	add_to_group("player")
	var mobile = get_node_or_null("/root/MobileInput")
	if mobile:
		if mobile.has_signal("direction_input"):
			mobile.direction_input.connect(_on_mobile_direction)
		if mobile.has_signal("investigate_pressed"):
			mobile.investigate_pressed.connect(_on_mobile_investigate)

func handle_mobile_input(input_vec: Vector2):
	mobile_dir = input_vec.x

func _on_mobile_direction(dir: Vector2):
	mobile_dir = dir.x

var _mobile_investigate: bool = false

func _on_mobile_investigate():
	_mobile_investigate = true

func _start_mv_threaded_load():
	mv_texture_count = 0
	var i = 1
	while true:
		var p = "res://MV/start/IMG_%02d.jpg" % i
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)
			mv_texture_count += 1
			i += 1
		else:
			break

func _get_mv_texture(idx: int) -> Texture2D:
	var p = "res://MV/start/IMG_%02d.jpg" % (idx + 1)
	var status = ResourceLoader.load_threaded_get_status(p)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(p)

func _setup_overlays():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.modulate.a = 0.0
	ui_layer.add_child(fade_overlay)

func _setup_camera():
	camera = Camera2D.new()
	camera.name = "OpeningCamera"
	camera.enabled = true
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.position = viewport_size / 2
	add_child(camera)



# ==================== 第1阶段：上浮 ====================

func _setup_ascent():
	phase = Phase.ASCENT
	ascend_started = true

	main_text = Label.new()
	main_text.text = "继续游戏"
	if MAIN_FONT:
		main_text.add_theme_font_override("font", MAIN_FONT)
	main_text.add_theme_font_size_override("font_size", 24)
	main_text.add_theme_color_override("font_color", Color(1, 1, 0))
	main_text.add_theme_constant_override("outline_size", 2)
	main_text.add_theme_color_override("font_outline_color", Color(0.6, 0.5, 0))
	main_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_text.size = Vector2(260, 50)
	main_text.pivot_offset = Vector2(130, 25)
	main_text.z_index = 50
	ascent_text_y = viewport_size.y * 0.45
	main_text.position = Vector2(viewport_size.x / 2 - 130, ascent_text_y)
	add_child(main_text)

	_float_text_spawn_time = Time.get_ticks_msec() * 0.001

	# 灰色副本
	for i in range(250):
		var t = Label.new()
		t.text = "继续游戏"
		if MAIN_FONT:
			t.add_theme_font_override("font", MAIN_FONT)
		var sz = 6 + randi() % 36
		t.add_theme_font_size_override("font_size", sz)
		var a = 0.3 + randf() * 0.4
		var shade = 0.3 + randf() * 0.3
		t.add_theme_color_override("font_color", Color(shade, shade, shade, a))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.size = Vector2(200, 30 + sz)
		t.position = Vector2(
			randf_range(-viewport_size.x * 0.8, viewport_size.x * 1.8),
			randf_range(-viewport_size.y * 4.0, viewport_size.y * 2.5)
		)
		t.modulate.a = 0.0
		t.set_meta("float_speed", 8.0 + randf() * 25.0)
		t.set_meta("float_phase", randf() * TAU)
		t.set_meta("fade_delay", randf() * 2.5)
		t.set_meta("fade_duration", 0.8 + randf() * 1.5)
		add_child(t)
		float_texts.append(t)

	# 三角形（用Polygon2D绘制）
	triangle_sprite = Sprite2D.new()
	triangle_sprite.texture = _make_triangle_tex()
	triangle_sprite.position = Vector2(viewport_size.x / 2, -viewport_size.y * 0.7)
	triangle_sprite.scale = Vector2(3.5, 3.5)
	triangle_sprite.modulate = Color(0.45, 0.45, 0.45)
	add_child(triangle_sprite)

func _make_triangle_tex() -> Texture2D:
	var w = 64
	var h = 56
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx = w * 0.5
	for y in range(h):
		var half_w = y / sqrt(3.0)
		var l = cx - half_w
		var r = cx + half_w
		var x_start = max(0, int(l))
		var x_end = min(w, int(r) + 1)
		for x in range(x_start, x_end):
			if x == x_start or x == x_end - 1 or y == h - 1 or y == 0:
				img.set_pixel(x, y, Color.WHITE)
			else:
				img.set_pixel(x, y, Color.BLACK)
	return ImageTexture.create_from_image(img)


# ==================== 第2阶段：破碎 ====================

func _hit_triangle():
	phase = Phase.SHATTER

	SoundManager.play("enemy_death", -5.0)
	_shatter_triangle()
	if is_instance_valid(triangle_sprite):
		triangle_sprite.visible = false

	# 文字撞碎：放大+淡出（0.2秒）
	var fall_tween = create_tween()
	fall_tween.set_parallel(true)
	fall_tween.tween_property(main_text, "scale", Vector2(3, 3), 0.2).set_ease(Tween.EASE_OUT)
	fall_tween.tween_property(main_text, "modulate:a", 0.0, 0.2)
	for ft in float_texts:
		if is_instance_valid(ft):
			fall_tween.tween_property(ft, "scale", Vector2(2.5, 2.5), 0.2).set_ease(Tween.EASE_OUT)
			fall_tween.tween_property(ft, "modulate:a", 0.0, 0.2)
	await fall_tween.finished

	main_text.visible = false
	for t in float_texts:
		t.visible = false

	var tw = create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.6)
	await tw.finished

	for p in get_children():
		if p is Polygon2D and p.get_index() >= 0:
			p.queue_free()


	if not GameSettings.full_opening:
		SoundManager.stop_bgm()
		var white_overlay = ColorRect.new()
		white_overlay.color = Color.WHITE
		white_overlay.modulate.a = 0.0
		white_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui_layer.add_child(white_overlay)

		var orig_cam = camera.position
		var elapsed = 0.0
		while elapsed < 0.7:
			var progress = elapsed / 0.7
			white_overlay.modulate.a = progress
			var shake = progress * 10.0
			if is_instance_valid(camera):
				camera.position = orig_cam + Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		get_tree().change_scene_to_file("res://node_2d.tscn")
		return

	SoundManager.play_bgm("res://music/muc/opening_ambient.wav")
	_setup_walk_phase()
	var tw2 = create_tween()
	tw2.tween_property(fade_overlay, "modulate:a", 0.0, 0.8)
	await tw2.finished
	phase = Phase.WALK

func _shatter_triangle():
	for i in range(16):
		var p = Polygon2D.new()
		var s = 6.0 + randi() % 14
		p.polygon = PackedVector2Array([
			Vector2(randf_range(-s, s), randf_range(-s, 0)),
			Vector2(randf_range(-s, 0), randf_range(0, s)),
			Vector2(randf_range(0, s), randf_range(0, s))
		])
		p.color = Color(0.5, 0.5, 0.5)
		p.position = triangle_sprite.position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		p.z_index = 10
		add_child(p)
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-250, 250), randf_range(-350, 80)), 0.7)
		tw.tween_property(p, "rotation", randf_range(-PI, PI), 0.7)
		tw.tween_property(p, "modulate:a", 0.0, 0.7)


# ==================== 第3阶段：行走 ====================

func _setup_walk_phase():
	phase = Phase.FADE_IN
	world_x = 0.0

	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.12, 0.12, 0.12)
	bg_rect.position = Vector2(-200, -viewport_size.y)
	bg_rect.size = Vector2(9000, viewport_size.y * 4)
	add_child(bg_rect)

	var top_shade = ColorRect.new()
	top_shade.color = Color(0.06, 0.06, 0.08)
	top_shade.position = Vector2(-200, -viewport_size.y)
	top_shade.size = Vector2(9000, viewport_size.y * 2)
	top_shade.z_index = -1
	add_child(top_shade)

	var gy = viewport_size.y * 0.72
	ground = ColorRect.new()
	ground.color = Color(0.18, 0.18, 0.18)
	ground.position = Vector2(-200, gy)
	ground.size = Vector2(9000, viewport_size.y * 3)
	add_child(ground)

	# 地面装饰 — 提供运动参照
	for i in range(80):
		var dot = ColorRect.new()
		dot.color = Color(0.22 + randf() * 0.06, 0.22 + randf() * 0.06, 0.22 + randf() * 0.06)
		dot.size = Vector2(1 + randi() % 5, 1 + randi() % 2)
		dot.position = Vector2(
			randf_range(-200, 9000),
			gy + 3 + randf() * 50
		)
		dot.z_index = -1
		add_child(dot)

	soul = Area2D.new()
	soul_sprite = Sprite2D.new()
	if SOUL_TEX:
		soul_sprite.texture = SOUL_TEX
	soul_sprite.scale = Vector2(2, 2)
	soul_sprite.modulate = Color.WHITE
	soul.add_child(soul_sprite)
	var sc = CollisionShape2D.new()
	var sh = RectangleShape2D.new()
	sh.size = Vector2(20, 20)
	sc.shape = sh
	sc.disabled = true
	soul.add_child(sc)
	soul.position = Vector2(viewport_size.x * 0.25, gy - 18)
	soul.z_index = 10
	add_child(soul)
	camera.position = Vector2(soul.position.x, viewport_size.y / 2)

	# MV照片显示UI（放在CanvasLayer中，屏幕空间固定）
	mv_display_bg = ColorRect.new()
	mv_display_bg.color = Color.BLACK
	mv_display_bg.position = Vector2(viewport_size.x * 0.1, viewport_size.y * 0.08)
	mv_display_bg.size = Vector2(viewport_size.x * 0.8, viewport_size.y * 0.55)
	mv_display_bg.visible = false
	ui_layer.add_child(mv_display_bg)

	mv_display_sprite = Sprite2D.new()
	mv_display_sprite.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.35)
	mv_display_sprite.visible = false
	ui_layer.add_child(mv_display_sprite)

	mv_caption_label = Label.new()
	mv_caption_label.text = ""
	mv_caption_label.position = Vector2(viewport_size.x * 0.1, viewport_size.y * 0.63)
	mv_caption_label.size = Vector2(viewport_size.x * 0.8, 80)
	mv_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	mv_caption_label.visible = false
	mv_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if MAIN_FONT:
		mv_caption_label.add_theme_font_override("font", MAIN_FONT)
	mv_caption_label.add_theme_font_size_override("font_size", 18)
	mv_caption_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ui_layer.add_child(mv_caption_label)

	# 白色叠层（渐亮用）
	white_cover = ColorRect.new()
	white_cover.color = Color.WHITE
	white_cover.modulate.a = 0.0
	white_cover.position = Vector2(-200, -viewport_size.y)
	white_cover.size = Vector2(9000, viewport_size.y * 4)
	white_cover.z_index = 5
	add_child(white_cover)

	# 设定MV触发点（相对于灵魂初始位置）
	var soul_start_x = viewport_size.x * 0.25
	var spacing = 350.0
	for i in range(mv_texture_count):
		mv_trigger_x.append(soul_start_x + spacing * (i + 1))

	_setup_final_continue()
	_setup_dust()
	_setup_mist()

	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0

func _setup_dust():
	const DUST_COUNT = 150
	for i in range(DUST_COUNT):
		var s = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		var a = 0.1 + randf() * 0.45
		for x in range(6):
			for y in range(6):
				if randf() > 0.6:
					img.set_pixel(x, y, Color(1, 1, 1, a * randf()))
		s.texture = ImageTexture.create_from_image(img)
		s.scale = Vector2.ONE * (0.2 + randf() * 2.5)
		s.position = Vector2(
			randf_range(-200, 8800),
			randf_range(-viewport_size.y * 0.5, viewport_size.y * 1.5)
		)
		s.set_meta("drift", randf_range(-10, 10))
		s.set_meta("speed", 2.0 + randf() * 18.0)
		s.set_meta("phase", randf() * TAU)
		s.z_index = 1
		add_child(s)
		dust_particles.append(s)

func _setup_mist():
	for i in range(30):
		var sz = 20 + randi() % 45
		var s = Sprite2D.new()
		var img = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		var base_a = 0.1 + randf() * 0.2
		var cx = sz * 0.5
		var cy = sz * 0.5
		var r = sz * 0.5
		for x in range(sz):
			for y in range(sz):
				var d = Vector2(x, y).distance_to(Vector2(cx, cy))
				if d < r:
					var a = sin((1.0 - d / r) * PI * 0.5) * base_a
					if a > 0:
						img.set_pixel(x, y, Color(1, 1, 1, a))
		s.texture = ImageTexture.create_from_image(img)
		s.position = Vector2(
			randf_range(-200, 8800),
			randf_range(0, viewport_size.y * 0.55)
		)
		s.set_meta("drift", randf_range(-4, 4))
		s.set_meta("speed", 0.3 + randf() * 1.5)
		s.set_meta("phase", randf() * TAU)
		s.z_index = 0
		add_child(s)
		mist_particles.append(s)

func _setup_final_continue():
	final_continue_label = Label.new()
	final_continue_label.text = "继续游戏"
	if MAIN_FONT:
		final_continue_label.add_theme_font_override("font", MAIN_FONT)
	final_continue_label.add_theme_font_size_override("font_size", 48)
	final_continue_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	final_continue_label.add_theme_constant_override("outline_size", 2)
	final_continue_label.add_theme_color_override("font_outline_color", Color(0.25, 0.25, 0.25))
	final_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	final_continue_label.size = Vector2(260, 70)
	final_continue_label.position = Vector2(FINAL_CONTINUE_X, viewport_size.y * 0.72 - 35)
	final_continue_label.z_index = 15
	final_continue_label.visible = false
	add_child(final_continue_label)

	final_continue_hitbox = Area2D.new()
	final_continue_hitbox.position = final_continue_label.position + Vector2(130, 35)
	var ac = CollisionShape2D.new()
	var ash = RectangleShape2D.new()
	ash.size = Vector2(280, 80)
	ac.shape = ash
	final_continue_hitbox.add_child(ac)
	add_child(final_continue_hitbox)


# ==================== MV照片处理器协程 ====================

func _mv_handler_loop():
	while true:
		await get_tree().process_frame
		if not is_instance_valid(self) or not is_inside_tree():
			return
		if mv_pending_idx >= 0 and not mv_active:
			var idx = mv_pending_idx
			mv_pending_idx = -1
			mv_awake = true
			await _show_mv_photo(idx)
			mv_awake = false


# ==================== MV照片展示 ====================

func _show_mv_photo(idx: int) -> bool:
	mv_captions = ["* 显然我是愤怒的，因为我没有找到第一张图片。", "* 依旧报错和3个警告好吧", "OS:不不不不不不不，我无疑是惊讶的。", "* 我去突然感觉我好帅呀\n* 毫无疑问，我是兴奋的", "点击此处输入文本。", "显而易见，我的作业还没写完，我无疑是劳累的"]
	if idx >= mv_texture_count or mv_active:
		return false
	mv_active = true

	var tex = _get_mv_texture(idx)
	if tex == null:
		mv_active = false
		return false
	mv_display_sprite.texture = tex
	var ts = tex.get_size()
	var mw = viewport_size.x * 0.75
	var mh = viewport_size.y * 0.5
	var sc = min(mw / ts.x, mh / ts.y)
	mv_display_sprite.scale = Vector2(sc, sc)
	mv_display_sprite.modulate.a = 0.0
	mv_display_sprite.visible = true
	mv_display_bg.modulate.a = 0.0
	mv_display_bg.visible = true

	var tw1 = create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(mv_display_sprite, "modulate:a", 1.0, 0.4)
	tw1.tween_property(mv_display_bg, "modulate:a", 1.0, 0.4)
	await tw1.finished

	# 打字机字幕
	if idx < mv_captions.size() and not mv_captions[idx].is_empty():
		mv_caption_label.visible = true
		mv_caption_label.text = ""
		var caption = mv_captions[idx]
		for i in range(caption.length()):
			mv_caption_label.text += caption[i]
			SoundManager.play("silent_talk", -15.0, 1.5 + randf() * 0.5)
			await get_tree().create_timer(0.04).timeout

	await get_tree().create_timer(1.5).timeout

	# 淡出
	var tw2 = create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(mv_display_sprite, "modulate:a", 0.0, 0.4)
	tw2.tween_property(mv_display_bg, "modulate:a", 0.0, 0.4)
	tw2.tween_property(mv_caption_label, "modulate:a", 0.0, 0.3)
	await tw2.finished

	mv_display_sprite.visible = false
	mv_display_bg.visible = false
	mv_caption_label.visible = false
	mv_caption_label.modulate.a = 1.0
	mv_display_sprite.modulate.a = 1.0
	mv_display_bg.modulate.a = 1.0

	mv_active = false
	return true


# ==================== _process ====================

func _process(delta):
	match phase:
		Phase.ASCENT:
			_tick_ascent(delta)
		Phase.WALK:
			_tick_walk(delta)
		Phase.BRIGHTEN:
			_tick_brighten(delta)
		Phase.FINALE:
			_tick_finale(delta)
		Phase.VOID_CREDITS:
			_tick_void_credits(delta)

func _tick_ascent(delta):
	ascent_text_y -= ASCENT_SPEED * delta
	main_text.position.y = ascent_text_y

	# 颜色从黄渐变到灰
	var ascent_start_y = viewport_size.y * 0.45
	var ascent_end_y = triangle_sprite.position.y + 40.0
	var ascent_total = ascent_start_y - ascent_end_y
	var ascent_done = ascent_start_y - ascent_text_y
	var progress = clamp(ascent_done / ascent_total, 0.0, 1.0)
	var text_color = Color(1, 1, 0).lerp(Color(0.5, 0.5, 0.5), progress)
	main_text.add_theme_color_override("font_color", text_color)
	var outline_color = Color(0.6, 0.5, 0).lerp(Color(0.25, 0.25, 0.25), progress)
	main_text.add_theme_color_override("font_outline_color", outline_color)

	# 摄像机死区：文字进入屏幕上半部分35%后，摄像机开始跟随
	var rel_y = ascent_text_y - camera.position.y + viewport_size.y / 2
	if rel_y < viewport_size.y * dead_zone_margin:
		var ideal_cam_y = ascent_text_y + viewport_size.y / 2 - viewport_size.y * dead_zone_margin
		camera.position.y = lerp(camera.position.y, ideal_cam_y, 4.0 * delta)

	# 装饰文字
	var now = Time.get_ticks_msec() * 0.001
	var elapsed = now - _float_text_spawn_time
	for ft in float_texts:
		if not is_instance_valid(ft):
			continue
		var spd = ft.get_meta("float_speed")
		var ph = ft.get_meta("float_phase")
		ft.position.y -= spd * delta
		ft.position.x += sin(now * 2.0 + ph) * 0.5
		var fd = ft.get_meta("fade_delay")
		var dur = ft.get_meta("fade_duration")
		var fade_progress = clamp((elapsed - fd) / dur, 0.0, 1.0)
		ft.modulate.a = fade_progress

	# 碰三角形？
	if not _hit_triangle_triggered and ascent_text_y <= triangle_sprite.position.y + 40:
		_hit_triangle_triggered = true
		_hit_triangle()

func _tick_dust(delta: float):
	var t = Time.get_ticks_msec() * 0.001
	for s in dust_particles:
		if not is_instance_valid(s):
			continue
		var dr = s.get_meta("drift")
		var sp = s.get_meta("speed")
		var ph = s.get_meta("phase")
		s.position.y -= sp * delta
		s.position.x += sin(t * 1.5 + s.position.y * 0.008 + ph) * dr * delta
		s.rotation += delta * sp * 0.05
		if s.position.y < -viewport_size.y * 0.5:
			s.position.y = viewport_size.y * 1.5
			s.position.x = randf_range(-200, 8800)
			s.set_meta("drift", randf_range(-8, 8))
			s.set_meta("speed", 3.0 + randf() * 15.0)
			s.set_meta("phase", randf() * TAU)

func _tick_mist(delta: float):
	var t = Time.get_ticks_msec() * 0.001
	for s in mist_particles:
		if not is_instance_valid(s):
			continue
		var dr = s.get_meta("drift")
		var sp = s.get_meta("speed")
		var ph = s.get_meta("phase")
		s.position.x += sin(t * 0.5 + ph) * dr * delta
		s.position.y += sin(t * 0.3 + ph * 0.7) * 0.3 * delta
		if s.position.x > 9000:
			s.position.x = -200
			s.position.y = randf_range(0, viewport_size.y * 0.6)
			s.set_meta("drift", randf_range(-3, 3))
			s.set_meta("phase", randf() * TAU)

func _tick_walk(delta):
	_tick_dust(delta)
	_tick_mist(delta)
	var dir = 0.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir -= 1.0
	if dir == 0.0:
		dir = mobile_dir
	if dir != 0.0:
		soul.position.x += dir * WALK_SPEED * delta
	soul.position.y += sin(Time.get_ticks_msec() * 0.003) * 0.4

	# 记录到达的最远x（用于MV触发判定）
	if soul.position.x > world_x:
		world_x = soul.position.x

	# 摄像机跟随（平滑+死区偏移）
	var ideal_cam_x = soul.position.x - viewport_size.x * 0.1
	camera.position.x = lerp(camera.position.x, ideal_cam_x, 3.0 * delta)

	# 保持摄像机Y
	camera.position.y = lerp(camera.position.y, viewport_size.y * 0.42, 2.0 * delta)

	# MV照片触发（通过标志位，避免在_process中await）
	if mv_pending_idx < 0 and not mv_active and mv_photo_index < mv_trigger_x.size() and world_x >= mv_trigger_x[mv_photo_index]:
		mv_pending_idx = mv_photo_index
		mv_photo_index += 1

	# 等待MV播放时，不检查后续状态变化
	if mv_awake:
		return

	# 虚空检测：往左走超出边界 -> 开发人员名单
	if soul.position.x < CREDITS_X_THRESHOLD and not credits_active and phase != Phase.VOID_CREDITS:
		if void_enter_time < 0.0:
			void_enter_time = Time.get_ticks_msec() * 0.001
		elif (Time.get_ticks_msec() * 0.001) - void_enter_time >= CREDITS_HOLD_TIME:
			void_enter_time = -1.0
			_show_credits()
	elif void_enter_time > 0.0 and soul.position.x >= CREDITS_X_THRESHOLD:
		void_enter_time = -1.0

	# 检查是否所有照片显示完 -> 渐亮
	if mv_photo_index >= mv_texture_count and not brightening and mv_texture_count > 0:
		brightening = true
		phase = Phase.BRIGHTEN
		brighten_progress = 0.0
	elif mv_texture_count == 0 and world_x > 500:
		brightening = true
		phase = Phase.BRIGHTEN
		brighten_progress = 0.0

	# 到终点？
	if world_x >= FINAL_CONTINUE_X - viewport_size.x * 0.3:
		_begin_reveal()

func _tick_brighten(delta):
	_tick_dust(delta)
	_tick_mist(delta)
	var dir = 0.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir -= 1.0
	if dir == 0.0:
		dir = mobile_dir
	if dir != 0.0:
		soul.position.x += dir * WALK_SPEED * 0.65 * delta
	soul.position.y += sin(Time.get_ticks_msec() * 0.003) * 0.3

	if soul.position.x > world_x:
		world_x = soul.position.x

	brighten_progress += delta * 0.2
	if brighten_progress > 1.0:
		brighten_progress = 1.0

	white_cover.modulate.a = brighten_progress

	var ideal_cam_x = soul.position.x - viewport_size.x * 0.1
	camera.position.x = lerp(camera.position.x, ideal_cam_x, 3.0 * delta)

	if brighten_progress >= 1.0:
		_begin_reveal()

func _begin_reveal():
	if phase == Phase.REVEAL or phase == Phase.FINALE or phase == Phase.EXIT:
		return
	phase = Phase.REVEAL

	white_cover.modulate.a = 1.0

	await get_tree().create_timer(0.4).timeout

	# 把"继续游戏"移到灵魂前方
	var text_x = soul.position.x + viewport_size.x * 0.25
	final_continue_label.position = Vector2(text_x, viewport_size.y * 0.72 - 35)
	final_continue_hitbox.position = final_continue_label.position + Vector2(130, 35)
	final_continue_label.visible = true

	# 摄像机前移（文字右缘在屏幕 85% 处，完全可见）
	var label_right = text_x + final_continue_label.size.x
	var reveal_x = label_right - viewport_size.x * 0.35
	var tw1 = create_tween()
	tw1.tween_property(camera, "position:x", reveal_x, 0.6)
	tw1.set_ease(Tween.EASE_IN_OUT)
	tw1.set_trans(Tween.TRANS_CUBIC)
	await tw1.finished

	await get_tree().create_timer(0.3).timeout

	phase = Phase.FINALE
	_enter_player_control()

func _enter_player_control():
	controlled_mode = true
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	camera.set_drag_margin(Side.SIDE_LEFT, dead_zone_margin)
	camera.set_drag_margin(Side.SIDE_RIGHT, dead_zone_margin)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	soul_touching_text = false

func _tick_void_credits(_delta: float):
	pass

func _tick_finale(_delta: float):
	if not controlled_mode:
		return
	var dir = 0.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir -= 1.0
	if dir == 0.0:
		dir = mobile_dir
	if dir != 0.0:
		soul.position.x += dir * 220.0 * _delta
	soul.position.y += sin(Time.get_ticks_msec() * 0.003) * 0.3

	# 碰撞检测
	var sp = soul.position
	var ap = final_continue_hitbox.position
	var asz = (final_continue_hitbox.get_child(0) as CollisionShape2D).shape.size
	var r = Rect2(ap - asz / 2, asz)
	var touching = r.has_point(sp)

	if touching and not soul_touching_text:
		soul_touching_text = true
		final_continue_label.add_theme_color_override("font_color", Color(1, 1, 0))
		final_continue_label.add_theme_color_override("font_outline_color", Color(0.6, 0.5, 0))
		SoundManager.play_ui("select")
	elif not touching and soul_touching_text:
		soul_touching_text = false
		final_continue_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
		final_continue_label.add_theme_color_override("font_outline_color", Color(0.25, 0.25, 0.25))

	var investigate_triggered = Input.is_action_just_pressed("investigate")
	if _mobile_investigate:
		investigate_triggered = true
		_mobile_investigate = false

	if touching and investigate_triggered:
		_exit_opening()


# ==================== 虚空 → 开发人员名单 ====================

func _show_credits():
	phase = Phase.VOID_CREDITS
	credits_active = true
	controlled_mode = false

	credits_bg = ColorRect.new()
	credits_bg.color = Color.BLACK
	credits_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_bg.modulate.a = 0.0
	ui_layer.add_child(credits_bg)

	var credit_lines = [
		"",
		"",
		"",
		"    ----核心----",
		"    Xmouse - 程序&后期",
		"    克斯里德 - 美术&剧情",
		"    EmoCez - 贴图&音效",
		"    Xx_出c好吃_xX - 音乐&运维",
		"    飞 - debug&音乐",
		"",
		"    ----感谢----",
		"    青龙狱碧 - 贴图",
		"    粥伞 - 贴图",
	]

	credits_label = Label.new()
	credits_label.text = "\n".join(credit_lines)
	if MAIN_FONT:
		credits_label.add_theme_font_override("font", MAIN_FONT)
	credits_label.add_theme_font_size_override("font_size", 22)
	credits_label.add_theme_color_override("font_color", Color(1, 1, 1))
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credits_label.size = viewport_size
	credits_label.position = Vector2.ZERO
	credits_label.modulate.a = 0.0
	ui_layer.add_child(credits_label)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(credits_bg, "modulate:a", 0.7, 1.0)
	tw.tween_property(credits_label, "modulate:a", 1.0, 1.2)
	tw.tween_property(camera, "position:x", -viewport_size.x, 1.0)
	SoundManager.play_ui("select")
	await tw.finished

	await get_tree().create_timer(4.0).timeout

	get_tree().quit()


# ==================== 退出 ====================

func _exit_opening():
	phase = Phase.EXIT
	controlled_mode = false

	SoundManager.play_title_start()
	SoundManager.stop_bgm()

	fade_overlay.color = Color.WHITE

	var shake_objects = []
	var orig_positions = {}
	for obj in [soul, final_continue_label, camera]:
		if is_instance_valid(obj):
			shake_objects.append(obj)
			orig_positions[obj] = obj.position

	var elapsed = 0.0
	while elapsed < 5.12:
		var progress = elapsed / 5.12
		fade_overlay.modulate.a = progress
		var shake = progress * 10.0
		for obj in shake_objects:
			if is_instance_valid(obj):
				obj.position = orig_positions[obj] + Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	for obj in shake_objects:
		if is_instance_valid(obj):
			obj.position = orig_positions[obj]

	get_tree().change_scene_to_file("res://node_2d.tscn")
