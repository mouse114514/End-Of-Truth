[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$folder2 = "D:\godot\au\music\sfx\pack1"
$files = Get-ChildItem -Path $folder2 -File
foreach ($f in $files) {
    $newName = $f.Name
    if ($f.Name -eq "砸下.wav") { $newName = "hit.wav" }
    elseif ($f.Name -eq "gb准备发射二样式.wav") { $newName = "gaster_charge_2.wav" }
    elseif ($f.Name -eq "gb准备发射.wav") { $newName = "gaster_charge.wav" }
    elseif ($f.Name -eq "gb长时间发射.ogg") { $newName = "gaster_charge_loop.ogg" }
    elseif ($f.Name -eq "gb发射.wav") { $newName = "gaster_fire.wav" }
    elseif ($f.Name -eq "亮眼.wav") { $newName = "flash.wav" }
    elseif ($f.Name -eq "sans说话音效.wav") { $newName = "sans_talk.wav" }
    elseif ($f.Name -eq "怪物死亡.wav") { $newName = "enemy_death.wav" }
    elseif ($f.Name -eq "羊妈愤怒说话音效.wav") { $newName = "toriel_angry.wav" }
    elseif ($f.Name -eq "羊妈说话.wav") { $newName = "toriel_talk.wav" }
    elseif ($f.Name -eq "杂项npc说话.wav") { $newName = "npc_talk.wav" }
    elseif ($f.Name -eq "无话人说话音效.wav") { $newName = "silent_talk.wav" }
    elseif ($f.Name -eq "按钮.wav") { $newName = "button.wav" }
    elseif ($f.Name -eq "选择.wav") { $newName = "select.wav" }
    elseif ($f.Name -eq "确认.wav") { $newName = "confirm.wav" }
    elseif ($f.Name -eq "老鼠叫.wav") { $newName = "mouse.wav" }
    elseif ($f.Name -eq "电梯按钮.wav") { $newName = "elevator.wav" }
    elseif ($f.Name -eq "书本攻击音效.wav") { $newName = "book_attack.wav" }
    elseif ($f.Name -eq "1万暴击.wav") { $newName = "powerful_hit.wav" }
    elseif ($f.Name.Contains("神秘G爹")) { $newName = "gaster_blaster.wav" }
    elseif ($f.Name -eq "起身.wav") { $newName = "stand_up.wav" }
    elseif ($f.Name -eq "跑路了兄弟.wav") { $newName = "flee.wav" }
    elseif ($f.Name -eq "造成伤害c.wav") { $newName = "damage_c.wav" }
    elseif ($f.Name -eq "造成伤害.wav") { $newName = "damage.wav" }
    elseif ($f.Name -eq "存档成功.wav") { $newName = "save.wav" }
    elseif ($f.Name -eq "打开设置界面.ogg") { $newName = "settings.ogg" }
    elseif ($f.Name -eq "Logo出现音效.ogg") { $newName = "logo.ogg" }
    elseif ($f.Name -eq "主页面进入游戏.ogg") { $newName = "title_start.ogg" }
    elseif ($f.Name.Contains("PVZ")) { $newName = "zombie_door.ogg" }
    
    if ($newName -ne $f.Name) {
        Rename-Item -Path $f.FullName -NewName $newName -Force
        Write-Host "Renamed: $($f.Name) -> $newName"
    }
}

$folder3 = "D:\godot\au\music\sfx\pack2"
$files3 = Get-ChildItem -Path $folder3 -File
foreach ($f in $files3) {
    $newName = $f.Name
    if ($f.Name -eq "存档.wav") { $newName = "save.wav" }
    elseif ($f.Name -eq "回血.wav") { $newName = "heal.wav" }
    elseif ($f.Name -eq "电话.wav") { $newName = "phone.wav" }
    elseif ($f.Name -eq "小心弹幕.wav") { $newName = "warning.wav" }
    elseif ($f.Name -eq "升级.wav") { $newName = "level_up.wav" }
    elseif ($f.Name -eq "砍.wav") { $newName = "slash.wav" }
    elseif ($f.Name -eq "坎c.wav") { $newName = "slash_alt.wav" }
    elseif ($f.Name -eq "受伤.wav") { $newName = "hurt.wav" }
    elseif ($f.Name -eq "受伤c.wav") { $newName = "hurt_alt.wav" }
    elseif ($f.Name -eq "小花生气的说.wav") { $newName = "flowey_angry.wav" }
    elseif ($f.Name -eq "小花说.wav") { $newName = "flowey_talk.wav" }
    elseif ($f.Name -eq "灵魂碎c.wav") { $newName = "soul_shatter_alt.wav" }
    elseif ($f.Name -eq "灵魂碎.wav") { $newName = "soul_shatter.wav" }
    elseif ($f.Name -eq "破碎.wav") { $newName = "break.wav" }
    elseif ($f.Name -eq "破碎c.wav") { $newName = "break_alt.wav" }
    elseif ($f.Name -eq "铃铛c.wav") { $newName = "bell_alt.wav" }
    elseif ($f.Name -eq "铃铛.wav") { $newName = "bell.wav" }
    elseif ($f.Name -eq "进入战斗.wav") { $newName = "battle_start.wav" }
    elseif ($f.Name -eq "警告.wav") { $newName = "alert.wav" }
    elseif ($f.Name -eq "黑屏.wav") { $newName = "blackout.wav" }
    
    if ($newName -ne $f.Name) {
        Rename-Item -Path $f.FullName -NewName $newName -Force
        Write-Host "Renamed: $($f.Name) -> $newName"
    }
}