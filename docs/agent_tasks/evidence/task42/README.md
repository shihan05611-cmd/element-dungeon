# Task42 正式证据说明

状态：`REVIEW`  
固定基线：`041928642bda41bdc1adc4b6ed16fa05db2ac17c`  
最终冷根：`C:\tmp\element-dungeon-task42-final-20260812-01`  
独立 profile：`C:\tmp\element-dungeon-task42-profile-20260812-01`

## 结论

- 生产仅将技能候选索引改为 `(stable_hash / 2) % candidates.size()`，解耦 50/50 类型最低位；未引入 RNG、权重、保底、历史或新框架。
- 两遍 512 cohort 都得到技能/梦尘 `256/256`；四候选技能分布均为 `element_reclaim=65`、`elemental_fury=65`、`elemental_laser=64`、`unending=62`。固定旧 HEAD 同 runner 为 `129/0/127/0` 并按预期失败，证明门禁覆盖旧偏差。
- 三个独立 Task31 进程结果逐字段一致：safe 为梦尘 `300`、技能 `elemental_laser|elemental_fury|element_reclaim`、账本 `895/300/300/105/400`；risk 为梦尘 `450`、技能 `elemental_laser|elemental_fury`、账本 `1150/390/115/0/645`。
- 授权的 Task40 迁移锁定入店前已拥有 `element_reclaim`、购买控件缺席、钱包/购买账本/revision 零购买变化，随后原 HUD/交换/恢复/authority 门禁完整通过。
- 全新成功 formal 批次 `33/33`，总计 `315 tests / 6790 assertions`；Task20 单列 `7/68`；RunGame/TestRoom 各 180 帧、非 headless capture 与 final editor rescan 均通过。

## 证据索引

- `logs/formal33/`：从头重生的 33 个正式 runner；汇总见 `csv/formal33_summary.csv`。旧中断 formal 批次未复制。
- `logs/task31_repeatability/`：三独立进程；逐字段表见 `csv/task31_repeatability.csv`。
- `logs/cohort_01.log`、`logs/cohort_02.log`：新候选两遍分布。
- `logs/expected_failure/old_head_distribution_gate.log`：固定旧 HEAD 的预期失败，仅用于证明四候选门禁；不计入成功日志扫描。
- `logs/task40_authorized_migration.log`、`logs/task20_non_gate.log`、两份 smoke、capture、initial scan 与 final rescan：其余执行证据。
- `csv/log_marker_summary.csv`：45 份成功日志逐文件扫描，`SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 五类合计均为 0。
- `screenshots/` 与 `csv/screenshots.csv`：4 张原尺寸 QA 图；safe 商店前/后为 `1920x1080`，safe/risk Results 为 `2560x1440`。

## 冷隔离与保护对账

- runner UID 为 `uid://d2hft1c3d3qe3`，SHA-256 `0156519851B30C94C6C6FFD53BFC804DD328BB17E5821E1853AB2DC4609ABC4E`；capture UID 为 `uid://d0bale15eq5sj`，SHA-256 `533279F55AD8F23B6F5A865742DD7D7F7EEB42B95206ADEEDA51B2E2DAED49C1`。两者均由此前不存在的冷根首次 4.7.1 scan 生成，并以 UID-first 顺序回流共享。
- 既有 `.uid/.import` 仍为 `658 files / 328030 bytes`，另有两枚 Task42 UID；622 个 tracked sidecar diff 为 0。Task41 runner/capture/tracked evidence diff 为 0；Task39 五 PNG/五 import `10/10` 哈希一致。
- 两份中文保护文档只做哈希核对，未读取内容且哈希不变；中枢 README 未修改。完整记录见 `csv/protected_document_hashes.csv`、`csv/task39_dependency_hashes.csv` 与 `csv/protection_reconciliation.csv`。
- 共享 Godot PID 52240 与 godot-ai PID 9908 始终被动保留。外部 editor 期间共享 `.godot` 从 `1110 files / 45800979 bytes` 漂到 `1111 / 45801258`，外部未跟踪保持 `36 .import + 50 .translation`；路径与时间见 `csv/external_untracked_sidecars.csv`，最新 `.godot` 路径/时间快照见 `csv/shared_godot_latest_files.csv`。这些外部文件没有被删除、修改、复制、认领、暂存或带入 Task42 evidence。
- 正式 evidence 只含本 README、日志、CSV 和 4 张 PNG；没有 `.import`、`.translation` 或冷 `.godot`。Git add/commit/push/reset/restore/checkout/clean/stash 均为 0。
