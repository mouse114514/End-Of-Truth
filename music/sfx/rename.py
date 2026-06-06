import os
import shutil

folder1 = r"D:\godot\au\music\sfx\pack1"
folder2 = r"D:\godot\au\music\sfx\pack2"

renames1 = {
    "砸下.wav": "hit.wav",
    "gb准备发射二样式.wav": "gaster_charge_2.wav",
    "gb准备发射.wav": "gaster_charge.wav",
    "gb长时间发射.ogg": "gaster_charge_loop.ogg",
    "gb发射.wav": "gaster_fire.wav",
    "亮眼.wav": "flash.wav",
    "sans说话音效.wav": "sans_talk.wav",
    "怪物死亡.wav": "enemy_death.wav",
    "羊妈愤怒说话音效.wav": "toriel_angry.wav",
    "羊妈说话.wav": "toriel_talk.wav",
    "杂项npc说话.wav": "npc_talk.wav",
    "无话人说话音效.wav": "silent_talk.wav",
    "按钮.wav": "button.wav",
    "选择.wav": "select.wav",
    "确认.wav": "confirm.wav",
    "老鼠叫.wav": "mouse.wav",
    "电梯按钮.wav": "elevator.wav",
    "书本攻击音效.wav": "book_attack.wav",
    "1万暴击.wav": "powerful_hit.wav",
    "神秘G爹💀.wav": "gaster_blaster.wav",
    "起身.wav": "stand_up.wav",
    "跑路了兄弟.wav": "flee.wav",
    "造成伤害c.wav": "damage_c.wav",
    "造成伤害.wav": "damage.wav",
    "存档成功.wav": "save.wav",
    "打开设置界面.ogg": "settings.ogg",
    "Logo出现音效.ogg": "logo.ogg",
    "主页面进入游戏.ogg": "title_start.ogg",
    "PVZ乱入彩蛋_僵尸进门音效.ogg": "zombie_door.ogg",
}

renames2 = {
    "存档.wav": "save.wav",
    "回血.wav": "heal.wav",
    "电话.wav": "phone.wav",
    "小心弹幕.wav": "warning.wav",
    "升级.wav": "level_up.wav",
    "砍.wav": "slash.wav",
    "坎c.wav": "slash_alt.wav",
    "受伤.wav": "hurt.wav",
    "受伤c.wav": "hurt_alt.wav",
    "小花生气的说.wav": "flowey_angry.wav",
    "小花说.wav": "flowey_talk.wav",
    "灵魂碎c.wav": "soul_shatter_alt.wav",
    "灵魂碎.wav": "soul_shatter.wav",
    "破碎.wav": "break.wav",
    "破碎c.wav": "break_alt.wav",
    "铃铛c.wav": "bell_alt.wav",
    "铃铛.wav": "bell.wav",
    "进入战斗.wav": "battle_start.wav",
    "警告.wav": "alert.wav",
    "黑屏.wav": "blackout.wav",
}

for old, new in renames1.items():
    old_path = os.path.join(folder1, old)
    new_path = os.path.join(folder1, new)
    if os.path.exists(old_path):
        os.rename(old_path, new_path)

for old, new in renames2.items():
    old_path = os.path.join(folder2, old)
    new_path = os.path.join(folder2, new)
    if os.path.exists(old_path):
        os.rename(old_path, new_path)

print("Done!")