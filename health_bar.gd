extends ProgressBar

@onready var label = $Label

func _ready():
	# 确保有Label子节点
	if not label:
		label = Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = size
		add_child(label)
	
	# 设置字体样式
	var font = load("res://font/main.ttf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	
	# 连接值变化信号
	value_changed.connect(_on_value_changed)
	
	# 初始更新
	update_text()

func _on_value_changed(new_value):
	update_text()

func update_text():
	if label:
		# 显示格式：当前值/最大值
		label.text = str(int(value)) + "/" + str(int(max_value))
