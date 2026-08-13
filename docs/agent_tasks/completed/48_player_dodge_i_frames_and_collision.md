# 任务 48：玩家闪避（约 1.5 身位、全动作无敌、穿敌不穿墙）

状态：ACCEPTED
负责人：独立执行任务（中枢派发）
依赖：任务 46（ACCEPTED）；任务 47 已取消且无生产改动
Git 基线：`main` HEAD `fc7b531`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L3
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级/停线触发：需要修改 `CombatReceiver` 拒绝语义、公共战斗接口、项目碰撞层定义、精确 allowlist 外文件，专项 runner 随机不稳定，或共享并发漂移影响候选真实性时立即停止回传。

## 1. 冻结行为

1. 新动作 `dodge`，默认键盘 `Shift`，不得覆盖现有输入。
2. 仅在玩家存活、在地面、未受击、未施法、未闪避且冷却结束时启动。
3. 方向取当前非零水平输入，无输入时沿最后朝向；不产生垂直位移。
4. 动作时长 `0.18s`，冷却 `0.55s`，冷却从动作结束开始。
5. 开放地面位移为玩家碰撞体水平完整宽度的 `1.5` 倍，允许 `±15%`；遇墙必须提前截断。
6. 闪避期间锁定普通移动、跳跃、技能和元素切换；死亡、退出树、碰墙和其他中断均幂等清理。

## 2. 无敌与碰撞契约

1. 位移/表现第一帧前设置 `CombatReceiver.dodging = true`，最后一帧结束后才恢复；不得改 `CombatReceiver` 源码。
2. 不读写或覆盖其他来源的 `invulnerable`；现有拒绝链使用 `dodging`。
3. 进入时保存完整 collision mask，只临时关闭敌人身体第 2 层；世界阻挡第 3 层始终开启。所有结束/中断路径精确恢复原 mask。
4. 使用真实碰撞移动，不得用 `test_only`、直接改 `global_position` 或关闭全部碰撞；可穿敌，不可穿墙。

## 3. 轻量表现

复用现有玩家贴图做透明度变化和/或短寿命残影，覆盖完整动作并可读出起止。不新增 Sprite、纹理、音频或动画资源；结束后恢复原始视觉状态，Tween 必须有声明和幂等清理。

## 4. 精确 allowlist

1. `project.godot`
2. `scripts/player.gd`
3. `scenes/player.tscn`
4. `combat/tests/run_task48_dodge_integration.gd`
5. `combat/tests/run_task48_dodge_integration.gd.uid`（仅隔离 scan 确实生成时）
6. `combat/tests/capture_task48_dodge_visuals.gd`
7. `combat/tests/capture_task48_dodge_visuals.gd.uid`（仅隔离 scan 确实生成时）
8. `docs/agent_tasks/pending/48_player_dodge_i_frames_and_collision.md`
9. `docs/agent_tasks/evidence/task48/**`

现有 combat/技能 runner 只运行回归，不修改。

## 5. 禁止项

不修改 `combat/components/combat_receiver.gd`、伤害计算、公共技能接口或碰撞层定义；不处理 Task 20/47；不删除、暂存、认领共享未跟踪产物；不连接、关闭或控制共享 Godot/editor/godot-ai；不执行 Git 写操作，不 push，不自行 `ACCEPTED`。

## 6. 专项与 L3 验收

专项 runner 至少覆盖开放地面距离/方向/时长/冷却、完整伤害拒绝、穿敌/撞墙、mask 正常和中断恢复、空中/受击/施法/死亡启动拒绝、结束后移动跳跃技能元素恢复。执行者只在全新隔离副本/独立 profile 验证并交付 `REVIEW`。

中枢按 `REVIEW_L3_PLAYBOOK.md` 在另一全新冷副本执行 editor scan、专项、直接影响域回归、主场景 smoke、单组 `1920x1080` 实际动作 capture 和 final scan；正式日志五类标记为零，allowlist、sidecar、manifest 与共享零漂移对账通过后才能 `ACCEPTED`。

## 7. 执行交付（冻结待中枢 Review）

- 实际模型：`gpt-5.6-sol`；推理等级：`high`。
- 实际生产修改：`project.godot` 新增 Shift 的 `dodge`；`scripts/player.gd` 新增 `0.18s / 0.55s / 1.5 身位`闪避、真实碰撞移动、DODGED i-frame、敌体层临时关闭、世界层保留、透明度表现和幂等清理。`scenes/player.tscn` 无需修改。
- 新增 runner/capture 及 cold-first UID；三张 1920×1080 正式图片、8 份成功日志、汇总 CSV 和 manifest 位于 `docs/agent_tasks/evidence/task48/`。
- 最终执行候选：`C:\tmp\element-dungeon-task48-exec-20260813-03`；独立 profile：`C:\tmp\element-dungeon-task48-profile-20260813-03`；Godot `4.7.1.stable.official.a13da4feb`。
- 正式结果：editor scan 0；专项 `5/55`；Agent D `9/73`；技能目录 `11/236`；Task31 `4/534`；主场景 180 帧 smoke 0；capture `1 test / 3 images / 0 failures`；final scan 0。8 份成功日志五类标记均 0。
- 保护对账：`CombatReceiver`、公共战斗接口、碰撞层定义、`scenes/player.tscn` 均未修改；共享 `.godot` 与 PID 不变。外部新增顶层 `tmp/` 树不在 allowlist 且未认领，候选六文件与最终冷根 SHA 全等，因此未影响候选真实性。
- 诊断保留：`-01` 隔离包装错误；`-02` headless capture 卡住与首轮 Tween 夹具失败；均排除正式 evidence。精确说明见 evidence README。
- Git 写操作为零；未 add/commit/push/reset/restore/checkout/clean/stash。交付后冻结，不自行 `ACCEPTED`。

## 8. 独立 Review 回填（L3，2026-08-13）

- Review 实际模型：`gpt-5.6-sol`；推理等级：`high`；结论：`PASS`。本结论不等于 `ACCEPTED`，任务状态继续保持 `REVIEW`，最终接受由中枢决定。
- 执行证据失效点：执行者 `-03` 从共享 live 工作区整文件复制 `project.godot` 与 `scripts/player.gd`，把 Task48 外的 `global_instakill` 一并带入；共享/冷根 SHA 全等不能证明纯 overlay，原执行全绿不作为本次 PASS 依据。
- 正式候选从 `fc7b5318f3b32860ee10265c23aa1cff199e1b99` Git ZIP 对象导出，在此前不存在的 `C:\tmp\element-dungeon-task48-review-20260813-04` 只重建纯 Task48：`project.godot` 仅 `dodge/Shift`；`scripts/player.gd` 仅闪避；加入 runner/capture 与两枚 UID；`scenes/player.tscn` 保持基线。全冷根 `global_instakill` 搜索为 0。
- 独立 profile：`C:\tmp\element-dungeon-task48-review-profile-20260813-04`；Godot `4.7.1.stable.official.a13da4feb`。cold-first scan 0；专项 `5/55`；Agent D `9/73`；技能目录 `11/236`；Task31 `4/534`；正式 RunGame 180 帧 smoke 0；非 headless capture `1 test / 3 images / 0 failures`；final scan 0。
- 八份正式日志五类标记全 0。三张 1920×1080 原图已逐张检查：ready 清晰，mid 透明且与敌体重叠，end 越过敌人并恢复不透明；墙体截断、完整 i-frame 与结束恢复由专项真实碰撞/伤害断言覆盖。
- `CombatReceiver` 与 `scenes/player.tscn` 对基线 SHA 一致；冷根/共享 sidecar、共享 `.godot`、共享 Godot/editor PID 均零漂移。Task49 并发新增的三个共享 tracked 修改未进入冷根、未认领且不影响候选真实性。
- Review evidence：`docs/agent_tasks/evidence/task48/review_l3/`。Git 写操作为零；未 add/commit/push/reset/restore/checkout/clean/stash，也未控制共享 Godot/editor/godot-ai。

## 9. 中枢接受与归档（2026-08-13）

- 中枢采纳独立 L3 的 `PASS`，Task48 状态更新为 `ACCEPTED` 并归档。本节及第 8 节为最终权威验收依据。
- 第 7 节所述执行者 `-03` 候选及其“共享/冷根 SHA 全等因此候选真实”的结论已失效：该候选夹带 Task48 外 `global_instakill`，仅保留作审计记录，不用于接受判断。
- 接受范围严格为独立 L3 从 `fc7b5318f3b32860ee10265c23aa1cff199e1b99` 重建的纯 Task48 overlay：`project.godot` 仅新增 `dodge/Shift`，`scripts/player.gd` 仅新增闪避，外加 Task48 runner/capture、两枚 UID、任务书和 evidence。共享工作树中的 `global_instakill` 不属于 Task48，不删除、不覆盖、不暂存、不认领。
- 验收结论：约 1.5 身位、完整动作无敌、穿敌不穿墙、输入/动作门禁、mask 与视觉幂等恢复均通过专项、直接回归、主场景 smoke 和独立三帧视觉证据；正式日志与隔离保护门禁通过。
