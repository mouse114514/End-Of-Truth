extends CanvasLayer

@onready var border_rect = $BorderRect
@onready var background_rect = $BorderRect/BackgroundRect
@onready var rich_label = $BorderRect/BackgroundRect/RichLabel
@onready var speaker_label = $BorderRect/BackgroundRect/SpeakerLabel
@onready var avatar_rect = $BorderRect/BackgroundRect/AvatarRect

signal dialog_closed
signal dialog_shown
signal branch_selected(index: int)
signal branch_input_resolved

var is_showing: bool = false
var is_animating: bool = false
var waiting_for_close: bool = false
var full_text: String = ""
var current_text: String = ""
var char_index: int = 0
var current_speaker: String = ""

var text_speed: float = 20.0
var time_accum: float = 0.0
var can_skip: bool = false

var current_pitch: float = -1.0

var parsed_segments: Array = []
var active_effects: Dictionary = {}
var grayscale_shader: Shader

const MAIN_FONT = preload("res://font/main.ttf")
#const AVATAR_SIZE: Vector2 = Vector2(150, 150)
const SCALE_FACTOR: float = 1.5

var _tag_regex: RegEx
var _parse_regex: RegEx

func _ready():
	grayscale_shader = load("res://grayscale_shader.gdshader")
	_tag_regex = RegEx.new()
	_tag_regex.compile("'\\[([^\\]]+)\\]<([^>]+)>")
	_parse_regex = RegEx.new()
	_parse_regex.compile("([a-z]+)(?:\\(([^)]*)\\))?")
	hide_dialog()
	_connect_mobile_input_signals()
	_install_custom_effects()
	set_process(true)

func _install_custom_effects():
	var wave_script = load("res://wave_effect.gd")
	var wave_effect = RichTextEffect.new()
	wave_effect.set_script(wave_script)
	rich_label.install_effect(wave_effect)
	
	var tornado_script = load("res://tornado_effect.gd")
	var tornado_effect = RichTextEffect.new()
	tornado_effect.set_script(tornado_script)
	rich_label.install_effect(tornado_effect)
	
	var rainbow_script = load("res://rainbow_effect.gd")
	var rainbow_effect = RichTextEffect.new()
	rainbow_effect.set_script(rainbow_script)
	rich_label.install_effect(rainbow_effect)

func _connect_mobile_input_signals():
	var mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input:
		if mobile_input.has_signal("investigate_pressed"):
			mobile_input.investigate_pressed.connect(_on_mobile_investigate_pressed)
		if mobile_input.has_signal("close_dialog_pressed"):
			mobile_input.close_dialog_pressed.connect(_on_mobile_close_dialog_pressed)
		if "direction_input" in mobile_input:
			mobile_input.direction_input.connect(_on_mobile_direction_input)

func _on_mobile_investigate_pressed():
	if is_showing:
		if is_animating:
			skip_animation()
		elif waiting_for_branch_input:
			SoundManager.play_ui("confirm")
			waiting_for_branch_input = false
			branch_input_resolved.emit()
		elif not is_animating:
			hide_dialog()

func _on_mobile_close_dialog_pressed():
	if is_showing and is_animating and can_skip:
		skip_animation()
	elif is_showing and waiting_for_branch_input:
		SoundManager.play_ui("confirm")
		waiting_for_branch_input = false
		branch_input_resolved.emit()

func _on_mobile_direction_input(dir: Vector2):
	if is_showing and waiting_for_branch_input:
		var moved = false
		if dir.y < 0:
			current_branch_selection = (current_branch_selection + 2) % branch_options.size()
			moved = true
		elif dir.y > 0:
			current_branch_selection = (current_branch_selection - 2 + branch_options.size()) % branch_options.size()
			moved = true
		elif dir.x < 0:
			current_branch_selection = (current_branch_selection - 1 + branch_options.size()) % branch_options.size()
			moved = true
		elif dir.x > 0:
			current_branch_selection = (current_branch_selection + 1) % branch_options.size()
			moved = true
		if moved:
			SoundManager.play_ui("select")
			_update_branch_display()

func _input(event):
	if not is_showing:
		return
	
	if is_animating:
		if event.is_action_pressed("close_dialog") or event.is_action_pressed("investigate"):
			skip_animation()
			get_viewport().set_input_as_handled()
		return
	
	if waiting_for_branch_input:
		var moved = false
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_W, KEY_UP:
					current_branch_selection = (current_branch_selection + 2) % branch_options.size()
					moved = true
				KEY_S, KEY_DOWN:
					current_branch_selection = (current_branch_selection - 2 + branch_options.size()) % branch_options.size()
					moved = true
				KEY_A, KEY_LEFT:
					current_branch_selection = (current_branch_selection - 1 + branch_options.size()) % branch_options.size()
					moved = true
				KEY_D, KEY_RIGHT:
					current_branch_selection = (current_branch_selection + 1) % branch_options.size()
					moved = true
				KEY_Z:
					SoundManager.play_ui("confirm")
					waiting_for_branch_input = false
					branch_input_resolved.emit()
					get_viewport().set_input_as_handled()
		if moved:
			SoundManager.play_ui("select")
			_update_branch_display()
		if event.is_action_pressed("investigate"):
			SoundManager.play_ui("confirm")
			waiting_for_branch_input = false
			branch_input_resolved.emit()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("investigate"):
		hide_dialog()
		get_viewport().set_input_as_handled()

func _process(delta):
	if is_animating and is_showing:
		time_accum += delta
		var interval = 1.0 / text_speed
		if time_accum >= interval:
			time_accum = 0
			if char_index < full_text.length():
				char_index += 1
				var new_char = full_text[char_index - 1] if char_index > 0 else ""
				if new_char != " " and new_char != "\n" and new_char != "\t":
					SoundManager.play_talk(_get_speaker_sound(current_speaker), current_pitch)
				_update_display_text()
			else:
				is_animating = false
				if branch_options.size() > 0:
					waiting_for_branch_input = true
					SoundManager.play_ui("select")
					_update_branch_display()

func _update_display_text():
	var result = _apply_tags_to_text(char_index)
	rich_label.text = result

func _test_wave_effect():
	rich_label.text = "[wave]测试浮动效果[/wave]"

func _apply_tags_to_text(char_idx: int) -> String:
	var result = ""
	
	for segment in parsed_segments:
		var seg_start = segment.start_idx
		var seg_end = segment.end_idx
		var seg_text = segment.text
		var tags = segment.tags
		
		if seg_start >= char_idx:
			continue
		
		var end_pos = min(seg_end, char_idx)
		var visible_len = end_pos - seg_start
		if visible_len <= 0:
			continue
		
		var visible_text = seg_text.substr(0, visible_len)
		
		if tags.size() == 0:
			result += visible_text
		else:
			var open_tags = ""
			var close_tags = ""
			for tag in tags:
				match tag.type:
					"fl":
						open_tags += "[mywave]"
						close_tags = "[/mywave]" + close_tags
					"co":
						var r = int(tag.r * 255)
						var g = int(tag.g * 255)
						var b = int(tag.b * 255)
						var color_tag = "[color=#%02x%02x%02x]" % [r, g, b]
						open_tags += color_tag
						close_tags = "[/color]" + close_tags
					"ra":
						open_tags += "[myrainbow]"
						close_tags = "[/myrainbow]" + close_tags
					"ro":
						open_tags += "[mytornado]"
						close_tags = "[/mytornado]" + close_tags
					"sh":
						open_tags += "[font_size=50]"
						close_tags = "[/font_size]" + close_tags
					"no":
						open_tags += "[s]"
						close_tags = "[/s]" + close_tags
			result += open_tags + visible_text + close_tags
	
	return result

func _parse_text_tags(text: String) -> Array:
	parsed_segments = []
	
	var segments = []
	var last_end = 0
	
	var matches = _tag_regex.search_all(text)
	for match in matches:
		var tag_content = match.get_string(1)
		var inner_text = match.get_string(2)
		var match_start = match.get_start()
		
		# Example: §[fl]<剧情开始测试>
		# Position: 0=§, 1=[, 2-3=fl, 4=], 5=<, 6-11=剧情开始测试, 12=>
		# inner_start = match_start + 2 (skip §[) + tag_content_len + 2 (skip ])
		var inner_start = match_start + 2 + tag_content.length() + 2
		var inner_end = inner_start + inner_text.length()
		var after_end = inner_end + 1
		
		if match_start > last_end:
			segments.append({
				"text": text.substr(last_end, match_start - last_end),
				"tags": [],
				"start_idx": last_end,
				"end_idx": match_start
			})
		
		var tags = _parse_tags(tag_content)
		segments.append({
			"text": inner_text,
			"tags": tags,
			"start_idx": inner_start,
			"end_idx": inner_end
		})
		
		last_end = after_end
	
	if last_end < text.length():
		segments.append({
			"text": text.substr(last_end),
			"tags": [],
			"start_idx": last_end,
			"end_idx": text.length()
		})
	
	parsed_segments = segments
	return segments

func _parse_tags(tag_str: String) -> Array:
	var tags = []
	var matches = _parse_regex.search_all(tag_str)
	for match in matches:
		var tag_type = match.get_string(1)
		var tag_params = match.get_string(2)
		match tag_type:
			"fl":
				tags.append({"type": "fl"})
			"sh":
				tags.append({"type": "sh"})
			"no":
				tags.append({"type": "no"})
			"ra":
				tags.append({"type": "ra"})
			"ro":
				tags.append({"type": "ro"})
			"co":
				var nums = tag_params.split(",")
				if nums.size() >= 3:
					tags.append({
						"type": "co",
						"r": float(nums[0]) / 255.0,
						"g": float(nums[1]) / 255.0,
						"b": float(nums[2]) / 255.0
					})
	return tags

func _get_speaker_sound(speaker: String) -> String:
	var s = speaker.to_lower()
	if s.contains("toriel") or s.contains("羊妈"):
		return "toriel_talk"
	elif s.contains("flowey") or s.contains("小花"):
		return "flowey_talk"
	elif s.contains("sans"):
		return "sans_talk"
	return "npc_talk"

func show_text(text: String, speaker: String = "", avatar_texture: Texture2D = null, pitch: float = -1.0):
	branch_options.clear()
	waiting_for_branch_input = false
	_parse_text_tags(text)
	
	if not rich_label.bbcode_enabled:
		rich_label.bbcode_enabled = true
	
	full_text = text
	char_index = 0
	is_animating = true
	time_accum = 0
	current_speaker = speaker
	can_skip = false
	
	if pitch > 0:
		current_pitch = pitch
	else:
		current_pitch = -1.0
	
	rich_label.text = ""
	
	SoundManager.play_talk(_get_speaker_sound(speaker), current_pitch)
	
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	
	if speaker != "" and avatar_texture != null:
		if avatar_rect:
			avatar_rect.texture = avatar_texture
			#avatar_rect.size = AVATAR_SIZE
			if grayscale_shader:
				var mat = ShaderMaterial.new()
				mat.shader = grayscale_shader
				avatar_rect.material = mat
			avatar_rect.visible = true
	else:
		if avatar_rect:
			avatar_rect.visible = false
	
	var text_size = rich_label.get_minimum_size()
	var background_height = max(120, text_size.y + 40) * SCALE_FACTOR * 0.75
	var background_size = Vector2(screen_width - 6, background_height)
	var border_size = Vector2(screen_width, background_height + 6)
	
	border_rect.size = border_size
	border_rect.position = Vector2(0, 0)
	background_rect.size = background_size
	background_rect.position = Vector2(3, 3)
	
	rich_label.add_theme_font_override("normal_font", MAIN_FONT)
	rich_label.add_theme_font_size_override("normal_font_size", int(20 * SCALE_FACTOR))
	rich_label.offset_top = 0
	
	if avatar_rect and avatar_rect.visible:
		rich_label.offset_left = int(75 * SCALE_FACTOR) + 20
	else:
		rich_label.offset_left = int(75 * SCALE_FACTOR) + 20
	
	border_rect.visible = true
	background_rect.visible = true
	is_showing = true
	set_process_input(true)
	set_process(true)
	
	await get_tree().create_timer(0.1).timeout
	can_skip = true
	dialog_shown.emit()

var branch_options: Array = []
var current_branch_selection: int = 0
var branch_dialog_text: String = ""
var waiting_for_branch_input: bool = false

func show_text_with_options(text: String, speaker: String = "", avatar_texture: Texture2D = null, options: Array = [], pitch: float = -1.0) -> int:
	branch_options = options
	current_branch_selection = 0
	branch_dialog_text = text
	
	_parse_text_tags(text)
	
	if not rich_label.bbcode_enabled:
		rich_label.bbcode_enabled = true
	
	full_text = text
	char_index = 0
	is_animating = true
	time_accum = 0
	current_speaker = speaker
	can_skip = false
	
	if pitch > 0:
		current_pitch = pitch
	else:
		current_pitch = -1.0
	
	rich_label.text = ""
	
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	
	if speaker != "" and avatar_texture != null:
		if avatar_rect:
			avatar_rect.texture = avatar_texture
			#avatar_rect.size = AVATAR_SIZE
			if grayscale_shader:
				var mat = ShaderMaterial.new()
				mat.shader = grayscale_shader
				avatar_rect.material = mat
			avatar_rect.visible = true
	else:
		if avatar_rect:
			avatar_rect.visible = false
	
	background_rect.size = Vector2(screen_width - 6, 160)
	border_rect.size = Vector2(screen_width, 166)
	border_rect.position = Vector2(0, 0)
	background_rect.position = Vector2(3, 3)
	
	rich_label.add_theme_font_override("normal_font", MAIN_FONT)
	rich_label.add_theme_font_size_override("normal_font_size", 20)
	rich_label.offset_top = 0
	
	if avatar_rect and avatar_rect.visible:
		rich_label.offset_left = int(75 * SCALE_FACTOR) + 20
	else:
		rich_label.offset_left = int(75 * SCALE_FACTOR) + 20
	
	border_rect.visible = true
	background_rect.visible = true
	is_showing = true
	set_process_input(true)
	set_process(true)
	
	await get_tree().create_timer(0.1).timeout
	can_skip = true
	dialog_shown.emit()
	
	_update_branch_display()
	waiting_for_branch_input = true
	
	if waiting_for_branch_input:
		await branch_input_resolved
	
	hide_dialog()
	return current_branch_selection

func show_branch_dialog():
	is_showing = true
	set_process_input(true)
	set_process(true)
	
	await get_tree().create_timer(0.1).timeout
	can_skip = true
	dialog_shown.emit()
	
	_update_branch_display()
	waiting_for_branch_input = true
	
	if waiting_for_branch_input:
		await branch_input_resolved
	
	hide_dialog()
	return current_branch_selection

func _update_branch_display():
	var options_text = "\n\n"
	var cols = 2
	for i in range(branch_options.size()):
		if i == current_branch_selection:
			options_text += "[color=yellow]> " + branch_options[i] + "[/color]"
		else:
			options_text += "  " + branch_options[i]
		if (i + 1) % cols == 0:
			options_text += "\n"
		else:
			options_text += "     "
	
	rich_label.text = branch_dialog_text + options_text

func skip_animation():
	char_index = full_text.length()
	_update_display_text()
	is_animating = false
	if branch_options.size() > 0:
		_update_branch_display()

func hide_dialog():
	border_rect.visible = false
	background_rect.visible = false
	speaker_label.visible = false
	if avatar_rect:
		avatar_rect.visible = false
	is_showing = false
	is_animating = false
	if waiting_for_branch_input:
		waiting_for_branch_input = false
		branch_input_resolved.emit()
	branch_options.clear()
	set_process_input(false)
	dialog_closed.emit()
