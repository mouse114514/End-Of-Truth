extends Control

@onready var continue_label: Label = $VBoxContainer/ContinueLabel
@onready var settings_label: Label = $VBoxContainer/SettingsLabel
@onready var title_label: Label = $TitleLabel
@onready var sprite: Sprite2D = $Sprite2D
@onready var vbox: VBoxContainer = $VBoxContainer

var menu_options = []
var menu_actions = []
var current_selection = 0

var fade_rect: ColorRect
var is_fading = false
var mobile_input = null

func _ready():
	fade_rect = ColorRect.new()
	fade_rect.color = Color.WHITE
	fade_rect.modulate.a = 0.0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)

	var font = load("res://font/main.ttf")
	if font:
		continue_label.add_theme_font_override("font", font)
		continue_label.add_theme_font_size_override("font_size", 24)
		settings_label.add_theme_font_override("font", font)
		settings_label.add_theme_font_size_override("font_size", 24)

	menu_options = [continue_label, settings_label]
	menu_actions = ["continue", "settings"]

	mobile_input = get_node_or_null("/root/MobileInput")
	if mobile_input and mobile_input.has_signal("direction_input"):
		mobile_input.direction_input.connect(_on_mobile_direction_input)
	if mobile_input and mobile_input.has_signal("investigate_pressed"):
		mobile_input.investigate_pressed.connect(_on_confirm_pressed)

	update_selection()

func _process(_delta):
	if is_fading:
		return

	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_right"):
		current_selection = (current_selection + 1) % menu_options.size()
		SoundManager.play_ui("select")
		update_selection()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_left"):
		current_selection = (current_selection - 1 + menu_options.size()) % menu_options.size()
		SoundManager.play_ui("select")
		update_selection()
	elif Input.is_action_just_pressed("investigate"):
		_on_confirm_pressed()

func _on_mobile_direction_input(dir: Vector2):
	if is_fading:
		return
	if dir.y < 0:
		current_selection = (current_selection - 1 + menu_options.size()) % menu_options.size()
		SoundManager.play_ui("select")
		update_selection()
	elif dir.y > 0:
		current_selection = (current_selection + 1) % menu_options.size()
		SoundManager.play_ui("select")
		update_selection()

func _on_confirm_pressed():
	if is_fading:
		return
	match menu_actions[current_selection]:
		"continue":
			is_fading = true
			continue_label.modulate.a = 0.0

			var opening = load("res://opening_sequence.tscn").instantiate()
			add_child(opening)
			move_child(opening, 0)

			var tw = create_tween()
			tw.tween_property(settings_label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(title_label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(sprite, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				vbox.visible = false
			)
		"settings":
			SoundManager.play_ui("select")
			get_tree().change_scene_to_file("res://settings_menu.tscn")

func update_selection():
	for i in range(menu_options.size()):
		var label = menu_options[i]
		if i == current_selection:
			label.add_theme_color_override("font_color", Color(1, 1, 0))
		else:
			label.add_theme_color_override("font_color", Color(1, 1, 1))
