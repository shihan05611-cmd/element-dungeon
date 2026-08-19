# 任务 64：契约层 getter 样板收敛

## 0. 阅读方式

这是一次**纯机械替换**，没有设计决策。硬约束是 §3 allowlist 与 §4 禁止项。
唯一需要动脑的地方是 §2 的「不许动」名单 —— 那 32 个 getter 里藏着真实语义。

**执行顺序**：与任务 62 / 63 无冲突，可任意顺序，但建议排在最后（它改的文件最多，先做会让别的任务 rebase 变麻烦）。

---

## 1. 背景事实（已验证）

`growth/contracts/` + `combat/contracts/` 共 50 个契约类，用「私有字段 `_x` + 只读 property getter」包装每个字段：

- `growth/contracts` 2044 行中约 **492 行**是纯 getter
- `combat/contracts` 1841 行中约 **366 行**是纯 getter
- 全部 286 个 getter 中，**零个有 setter** —— 本来就没有写语义，这层包装换来的保护很薄

而**项目内部已经有更简洁的先例**：`combat/execution/` 整个目录用「公有字段 + 静态工厂」写法
（见 `combat/execution/skill_execution_prepare_result.gd` 的 `success()` / `rejected()`），一直没出问题。

本任务把 contracts 层对齐 execution 层的写法。

---

## 2. 改动需求

### C1 — 平凡 getter 改公有字段

**254 个**形如下面这样的 getter，改为直接的公有字段：

```gdscript
var foo: Bar:
	get:
		return _foo
```

判定标准极简单：getter 体**只有** `return _<同名字段>` 一行。

外部调用点写法不变（`snapshot.foo` 照旧），所以**调用方一律不需要改**。

### C2 — 32 个非平凡 getter 必须原样保留

getter 体不是单纯 `return _x` 的，**一个都不许动**。它们分三类，每一类都有真实语义：

| 类 | 数量 | 例子 | 为什么不能动 |
| --- | --- | --- | --- |
| 防御性拷贝 | 11 | `return _owned_skill_ids.duplicate()` | 改公有字段会**泄露内部数组引用**，调用方能改到快照内部状态 |
| 计算值 | ~19 | `return _total_spent_on_purchases + _total_spent_on_upgrades`、`return _reaction_consumed > 0` | 没有对应的存储字段 |
| 常量 | 2 | `return 0` | 无字段可暴露（注：其中恒返回 0 / false 的僵尸开关由任务 62 负责删，本任务不碰） |

**判据**：改动后全项目 grep `.duplicate()` 在 contracts 目录的命中数与改动前**完全相同**。

### C3 — 静态工厂保持不变

契约上已有的 `success()` / `rejected()` / `copy()` / `is_valid()` / `legacy_enabled()` 等静态方法与实例方法**一律不动**。本任务只动字段的暴露方式。

---

## 3. Allowlist

- `growth/contracts/*.gd`
- `combat/contracts/*.gd`
- 本任务书（追加 §6）

**仅此三项。** 调用方按 C1 的设计本来就不需要改 —— 如果发现某处非改不可，说明该 getter 其实不平凡，**回去把它归到 C2**，不要改调用方。

---

## 4. 禁止项

- 不改任何调用方文件。触发要改调用方 = 分类错了，退回重判。
- 不动 `combat/execution/`、`combat/loadouts/` 等其他目录的契约（它们要么已经是目标写法，要么另案）。
- 不顺手重命名字段、不调整构造函数参数顺序、不加删字段。
- 不合并、不拆分契约类。
- 不动 git 历史，不提交（除非另行要求）。

---

## 5. 验收

这次没有行为变化，所以验收就是**证明什么都没变**。

改动前跑全部 `run_*.gd` 存基线，改动后重跑：

```bash
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://combat/tests/<file>.gd
```

通过标准：

1. **每个 `run_*.gd` 的测试数 / 断言数 / exit code 与基线逐一相同，零差异。**
   这一项没有例外可言 —— 出现任何数字变动都说明改错了。
2. `git status` 的改动文件集合 ⊆ §3 allowlist（即：只有 contracts 目录下的文件）。
3. contracts 目录内 `.duplicate()` 命中数不变。
4. 报告实际减少的行数。

> 已知前提：基线本来就有若干失败项（`run_task30_run_ui_tests`、`run_task31_content_balance_tests`、
> `run_task32_formal_four_passive_content_tests`、`run_task40_drag_compact_hud_tests`、`run_task58_*`），
> 与本任务无关，**失败的方式也必须和基线一模一样**，不要修。

---

## 6. 交付（执行者填写）

- 改写的契约清单 + 各自减少行数 + 合计
- C2 保留清单：32 个非平凡 getter 逐个列出，标注归入哪一类
- 基线 vs 改后的逐文件数字表（应当零差异）
- Allowlist 对账
- 发现但未做的事项
