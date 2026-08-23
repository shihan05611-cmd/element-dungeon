# Task 85 技能提示清理、引燃图标与命中边界证据

## 结论

- 技能释放成功、自动切形态成功与结构化失败均不再改变 `FeedbackPanel`，也不再产生主动槽“锁定/失败”瞬时文字；调试 `_last_event_text`、权威结果、灰度、冷却遮罩/秒数均保留。
- 手动切形态、辅助模式、反应/减伤、配装提交和 Overlay 错误继续使用 `FeedbackPanel`。
- 引燃正式图标绑定路径固定为 `res://assets/generated/vfx/ignition/icon.png`；最终资产为 `256×256 RGBA`，外边缘全透明，alpha 仅 0/255，无半透明脏边。32×32 最近邻样本见 `ignition_icon_32px_nearest.png`。
- 引燃 `BasicAttackAirflow` 保持普通气流的精确 `1.5×` 与橙色；真实查询倍率按视觉前缘与普通固定余量反推为 `125 / 108 = 1.1574074…`，在攻击接受时锁入 payload。

## 图标来源

- 使用 Codex 内置 ImageGen 生成透明像素图；生成原图保存在 `assets/generated/vfx/ignition/_sources/ignition_generated_source.png`（1254×1254，SHA-256 `06BA2E97B829AE9BD11A69721A1AD6203D57E8E69178CE9557A4C3415B9EE4A4`）。
- 最终图标最近邻缩放至 256×256，并以 alpha 96 为阈值确定性硬化边缘；SHA-256 `35F561130738C071463C3F12880D3B6A3ADB73A57408BF72F549E779057912CB`。
- 最终生成提示：透明背景的方形像素风主动技能图标；数枚橙金火星从不同方向向中心汇聚，形成明亮紧凑的橙色引燃核心，深红轮廓、有限色阶、硬像素边缘、32×32 可辨；无文字、边框、水印，不得表现为单向火球、爆炸环、火焰柱、篝火或持续燃烧被动。

## 窗口取证

窗口使用唯一允许的 Godot 4.7.1 控制台程序、OpenGL Compatibility、同一测试房间/机位；Windows HiDPI 的 3840×2160 backing framebuffer 以最近邻规范化为稳定 1920×1080 证据：

- `screenshots/01_ignition_icon_normal_1920x1080.png`：火形态、图标正常全彩。
- `screenshots/02_ignition_icon_disabled_grayscale_1920x1080.png`：水形态不匹配、图标灰度禁用。
- `screenshots/03_ignition_icon_cooldown_1920x1080.png`：真实施放后的灰度、冷却遮罩和 `8.0` 秒数，无技能成功横幅/槽位瞬时字。
- `screenshots/04_skill_hud_hidden_1920x1080.png`：H 隐藏时技能区整体消失；恢复断言确认同一图标绑定仍在。
- `screenshots/05_normal_fire_attack_critical_frame_1920x1080.png`：普通火普攻关键帧。
- `screenshots/06_ignition_fire_attack_critical_frame_1920x1080.png`：同机位引燃关键帧，仅独立气流精确放大 1.5 倍并染橙。
- `screenshots/07_ignition_boundary_formula_overlay_1920x1080.png`：`V0=34`、`V1=51`、`Q0=108`、`Q1=125`、`P=74` 的前缘叠加诊断。

窗口日志：`logs/14_windowed_visual_capture_final_icon.log`，输出 `TASK 85 VISUAL CAPTURE PASSED: 7 screenshots`。

## 自动化

- `logs/18_task81_final.log`：4 tests / 68 assertions；贴图前缘实测、反推公式、左右边界内外、接受后快照稳定、视觉复原。
- `logs/13_hud_feedback_hard_alpha.log`：13 tests / 136 assertions；成功/失败无技能投影、手动反馈保留、图标正常/灰度/冷却/H 显隐。
- `logs/12_content_catalog_hard_alpha.log`：11 tests / 243 assertions；图标唯一稳定路径、256×256、透明外边缘。
- `logs/05_task24_hud.log`：10 tests / 232 assertions；busy 无反馈横幅/槽位瞬时字，权威 HUD 状态保留。
- `logs/06_task40_hud.log`：4 tests / 100 assertions；busy 无反馈横幅/槽位瞬时字，灰度/冷却遮罩保留。
- `logs/07_task82_toggle.log`：3 tests / 14 assertions；H 显隐回归。
- `logs/08_task76_attack_presentation.log`：4 tests / 44 assertions；普通普攻气流分层与复原回归。
- `logs/16_combat_core.log`：27 tests / 124 assertions；核心战斗接收与结算回归。
- `logs/17_delivery_core.log`：16 tests / 56 assertions；近战与投射物 Delivery 回归。
- `logs/19_editor_parse_unsandboxed.log`：Godot 4.7.1 全项目编辑器解析退出码 0。

所有 headless 日志仅出现 Windows 根证书存储环境提示；测试退出码均为 0。
