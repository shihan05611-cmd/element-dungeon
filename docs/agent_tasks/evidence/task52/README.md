# Task52 执行证据（REVIEW）

状态：`REVIEW`  
实际模型：`gpt-5.6-sol`  
推理等级：`medium`  
Review Level：`L2`

## 修改与候选

- 共享生产只改 `scripts/player.gd` 的一行常量：`1.5 -> 5.0`。
- 测试先同步 `1.5 body widths -> 5.0 body widths`；中枢对齐测试合同后，仅把旧终点重叠断言迁移为“完成 5 身位后玩家终点越过敌人中心”。敌人仍固定在起点右侧 `35px`；期望计算仍读取生产常量，容差仍为 `expected_distance * 0.02`，墙体和其他门禁未改。
- 正式候选：`tmp/element-dungeon-task52-exec-20260813-02`。
- 独立 profile：`tmp/element-dungeon-task52-profile-20260813-02`。
- 来源：固定 Git 对象 `616867f9f736f53d41d4dfe9587eaee07c48070f`。为满足候选全树字面量零命中，导出时排除了固定基线中仅用于描述旧污染事故、且含该字面量的 3 个 Task48 历史审计文件；共享历史文件没有修改。
- 候选相对过滤基线的 changed-files 仅为上述两项；候选全树 `global_instakill|GLOBAL_INSTAKILL` 命中 `0`。

## 保护哈希

| 对象 | SHA / blob | 结果 |
|---|---|---|
| candidate `project.godot` | SHA256 `1B095A4CEDD0BD4C753202DE2FA6799EE114A20959E374799DDF1700BE30AAAE`; blob `2c0714d6b08e04ea69b3d697b2540e53d875259f` | 与 `616867f` 一致 |
| candidate `combat/components/combat_receiver.gd` | SHA256 `1195829532A696B4A9801CE4A569BE3E50839E04BE0617FCB2838FD66F16A89E`; blob `11a724c3854bb06540c50ad55d79b909f289681b` | 与 `616867f` 一致 |
| candidate `scenes/player.tscn` | SHA256 `F0B1567E4E33A182F518426E2EEEA20FF51ED4435DE26D868689DF780ED85633`; blob `e1d8819a402391c336b79d3854186c6fe50fbdda` | 与 `616867f` 一致 |
| candidate `scripts/player.gd` | SHA256 `8DA30B7B25BE084B7A7872BFBC95B5158AB4D8CB8A189E80670AAF7C57262B44` | Task52 单行常量 overlay |
| candidate/test shared parity | SHA256 `6AF1BDEE0E9B18BD1FF1512B6CFCC5F9BB8638C275F5C09270AE976AEC1B6D9F` | 一致 |
| Task48 归档 | blob `cdfa268e054125b975dd2901fc03028698cfcae3` | 与 `616867f` 一致、未修改 |

## 首次专项阻塞记录

命令入口：Godot `4.7.1.stable.official.a13da4feb`，`--headless --path <candidate> --script res://combat/tests/run_task48_dodge_integration.gd`。

- 结果：`5 tests / 55 assertions / 1 failure / exit 1`。
- 通过：开放地面左右方向按生产常量完成 5 身位；`0.18s` 动作与结束后 `0.55s` 冷却；完整动作伤害拒绝；敌体层不截断位移；墙体提前截断；真实 sweep；collision mask 保存/恢复；死亡、退出、中断与动作门禁恢复。
- 唯一失败：`player occupies enemy body space without disabling world collision`。
- 五类日志标记：`SCRIPT ERROR=0`、`Parse Error=0`、`ERROR:=0`、`WARNING:=0`、`CrashHandlerException=0`。

失败原因是旧夹具将敌人固定在起点右侧 `35px` 并在完整动作结束后要求玩家与敌人距离 `<32px`。5 身位闪避按新合同会完整越过敌人并在更远处结束；因此该旧终点重叠门禁与 5 身位合同冲突。修改其断言或布置超出“只同步说明文字、其他门禁不得改”的授权。

## 停线与未运行项

- 按任务范围立即停线，未修改位移算法、公共接口、碰撞层、输入、时长、冷却或其他测试门禁。
- 因专项不是全绿，未继续原 capture 或主场景 smoke；二者不能覆盖专项合同冲突。
- 首次沙箱内 cold import exit 0，但 Windows 根证书库访问被沙箱拒绝，出现 1 条环境级 `ERROR:`；该次仅作诊断，不作为正式成功日志。正式专项在沙箱外以同一候选/profile 运行，五类标记全 0。
- 未读取、修改、运行或认领用户独立的 `global_instakill` runner/UID；共享 `project.godot` 及该功能原样保留。
- Git 写操作为零。该轮曾等待中枢决定是否授权调整冲突测试门禁；授权与恢复结果见下节。

## 测试合同对齐后的正式 L2 结果

中枢仅授权将旧终点重叠断言改为：

```gdscript
_expect(player.global_position.x > enemy.global_position.x, "completed five-body-width dodge ends beyond the enemy center")
```

敌人仍位于起点右侧 `35px`；紧邻的完整期望距离断言和 `2%` 容差保持原样，墙体截断、真实 sweep、i-frame、mask/中断恢复与其他动作门禁全部保持。

- Task48 专项全量：`5 tests / 55 assertions / 0 failures / exit 0`。
- 原 Task48 OpenGL capture：`1 test / 3 images / 0 failures / exit 0`。
- 主场景短 smoke：`180 frames / exit 0`。
- 三份正式输出各自的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 `0`。
- 三张 1920×1080 原图逐张检查通过：ready 清晰；mid 玩家透明且已穿过敌人；recovered 位于敌人另一侧并恢复不透明。

截图 SHA256：

| 文件 | Bytes | SHA256 |
|---|---:|---|
| `task48_01_dodge_ready_1920x1080.png` | 75346 | `968C650D7A827C9E1FB4B70361F378C2E3B760F84C901FC84966582A38A777ED` |
| `task48_02_dodge_mid_enemy_overlap_1920x1080.png` | 75663 | `5F6636327CE89C236FE8FF875F057E20D7D8CBB485D7E4B411EDB8715AD9C14A` |
| `task48_03_dodge_recovered_1920x1080.png` | 75483 | `6C76EA608723928E532BAF7F3FB2E1F0FB62B2974734867FA234CDD6821EC7C3` |

最终候选全树 `global_instakill|GLOBAL_INSTAKILL` 命中为 `0`。`project.godot`、`CombatReceiver`、`scenes/player.tscn` 的 blob 仍与固定基线一致。共享 `scripts/player.gd` SHA256 为 `1E821B9DE4BC341F5DE23910FBA5C26DB3C964D0FDCEA5629E06D3899C8AA093`，与恢复执行前一致；用户受保护修改无漂移。Task48 历史归档未改，相关 runner/UID 未读取、修改、运行或认领。

Task52 冻结为 `REVIEW`，等待独立 L2 Review；执行者不自行 `ACCEPTED`，Git 写操作为零。
