# End Of Truth

传说之下 (Undertale) 同人游戏，使用 Godot 4.3 开发。
*具备完整的**剧情管理器**、**战斗系统**、**弹幕系统**、**解谜系统**、**调查系统**以及**移动端支持***

## 核心功能

### 战斗系统
- **回合制 + 弹幕躲避**: 模仿原版 Undertale 的混合玩法
- **三重闪黑转场**: 战斗开始时的经典转场效果
- **灵魂系统**: 7种灵魂类型（决心、耐心、勇敢、正义、善良、正直、坚持）
- **死亡动画**: 灵魂破裂效果 + GAME OVER 流程（支持跳过）
- **无敌帧机制**: 受伤后的短暂无敌时间
- **生命值管理**: 动态血条与标签显示

### 弹幕系统
- **多种攻击模式**: 圆形、螺旋、瞄准、随机、回旋镖等
- **碰撞检测**: 基于 Area2D 的弹幕碰撞系统
- **伤害计算**: 可配置的弹幕伤害值
- **子弹对象池**: 高效的弹幕管理

### 剧情与对话系统
- **剧情管理器 (StoryManager)**: 全局自动加载单例
- **时间线系统**: 基于 JSON 的剧情时间线 (`timelines.json`)
- **对话标签系统**: 富文本效果（见下文）
- **调查系统**: 可交互区域与调查对话框
- **调查区域 (InvestigationArea)**: 可配置的调查触发区域

### 解谜系统
- **谜题管理器 (PuzzleManager)**: 全局自动加载单例
- **谜题方块 (PuzzleBlock)**: 可推动的方块
- **谜题开关 (PuzzleSwitch)**: 触发机制
- **谜题门 (PuzzleDoor)**: 解锁机制

### QTE 系统
- **快速反应事件**: 动态生成的 QTE 挑战
- **多种输入方式**: 支持键盘与移动端

### 视觉效果
- **灰度着色器 (grayscale_shader.gdshader)**: 用于特殊场景效果
- **高对比度灰度着色器 (grayscale_high_contrast.gdshader)**: 专门用于头像显示
- **彩虹效果**: 动态彩虹色循环
- **波浪效果**: 浮动动画
- **龙卷风效果**: 旋转动画
- **受伤闪烁**: 受伤时的颜色闪烁效果

### 音频系统
- **音频管理器 (SoundManager)**: 全局自动加载单例
- **动态音效**: 受伤、死亡、弹幕碰撞等音效

### 移动端支持
- **虚拟摇杆 (VirtualJoystick)**: 触摸控制
- **虚拟按钮 (VirtualButton)**: 自定义按钮布局
- **移动端输入管理器 (MobileInput)**: 全局自动加载单例
- **自适应输入**: 自动检测键盘/触摸输入

### 移动端输入接入标准

项目中所有需要接收移动端方向输入的节点必须遵循以下**统一模式**：

```gdscript
func _ready():
	add_to_group("player")                    # 1. 注册到 player 组
	
func handle_mobile_input(input_vec: Vector2): # 2. 实现此方法
	mobile_dir = input_vec.x                  # 存储方向，由 MobileInput 自动调用
```

**规则说明：**
- **方向输入**：将节点加入 `"player"` 组 + 实现 `handle_mobile_input`，`MobileInput` 自动查找并调用。参考：`character_body_2d.gd`、`player_soul.gd`、`opening_sequence.gd`
- **确认/调查输入**：不用额外处理。移动端按钮已通过 `Input.action_press("investigate")` 触发全局动作，用 `Input.is_action_just_pressed("investigate")` 即可捕获。参考：`_tick_finale` 中的 Z 键检查
- **菜单/UI 场景**（非玩家控制器）：可以直接连接 `direction_input` 和 `investigate_pressed` 信号。参考：`main_menu.gd`、`settings_menu.gd`、`canvas_c.gd`

**不要**直接用信号连接方向输入来驱动角色移动——那是菜单场景的特例，不是移动端操控玩家的标准做法。

### UI 系统
- **主菜单**: 开始游戏、设置等选项
- **设置菜单**: 音频、显示等配置
- **HUD**: 生命值条、战斗界面等
- **战斗预览**: 战斗前的敌人预览

### 其他功能
- **游戏设置 (GameSettings)**: 全局自动加载单例，保存游戏配置
- **强制遭遇触发器**: 固定位置的战斗触发
- **随机遭遇系统**: 可配置的随机战斗触发
- **存档系统**: 世界状态保存与恢复

## 对话标签系统

在对话文本中使用 `§[标签]<文本>` 格式添加效果：

| 标签 | 效果 | 示例 |
|------|------|------|
| `fl` | 字符串上下浮动 | `§[fl]<浮动文本>` |
| `co(R,G,B)` | 修改颜色 (RGB 0-255) | `§[co(255,0,0)]<红色文本>` |
| `ra` | 彩虹色循环 | `§[ra]<彩虹文本>` |
| `ro` | 持续旋转 | `§[ro]<旋转文本>` |
| `sh` | 字符串变大 | `§[sh]<放大文本>` |
| `no` | 删除线 | `§[no]<删除文本>` |

### 组合示例

```
§[fl,co(255,0,0),sh]<这很重要!>
```

可组合使用多个标签，用逗号分隔。标签会按照顺序依次应用。

## 操作

### 键盘操作

| 按键 | 功能 |
|------|------|
| 方向键 / WASD | 移动（战斗中按住 X 可减速） |
| Z | 调查 / 确认 / 跳过死亡动画 |
| X | 关闭对话 / 减速移动（战斗中） |

### 移动端操作

| 操作 | 功能 |
|------|------|
| 虚拟摇杆 | 移动 |
| 虚拟按钮 | 调查 / 确认 |
| 触摸屏幕 | 交互 |

## 项目结构

### 自动加载单例 (Autoload)
- `BattleManager.gd` - 战斗管理器，处理战斗的开始、结束与状态管理
- `GameSettings.gd` - 游戏设置，保存音量、显示等配置
- `MobileInput.gd` - 移动端输入管理器
- `PuzzleManager.gd` - 解谜管理器
- `SoundManager.gd` - 音频管理器
- `StoryManager.gd` - 剧情管理器

### 核心系统
- `player_soul.gd` - 玩家灵魂系统（7种灵魂类型、移动、碰撞、死亡动画）
- `enemy.gd` - 敌人基类
- `bullet.gd` / `bullet.tscn` - 弹幕基础类与场景
- `bullet_hell_scene.gd` / `bullet_hell_scene.tscn` - 弹幕战斗场景
- `attack_patterns.gd` - 攻击模式定义
- `boomerang_bullet.gd` / `boomerang_bullet.tscn` - 回旋镖弹幕

### 剧情与对话
- `canvas_c.gd` - 对话框系统（含标签解析）
- `timeline_editor.gd` / `timeline_editor.tscn` - 时间线编辑器
- `timeline_track.gd` - 时间线轨道
- `timelines.json` - 剧情时间线数据
- `stories/all_stories.gd` - 所有故事内容
- `StoryRegion.gd` / `StoryRegion.tscn` - 剧情区域
- `InvestigationArea.gd` / `InvestigationArea.tscn` - 调查区域
- `InvestigationDialog.tscn` - 调查对话框

### 解谜系统
- `PuzzleBlock.gd` - 谜题方块
- `PuzzleSwitch.gd` - 谜题开关
- `PuzzleDoor.gd` - 谜题门

### QTE 系统
- `qte_system.gd` / `qte_system.tscn` - 快速反应事件系统

### UI 系统
- `main_menu.gd` / `main_menu.tscn` - 主菜单
- `settings_menu.gd` / `settings_menu.tscn` - 设置菜单
- `mv_screen.gd` / `mv_screen.tscn` - 移动端屏幕适配
- `battle_preview.gd` / `battle_preview.tscn` - 战斗预览
- `health_bar.gd` - 生命值条
- `progress_bar.gd` - 进度条
- `ui/virtual_joystick.gd` - 虚拟摇杆
- `ui/virtual_button.gd` - 虚拟按钮
- `ui/joystick_input.gd` - 摇杆输入处理

### 视觉效果
- `wave_effect.gd` / `wave_effect.tres` - 波浪浮动效果
- `tornado_effect.gd` / `tornado_effect.tres` - 龙卷风旋转效果
- `rainbow_effect.gd` / `rainbow_effect.tres` - 彩虹色循环效果
- `strike_effect.gd` - 打击效果
- `grayscale_shader.gdshader` - 灰度着色器
- `grayscale_high_contrast.gdshader` - 高对比度灰度着色器

### 触发器与区域
- `forced_encounter_trigger.gd` / `forced_encounter_trigger.tscn` - 强制遭遇触发器
- `VisibilityOccluder.gd` / `VisibilityOccluder.tscn` - 可见性遮挡器
- `Collectible.gd` - 可收集物品
- `action_drag_button.gd` - 拖动按钮

### 其他
- `character_body_2d.gd` - 角色物理体
- `area_2d.gd` - 区域基类
- `node_2d.gd` / `node_2d.tscn` - 基础 2D 节点
- `canvas_layer.gd` - 画布层
- `tell.gd` - 通知/提示系统
- `mos_guen.gd` / `mos_mosk.gd` - 特殊脚本

### 资源目录
- `addons/` - Godot 插件
- `android/` - Android 平台资源
- `bullets/` - 弹幕资源
- `font/` - 字体文件
- `look_tscn/` - 场景预览资源
- `map/` - 地图资源
- `music/` - 音乐文件
- `MV/` - MV 相关资源
- `player/` - 玩家资源

## 运行

### 系统要求
- [Godot 4.3](https://godotengine.org/) 或更高版本
- 支持 Windows / Android / iOS / 其他 Godot 支持的平台

### 步骤
1. 克隆或下载本项目
2. 使用 Godot 4.3 打开项目目录（选择 `project.godot` 文件）
3. 点击右上角的 **运行按钮** 或按 **F5** 启动游戏
4. 首次运行会加载 `mv_screen.tscn` 作为主场景

### 对于移动端开发者
- 确保已安装 Android/iOS 导出模板
- 在 Godot 的 **项目 → 导出** 中配置导出预设
- 参考 `export_presets.cfg` 查看已有导出配置

## 技术栈

- **引擎**: Godot 4.3
- **编程语言**: GDScript
- **渲染器**: Mobile 渲染器（针对移动端优化）
- **平台支持**: Windows, Android, iOS, Web (理论上支持)

## 已知问题 & 待办事项

### 待优化
- [ ] 弹幕数量多时的性能优化
- [ ] 添加完整的存档/读档系统
- [ ] 补充更多敌人类型与攻击模式
- [ ] 完善移动端 UI 适配
- [ ] 添加成就系统

### 已知问题
- 无（如有问题请提交 Issue）

## 贡献

本项目为同人作品，欢迎提出建议与反馈！

## 许可证

*本项目为同人作品，非官方内容。Undertale 及其相关元素版权归 Toby Fox 所有。*

---

**开发状态**: 活跃开发中 🚧  
**最后更新**: 2026-05-05
