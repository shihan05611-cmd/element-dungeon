# Task57 rework1 执行证据

状态：`REVIEW`（首轮独立 L3 Review 的间歇性专项失败已返工，等待重新独立 Review）

固定基线：`b080de734d8a9dd321a62ec13a4152b00b8989f7`

冷根：`C:\Users\heliashi\.codex\cold-roots\element-dungeon\task57-exec-rework1-20260814-01`

独立 profile：`C:\Users\heliashi\.codex\cold-roots\element-dungeon\task57-exec-rework1-profile-20260814-01`

## Review FAIL 与根因

首轮独立 L3 Review 的第一次专项为 `204/205`，唯一失败为 `formal Boss projectile remains operational without a dais`；同一 Review 的后两轮为 `205/205`，因此不能按稳定通过处理。

根因在 Task57 专项 runner 的正式 Boss 观测时序：runner 在 Boss 首次 physics tick 自动取得正式 RunGame Player 前就设置 `ai_enabled=false`，而生产 `enemy.gd` 的自动 Player 获取位于该早退之后；冷启动时手动 `_spawn_boss_projectile()` 因 `player` 尚无效而直接返回。原测试只等待一个 physics frame 后合并检查计数器与递归 delivery 数量，既没有等待正式 Player wiring，也没有捕获本次实例。

## 修复

只修改既有 allowlist 内的 `combat/tests/run_task57_full_room_background_collision_tests.gd`：

- 有界等待 Boss 主地面落稳且 `boss.player == coordinator.player`，证明正式 RunGame wiring 完成后才冻结 AI。
- 隔离自动 Boss cooldown，监听 `delivery_created` 并捕获本次实例。
- 最多等待 30 个 physics tick，要求同一实例有效、已进树、直属正式 coordinator、尚未结束、`distance_travelled > 0`，同时本次计数严格 `+1` 且正式树中存在 delivery。
- 保持专项为 `5 tests / 205 assertions`；没有固定 sleep、删除断言、仅计数放宽或绕开正式 RunGame。

## 返工门禁

- Task57 专项由 5 个独立 Godot PID 顺序执行，连续五次 `205/205`。
- Task41/43/51/29/31 各一次，合计 `15 tests / 695 assertions`，全部通过。
- 正式 RunGame 180 帧 smoke 与 final editor scan 均退出码 0。
- 13 份正式日志五类标记均为 0。
- final scan 前后 955 个受监控 sidecar：新增 0、删除 0、内容变化 0。
- 14 个生产文件与原冻结候选、workspace、rework 冷根三方 SHA-256 一致；因此复用原 6 图，并再次核对 6/6 图片哈希一致。
- 共享 `project.godot`、Player、Enemy、HUD blob 零漂移；共享 Godot PID 17624 与 godot-ai PID 3964 原样存活。

详表见 `rework_test_matrix.csv`、`production_hash_reuse.csv`、`visual_reuse_manifest.csv`、`log_marker_scan.csv`、`sidecar_stability.csv`、`protection_audit.csv`、两份完整 sidecar manifest 与 `rework_overlay.sha256`。
