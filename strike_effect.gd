extends RichTextEffect
var bbcode = "mystrike"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var height = 4.0
	if char_fx.env.has("height"):
		height = char_fx.env["height"]
	
	var trans = char_fx.transform
	trans = trans.scaled(Vector2(1.0, height))
	char_fx.transform = trans
	return true