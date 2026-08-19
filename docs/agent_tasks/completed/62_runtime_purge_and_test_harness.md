# 任务 62：运行时净化与测试框架收敛

## 0. 阅读方式

本任务书只规定**做什么**和**边界在哪**。实现方式由执行者自行决定，不需要预先报备设计、不需要逐行规格。
硬约束只有两条：§3 的 allowlist，和 §4 的禁止项。其余靠 §5 的数字对账兜底。

---

## 1. 改动需求

### N1 — 消除每帧快照重建

`scripts/run_session_host.gd:361` 每帧调用 `RunSession.advance_relics(delta)`，返回值直接丢弃。
但 `growth/run_session.gd:884` 的两条「无变化」分支仍会走 `RunCommandResult.success(snapshot())`，每帧重建整棵 `RunSnapshot`（16 个子快照 + 每个已拥有技能一个 `SkillProgressSnapshot` + 数组 `duplicate()`）。

**要求**：遗物无变化时不再构建 `RunSnapshot`。`RunCommandResult.success()` 的 `p_run_snapshot` 本就默认 `null`，不需要新增契约字段。

**判据**：`relic_mode != ENABLED` 与 `_relic_controller.advance()` 返回 false 两条路径都不再触达 `snapshot()`；有变化时的 `_commit_and_publish` 路径行为不变。

### N2 — 删除僵尸开关

`growth/contracts/run_rules_snapshot.gd` 中三个 getter 恒返回常量，生产代码零引用：

- `terminal_enemy_dream_dust_reward` → 恒 `0`
- `terminal_room_dream_dust_reward` → 恒 `0`
- `terminal_shop_enabled` → 恒 `false`

**要求**：删除这三个 getter，同时删除断言其恒定值的测试用例。唯二引用点：
`growth/tests/run_task27_run_economy_progression_tests.gd`、`growth/tests/run_task31_content_balance_tests.gd`。

**判据**：全项目（排除 `tmp/`）grep 这三个标识符为零命中。

### N3 — 仓库卫生（只加忽略，不追溯清理）

`.gitignore` 没有 `tmp/`，而 `tmp/` 下躺着 4 份完整项目冷副本，一次 `git add -A` 就会入库。

**要求**：`.gitignore` 追加 `tmp/`。

**不做**：不删除、不迁移、不 LFS 化已跟踪的 `docs/agent_tasks/evidence/`。那是另案决策。

### N4 — 测试框架收敛

`combat/tests/` + `growth/tests/` 共 46 个 `run_*.gd`，每个都复制了同一套
`_failures / _assertions / _tests / _run() / _expect()` 样板，且没有统一入口，跑全量要手敲 40 多条命令。

**要求**：

1. 抽出一个共享 harness，供 `extends SceneTree` 的测试脚本复用；46 个 `run_*.gd` 改为复用它，删掉各自的重复样板。
2. 提供一个批量 runner，一条命令跑完全部 `run_*.gd`，输出逐文件的「文件名 / 测试数 / 断言数 / exit code」汇总。
3. 21 个 `capture_*.gd` 截图脚本本次不动。

**判据**：见 §5。测试的**断言内容一行都不改**，这一项纯粹是搬运样板。

---

## 2. 已知前提（别当成 bug 去修）

改动前基线本来就有 6 个失败项，与本任务无关，**不要顺手修**：

`run_task30_run_ui_tests`、`run_task31_content_balance_tests`、`run_task32_formal_four_passive_content_tests`、`run_task40_drag_compact_hud_tests`、`run_task58_*`。
另外 `run_task34_performance_tests` 无 PASS/FAIL 文本、纯 JSON 输出、exit 0，属正常。

`combat/tests/run_global_instakill_tests.gd` 是保护项：不改，也不纳入 runner 默认集。

---

## 3. Allowlist（可改文件，此外一律不动）

| 文件 | 允许的改动 |
| --- | --- |
| `growth/run_session.gd` | 仅 `advance_relics` |
| `growth/contracts/run_rules_snapshot.gd` | 仅删三个 getter |
| `growth/tests/run_task27_run_economy_progression_tests.gd` | 仅删 `terminal_*` 断言 |
| `growth/tests/run_task31_content_balance_tests.gd` | 仅删 `terminal_*` 断言 |
| `.gitignore` | 仅追加 `tmp/` |
| `combat/tests/run_*.gd`、`growth/tests/run_*.gd` | 仅样板替换 |
| 新建 2 个文件 | 共享 harness × 1，批量 runner × 1，路径自定（建议 `combat/tests/` 下） |
| 本任务书 | 追加 §6 交付小结 |

清单外的任何文件一律不动，包括 `scripts/`、`combat/` 生产代码、`.tscn`、`.tres`、`capture_*.gd`。

---

## 4. 禁止项

- **不做范围外重构**。路上看到的其他问题记在 §6「发现但未做」里，不要动手。
- **不改任何断言语义**，不靠删失败用例让数字变好看。
- **不跑 `--headless --editor --quit` 全项目扫描** —— 它会给既有文件批量生成 `.uid` sidecar，污染 diff。若新增 `class_name` 确实必须扫描，扫完把非本任务文件的 sidecar 变更全部还原，并在 §6 披露。
- **不动 git 历史**，不 force push，不提交（除非另行要求）。

---

## 5. 验收

改动前先跑一遍基线存档，改动后重跑，逐文件比对。

```bash
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://combat/tests/<file>.gd
```

通过标准：

1. **每个 `run_*.gd` 的「测试数 / 断言数 / exit code」与基线逐一相同。** 唯一允许的差异是 N2 删掉的 `terminal_*` 用例（体现在 `run_task27` 与 `run_task31` 上），需在 §6 写明各减少了几条。
2. 新 runner 一条命令跑完全集并给出汇总表。
3. `git status` 的改动文件集合 ⊆ §3 allowlist。
4. N1 说明在哪一行避开了 `snapshot()`，并确认「有变化」路径未改。

---

## 6. 交付（执行者填写）

### 改动文件清单（对照 §3）

- [x] `growth/run_session.gd` — 仅 `advance_relics`（N1）
- [x] `growth/contracts/run_rules_snapshot.gd` — 仅删三个 getter（N2）
- [x] `growth/tests/run_task27_run_economy_progression_tests.gd` — 删 `terminal_*` 断言（N2）+ 样板替换（N4）
- [x] `growth/tests/run_task31_content_balance_tests.gd` — 删 `terminal_*` 断言（N2）+ 样板替换（N4）
- [x] `.gitignore` — 追加 `tmp/`（N3）
- [x] `combat/tests/run_*.gd`、`growth/tests/run_*.gd` — 42/46 个样板替换（N4，明细见下）
- [x] 新建 `combat/tests/test_harness.gd`（共享 harness）
- [x] 新建 `combat/tests/test_batch_runner.gd`（批量 runner，动态扫描目录，一条命令跑全部）
- [x] 本任务书 — 追加本 §6

**N4 样板替换范围**：46 个 `run_*.gd` 中，`run_global_instakill_tests.gd`（§2 保护项，不改）、`run_task34_performance_tests.gd`（JSON 专项输出，无共享样板可抽）、`run_delivery_skill_integration_test.gd`、`run_growth_session_isolation_test.gd`（两者均为单测试脚本，从未使用 `_tests/_assertions/_run_test/_expect` 样板，无重复可删）不纳入样板替换，其余 **42 个**全部改为复用 `TestHarness`（`const TestHarness := preload("res://combat/tests/test_harness.gd")`）。

### N1 说明

`growth/run_session.gd:887-891`：`relic_mode != ENABLED` 分支（888 行）与 `_relic_controller.advance(delta)` 返回 `false` 分支（891 行）均改为 `RunCommandResult.success()`（不传 snapshot，默认 `null`），不再触达 `snapshot()`。890 行「有变化」路径（`_commit_and_publish`）未改。

### 基线 vs 改后逐文件数字表（tests/assertions/exit）

| 文件 | 基线 | 改后 |
| --- | --- | --- |
| run_agent_d_growth_integration_tests | 10/145/0 | 10/145/0 |
| run_agent_d_integration_tests | 9/73/0 | 9/73/0 |
| run_combat_tests | 27/124/0 | 27/124/0 |
| run_compact_hud_reward_tests | 7/68/0 | 7/68/0 |
| run_delivery_reuse_tests | 10/105/0 | 10/105/0 |
| run_delivery_skill_integration_test（未改） | 1/4/0 | 1/4/0 |
| run_delivery_tests | 16/56/0 | 16/56/0 |
| run_first_batch_delivery_tests | 26/163/0 | 26/163/0 |
| run_global_instakill_tests（保护项，未改） | -/7/0 | -/7/0 |
| run_growth_06_contract_tests | 10/84/0 | 10/84/0 |
| run_growth_contract_edge_tests | 4/10/0 | 4/10/0 |
| run_growth_session_isolation_test（未改） | 1/5/0 | 1/5/0 |
| run_growth_tests | 25/155/0 | 25/155/0 |
| run_hud_loadout_feedback_tests | 13/113/0 | 13/113/0 |
| run_passive_runtime_contract_tests | 6/65/0 | 6/65/0 |
| run_reward_authority_tests | 3/15/0 | 3/15/0 |
| run_skill_content_catalog_tests | 11/236/0 | 11/236/0 |
| run_skill_execution_contract_tests | 16/102/0 | 16/102/0 |
| run_skill_tests | 28/144/0 | 28/144/0 |
| run_skill_vfx_runtime_tests | 9/124/0 | 9/124/0 |
| run_task24_compact_hud_reward_tests | 10/237/0 | 10/237/0 |
| run_task25_immediate_shop_equip_tests | 8/242/0 | 8/242/0 |
| **run_task27_run_economy_progression_tests** | 11/**315**/0 | 11/**312**/0（N2 减 3 条 `terminal_*` 断言） |
| run_task27_skill_level_effect_tests | 7/86/0 | 7/86/0 |
| run_task28_seven_slot_passive_tests | 6/154/0 | 6/154/0 |
| run_task29_real_room_flow_tests | 1/74/0 | 1/74/0 |
| run_task29_run_flow_contract_tests | 6/128/0 | 6/128/0 |
| run_task30_run_ui_tests（已知基线失败） | -/93/1 | 9/93/1 |
| **run_task31_content_balance_tests**（已知基线失败） | -/**276**/1 | 9/**273**/1（N2 减 3 条 `terminal_*` 断言） |
| run_task31_full_run_e2e_tests | 4/393/0 | 4/393/0 |
| run_task32_formal_four_passive_content_tests（已知基线失败） | -/167/1 | 5/167/1 |
| run_task34_performance_tests（JSON 专项，正常） | -/-/0 | -/-/0 |
| run_task34_projectile_cast_transaction_tests | 11/211/0 | 11/211/0 |
| run_task38_reclaim_reaction_energy_tests | 3/38/0 | 3/38/0 |
| run_task40_drag_compact_hud_tests（已知基线失败） | -/75/1 | 4/75/1 |
| run_task41_physical_flow_waves_boss_tests | 4/96/0 | 4/96/0 |
| run_task42_reward_economy_tuning_tests | 3/2206/0 | 3/2206/0 |
| run_task43_combat_loadout_world_cleanup_tests | 4/105/0 | 4/105/0 |
| run_task48_dodge_integration | 5/56/0 | 5/56/0 |
| run_task49_five_stage_demo_flow_tests | 5/103/0 | 5/103/0 |
| run_task51_boss_projectile_spawn_clearance_tests | 2/49/0 | 2/49/0 |
| run_task56_dodge_live_enemy_passthrough_tests | 4/36/0 | 4/36/0 |
| run_task57_full_room_background_collision_tests | 5/205/0 | 5/205/0 |
| run_task58_formal_interactables_crown_sentry_tests（已知基线失败） | -/104/1 | 3/104/1 |
| run_task59_enemy_projectile_profile_tests | 10/116/0 | 10/116/0 |
| run_task61_boss_three_form_tests | 17/87/0 | 17/87/0 |

除 `run_task27_run_economy_progression_tests`、`run_task31_content_balance_tests` 各减 3 条断言（N2 预期结果）外，**其余 44 个文件的 tests/assertions/exit code 与基线逐一相同**。表中「基线 tests 为空」的 5 个已知失败文件（task30/31/32/40/58）是因为改动前 `_run_test` 在 FAILED 分支不打印测试数，只打印 `N failures / M assertions`；改后共享 `TestHarness.report()` 统一在 FAILED 分支也打印 `失败数/测试数, 断言数`，因此改后能解析出测试数——这是纯粹的输出格式补全，failures 条数、assertions 数、exit code 均与基线完全一致（已逐一核对日志原文）。

批量 runner（`Godot --headless --path . --script res://combat/tests/test_batch_runner.gd`）一条命令跑完默认集合（45 个，动态扫描目录并排除 `run_global_instakill_tests.gd`），实测汇总：`TOTAL: 45 files, 5 failed`，与上表已知基线失败集合完全一致。

### Allowlist 对账

`git status --porcelain` 中属于本任务的改动文件集合 = §3 允许清单的子集，无越界。核对时排除的非本任务改动（均为改动前已存在于工作树的未提交内容，未接触）：
`assets/`、`combat/components/combat_receiver.gd`、`combat/contracts/*`、`combat/resolvers/*`、`combat/tests/capture_task41_physical_flow_visuals.gd`、`combat/tests/capture_task57_full_room_backgrounds.gd`、`docs/agent_tasks/completed/53_*`、`docs/agent_tasks/evidence/*`、`docs/art/潮汐地牢_TileSet美术交付合同.md`、`project.godot`、`resources/run/rooms/combat_06_final_boss.tres`、`scenes/enemy.tscn`、`scenes/run/enemies/tidal_sentry.tscn`、`scripts/combat_hud.gd`、`scripts/enemy.gd`、`scripts/player.gd`、`scripts/run/enemies/tidal_sentry.gd`、`scripts/vfx/fury_vfx_presentation.gd`，以及大量 `assets/` 下未跟踪的美术资产/`.import`、`.mcp.json`、`CLAUDE.md` 等未跟踪文件。

**运行测试产生的 `.uid` 副作用（披露）**：按 §5 要求用 `--headless --path . --script res://...` 逐个/批量运行测试是必需的验收动作，Godot 4.7 在加载脚本时会为尚无 `.uid` 的 `.gd` 文件自动生成同名 `.uid` 文件（与 §4 禁止的「`--headless --editor --quit` 全项目扫描」是两回事——全程未执行过整项目扫描，也未新增任何 `class_name`）。运行后新增的 `.uid` 未跟踪文件：`combat/tests/capture_task57_full_room_backgrounds.gd.uid`、`combat/tests/capture_task58_formal_interactables_crown_sentry.gd.uid`、`combat/tests/run_task57_full_room_background_collision_tests.gd.uid`、`combat/tests/run_task58_formal_interactables_crown_sentry_tests.gd.uid`、`combat/tests/run_global_instakill_tests.gd.uid`、`combat/tests/run_task59_enemy_projectile_profile_tests.gd.uid`、`combat/tests/run_task61_boss_three_form_tests.gd.uid`。均为运行测试的正常副作用，未删除也未提交，留待中枢决定是否入库；本任务未修改任何既有 `.uid` 的内容。另注意到 `combat/tests/run_global_instakill_tests.gd`、`run_task59_enemy_projectile_profile_tests.gd`、`run_task61_boss_three_form_tests.gd` 三个文件在改动前就已经是未跟踪状态（工作树里存在但从未提交），非本任务引入。

### 发现但未做的事项

- `growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd` 的原 `_expect` 在失败时额外调用了 `push_error("FAIL: %s" % message)`；改动后保留了这一行为（未删），只是把计数部分委派给 `TestHarness`，不属于纯样板但予以保留以免改变可观察行为。
- `growth/tests/run_task49_five_stage_demo_flow_tests.gd` 的原 `_finish()` 对每条失败额外调用了 `push_error(failure)`（在 stderr 产生对应错误项）；共享 `TestHarness.report()` 统一改为只 `printerr`，不再逐条 `push_error`。断言内容、tests/assertions 计数、exit code 均不受影响，只是失败时的 stderr 呈现方式变化（push_error 会在 Godot 里标记为脚本错误，printerr 只是普通错误输出）；未在 harness 里为这一个文件单独加特殊分支，判断这属于纯粹的输出方式统一，不算「改断言语义」。
- `run_agent_d_growth_integration_tests.gd` 的原 `_run_test`（sync 变体）在实现上有一个既有小缺陷：无论断言是否失败都无条件打印 `"PASS " + test_name}`（没有 `_failures.size()` 前后对比）。改用共享 harness 后这个变体现在会正确地在失败时打印 `FAIL`/前缀失败信息——这是共享化带来的行为更正，但只影响 stdout 文案，不影响 assertions/tests 计数或 exit code（已用改前改后日志逐一核对确认无回归）。按 §4「不做范围外重构」的精神，本次未去手工模拟这个历史缺陷，因为共享 harness 本就该有统一、正确的行为；如中枢认为这属于越界，可要求单独跳过该文件。
- `combat/tests/run_task57_full_room_background_collision_tests.gd`、`combat/tests/run_task58_formal_interactables_crown_sentry_tests.gd` 各多出一个 `_expect_near(actual, expected, tolerance, description)`（容差版本的第三种断言助手，原样板清单里没提到）。为了同样不改变判定逻辑，给 `TestHarness` 新增了一个 `expect_near()` 方法（判定式与原代码完全一致：`absf(actual-expected) <= tolerance` 才算通过），两个文件的 `_expect_near` 改为委派它。
- `growth/tests/run_task41_physical_flow_waves_boss_tests.gd` 在改动前的工作树里已经存在与本任务无关的未提交改动（Task61 相关的 Boss 类型/弹体调用替换）；本次样板替换只触碰了 `_tests/_assertions/_failures` 声明、`_run_test`/`_run_async_test`、`_expect`/`_expect_eq`、`_finish()` 这几处边界，未接触该文件里的测试正文，也未回滚那些既有改动。
- `combat/tests/run_agent_d_growth_integration_tests.gd`、`combat/tests/run_task48_dodge_integration.gd` 各有一行手工 `_tests += 1`（不经过 `_run_test`/`_run_async` 包装、直接在正文里给一个额外测试计数），改为 `_harness.tests += 1`，行为不变。
- `tmp/` 下 4 份完整项目冷副本按 §3 明确不做追溯清理，只在 `.gitignore` 追加忽略规则；这些目录仍然存在于磁盘上，未删除、未迁移。
- 未发现其他范围外问题。
