# Task 90 执行者证据

身份：执行者。以下仅为实现与验证证据，不构成最终验收。

## 改动边界

- `scripts/combat_feedback.gd`：反应组合生成时，从有效 `receiver` 的 `Node2D` 宿主计算目标局部命中偏移；伤害数字分支未改。
- `combat/presentation/element_reaction_visual.gd`：节点继续由 `CombatFeedback` 持有；仅用 `WeakRef` 在生命周期内同步世界位置，宿主失效或离树后冻结。
- 新增 Task 90 专项与真实窗口取证脚本、日志、截图；未修改 gameplay、结果契约、Task87 动画参数、Task88、RunOverlay、Cloud 或位图资源。

## 自动化

- `logs/02_task90_specialist.log`：`TASK 90 REACTION VISUAL FOLLOW TESTS PASSED: 6 tests, 28 assertions`
  - 局部偏移与逐帧跟随；伤害数字不跟随。
  - 左右与多目标独立跟随。
  - 无宿主固定命中点；离树/释放后冻结且弱引用清空。
  - 原 0.42 秒生命周期、减少动态锚定、静止普通怪与 Boss。
  - 16 并发上限、既有去重键及清理。
- `logs/03_task87_regression.log`：`TASK 87 ELEMENT REACTION VISUAL TESTS PASSED: 7 tests, 38 assertions`
- `logs/06_hud_feedback_regression.log`：`TASK 12 HUD LOADOUT FEEDBACK TESTS PASSED: 13 tests, 140 assertions`
- `logs/08_editor_scan_final.log`：Godot 4.7.1 完成 filesystem、全局类和编辑器布局扫描，退出码 0。末尾 editor settings 保存失败来自工作区外 AppData 写权限，不影响脚本扫描与上述运行结果。
- `logs/09_manifest_check.log`：共享严格清单仍报告未登记的 Task87 与 Task90 直跑入口。为隔离 Task88 已有的 `test_batch_runner.gd` 未提交改动，本任务未编辑该共享清单；Task87、Task90 均已用上面的直跑日志验证。

## Godot 4.7.1 真实窗口连续帧

`logs/05_window_capture_clean.log`：OpenGL/NVIDIA 真实窗口运行，`TASK 90 WINDOW CAPTURE PASSED: 13 same-camera screenshots`。右击退、左击退、多目标和减少动态的每次采样均记录 `distance=0.000`。

- 右击退连续帧：`01_right_spawn_1280x720.png`、`02_right_mid_1280x720.png`、`03_right_late_1280x720.png`
- 左击退连续帧：`04_left_spawn_1280x720.png`、`05_left_mid_1280x720.png`、`06_left_late_1280x720.png`
- 多目标反向击退：`07_multiple_opposite_knockback_1280x720.png`
- 静止普通怪 / Boss：`08_static_enemy_control_1280x720.png`、`09_boss_static_control_1280x720.png`
- 减少动态仍锚定：`10_reduced_motion_spawn_1280x720.png`、`11_reduced_motion_mid_1280x720.png`
- 目标离树冻结：`12_exit_before_1280x720.png`、`13_exit_frozen_1280x720.png`

连续帧可见反应双色组合随怪物移动；数字与固定“反应”文字留在原命中区域独立上浮。末段视觉按原 0.42 秒衰减，没有瞬移到旧命中点。
