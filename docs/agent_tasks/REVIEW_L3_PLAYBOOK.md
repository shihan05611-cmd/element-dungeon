# Review L3 严格验收附录

本附录只在任务书标记 `Review Level: L3`，或 L1/L2 输出 `ESCALATE -> L3` 后读取。日常 L1/L2
不得被本文件的冷副本、全量哈希或证据包要求反向绑架。

## 1. 冻结输入

L3 开始前固定并记录：

- Git 基线 commit；
- 任务书版本、精确 allowlist 和依赖版本；
- 执行者冻结文件及 evidence 清单；
- 共享工作区已有 tracked/untracked 修改、保护文件、sidecar、`.godot` 与编辑器进程；
- 哪些历史失败日志只作说明，不属于成功门禁。

候选必须能由“固定 Git 基线 + 精确冻结 overlay”重建。Review 不在共享项目修复候选。

## 2. Godot 冷副本与 profile

1. 在此前不存在的 `C:\tmp\element-dungeon-taskNN-review-<date>-<seq>` 建立 Review 根；不得复用
   执行根、旧 Review 根或旧截图。
2. 优先从固定 commit 的 Git 对象导出基线，再逐项叠加 allowlist 文件；不把 live 工作树整目录
   宽泛复制为候选。
3. 候选不包含 `.git`、共享 `.godot`、任务外未跟踪文件或保护文档。
4. profile 位于候选外的独立目录，并为 Review 进程设置独立 `APPDATA`、`LOCALAPPDATA` 等
   Godot 用户数据位置；不得连接、关闭或驱动共享 Godot/editor/godot-ai。
5. 若归档 evidence 中的 CSV 会被 Godot 误识别为翻译表，可在第一条 Godot 命令前创建冷根专用
   0-byte `docs/agent_tasks/evidence/.gdignore`。它不得进入共享项目、正式 evidence 或 Git。
6. 第一条 Godot 命令必须是任务书指定版本的 headless editor scan；本项目当前基准为 Godot
   `4.7.1`。记录版本、退出码和完整日志。

## 3. 回归集合

按任务书依次运行：

1. 专项 runner；
2. 直接依赖 runner；
3. 完整影响域回归；只有任务书要求或影响无法收束时才扩大为全量；
4. 历史非门禁 runner 单列运行、单列结论，不得借通过追认历史任务；
5. 相关主场景 smoke；
6. 视觉/交互 capture；
7. final editor rescan。

每个正式命令记录命令、Godot 版本、退出码、tests/assertions/images 和日志路径。发现确定性失败
立即停止并回传；Review 不修复。

## 4. 日志扫描

成功门禁日志统一扫描：

```text
SCRIPT ERROR
Parse Error
ERROR:
WARNING:
CrashHandlerException
```

正式成功日志五类标记必须为 0，除非任务书对已知第三方输出给出精确例外。预期失败、旧实现
辨识和 Review harness 失误必须放在独立目录并明确排除，不能混入成功汇总。

## 5. 截图与实际画面

- 只有视觉、UI、交互、场景几何或任务书明确要求时才重新生成截图；数量按任务书，不机械复制
  历史大矩阵。
- 截图必须来自本轮候选，保存前由 runner 断言关键权威状态、节点和分辨率。
- Review 至少以原尺寸打开每张最终图，检查目标行为、裁切、遮挡、对比度、可读性和实际构图。
- 记录尺寸、bytes、SHA256 与生成时间；重复运行时证明文件被本轮覆盖。
- 冷副本生成的截图 `.import` 不回流正式 evidence。

分辨率覆盖遵循 `README.md`：L3 UI 默认覆盖完整 P0/P1/P2 边界；任务书可用程序化断言替代
部分重复截图，但不能省略相应安全区与可读性检查。

## 6. SHA、allowlist 与 sidecar

- 逐项比较固定基线、冻结 overlay、Review 候选和共享交付；任务 allowlist 外源文件变化为阻塞。
- 新 `.gd.uid` 或 `.import` 必须由任务书逐项授权，并核对 UID 唯一性、source_file、bytes 与
  SHA；不得认领共享编辑器生成的其他 sidecar。
- 首次 scan 前保存既有候选 sidecar 基线；final rescan 后核对 missing/changed/new。
- 证据 manifest 应排除自身避免哈希循环，并逐项验证路径、bytes、SHA256。
- 不要求对无关缓存做无意义的全项目哈希；但任务依赖、保护项、allowlist 和已声明不变集合必须
  完整对账。

## 7. 性能 before/after

仅当任务目标包含性能，或修改明确命中热路径时执行：

1. 固定同一机器、版本、输入、窗口/无头模式和测试夹具；
2. 基线与候选各预热至少 1 次，再各测至少 5 轮；
3. 报告每轮数据、中位数和最差值，不能只挑最快结果；
4. 波动超过约 10% 或结论接近门槛时增至至少 10 轮，并说明噪声；
5. 同时验证行为/输出不变，性能改善不能以削弱正确性门禁换取。

## 8. 共享工作区零漂移

L3 前后只读核对：

- tracked/untracked status；
- 共享 `.godot` 文件数、bytes 和必要的最新时间；
- `.gd.uid`、`.import`、`.translation` 的精确新增或漂移；
- 任务外保护文件的 bytes/SHA；
- 共享 Godot/editor/godot-ai 进程状态。

Review 不删除、恢复、暂存或认领共享区的来源无关内容。出现外部并发变化时记录所有权；只有它
影响候选真实性或验收结论时才阻塞。

## 9. 独立 evidence 包

L3 evidence 通常放在 `docs/agent_tasks/evidence/taskNN/`，最小包含：

- `README.md`：基线、候选、profile、结果、例外和残余风险；
- `logs/`：本轮成功正式日志；
- 汇总 CSV：runner 结果、日志标记、allowlist/SHA、保护对账；
- `screenshots/`：仅在任务需要时；
- manifest：列出自身以外正式证据的相对路径、bytes、SHA256。

正式 evidence 不含 `.godot`、`.gdignore`、`.import`、`.translation`、旧失败截图或临时包装器
输出。失败证据可以留在 Review 冷根，并在回传中给出绝对路径。

## 10. L3 结论清单

- 候选可由固定基线和精确 overlay 重建；
- 第一条 Godot 命令、profile 和共享编辑器隔离正确；
- 专项、影响域回归、smoke、视觉和 final scan 达到任务书门禁；
- 正式日志五类标记为 0；
- allowlist、UID/import、证据 manifest 与共享零漂移核对通过；
- 性能任务具有可重复 before/after；
- 输出 `PASS / FAIL`；若需求或任务书本身仍缺权威决定，输出 `ESCALATE` 给中枢。
