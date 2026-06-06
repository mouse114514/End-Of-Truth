extends RichTextEffect
var bbcode = "myrainbow"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var time = Time.get_ticks_msec() / 1000.0
	var char_idx = char_fx.relative_index
	var hue = fmod(time + char_idx * 0.05, 1.0)
	char_fx.color = Color.from_hsv(hue, 1.0, 1.0)
	return true