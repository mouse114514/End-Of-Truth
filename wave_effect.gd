extends RichTextEffect
var bbcode = "mywave"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var time = Time.get_ticks_msec() / 1000.0
	
	var amp = 8.0
	var freq = 1.0
	
	if char_fx.env.has("amp"):
		amp = char_fx.env["amp"]
	if char_fx.env.has("freq"):
		freq = char_fx.env["freq"]
	
	var char_idx = char_fx.relative_index
	char_fx.offset.y = sin(time * freq * TAU + char_idx * 0.1) * amp
	return true
