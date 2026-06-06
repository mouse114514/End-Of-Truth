extends RichTextEffect
var bbcode = "mytornado"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var time = Time.get_ticks_msec() / 1000.0
	var radius = 5.0
	var freq = 3.0
	
	if char_fx.env.has("radius"):
		radius = char_fx.env["radius"]
	if char_fx.env.has("freq"):
		freq = char_fx.env["freq"]
	
	var char_idx = char_fx.relative_index
	var angle = time * freq * TAU + char_idx * 0.1
	char_fx.offset.x = cos(angle) * radius
	char_fx.offset.y = sin(angle) * radius
	return true