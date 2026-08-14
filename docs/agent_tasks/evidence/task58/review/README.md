# Task58 independent L3 Review evidence

状态：`FAIL / FROZEN`

- Reviewer：`gpt-5.6-sol / high`
- 固定基线：`51b8ffde0894fd430517225e693b7c44008038aa`
- 冻结候选：`C:\Users\heliashi\.codex\worktrees\b487\元素地牢-4.7`
- Review 冷根：`C:\Users\heliashi\.codex\cold-roots\element-dungeon\task58-review-20260814-01`
- Review profile：`C:\Users\heliashi\.codex\cold-roots\element-dungeon\task58-review-profile-20260814-01`
- Godot：`4.7.1.stable.official.a13da4feb`

## 结论

正式自动化、视觉、smoke、final scan、PNG/删除/sidecar/保护对账均通过，但候选仍为 `FAIL`：进入 `SHOP` 的权威快照先同步触发 `RunOverlayInterface._show_formal_shop()`，Coordinator 下一 deferred frame才创建商店房并隐藏 Overlay。Review-only 诊断实测 `OVERLAY_VISIBLE_AT_SHOP_SNAPSHOT=true` 且 `SHOP_ROOM_ACTIVE_AT_SHOP_SNAPSHOT=false`，违反“入店 UI 初始关闭、皇冠 F 才打开”。执行专项只在 `active_shop_room != null` 后检查关闭态，漏掉该帧序。

另有一项 L3 evidence 缺陷：执行 `overlay_manifest.csv` 将固定基线中不存在的 Task58 任务书记成 `M`，实际应为 `A`。其余 22 个非 evidence overlay 文件、十项精确删除和 evidence glob 均对齐。

## 已通过门禁

- Task58 `3/77`；Task41 `4/84`；Task43 `4/105`；Task51 `2/49`；Task29 `1/74`；Task31 `4/383`；Task57 `5/205`，总计 `23 tests / 977 assertions`。
- Task43 diff 只调整 alpha 可见底边公式，加入 `sprite.position.y` 与 `max_alpha_y + 1`；未删除或放宽清场、配装、跳跃、几何门禁。
- fresh capture `1 test / 7 images / 0 failures`；七张 `1920×1080` 已逐张原尺寸 QA。
- RunGame 180 帧 smoke、正式 cold-first scan、final scan 均退出 `0`。
- 12 组正式成功日志五类标记全部为 `0`；失败/环境尝试单列，不混入正式汇总。
- 六张正式 PNG SHA/尺寸/alpha 与任务书一致；宝箱、传送门使用真实双 texture；旧生产引用为 0；十项旧文件全部不存在。
- Battle02 SpawnA 为专用 Tidal Sentry，`55 HP / 15` 梦尘；静态水平位移、平台落地、三发 ProjectileDelivery 生命周期、元素/死亡/奖励/清房通过。
- Task57 Battle02 scene、RunGame、房间背景以及 `project.godot`、Player、Enemy 均与固定基线 blob 一致；五阶段 `4/1/0` 与奖励账本回归通过。
- final scan sidecar `1091 → 1091`，added/removed/changed `0/0/0`。
- 执行 worktree 前后 status 不变且无 `.godot`；共享 PID `17624/3964` 始终存活且 Responding，未连接、关闭、reload、reimport 或保存。

## 证据索引

- `runner_summary.csv`：正式 runner、capture、smoke、scan 与 Review-only 失败诊断。
- `log_marker_summary.csv`：12 组正式成功日志五类标记。
- `attempt_register.csv`：环境 scan 与 headless capture 排除尝试。
- `overlay_reconciliation.csv`：固定基线相对 overlay 核对及 manifest 单项状态错误。
- `protection_reconciliation.csv`：PNG、删除、Task57、保护文件、进程和共享零漂移。
- `visual_manifest.csv`、`visual_review.md`、`screenshots/`：本轮 fresh 七图 SHA 与原尺寸 QA。
- `logs/sidecar_before_formal_scan.csv`、`logs/sidecar_before_final_freeze_scan.csv`、`logs/sidecar_after_final_freeze_scan.csv`：sidecar 对账。
- `logs/13_review_shop_initial_visibility.log`：确定性复现的阻塞问题。
- `review_task58_shop_initial_visibility.gd`：Review-only 诊断夹具，未复制进候选。
- `command_ledger.md`：本轮命令、退出码与日志映射。
- `evidence_manifest.csv`：除自身外 Review evidence 的 bytes/SHA256。

未执行任何 Git 写操作；未修改冻结生产候选；未读取、运行或复制用户 `global_instakill` runner。
