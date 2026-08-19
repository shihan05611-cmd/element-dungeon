# 任务 65：收编未提交工作与清除 tmp 冷副本

## 0. 阅读方式

两件事，都是机械操作，**不改任何一行功能代码**。
目的不是"整理仓库"，而是让后续执行者一进来就能分清「哪些是我改的」——现在分不清。

硬约束是 §4 禁止项。

---

## 1. 背景事实（已验证）

- 最后一次提交是 **5 天前的 `09057fe task58`**。
- 此后 **183 个已跟踪文件被改动未提交**（+924 / −5807），另有 **16 个源码文件从未入库**，
  其中包含生产代码：Task61 的 `boss_form_definition.gd` / `boss_tuning.gd` / `boss_tide_ember.gd`
  与 6 个 boss 场景、Task59 的 `enemy_projectile_profile.gd`。
- 后果：新执行者 clone 后**拿不到 Task59/61 的代码**；在现有工作区里 `git diff` 有 183 个文件的噪音，
  无法分辨自己改了什么。任务 62 的执行者为此在交付记录里写了整整一段免责声明列举
  「哪些改动不是我干的」——那段声明本身就是被浪费掉的注意力。
- `tmp/` 下有 **440MB** 内容：4 份完整项目冷副本 + 2 个 zip + 1 个 Godot 缓存目录 + 1 个空目录。
  `.gitignore` 已在任务 62 加了 `tmp/`，但**目录仍在磁盘上，Godot 的 `res://` 扫描照样能看见**。
- `combat/tests/run_task58_formal_interactables_crown_sentry_tests.gd` 当前失败，**唯一原因**就是它扫到了
  `res://tmp/...` 冷副本里已退役的 chest/portal 场景。测试逻辑完全正确，是环境脏。

---

## 2. 改动需求

### H1 — 删除 `tmp/`

整个删掉 `tmp/`（440MB）。已确认无孤本：

- 4 份项目冷副本（`codex-global-instakill-validation-*`、`element-dungeon-task52-*`）是历史执行快照，
  正式产出早已在主干与 `docs/agent_tasks/evidence/` 中。
- `element-dungeon-task52-profile-20260813-02/` 里只有 Godot 的 `shader_cache`、`editor_doc_cache`
  和运行日志，不是证据；task52 的正式证据在 `docs/agent_tasks/evidence/task52/`。

**判据**：`tmp/` 不存在；`run_task58_*` 由 FAIL 转 PASS（这是本任务唯一一处测试数字变化，且是变好）。

### H2 — 收编未提交工作

把当前工作区的全部改动提交掉，**分两个 commit**：

| # | 内容 | 理由 |
| --- | --- | --- |
| 1 | 全部代码改动 + 16 个未入库源码文件 + 12 个未跟踪 `.uid` | 一个 commit 就够，原因见下 |
| 2 | `docs/` 下的 121 个 evidence 与文档改动 | 单独一个，日后 review 代码时可整段跳过 |

**为什么代码只能一个 commit**：任务 62 的样板替换叠在了 Task59/61 的未提交改动之上
（例如 `growth/tests/run_task41_physical_flow_waves_boss_tests.gd` 同时含两者），已经无法干净拆分。
不要为了好看去硬拆，说明清楚比拆错重要。commit message 里注明涵盖 Task59/60/61 产出与 Task62 净化即可。

**12 个未跟踪 `.uid` 一并入库**。`.uid` 是 Godot 4.4+ 给每个脚本分配的稳定标识
（内容就一行 `uid://xxxxx`），场景通过它引用脚本而非靠路径，脚本改名/移动时引用不会断。
不入库的话别人 clone 后 Godot 会重新生成不同的 uid，场景引用会失配报「脚本丢失」。
本项目已有 **384 个 `.uid` 入库**，惯例明确。

**判据**：`git status` 干净（除 `.gitignore` 已忽略项）；`git ls-files` 能查到那 16 个源码文件。

---

## 3. 必须活下来的东西

1. 任何功能代码的**内容**不得改动 —— 本任务只做「提交」和「删 tmp」，不做修改。
2. `docs/agent_tasks/evidence/` 全部保留，不删不迁（另案）。
3. 提交后从干净 clone 能跑通全部测试。

---

## 4. 禁止项

- **不改任何一行功能代码**。提交过程中若发现 bug，记在 §6，不要顺手修。
- 不 rebase、不 amend、不 force push、不改写历史。
- 不删 `docs/`、不删 `.godot/` 之外的任何非 `tmp/` 目录。
- 不为了「让 commit 好看」去硬拆已经交织的改动。
- 删 `tmp/` 前先确认 §2 H1 的三条无孤本结论仍然成立（磁盘状态可能已变）。

---

## 5. 验收

**删 tmp 前**先用批量 runner 存基线，**H1+H2 都做完后**重跑：

```bash
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://combat/tests/test_batch_runner.gd
```

通过标准：

1. `run_task58_formal_interactables_crown_sentry_tests` 由 `exit 1` 转 `exit 0`，
   **TOTAL 从 `45 files, 5 failed` 变成 `45 files, 4 failed`**。
2. 其余 44 个文件的 tests / assertions / exit code **与基线逐一相同**。
3. `git status` 干净。
4. 从一个干净 clone（或 `git stash -u` 后的工作树）能跑通 runner，结果与 2 一致 ——
   这一条是本任务的真正目的：**证明新执行者拿到的代码是完整的**。

> 其余 4 个失败（task30 / task31 / task32 / task40）不在本任务范围，
> 归后续调查任务处理，**不要去修**。

---

## 6. 交付（执行者填写）

- 两个 commit 的 hash 与涵盖范围
- 删除 `tmp/` 前后的磁盘占用
- 基线 vs 改后的逐文件数字表（应只有 task58 一处变化）
- 干净 clone 的验证结果
- 发现但未做的事项
