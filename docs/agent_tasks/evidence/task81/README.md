# Task 81 引燃主动技能证据

- `run_task81_ignition_tests.log`：专项 4 项 / 60 断言通过。覆盖可见目标稳定原子清火、保留水层、无火拒绝、1/5/20 层倍率、固定普攻火附着快照、覆盖刷新、到期、死亡/换房/重载清理；以及引燃期间左右朝向真实近战范围 1.5 倍、基础外至 1.5 倍内命中、1.5 倍外不命中、攻击接受后到期仍按快照结算、普通火普攻不变。
- `run_skill_content_catalog_tests.log`：既有目录与正式运行时回归 11 项 / 237 断言通过。
- `run_delivery_tests.log`：近战/投射物投递回归 16 项 / 56 断言通过。
- `run_combat_tests.log`：战斗接收与结算回归 27 项 / 124 断言通过。
- `editor_parse.log`：Godot 4.7.1 编辑器脚本扫描成功；Windows 根证书存储提示为环境噪声。
- `screenshots/01_fire_reclaim_gathering.png`：窗口渲染中，敌人火元素抽取粒子正汇聚至玩家。
- `screenshots/02_normal_fire_attack.png`：同一窗口机位下，普通火普攻保持原始独立气流尺寸与颜色。
- `screenshots/03_ignition_fire_attack.png`：同一窗口机位下，引燃固定普攻仅将已分离的 `BasicAttackAirflow` 放大至 1.5 倍并调为明显橙色；玩家本体未缩放、未染色。
- `screenshots/04_expired_recovery.png`：测试强制清理状态后的恢复画面，气流即时恢复普通火普攻的尺寸与颜色。

窗口取证命令使用唯一指定的 Godot 4.7.1 控制台可执行文件和 OpenGL 渲染；捕获脚本输出 `TASK 81 VISUAL CAPTURE PASSED`。进程返回码虽为 1，但日志中没有脚本或渲染失败，四张 PNG 均已成功写入。
