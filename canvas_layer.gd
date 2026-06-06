# UI_Dialog.gd
extends CanvasLayer

@onready var label = $Panel/Label
@onready var panel = $Panel

func _ready():
	hide_dialog()

func show_text(text: String):
	label.text = text
	panel.visible = true

func hide_dialog():
	panel.visible = false
