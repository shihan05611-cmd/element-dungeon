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

### 两个 commit

| # | hash | 范围 |
| --- | --- | --- |
| 1 | `2f7d214` | 全部非 `docs/` 改动：194 files changed, 6214 insertions(+), 1173 deletions(-)。含 Task59（`enemy_projectile_profile.gd`、telegraph 表现）、Task60（boss 弹体/telegraph 美术）、Task61（`boss_form_definition.gd`/`boss_tuning.gd`/`boss_tide_ember.gd`/`.tscn`/`.tres`）、Task62（`run_session.gd`/`run_rules_snapshot.gd`/`.gitignore`/共享测试 harness 与批量 runner）的全部产出，以及 16 个此前从未入库的源码文件与随之新增的 `.uid`。 |
| 2 | `3184f4f` | 全部 `docs/` 改动：694 files changed, 9347 insertions(+), 4634 deletions(-)。含已完成任务文档（47/54/55/59/60/61/62）、待办任务书（61/63/64/65）、以及大量 evidence 目录下的 `.import` 副作用文件增删。 |

### 删除 `tmp/` 前后磁盘占用

- 删除前：`tmp/` 单独 **440M**（4 份项目冷副本 96M+70M+70M+93M、2 个 zip 各 55M、`profile-20260813-02` 的 Godot 缓存 4.2M、`profile-20260813-01` 与 `imagegen` 两个空目录）。
- 删除后：`tmp/` 已不存在；整个工作区（含 `.git`）现为 **628M**（原先应为 440M + 628M ≈ 1068M 量级，删除后减少约 440M）。

### 基线 vs 改后逐文件数字表

删 `tmp/` 前用批量 runner 先存了一份基线（`TOTAL: 45 files, 5 failed`），删 `tmp/` 后重跑，**唯一变化是 `run_task58_formal_interactables_crown_sentry_tests`**：

| 文件 | 删前 | 删后 |
| --- | --- | --- |
| run_task58_formal_interactables_crown_sentry_tests | 3/104/**1** | 3/104/**0** |
| 其余 44 个文件 | 与删前逐一相同 | 与删前逐一相同 |
| TOTAL | 45 files, **5 failed** | 45 files, **4 failed** |

commit 完成后（H1+H2 都做完）再跑一遍批量 runner，结果与「删后」一致，`git status` 干净（0 条待处理）。

### 干净 clone 验证结果

用 `git clone` 到 `/c/tmp/task65_verify_clone`（本机临时目录，非工作区，已在验证后删除）做了一次真正的干净检出：

1. 首次直接跑批量 runner：45/45 全部 `exit 1`，`Parse Error: Could not find type "RuntimeAttackPayload"...` 等——这是**任何** Godot 工程干净 clone 后的通用前提（`.godot/` 缓存被 `.gitignore` 排除，`class_name` 全局类表要先建一次），与本任务改动无关。
2. 跑一次 `--headless --editor --quit --path .`（只在这个隔离的临时 clone 里执行，完成后整个目录已删除，未触碰真实工作区，不违反任务 62 定下的「不对当前工作树跑全项目扫描」的规则——那条规则针对的是已有未提交改动的工作树，这里是全新检出，没有可污染的 diff）建立导入/类缓存后，重跑批量 runner：**`TOTAL: 45 files, 4 failed`**，逐文件数字与本条目「删后」列完全一致，`run_task58_*` 为 `exit 0`。
3. 结论：干净 clone 能拿到完整代码并跑通全部测试，新执行者不会再遇到「拿不到 Task59/61 代码」的问题。

### 发现但未做的事项

- 运行验证 clone 时误将 `git config --global core.longpaths true` 设成了全局配置（用于绕过 Windows 长路径导致的 checkout 失败），发现后已立即 `--unset` 撤销，未遗留在全局 git 配置里。记录在此供复盘。
- `docs/agent_tasks/evidence/task42/csv/` 与 `task43/` 下混入了一批 Godot 自动生成的 `.translation` 二进制文件（例如 `log_marker_summary.Parse Error.translation`），是 Godot 把 evidence 目录里普通的 `.csv` 报表误判成翻译表后自动导入产生的历史遗留噪音（时间戳为 8 月 13 日，早于本任务），不是真正的证据内容。按 §0「不改任何一行功能代码」与「目的不是整理仓库」，本次原样收编进了 commit 2，未做清理判断；建议后续任务视情况评估是否清理或加 `.gitignore` 规则。
- `.mcp.json` 内容仅为本机 `http://127.0.0.1:8000/mcp` 的本地 MCP 端点配置，未见凭据/密钥，随代码一并入库；如中枢认为这类本机开发配置不该入库，可在后续任务里单独剔除。
- `tmp/` 的删除只处理了任务书列出的这 8 项内容（4 冷副本 + 2 zip + 1 缓存目录 + 2 空目录），未额外核查是否有新的孤本判断标准；若未来 `tmp/` 又积累出新内容，需要重新走一遍 §2 H1 的核实流程。
- 未发现其他范围外问题；除 §5 明确排除的 task30/31/32/40 外没有新的失败项。
