# Task52 独立 L2 Review 证据

结论：`PASS`。本结论不等于 `ACCEPTED`，最终接受、归档和 Git 检查点仍由中枢决定。

## Review 身份与边界

- 实际模型：`gpt-5.6-sol`；推理等级：`medium`；Review Level：`L2`。
- 完整阅读 `CENTRAL_REVIEW_RULES.md`、`REVIEW_AGENT_RULES.md`、`README.md`、Task52 任务书和已归档 Task48；未读取 `REVIEW_L3_PLAYBOOK.md`。
- 仅复用执行者冻结的 `tmp/element-dungeon-task52-exec-20260813-02` 与 `tmp/element-dungeon-task52-profile-20260813-02`。未建立 L3 冷根，未连接、关闭、重启或控制共享 Godot/editor/godot-ai。
- 未实现或修复游戏代码，未修改或运行用户 `global_instakill` runner/UID，Git 写操作为零。

## 精确 diff 与 provenance

- 固定基线：`616867f9f736f53d41d4dfe9587eaee07c48070f`。
- 过滤基线根中的 `scripts/player.gd` blob 为 `88d7c21ac6ab5778a2e5eb1e8682a78ac17d94da`，与 `616867f:scripts/player.gd` 相同；候选 blob 为 `5794fbdcf1fc41c210dbe18848c3844d106acfaf`，唯一 source diff 是 `DODGE_DISTANCE_IN_BODY_WIDTHS := 1.5 -> 5.0`。
- 过滤基线根中的 Task48 runner blob 为 `11a2da8835e6be43c317d87788804276bee370f6`，与 `616867f:combat/tests/run_task48_dodge_integration.gd` 相同；候选 blob 为 `f0c140f0fe7fb08617989994977fb1d7125fd166`，只有两项授权迁移：说明文字 `1.5 -> 5.0`，以及终点 `<32px` 重叠断言改为 `player.global_position.x > enemy.global_position.x`。
- 敌人仍固定在起点右侧 `35px`；期望距离仍读取生产常量；容差仍为 `expected_distance * 0.02`。时长、冷却、输入、碰撞层、`move_and_collide` sweep、i-frame、mask/中断恢复及其他门禁均未改。
- 排除运行缓存 `.godot/**` 后，候选相对过滤基线的非缓存差异为上述两个 source 文件及三张由允许的 capture 重新生成的 Task48 PNG。后三者仅是隔离根内运行证据，不属于 Task52 source overlay，也未回流共享 Task48 evidence。
- 候选全树 `rg -uuu -i global_instakill` 命中 `0`。

## 独立复跑

Godot：`4.7.1.stable.official.a13da4feb`。正式运行均在沙箱外复用上述隔离 candidate/profile，以避免已知的 Windows 根证书库沙箱诊断噪声。

1. Task48 专项：`5 tests / 55 assertions / 0 failures / exit 0`。覆盖开放地面左右 5 身位、`2%` 容差、35px 敌体不截断且终点越过敌人中心、墙体提前截断、真实 `move_and_collide`、完整动作 DODGED 拒伤、`0.18s` 动作、`0.55s` 冷却、mask 与死亡/退出/中断/动作门禁恢复。日志：`task48_specialty.log`。
2. 直接依赖 combat 回归：`27 tests / 124 assertions / 0 failures / exit 0`，包含 receiver 的 invulnerable/blocking 拒绝、命中提交及重复身份等既有合同。日志：`combat_direct_regression.log`。
3. 正式主场景：`--quit-after 180 / exit 0`。日志：`main_scene_smoke.log`。
4. 三份正式日志逐份扫描 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException`，命中均为 `0`。

## Capture 与人工视觉核验

复用执行者冻结的三张 `1920x1080` OpenGL capture，并按原尺寸逐张检查：

- `task48_01_dodge_ready_1920x1080.png`：玩家与敌人清晰可辨，起始状态不透明；SHA256 `968C650D7A827C9E1FB4B70361F378C2E3B760F84C901FC84966582A38A777ED`。
- `task48_02_dodge_mid_enemy_overlap_1920x1080.png`：玩家已越过敌人且透明表现清楚，动作中状态可读；SHA256 `5F6636327CE89C236FE8FF875F057E20D7D8CBB485D7E4B411EDB8715AD9C14A`。
- `task48_03_dodge_recovered_1920x1080.png`：玩家位于敌人另一侧并恢复不透明；SHA256 `6C76EA608723928E532BAF7F3FB2E1F0FB62B2974734867FA234CDD6821EC7C3`。

## 保护对账

- candidate `project.godot` blob `2c0714d6b08e04ea69b3d697b2540e53d875259f`，与 `616867f` 一致。
- candidate `combat/components/combat_receiver.gd` blob `11a724c3854bb06540c50ad55d79b909f289681b`，与 `616867f` 一致。
- candidate `scenes/player.tscn` blob `e1d8819a402391c336b79d3854186c6fe50fbdda`，与 `616867f` 一致。
- 共享 `scripts/player.gd` SHA256 为 `1E821B9DE4BC341F5DE23910FBA5C26DB3C964D0FDCEA5629E06D3899C8AA093`，与执行冻结记录一致；共享 `project.godot` SHA256 为 `C0C130F2D480C855A4011F178935702F65D2A857ACEC653C26DFBC676396987A`。本 Review 只运行隔离根，未向共享项目写入 cache、sidecar 或 capture。

## L2 结论

- Result：`PASS`。
- Findings：无阻塞项；未发现高速穿墙、算法/接口扩域、随机或偶发失败、候选运行时污染。
- Residual Risk：按 L2 规则复用冻结验证根和既有三图，没有重建 L3 发布级冷副本；运行产物与 source overlay 已分账，不影响本次判断。
- Recommended Next Step：中枢可据此决定 `ACCEPTED`、归档及精确 Git 检查点；本 Review 保持冻结。
