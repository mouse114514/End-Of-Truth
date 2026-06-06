extends Node
# 参数说明：
# enemy_type              - 敌人类型 (0, 1, ...)
# turn_type               - 回合制类型变量 (默认 0)
# start_with_enemy_turn  - 是否立即进入敌人回合 (默认 false)
# end_after_one_turn     - 是否一回合后结束战斗 (默认 false)
# res://look_tscn/mouse.png
func mostell(sm: Node):
	sm.load_npc("res://look_tscn/mouse.png", Vector2(600, 400), "mouse", 5, "mouse", "res://look_tscn/talking/mouse.png", "res://music/muc/mouse.wav")
	await sm.wait(0.5)
	await sm.move_npc_to("mouse", "@$P+90,+0", 1.0)
	await sm.show_dialog("mouse", "hi")
	await sm.show_dialog("mouse", "如你所见，你成功进入了这个AU")
	await sm.show_dialog("mouse", "准确来说，目前连demo版都没有达到，顶多算是开发中版的。")
	await sm.show_dialog("mouse", "它的内容并不完整，能够算是一个铺垫。在这个版本以后，开发将会变得更加顺畅，因为我们已经完成了几乎所有的基本管理器")
	await sm.show_dialog("mouse", "所以，如果你发现了什么bug，欢迎来找我")
	await sm.show_dialog("mouse", "好了，在开始之前，我想问你一个问题")
	@warning_ignore("unused_variable")
	var choice = await sm.branch_talk("mouse", "你想要播放完整剧情吗？", ["放", "别", "钝角", "114514"])
	if sm.branch_do(0):
		await sm.show_dialog("mouse", "好吧欢迎你进行'[fl]<测试>")
		await sm.move_npc_to("mouse", "@$P+50,+0", 1.0)
		await sm.show_dialog("mouse", "'[co(255,0,0),sh]<这很重要!>")
		await sm.show_dialog("mouse", "我可是写了'[sh]<很久>的")
		await sm.move_npc_to("mouse", "@$P+90,+0", 0.4)
		await sm.show_dialog("mouse", "算了")
		await sm.show_dialog("mouse", "拜拜")
	sm.branch_od(0)
	if sm.branch_do(1):
		await sm.show_dialog("mouse", "'[ra,fl]<拜拜>")
	sm.branch_od(1)
	if sm.branch_do(2):
		await sm.show_dialog("mouse", "好吧")
		await sm.show_dialog("mouse", "。。。")
		await sm.show_dialog("mouse", "收到")
		await sm.move_npc_to("mouse", "@$P+2290,+0", 0.4)
	sm.branch_od(2)
	if sm.branch_do(3):
		await sm.show_dialog("mouse", "")
		await sm.show_dialog("mouse","             ")
		await sm.show_dialog("mouse", "'[fl,ra]<114514>")
		await sm.move_npc_to("mouse", "@$P+2290,+0", 0.4)
	sm.branch_od(3)
	sm.unload_npc("mouse")

func flwhlw(sm: Node):
	sm.load_npc("res://look_tscn/奸笑.png", Vector2(1755, 10), "flw", 0.12, "flw", "res://look_tscn/talking/平和.png")
	await sm.show_dialog("flw", "* Hi，我是金盏花")
	await sm.show_dialog("flw", "* 等等，你是一个人类?")
	await sm.start_battle("st_flw", 0, true)
	sm.unload_npc("flw")
	
func bye(sm: Node):
	sm.load_npc("res://look_tscn/mouse.png", Vector2(600, 400), "mouse", 5, "mouse", "", "res://music/muc/mouse.wav")
	await sm.move_npc_to("mouse", "@$P+0,-100", 1.0)
	await sm.wait(0.5)
	await sm.show_dialog("mouse", "没错，以上就是目前这个版本的所有内容了")
	await sm.show_dialog("mouse", "没办法呀，毕竟只是一个开发中版本")
	await sm.show_dialog("mouse", "我发出来就只是为了让你们看看我的进度的，顺便挖一下bug")
	await sm.wait(0.5)
	await sm.show_dialog("mouse", "'[ra]<哈哈哈哈哈哈>")
	await sm.wait(0.5)
	await sm.show_dialog("mouse", "接下来我甚至连图都没有抠好。")
	await sm.show_dialog("mouse", "所以你就随便逛逛吧，我可没有埋任何彩蛋")
	await sm.move_npc_to("mouse", "@$P+0,-500", 1.0)
	sm.unload_npc("mouse")
	
func execute(sm: Node, region_id: String) -> void:
	print("execute called with region_id: ", region_id)
	match region_id:
		"mosgay":
			await mostell(sm)
		"flwhlw":
			await flwhlw(sm)
		"mosbye":
			await bye(sm)
		_:
			print("Unknown region: ", region_id)
