# 任务 46：归档 evidence 的 Godot 导入隔离

状态：ACCEPTED
负责人：独立执行任务（中枢派发）
依赖：任务 43（ACCEPTED）
Git 基线：`main` HEAD `03b2374b6dfedda20123c7c2a5fb5ee00950e4f1`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L2
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级触发：若根级 `.gdignore` 不能递归阻止 evidence CSV 被识别为翻译表，或必须修改历史 evidence/manifest、`project.godot`、游戏代码、共享 `.godot`、既有 `.translation`，立即停止并回传中枢；不得擅自扩大范围。

## 1. 问题与目标

`docs/agent_tasks/evidence/` 内的日志汇总 CSV 表头含 `SCRIPT ERROR`、`ERROR:`、`WARNING:` 等列。Godot 将其误判为翻译表，并尝试生成含非法 Windows 文件名字符的 `.translation` 与 editor folding 路径，导致共享编辑器反复出现“加载错误”。

2026-08-13 本任务派发前只读盘点：evidence 下有 `51` 个 CSV、`329` 个 `.translation`、`0` 个 `.gdignore`。接手基线记录仅有 `189` 个 translation，表明扫描产物仍在增长。

本任务只负责切断后续生成源，并使 Review 冷副本规则与永久隔离屏障一致；不在共享编辑器运行期间删除既有缓存或生成物。

## 2. 实现要求

1. 新增 `docs/agent_tasks/evidence/.gdignore`，以目录级永久屏障阻止 Godot 递归扫描归档 evidence；文件内容须说明用途，不改变 evidence 对 Git、Agent 或普通文件工具的可读性。
2. 更新 `docs/agent_tasks/REVIEW_L3_PLAYBOOK.md` 中冷副本 `.gdignore` 规则：正式候选应携带项目内永久屏障；旧基线若尚无该文件，才允许在冷根第一条 Godot 命令前创建临时屏障，且临时文件不得回流。
3. 不改任何历史 CSV、日志、截图、manifest 或已归档任务结论。

## 3. 精确 allowlist

允许修改或新增：

1. `docs/agent_tasks/evidence/.gdignore`
2. `docs/agent_tasks/REVIEW_L3_PLAYBOOK.md`
3. `docs/agent_tasks/pending/46_evidence_godot_import_isolation.md`
4. `docs/agent_tasks/evidence/task46/**`，仅用于本任务隔离验证的文本证据；不得放入会再次触发导入的 CSV

## 4. 保护与禁止项

1. 不修改 `project.godot`、游戏代码、场景、资源、测试 runner 或 Task 42/43 历史 evidence。
2. 不删除、移动、重命名、暂存或认领当前共享区的 `.translation`、`.import`、无扩展名 Godot 产物、中文保护文档或 `.godot` 内容。
3. 不连接、关闭、重启或控制共享 Godot/editor/godot-ai；不运行任何 Git 写命令，不 push，不自行写 `ACCEPTED`。
4. 不以改 CSV 表头、改扩展名或重写历史 manifest 规避问题。
5. 当前中枢未提交的 `docs/agent_tasks/CENTRAL_REVIEW_RULES.md` 与 `docs/agent_tasks/README.md` 属于模型规则变更，任务 46 不得修改。

## 5. L2 验收与证据

1. 静态确认 `.gdignore` 位于 evidence 根且历史 evidence 文件 bytes/SHA 不变。
2. 在全新隔离副本和独立 profile 中运行 Godot `4.7.1` headless editor scan；不得使用或驱动共享编辑器。
3. scan 前后证明 evidence 下未新增或改写 `.translation`，日志中不再出现 `log_marker_summary.*.translation` 写入错误。
4. 确认项目脚本/场景仍被正常扫描，屏障只覆盖归档 evidence。
5. 记录命令、退出码、日志标记和 before/after 数量；证据使用 Markdown/TXT，不使用 CSV。
6. 执行开始改为 `IN_PROGRESS`，交付改为 `REVIEW`；最终 `ACCEPTED` 仅由中枢给出。

## 6. 后续缓存清理边界

本任务通过后，只能证明后续生成源已被切断。既有 `329` 个 `.translation` 与 `.godot/editor` 缓存仍按共享保护项处理；是否在用户主动关闭共享 Godot 后另立精确清理任务，由中枢基于文件清单和所有权再决定。

## 7. 执行交付（2026-08-13）

- 实际模型：`gpt-5.6-sol`，thinking=`high`。
- 新增 `docs/agent_tasks/evidence/.gdignore`；注释明确它是 Godot 归档 evidence 导入边界，
  不影响 Git、Agent 与普通文件工具读取。
- 仅修改 `REVIEW_L3_PLAYBOOK.md` 的冷副本 `.gdignore` 条款：正式候选携带永久屏障；只有旧基线
  缺失时才允许在第一条 Godot 命令前建立不回流的临时 0-byte 屏障。
- 成功隔离根：`C:\tmp\element-dungeon-task46-exec-20260813-02`；独立 profile：
  `C:\tmp\element-dungeon-task46-profile-20260813-02`。
- Godot `4.7.1.stable.official.a13da4feb` headless editor scan 退出码 `0`；日志七类目标标记均为 `0`。
- 冷副本 evidence 在 scan 前后均为 `51 CSV / 140 translation / 121 import`，`1522` 个历史文件
  bytes 与聚合 SHA-256 完全一致；项目脚本/场景文件系统缓存仍正常生成。
- 共享历史 evidence 执行前后均为 `51 CSV / 329 translation / 195 import / 0 无扩展名`，
  `1789 files / 30,700,276 bytes` 与聚合 SHA-256
  `caa84fda93fc58a6ba199d4e8987fb8e3d5d40d09d7e3eb24eaa4411c8d8630b` 完全一致。
- 证据：`docs/agent_tasks/evidence/task46/README.md` 与
  `docs/agent_tasks/evidence/task46/godot_4.7.1_editor_scan.txt`。
- 剩余风险：共享既有 `329` 个 `.translation`、`195` 个 `.import` 和 `.godot/editor` 缓存
  仍受保护且未清理；本任务只证明后续生成源已切断。
- 未连接、关闭、重启或控制共享 Godot/editor/godot-ai；Git 写操作为零，未 push。

## 8. 中枢独立 L2 Review（2026-08-13）

- 结论：`PASS / ACCEPTED`。
- Review 模型：`gpt-5.6-sol`；静态核对确认候选严格位于精确 allowlist，永久 `.gdignore`、L3 冷副本规则和文本 evidence 均符合任务书。
- 独立冷根：`C:\tmp\element-dungeon-task46-review-20260813-01`；独立 profile：`C:\tmp\element-dungeon-task46-review-profile-20260813-01`。
- 从固定基线 `03b2374b6dfedda20123c7c2a5fb5ee00950e4f1` 重建候选并叠加 Task 46 精确 overlay；Godot `4.7.1.stable.official.a13da4feb` headless editor scan 退出码 `0`。
- Review scan 前后均为 `51 CSV / 140 translation`；`SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:`、`CrashHandlerException`、`log_marker_summary`、`.translation` 日志命中均为 `0`。
- 本任务只切断后续生成源。共享既有 `329` 个 `.translation`、`195` 个 `.import` 与 `.godot/editor` 缓存继续作为受保护遗留项，不在本任务中清理。
