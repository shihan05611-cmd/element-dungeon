# Task58 rework1 L3 evidence

状态：`REVIEW / FROZEN`

- 固定基线：`51b8ffde0894fd430517225e693b7c44008038aa`
- 冷根：`C:\Users\heliashi\.codex\cold-roots\element-dungeon\task58-exec-rework1-20260814-02`
- 独立 profile：`C:\Users\heliashi\.codex\cold-roots\element-dungeon\task58-exec-rework1-profile-20260814-02`
- Godot：`4.7.1.stable.official.a13da4feb`
- 执行：`gpt-5.6-sol / high`，无子 Agent、无 Git 写入

## 首轮 FAIL 与修复

首轮独立 Review 冻结结论为 `FAIL`：正式 Overlay 在 SHOP 权威 snapshot 的同步监听器中显示，而 Coordinator 直到下一 deferred frame 才隐藏；Review-only 夹具捕获 `OVERLAY_VISIBLE_AT_SHOP_SNAPSHOT=true`、`SHOP_ROOM_ACTIVE_AT_SHOP_SNAPSHOT=false`。首轮 Review 证据仍保存在 Review worktree 的 `docs/agent_tasks/evidence/task58/review/`。

rework1 在既有 Coordinator allowlist 内修复：首次 SHOP snapshot 且 shop room 尚未创建时，同步执行 `_set_shop_ui_visible(false)`，再 deferred 创建房间。未修改 `RunOverlayInterface`。正式专项新增四个同信号栈断言，实测 Overlay 在外部 snapshot callback 当下已为 false，且 `active_shop_room` 仍为 null；随后皇冠 F 打开、重复交互、关闭重开和出口事务继续通过。

固定基线不含 Task58 任务书；顶层 `overlay_manifest.csv` 已由 `M` 更正为 `A`。

## rework1 L3 结果

- Task58：`3 tests / 81 assertions`。
- Task41/43/51/29/31/57：`20 tests / 900 assertions`。
- 总计：`23 tests / 981 assertions`，全部通过。
- fresh capture：`1 test / 7 images / 0 failures`；七张 `1920×1080` 均为本轮新字节并逐张 QA。
- RunGame 180 帧、cold-first scan、post-capture scan、final scan 均退出 0。
- 12 份正式日志五类标记全部为 0。
- final scan sidecar：`951 → 951`，差异 0。
- 非 evidence overlay：`10 D / 16 M / 6 A`，共 32 项；allowlist 差异 0。
- 六张正式 PNG 哈希保持；旧运行引用 0；十项旧文件不存在。
- protected diff 0；共享工作树无 `.godot`；PID17624/3964 存活且响应，未控制。

## 证据索引

- `logs/`：本轮 12 份正式日志及 final scan 前后 sidecar CSV。
- `screenshots/`、`visual_manifest.csv`、`visual_review.md`：本轮正式七图。
- `runner_summary.csv`、`log_marker_summary.csv`：正式门禁汇总。
- `overlay_reconciliation.csv`：固定基线状态与 allowlist 对账。
- `sidecar_reconciliation.csv`、`protection_reconciliation.csv`：冻结保护对账。
- `attempts/`、`attempt_register.csv`：本轮视觉取帧迭代，明确不计入正式结果。
- `evidence_manifest.csv`：除自身外 rework1 evidence 的 bytes/SHA256。
