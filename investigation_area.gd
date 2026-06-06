extends Area2D

# 可用的调查文本数组
var investigation_texts = [
	"* 你对这个并不感兴趣",
	"* 还不是看这个的时候...", 
	"* 你调查了，但什么也没发生",
	"* 我猜你现在按下了z键"
]

func get_random_text():
	return investigation_texts[randi() % investigation_texts.size()]
