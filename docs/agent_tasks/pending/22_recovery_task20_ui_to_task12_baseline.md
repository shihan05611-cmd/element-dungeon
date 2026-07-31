# 任务 22：将任务 20 UI 精确恢复到任务 12 已验收基线

状态：BLOCKED
负责人：UI Recovery Agent 1.0
依赖：任务 21 已验收；任务 20 继续 BLOCKED；独立 Review 已失败，依赖任务 23 完成 Overlay 最终基线纠正恢复

## 1. 任务目标

本任务只撤销任务 20 在三个正式 UI 脚本中的实现，并将三者精确恢复到任务 12 已验收基线：

- `scripts/combat_hud.gd`
- `scripts/ui/run_overlay_interface.gd`
- `scripts/ui/combat_ui_tokens.gd`

不得修改资源、场景、TestRoom、CombatFeedback、任务 20 测试/证据或其他游戏文件。本任务不继续实现任务 20，不修奖励页，不重做 UI，不把候选对象按新理解重新编写。

## 2. 三个完整候选对象与确认闸门

以下只作为任务 12 基线候选，执行前必须逐项证明，不能因时间戳接近、对象前缀相似或内容看似合理而直接覆盖：

| 目标脚本 / 对象 | 完整 Git 对象 | 字节 | SHA-256 | 结论 |
| --- | --- | ---: | --- | --- |
| `scripts/combat_hud.gd` | `661d017c4bb2025541deb09d72ec55bf5a12594f` | 33597 | `a04f35f058f833eb97b97a262561673195eacd3a3ec17ade3f1cb4fe8442eda5` | 唯一可信任务 12 基线；恢复目标 |
| `scripts/ui/run_overlay_interface.gd` | `2ca3b5792890357e802fac6b86b6ed8358d1c153` | 27503 | `cce4473bdd09931e09afa68c8a33c05cdff2731d387dbadf726e76b4513069fd` | 已确认任务 12 基线；恢复目标 |
| `scripts/ui/combat_ui_tokens.gd` | `78751a2d90c88f6457861717b7781c1d8179d278` | 1856 | `3d5f31126c969008ad3f5265777bf0b9067b5d3a22cd8dffcd0cfd1c43058994` | 已确认任务 12 基线；恢复目标 |
| 已排除的旧 `combat_hud.gd` 候选 | `51b5c0828b18f583870f1a307467149c82fbec2d` | 11106 | `5835e66ceba1f7f7859d2f50bbf46c914e68f7e79dd93d028842d2d62327696c` | 已排除：旧 `primary/melee` HUD，禁止恢复 |

执行回合必须先完成：

1. 使用只读 Git 查询确认三个完整 40 位对象都存在、可读且对象类型为 `blob`；记录对象字节数、SHA-256 与 Git blob 身份。
2. 对每个候选与当前任务 20 文件做人工逐函数、逐常量、逐预载、逐公开接口 diff；不能只看整体哈希、时间戳、文件长度或对象前缀。
3. 以 `docs/agent_tasks/completed/12_agent_d_hud_loadout_feedback.md`、`combat/tests/run_hud_loadout_feedback_tests.gd`、`combat/tests/capture_task12_visuals.gd`、`docs/agent_tasks/evidence/task12/` 九张实际截图、`docs/agent_tasks/evidence/task12/README.md` 和任务 12 交付/协调者验收记录逐项核对。
4. 明确证明候选包含任务 12 的固定四槽、CurrentElement、目标层数、奖励/路线/商店、结构化反馈、色觉辅助与减少动态接口，同时不包含任务 20 的紧凑 HUD/奖励布局实现。

若任一候选不能被完整证明为任务 12 已验收基线，立即停止：不得建立部分恢复、不得覆盖任何一个脚本、不得尝试拼接或猜测缺失内容，只向协调者报告证据缺口。

## 3. 恢复前外部胶囊

任何项目脚本覆盖前，必须在工作区外建立：

`C:\tmp\element-dungeon-task22-ui-recovery-20260731\`

至少包含：

- `source_task12_blobs/`：三个已确认候选 blob 的原始字节，按完整 40 位对象 ID 保存。
- `task20_current/`：当前三个 UI 脚本按原相对路径保存的原始字节。
- `manifest`：逐项记录目标路径、候选对象类型、完整 40 位对象 ID、候选字节数、候选 SHA-256、候选 Git blob、当前文件字节数、当前 Git blob、当前 SHA-256 与固化时间。
- `protected`：任务 20 两个测试、任务 20 证据、任务 20 任务书，以及任务 21 已验收 16+1 资源的保护清单；每项至少记录路径、字节数、SHA-256、Git blob 与 UTC 时间戳。
- `README`：记录项目绝对路径、用途、候选证明摘要、操作边界、二次复核结果和禁止命令。

胶囊完成后必须：

1. 对 `source_task12_blobs` 与 `task20_current` 重新按原始来源逐字节复核。
2. 将胶囊全部文件设为只读。
3. 在只读状态下二次复核对象类型、完整对象 ID、字节数、SHA-256、Git blob、路径与文件数量。
4. 把复核结果写入本任务书；胶囊未完整通过前禁止覆盖项目脚本。

全任务禁止 `git gc`、`git prune`、`git maintenance`、任何自动维护和所有 Git 写操作；不得创建、移动或删除 Git 引用。

## 4. 允许修改范围

只允许修改：

- `scripts/combat_hud.gd`
- `scripts/ui/run_overlay_interface.gd`
- `scripts/ui/combat_ui_tokens.gd`
- `docs/agent_tasks/pending/22_recovery_task20_ui_to_task12_baseline.md`
- `docs/agent_tasks/evidence/task22/ui_recovery_delivery.md`
- `C:\tmp\element-dungeon-task22-ui-recovery-20260731\` 外部胶囊

任务执行回合可以在三个候选全部证明且胶囊/保护闸门通过后创建 `docs/agent_tasks/evidence/task22/ui_recovery_delivery.md`；本文档准备回合不得创建 task22 证据目录或交付文件。

## 5. 绝对禁止范围

禁止修改、删除、重命名、格式化、保存、reimport 或触碰时间戳：

- `scenes/combat_hud.tscn`
- `scripts/combat_feedback.gd`
- `scripts/test_room.gd`
- `scenes/test_room.tscn`
- 任务 21 已验收的 16+1 资源：
  - `scenes/test_room.tscn`
  - `resources/element_slash.tres`
  - `resources/element_bolt.tres`
  - `resources/skills/burning.tres`
  - `resources/skills/element_reclaim.tres`
  - `resources/skills/elemental_fury.tres`
  - `resources/skills/elemental_laser.tres`
  - `resources/skills/unending.tres`
  - `resources/content/skills/element_bolt_content.tres`
  - `resources/content/skills/elemental_fury_content.tres`
  - `resources/content/skills/elemental_laser_content.tres`
  - `resources/content/skills/element_reclaim_content.tres`
  - `resources/content/skills/burning_content.tres`
  - `resources/content/skills/unending_content.tres`
  - `resources/animations/player_frames.tres`
  - `resources/animations/element_projectile_frames.tres`
  - `resources/animations/enemy_frames.tres`
- `combat/**`、`growth/**`
- Player、RunSessionHost、VFX、Delivery、Catalog 的正式实现与资源
- `project.godot`
- `.godot/**`
- `combat/tests/run_compact_hud_reward_tests.gd`
- `combat/tests/capture_task20_visuals.gd`
- `docs/agent_tasks/evidence/task20/**`
- `docs/agent_tasks/pending/20_agent_e_compact_hud_reward_runtime.md`
- 任何其他游戏代码、场景、资源、测试、证据或任务文档

不得启动、连接或复用共享 Godot；不得运行 Godot、测试、导入、扫描、截图或 smoke；不得调用保存、`ResourceSaver`、reimport、plugin reload 或 `ProjectSettings.save`。

不得执行任何 Git 写操作，包括 `add`、`commit`、`stash`、`reset`、`restore`、`checkout`、`clean`、ref 写入、`gc`、`prune` 或 `maintenance`。

## 6. 执行流程

1. 本文档准备回合完成后立即停止，等待协调者明确回复“执行任务22”。没有该原文授权，不得开始候选取证、胶囊、覆盖或证据交付。
2. 执行回合先只读完成人工候选比对，并把逐文件、逐函数/常量/预载的比对结论写入本任务书。胶囊未完成且未二次复核前，不得覆盖任何项目脚本。
3. 同时建立保护基线：任务 20 两个测试、任务 20 证据、任务 20 任务书、任务 21 的 16+1 资源，以及所有绝对禁止文件的相关只读状态。
4. 只有三个候选都确认、外部胶囊完成、保护清单通过且目标文件没有在固化期间发生新写入，才可从只读 `source_task12_blobs` 将三个脚本逐字节覆盖到工作区。
5. 每覆盖一个脚本后立即只读计算 SHA-256 和 Git blob；Git blob 必须精确等于第 2 节对应完整 40 位对象。任一不等立即停止，不继续写后续文件。
6. 三个脚本完成后执行纯静态校验与保护清单前后对账；执行者不得运行 Godot。
7. 将候选证明、胶囊清单、三脚本覆盖前后哈希、保护对账、精确修改清单和明确边界声明写入 `docs/agent_tasks/evidence/task22/ui_recovery_delivery.md`。
8. 执行完成后状态只更新为 `REVIEW` 并冻结继续写入；不得自行标记 `ACCEPTED`、移动任务书、继续任务 20 或评估提交。

## 7. 执行者静态验收

- 三个脚本的 Git blob 必须分别精确为：
  - `scripts/combat_hud.gd` → `661d017c4bb2025541deb09d72ec55bf5a12594f`
  - `scripts/ui/run_overlay_interface.gd` → `2ca3b5792890357e802fac6b86b6ed8358d1c153`
  - `scripts/ui/combat_ui_tokens.gd` → `78751a2d90c88f6457861717b7781c1d8179d278`
- 任务 20 奖励布局中 `SIZE_EXPAND_FILL + SIZE_SHRINK_CENTER` 导致卡片区域下沉的实现不在任务 12 基线中；不得残留任务 20 的紧凑 HUD/奖励重排代码。
- 任务 12 已验收能力仍完整：固定 `ACTIVE_1 / ACTIVE_2 / ACTIVE_3 / PASSIVE_1` 四槽、`CurrentElement`、目标水/火层数、奖励/路线/商店界面、结构化释放与失败反馈、色觉辅助、减少动态接口。
- `scenes/combat_hud.tscn`、`scripts/test_room.gd`、`scenes/test_room.tscn`、`scripts/combat_feedback.gd` 前后字节、SHA-256、Git blob 与 UTC 时间戳均不变。
- 任务 21 已验收 16+1 资源前后字节、SHA-256、Git blob 与 UTC 时间戳均不变。
- 任务 20 两个测试、`docs/agent_tasks/evidence/task20/**` 和任务 20 任务书前后字节、SHA-256、Git blob 与 UTC 时间戳均不变。
- `git status --short --untracked-files=all` 的任务 22 新变化只能来自三个 UI 脚本、本任务书和允许的 task22 交付记录；其他既有状态逐项一致。

## 8. 全新独立 Review

执行者不得自验收。任务状态达到 `REVIEW` 后，协调者必须新开全新独立 Review；共享工作区全程只读，所有 Godot 写入只允许发生在一个新的、此前不存在的 `C:\tmp` 冷副本中。

### 8.1 Review 顺序与运行边界

1. 在共享区只读重算三候选身份、三个恢复后脚本、任务 22 胶囊、任务 20 保护、任务 21 的 16+1 资源、`git status` 与共享 `.godot` 全清单，形成运行前不变性闸门。
2. 字节复制当前共享工作区到新的 `C:\tmp` 冷副本，排除 `.git`、`.godot`、项目 tmp、`__pycache__` 与其他缓存；逐项核对路径、长度、SHA-256 和 UTC 时间戳。
3. 冷副本中的第一条 Godot 命令必须是 Godot 4.7.1 headless editor scan：`--headless --editor --path <new-copy> --quit`。只有 scan 退出码 0，且完整日志没有 `SCRIPT ERROR`、`Parse Error` 或恢复相关 error/warning，才可运行任何 runner。
4. 运行任务 12、16、18 专项：
   - `combat/tests/run_hud_loadout_feedback_tests.gd`，应为 `13 tests / 110 assertions`；
   - `combat/tests/run_skill_content_catalog_tests.gd`，应为 `11 / 209`；
   - `combat/tests/run_skill_vfx_runtime_tests.gd`，应为 `9 / 124`。
5. 运行已验收基线的 18 个唯一 runner，明确排除唯一仍属 `BLOCKED` 任务 20 的 `combat/tests/run_compact_hud_reward_tests.gd`。应恢复为 `18/18 runners`、`224 tests / 1683 assertions`。
6. 将任务 20 runner 单独作为非门禁诊断运行并单独报告；它针对已撤销的任务 20 实现，失败不能被冒充为任务 12 回归，也不得混入 18-runner 门禁汇总。
7. 运行主场景至少 180 帧 smoke，检查退出码和完整 game log；不得只依据退出码。

### 8.2 实际图形与视觉复核

- 只有静态、scan、专项、18-runner 门禁和 smoke 全部通过后，才可启动一个全新、非共享、非编辑器、禁止保存的图形 Godot 进程。
- 在冷副本实际运行/实例化正式 TestRoom、正式 HUD 与正式 `RunContentCatalog`，从真实运行 Viewport 捕获任务 12 的 `1152×648`、`900×540`、奖励页及关键状态；截图和 Review-only 夹具只能写冷副本或其外层 `C:\tmp` artifacts，不得回写共享项目。
- 至少复核并与 `docs/agent_tasks/evidence/task12/` 九张已验收证据逐项对照：
  - 正式固定四槽 HUD、CurrentElement、目标元素层数和任务 17/18 正式图标；
  - 900×540 无越界/重叠；
  - 色觉辅助与减少动态；
  - ACTIVE 放被动、PASSIVE_1 拒绝主动、0 主动警告；
  - 单一最终伤害数字与结构化反应反馈；
  - 奖励页的正式 Catalog 名称/说明和任务 12 基线布局。
- 每张证据必须来自 Godot 实际运行 Viewport，不接受静态解析、设计稿、外部拼图或直接复用旧截图。人工查看并记录布局、文字、焦点、越界、颜色冗余编码和语义完整性。
- 检查图形进程 game/editor 日志；确认未保存、重写或 reimport 正式场景/资源。

### 8.3 共享区最终不变性

所有副本运行完成后回到共享工作区，只读复核并确认下列项目与运行前逐项一致：

- `git status --short --untracked-files=all`；
- 三个已恢复 UI 脚本；
- 任务 21 的 16+1 资源；
- 任务 20 两个测试、任务 20 证据和任务 20 任务书；
- 共享 `.godot` 完整路径、长度、SHA-256 与 UTC 时间戳清单。

任何共享区变化、门禁 runner 失败、恢复相关脚本错误或实际 Viewport 回归均为 `REVIEW FAIL`；Review 只报告，不修复。

## 9. Git 边界

- 任务 22 通过全新独立 Review 后，才允许重新组装阶段性提交候选；通过之前禁止机械提交任务 21 或任务 22。
- 候选提交必须排除任务 20 当前实现、`combat/tests/run_compact_hud_reward_tests.gd`、`combat/tests/capture_task20_visuals.gd`、`docs/agent_tasks/evidence/task20/**`、任务 20 任务书中的未接受交付，以及来源/验收尚未闭合的 `addons/godot_ai` 改动。
- 不得直接把当前共享脏工作树当作候选。必须先在工作区外重建精确候选快照，按任务 22 Review 的正确冷启动顺序重新执行 editor scan、专项、18-runner 门禁、180 帧 smoke 和实际视觉复核。
- 候选快照全部通过后，只能由协调者决定是否提交、提交范围与说明；UI Recovery Agent 和独立 Review 均不执行 Git 写操作。

## 10. 文档准备阶段冻结

本任务书在文档准备阶段创建。当前只完成任务 21 归档、协调索引更新和本任务书，不创建 `docs/agent_tasks/evidence/task22/`，不建立 `C:\tmp` 胶囊，不修改三个 UI 脚本或任何其他游戏文件。

下一步必须等待协调者明确回复“执行任务22”。在此之前，本任务保持 `PENDING`，UI Recovery Agent 立即停止。
## 11. UI Recovery Agent 1.0 候选闸门记录（2026-07-31）

历史候选闸门结论：`BLOCKED`（已由 §11.7 的全新只读取证更正）。三个对象都存在、可读且为完整 `blob`；`run_overlay_interface.gd` 与 `combat_ui_tokens.gd` 候选可与任务 12 契约对应，但 `scripts/combat_hud.gd` 候选 `51b5c0828b18f583870f1a307467149c82fbec2d` 明确不是任务 12 已验收基线。依照第 2、6 节硬规则，本任务停止在覆盖前候选闸门：不建立胶囊、不覆盖任何脚本、不创建 task22 证据目录或交付文件。

### 11.1 对象身份、字节与 SHA-256

| 目标 | 候选对象 | 类型 | 候选字节 | 候选 SHA-256 | 当前字节 | 当前 Git blob | 当前 SHA-256 |
| --- | --- | --- | ---: | --- | ---: | --- | --- |
| `scripts/combat_hud.gd` | `51b5c0828b18f583870f1a307467149c82fbec2d` | `blob` | 11106 | `5835e66ceba1f7f7859d2f50bbf46c914e68f7e79dd93d028842d2d62327696c` | 53510 | `b061dea669df99e9dbbbb7dff73090c5f5457aae` | `ef77b7d0cda39cbb7363197a0a20425ae3b6ae7be00482b2920d5fe6ea4674dd` |
| `scripts/ui/run_overlay_interface.gd` | `2ca3b5792890357e802fac6b86b6ed8358d1c153` | `blob` | 27503 | `cce4473bdd09931e09afa68c8a33c05cdff2731d387dbadf726e76b4513069fd` | 40829 | `651ca094484dbc1e3b5fe6d309443d6ab14ded46` | `9fe4f270fca47f0a4e52286f832ea50fba35bdeaafac54ebe2fc58c4672044cf` |
| `scripts/ui/combat_ui_tokens.gd` | `78751a2d90c88f6457861717b7781c1d8179d278` | `blob` | 1856 | `3d5f31126c969008ad3f5265777bf0b9067b5d3a22cd8dffcd0cfd1c43058994` | 2017 | `f7bd19d12ec3fe980046f3d7baa1ee576d242f06` | `f15229f3e4b3c4dc821c1562169c6beabc312c69f2c1d85c0b948cef3ea0c3a0` |

对象类型由 `git cat-file -t`、对象字节由 `git cat-file blob`、对象尺寸由 `git cat-file -s` 独立核对；候选 SHA-256 直接对 `cat-file` 原始字节计算，未写临时文件。

### 11.2 `scripts/combat_hud.gd` 逐函数、常量、预载与接口比对

先以完整函数体枚举和 SHA-256 防漏，再人工逐项阅读候选源码、任务 12 专项/视觉夹具与当前正式场景契约。

逐函数结果：

- 候选与当前同名且函数体完全一致 3 个：`_on_cooldown_changed`、`_on_cooldown_finished`、`_on_energy_changed`。
- 同名但函数体已改变 15 个：`configure`、`_unhandled_input`、`_process`、`_on_player_health_changed`、`_on_element_changed`、`_on_phase_changed`、`_on_cast_attempted`、`_on_target_health_changed`、`_on_target_elements_changed`、`_on_result_observed`、`_refresh_element`、`_refresh_skill_status`、`_availability_text`、`_pulse_energy`、`_refresh_debug`。
- 仅候选存在 1 个：`_show_energy_warning`。
- 仅当前存在 62 个：`_enter_tree`、`_ready`、`set_authoritative_target`、`target_projection_mode`、`slot_panel`、`feedback_text`、`set_reduced_motion`、`set_colorblind_mode`、`_on_element_change_attempted`、`cast_acceptance_feedback`、`_acceptance_tone`、`_show_reject_feedback`、`_set_rejected_slot_state`、`_on_authoritative_target_defeated`、`_on_authoritative_target_exited`、`_pulse_passive_for_result`、`_on_loadout_replaced`、`_on_overlay_status_requested`、`_refresh_target_elements`、`_update_target_projection`、`_hide_target_projection`、`_refresh_slot`、`_apply_transient_slot_state`、`_expire_slot_transients`、`_apply_slot_tone`、`_refresh_cooldown_text_only`、`_compact_availability_text`、`_availability_color`、`_format_cooldown`、`_show_feedback`、`_hide_feedback`、`_skill_policy_badge`、`_policy_glyph`、`_short_policy_text`、`_policy_color`、`_element_label`、`_element_short_label`、`_element_color`、`_tone_color`、`_key_for_slot`、`_short_slot_name`、`_connect_once`、`_unbind_target`、`_bind_ui_refs`、`_build_ui`、`_build_status_panel`、`_bar_row`、`_build_skill_panel`、`_build_element_pivot`、`_build_hud_slot`、`_build_target_panel`、`_build_feedback_panel`、`_build_help_panel`、`_build_debug_panel`、`_apply_responsive_layout`、`_layout_viewport_size`、`_layout_render_scale`、`_rendered_rect`、`_is_compact_breakpoint`、`_margin`、`_make_label`、`_exit_tree`。

常量与预载：

- 候选只有旧常量 `WATER_COLOR`、`FIRE_COLOR`、`LOW_HEALTH_THRESHOLD`、`WARNING_RATE_LIMIT_MSEC = 650`；没有任何 preload。
- 当前正式脚本包含 `UI`、`RUN_OVERLAY_SCRIPT`、`SLOT_ORDER`、`TARGET_FOLLOW_SIZE`、四槽/元素枢纽设计尺寸与 `WARNING_RATE_LIMIT_MSEC = 450`，并预载 `res://scripts/ui/combat_ui_tokens.gd` 与 `res://scripts/ui/run_overlay_interface.gd`。

公开接口与字段：

- 候选唯一公开函数是 `configure`；当前任务 12/20 文件还公开 `set_authoritative_target`、`target_projection_mode`、`slot_panel`、`feedback_text`、`set_reduced_motion`、`set_colorblind_mode`、`cast_acceptance_feedback`。
- 候选公开字段是旧 `status_panel / skill_panel / primary_state / melee_state / phase_text / warning_text / debug_* / reduced_motion` 集合；没有 `run_overlay`、`help_panel`、`colorblind_mode`。
- 候选只有 `reduced_motion_changed`；没有任务 12 需要的 `colorblind_mode_changed`。

人工语义结论：该候选仍通过 `_player_skills.get_skill_for_slot(&"primary")` 与 `get_skill_for_slot(&"melee")` 构建旧双行技能 HUD，明确早于任务 12 固定 `ACTIVE_1 / ACTIVE_2 / ACTIVE_3 / PASSIVE_1` 基线。它还依赖场景中预建的 `$Root/StatusPanel/...`、`$Root/SkillPanel/.../PrimaryRow` 与 `MeleeRow`；当前受保护的 `scenes/combat_hud.tscn` 只有 `CombatHUD` 根节点和脚本引用，候选没有 `_ready/_build_ui`，因此在不修改禁止场景的前提下甚至无法建立所需节点。

### 11.3 `scripts/ui/run_overlay_interface.gd` 逐函数、常量、预载与接口比对

逐函数结果：

- 候选与当前同名且函数体完全一致 28 个：`configure`、`set_colorblind_mode`、`set_preview_snapshot`、`try_preview_assignment`、`current_preview`、`zero_active_warning_visible`、`slot_card`、`_refresh_loadout`、`_select_skill`、`_on_slot_input`、`_skill_can_drop`、`_skill_drop`、`_slot_can_drop`、`_clear_selected_slot`、`_confirm_shop`、`_on_snapshot_changed`、`_candidate_with_assignment`、`_activation_text`、`_policy_text`、`_element_text`、`_assignment_preview_text`、`_publish_detail`、`_detail_text`、`_route_option_text`、`_key_for_slot`、`_label`、`_separator`、`_clear_children`。
- 同名但函数体已改变 21 个：`_ready`、`toggle_loadout`、`show_loadout`、`show_reward`、`hide_overlay`、`_build`、`_build_slot_card`、`_build_skill_card`、`_skill_drag_data`、`_slot_drag_data`、`_slot_drop`、`_claim_reward`、`_show_route_options`、`_choose_route`、`_refresh_warning`、`_refresh_passives`、`_refresh_relics`、`_policy_color`、`_element_color`、`_tone_color`、`_show_overlay`。
- 候选独有函数为 0。
- 当前任务 20 新增 17 个：`_build_reward_card`、`_reward_policy_chip_text`、`_reward_chip`、`_build_relic_glyph`、`_focus_reward_option`、`_wire_reward_focus`、`_confirm_reward_selection`、`reward_selected_index`、`reward_card_count`、`reward_confirm_button`、`_owns_skill`、`_equips_skill`、`_owns_relic`、`_cooldown_copy`、`_layout_viewport_size`、`_apply_responsive_layout`、`_set_reward_input_enabled`。

常量、预载与接口：

- 候选与当前都保留 `SLOT_ORDER = ACTIVE_1 / ACTIVE_2 / ACTIVE_3 / PASSIVE_1`、`status_requested`、`colorblind_mode` 和任务 12 的 11 个公开方法；当前只额外加入 `UI` preload 和 3 个任务 20 奖励诊断公开方法。
- 候选完整保留共享四槽、配装预览、ACTIVE 放被动、PASSIVE_1 拒绝主动、0 主动警告、奖励领取、路线选择、ShopDraft 确认与颜色冗余接口。
- 当前的 `_build_reward_card`、独立确认/焦点导航、1/2/3 卡响应布局、`SIZE_EXPAND_FILL` 卡区与 `_apply_responsive_layout` 中的 `SIZE_SHRINK_CENTER` 均不在候选中。该候选可证明为任务 12 Overlay 基线。

### 11.4 `scripts/ui/combat_ui_tokens.gd` 逐函数、常量、预载与接口比对

- 三个公开函数 `panel`、`flat_panel`、`button_style` 的完整函数体在候选与当前逐字节相同；没有新增、删除或改变函数。
- 候选与当前共同保留 19 个任务 12 语义常量：`SURFACE`、`SURFACE_RAISED`、`SURFACE_SOFT`、`SCRIM`、`BORDER`、`BORDER_FOCUS`、`TEXT`、`TEXT_MUTED`、`TEXT_DIM`、`WATER`、`WATER_COLORBLIND`、`FIRE`、`FIRE_COLORBLIND`、`NEUTRAL`、`SUCCESS`、`WARNING`、`ERROR`、`BUSY`、`COOLDOWN`。
- 当前仅增加任务 20 的 `COOLDOWN_MASK`、`FOCUS_RING_WIDTH`、`SPACE_1`、`SPACE_2`、`SPACE_3`、`SPACE_4`；候选没有这些新增项。
- 候选与当前都无 preload、signal、公开字段；公开样式接口完全一致。该候选可证明为任务 12 token 基线。

### 11.5 任务 12 专项、视觉夹具、九张证据与交付记录交叉核对

`combat/tests/run_hud_loadout_feedback_tests.gd` 直接要求：

- `slot_panel()` 返回恰好四个共享槽；候选 HUD 无此函数，并仍使用 `primary/melee`。
- `help_panel`、目标层数节点与 1152×648、900×540、1280×720 响应布局；候选无 `help_panel`、`_build_ui` 或 `_apply_responsive_layout`。
- `set_colorblind_mode()`、`colorblind_mode`、`_element_color()` 以及对 Overlay 的传播；候选全部缺失。
- `_show_reject_feedback()`、`feedback_text()`、`cast_acceptance_feedback()`、`_show_feedback()`、`set_reduced_motion()`；候选全部缺失。
- `_hud.run_overlay` 连接正式配装、奖励、路线、商店；候选没有 `run_overlay` 字段，也没有 Overlay preload。

`combat/tests/capture_task12_visuals.gd` 同样直接读取 `_hud.run_overlay`，调用 `set_colorblind_mode()`、`set_reduced_motion()` 和 `_show_feedback()`。因此用候选 HUD 无法执行任务 12 视觉夹具。

已验收证据目录只读核对为恰好九张 PNG：

| 证据 | 尺寸 | SHA-256 | 候选契约核对 |
| --- | ---: | --- | --- |
| `01_combat_hud_1152x648.png` | 1152×648 | `e81725f4861557acb8445b22bbfa49a82b25e329f45c4956ba1d512c453bffcc` | 要求正式四槽、CurrentElement、目标层数；候选 HUD 不具备 |
| `02_combat_hud_scaled_900x540.png` | 900×540 | `41c44e476dbfa04694cdc3b3fc8c9f906d3878245d2487bd5e0f7f79a4c08033` | 要求响应布局；候选 HUD 不具备 |
| `03_colorblind_target_layers.png` | 1152×648 | `864a0c75e9e71e5aa8a6e768d6b4109c1977a24b23de3fd8bd3d0d40af2e8f50` | 要求色觉接口与目标层数；候选 HUD 不具备 |
| `04_reduced_motion_locked_element.png` | 1152×648 | `57c1ec7ea8524dd30b485290b5684de71c869aefc5a00db2167e78825dba81a0` | 要求结构化锁定反馈与减少动态接口；候选 HUD 不具备 |
| `05_active_slot_passive_preview.png` | 1152×648 | `92201c5dd9fcab756a11f4f911887c96bffdbbffdc17f0b8e73da277b946a7d9` | Overlay 候选具备，但候选 HUD 无 `run_overlay` 接线 |
| `06_passive_slot_rejects_active.png` | 1152×648 | `4059cbdf54b41ed4cb039c6d456495dd74c9c66389cd8819b865afca1bf1e40a` | Overlay 候选具备，但候选 HUD 无 `run_overlay` 接线 |
| `07_zero_active_four_passive_warning.png` | 1152×648 | `d8f9a5e30a75334ab59b5cce1a5fb727d081528717987e3a3199df90f3025115` | Overlay 候选具备，但候选 HUD 无 `run_overlay` 接线 |
| `08_single_final_damage_reaction.png` | 1152×648 | `973dd4ad0e6e16cbd4b98e5c02f7a137676d989d9c5bed1a1624f31948988efe` | 由受保护 `CombatFeedback` 负责，不能补足 HUD 候选缺口 |
| `09_reward_ui_catalog_copy.png` | 1152×648 | `71c6fc6dde6447762368f3b989dee329af1de1c27307f2ab94dbcd5d30f19b14` | Overlay 候选具备任务 12 奖励页，但候选 HUD 无接线 |

这与 `docs/agent_tasks/completed/12_agent_d_hud_loadout_feedback.md` 和 `docs/agent_tasks/evidence/task12/README.md` 的已验收事实一致：任务 12 基线必须同时具备固定四槽、CurrentElement、目标层数、奖励/路线/商店、结构化反馈、色觉辅助和减少动态。`51b5...` 无法满足其中多数硬接口，不能因另外两个对象正确而拼接或部分恢复。

### 11.6 停止与不变性声明

- 失败对象：`scripts/combat_hud.gd` 候选 `51b5c0828b18f583870f1a307467149c82fbec2d`。
- 精确原因：它是旧 `primary/melee` HUD，缺失任务 12 接口，并与受保护的最小 `scenes/combat_hud.tscn` 不兼容，不能证明为任务 12 基线。
- 未创建 `C:\tmp\element-dungeon-task22-ui-recovery-20260731\`；未创建任何 `source_task12_blobs`、`task20_current`、manifest、protected 或 README。候选闸门失败后没有进入胶囊阶段。
- 未覆盖或修改三个 UI 脚本；未创建 `docs/agent_tasks/evidence/task22/` 或 `ui_recovery_delivery.md`。
- 未修改任务 20 两个测试、任务 20 证据、任务 20 任务书、任务 21 的 16+1 资源、场景、TestRoom、CombatFeedback、`.godot`、`project.godot` 或任何其他游戏文件。
- 未启动、连接或调用 Godot；未执行任何 Git 写操作；只使用 `cat-file`、`hash-object` 等只读对象查询。
- 本任务保持冻结，不进入 `REVIEW`，不自行 `ACCEPTED`，不继续任务 20，不评估或执行提交。需要协调者提供可证明的任务 12 `combat_hud.gd` 完整对象后，另行明确恢复指令。
### 11.7 新取证更正与恢复重启（2026-07-31）

状态：`IN_PROGRESS`。协调者已明确下发“恢复执行任务22”。本节以全新独立只读取证线程 `019fb764-5209-7900-abe9-f23bc65c13a4`（host `local`）最终报告更正旧候选；§11.1～11.6 保留为旧对象被正确排除的历史审计，不再代表当前 CombatHUD 恢复目标。

唯一可信任务 12 CombatHUD：

- 完整 Git blob：`661d017c4bb2025541deb09d72ec55bf5a12594f`。
- 对象类型：`blob`。
- 字节：33597。
- SHA-256：`a04f35f058f833eb97b97a262561673195eacd3a3ec17ade3f1cb4fe8442eda5`。
- 决定性证据：取证线程完整读取任务 12 执行线程 `019fb35f-3267-7810-a0e7-17f1cb319639`，从原始参数在内存中按顺序重放一次完整 `script_create` 和随后 11 次补丁；所有非全局补丁唯一命中，一次 `replace_all` 按记录命中 66 处，最终 33597 字节与 `661d…` 对象逐字节相等。
- 时间链：最后 CombatHUD 补丁后，任务 12 专项为 `13 tests / 110 assertions`，九张实际 Viewport 证据随后生成，最终全量为 `18/18 runners`、`224 tests / 1683 assertions`；对象时间只作辅助线索，逐字节重放相等是决定性证明。
- 契约：对象具备固定 `ACTIVE_1 / ACTIVE_2 / ACTIVE_3 / PASSIVE_1`、CurrentElement、目标层数、`slot_panel()`、`feedback_text()`、`set_reduced_motion()`、`set_colorblind_mode()`、`cast_acceptance_feedback()`、`run_overlay`、Overlay/Token preload、`_enter_tree()` 与 `_build_ui()`，可配合最小正式 `combat_hud.tscn`。
- 排除任务 20：对象没有权威目标跟随/离屏回退、底部 CurrentElement 枢纽、冷却遮罩、紧凑面积响应布局等任务 20 增量。

旧候选 `51b5c0828b18f583870f1a307467149c82fbec2d` 保留为“已排除”历史对象：它只有 11106 字节，仍使用 `primary/melee`，缺失任务 12 四槽、Overlay/Token preload、可访问性、结构化反馈与最小场景 build 接口。严禁用于恢复或拼接。

当前三份精确恢复目标固定为：

1. `scripts/combat_hud.gd` ← `661d017c4bb2025541deb09d72ec55bf5a12594f`。
2. `scripts/ui/run_overlay_interface.gd` ← `2ca3b5792890357e802fac6b86b6ed8358d1c153`。
3. `scripts/ui/combat_ui_tokens.gd` ← `78751a2d90c88f6457861717b7781c1d8179d278`。

恢复重新进入候选后的现场审计阶段；仍须先完成新的外部胶囊、只读二次复核和全部保护闸门，未通过前不得覆盖。
### 11.8 任务20保护清单 37/35 口径对齐（覆盖前闸门）

已直接读取任务 21 胶囊 `C:\tmp\element-dungeon-task21-recovery-20260731\protected_task20_manifest.tsv` 并逐路径对账，确认原始“37 项”口径为：

- 3 个任务 20 UI 脚本：本任务允许恢复，但写前原始字节必须完整保存在 `task20_current`，同时保留在原始 37 项映射中；
- 2 个任务 20 测试；
- `docs/agent_tasks/evidence/task20/**` 的 32 个文件（含 `.import`）；
- 原始 37 项不包含任务 20 任务书。

逐路径结果：`3 + 2 + 32 = 37`，缺失 0、额外 0、重复 0。

本任务所称“35 项不可改保护清单”采用不同但更严格的非目标口径：

- 2 个任务 20 测试；
- 32 个任务 20 证据文件；
- 1 份任务 20 任务书 `docs/agent_tasks/pending/20_agent_e_compact_hud_reward_runtime.md`；
- 排除三个允许恢复的 UI 目标，因为它们单独进入 `manifest.tsv` 与 `task20_current` 原始字节副本。

因此 `2 + 32 + 1 = 35`。这不是把 37 项缩减为 35 项，也不是去重遗漏：胶囊将同时保存 `task20_original37_manifest.tsv`（原始 37 路径口径）、`protected_task20_manifest.tsv`（35 项不可改口径）和三目标原始字节。两种口径的唯一并集为 38 项：3 个目标脚本 + 2 个测试 + 32 个证据 + 1 份任务书。任何计数、路径、SHA-256 或 Git blob 无法一一对齐，任务立即转为 `BLOCKED` 且不覆盖。
### 11.9 覆盖前胶囊与保护闸门（2026-07-31）

覆盖前外部胶囊已建立并通过只读二次复核：

- 绝对路径：`C:\tmp\element-dungeon-task22-ui-recovery-20260731`。
- 胶囊文件：13/13 均为 Windows `ReadOnly`；最终路径移动后再次复核仍为 13/13。
- `source_task12_blobs`：3/3，均直接由 `git cat-file blob <完整OID>` 提取；对象类型、完整 40 位 ID、字节、SHA-256、Git blob 身份全部命中。
- `task20_current`：3/3，保存当前任务 20 三脚本原始字节；与 `manifest.tsv` 的字节、SHA-256、Git blob 和原文件 UTC 时间/只读状态逐项一致。
- 当前脚本现场：`combat_hud.gd` 为 53510 字节、Git blob `b061dea669df99e9dbbbb7dff73090c5f5457aae`、SHA-256 `ef77b7d0cda39cbb7363197a0a20425ae3b6ae7be00482b2920d5fe6ea4674dd`；`run_overlay_interface.gd` 为 40829 字节、`651ca094484dbc1e3b5fe6d309443d6ab14ded46`、`9fe4f270fca47f0a4e52286f832ea50fba35bdeaafac54ebe2fc58c4672044cf`；`combat_ui_tokens.gd` 为 2017 字节、`f7bd19d12ec3fe980046f3d7baa1ee576d242f06`、`f15229f3e4b3c4dc821c1562169c6beabc312c69f2c1d85c0b948cef3ea0c3a0`。
- `task20_original37_manifest.tsv`：37 行，严格复现任务 21 的 3 脚本 + 2 测试 + 32 证据路径口径，并与任务 21 原清单逐路径、SHA-256、Git blob 对齐。
- `protected_task20_manifest.tsv`：35 行，严格保护 2 测试 + 32 证据 + 1 份任务 20 任务书。
- 两种口径唯一并集：38 路径；无缺失、额外或重复。三个允许恢复脚本同时保存在原始37清单和 `task20_current`。
- `protected_task21_resources_manifest.tsv`：17/17 命中任务 21 已验收完整 Git blob。
- `protected_workspace_before.tsv`：1767 个允许范围外共享项目文件的路径、字节、SHA-256、Git blob、UTC 时间与只读状态已固化，包含共享 `.godot`；仅排除三个恢复目标、任务 22 任务书和允许新建的 `docs/agent_tasks/evidence/task22/**`。
- `git_status_before.txt`：969 行，SHA-256 `2e731fc84fd5f17295a5a16050f5e0d935d7f38241790111770b5ac18773ece4`。
- 胶囊 `README.md` 已记录新取证线程、三目标映射、旧 `51b5…` 禁用、37/35/38 口径、禁止 Git 维护/写入与最终只读 `PASS`。

至此胶囊与保护闸门通过。覆盖仍须先重新核对活体三脚本与 `task20_current` 一致、1767 个保护文件与前置清单一致；任何漂移即 `BLOCKED`，不得部分写入。
### 11.10 精确恢复、静态验收与执行侧交付（2026-07-31）

三个保护前置条件全部通过后，已直接从 `git cat-file blob` 重新读取完整目标对象，与胶囊只读 `source_task12_blobs` 逐字节核对，再逐字节覆盖且仅覆盖三个允许脚本。写后结果：

| 文件 | 字节 | Git blob | SHA-256 |
| --- | ---: | --- | --- |
| `scripts/combat_hud.gd` | 33597 | `661d017c4bb2025541deb09d72ec55bf5a12594f` | `a04f35f058f833eb97b97a262561673195eacd3a3ec17ade3f1cb4fe8442eda5` |
| `scripts/ui/run_overlay_interface.gd` | 27503 | `2ca3b5792890357e802fac6b86b6ed8358d1c153` | `cce4473bdd09931e09afa68c8a33c05cdff2731d387dbadf726e76b4513069fd` |
| `scripts/ui/combat_ui_tokens.gd` | 1856 | `78751a2d90c88f6457861717b7781c1d8179d278` | `3d5f31126c969008ad3f5265777bf0b9067b5d3a22cd8dffcd0cfd1c43058994` |

静态验收通过：CombatHUD 55个函数、Overlay 49个函数；固定四槽、CurrentElement、目标层数、`slot_panel()`、`feedback_text()`、色觉/减少动态、cast feedback、Overlay/Token preload、奖励/路线/商店及最小场景 build 接口齐全；22个 Token 引用全部可解析。任务20目标跟随/离屏回退、底部元素枢纽、冷却遮罩、紧凑响应布局、奖励焦点/确认增量和 `SIZE_EXPAND_FILL + SIZE_SHRINK_CENTER` 下沉实现均不在三份任务12基线中。

交付记录写入前的全量保护对账通过：允许范围外共享文件1767/1767零差异，其中 `.godot` 652/652；任务20不可改35/35；原始37项中的34个非目标现场文件和3个 `task20_current` 原始只读副本均命中；任务21的16+1资源17/17；胶囊13/13只读；排除允许路径后的 Git status 965行逐行差异0。37/35/38口径无遗漏。

完整恢复前后映射、胶囊与保护结果见 `docs/agent_tasks/evidence/task22/ui_recovery_delivery.md`。执行侧未启动或连接 Godot、未运行测试、未执行 Git 写操作、未保存/reimport/plugin reload。任务现冻结为 `REVIEW`；本节写入后只做最终只读复核，不再写入，等待全新独立 Review。

最终只读复核（交付文件和 REVIEW 状态均已写入后）通过：允许范围外1767/1767、.godot 652/652、任务20不可改35/35、原37项的34个非目标与3个原始只读副本、任务21的17/17、三个恢复目标及胶囊13/13只读均零失败；Git status 从969行变为970行仅来自允许的任务22交付文件，排除允许路径后前后均为965行且逐行差异0。此后停止所有写入。
## 12. 全新独立 Recovery Review 2.0：REVIEW FAIL（2026-07-31）

独立 Review 线程：`019fb78e-0c54-7ca1-beba-044c32edd1ee`。结论为 `REVIEW FAIL`；Review 只报告、未修复，且共享工作区最终零漂移。

### 12.1 已通过的前置与非故障范围

- 三个恢复后脚本当时分别精确命中任务22指定对象：CombatHUD `661d017c4bb2025541deb09d72ec55bf5a12594f`、Overlay `2ca3b5792890357e802fac6b86b6ed8358d1c153`、Token `78751a2d90c88f6457861717b7781c1d8179d278`。
- 任务22胶囊 13/13 文件只读，3份任务12候选、3份任务20现场、37/35/38映射、任务21资源清单均通过复核。
- 全新冷副本 1118/1118 文件、36,046,617 字节逐项路径/长度/SHA-256 对账通过；第一条 Godot 命令严格为 headless editor scan，退出码0，`SCRIPT ERROR / Parse Error / ERROR / WARNING` 均为0。
- 任务16专项 `11/209`、任务18专项 `9/124`、主场景180帧 smoke 均通过且日志干净。
- 共享区最终不变性通过：`git status` 970→970且逐行差异0；三个UI脚本、任务21的17项资源、任务20的35项不可改保护、共享`.godot` 652/652和复制范围1118/1118均不变；没有共享写入或Git写操作。

### 12.2 决定性失败

- 任务12专项实际执行 `13 tests / 110 assertions`，但有3个失败断言，退出码1；完整日志出现6次确定性 `SCRIPT ERROR`。
- 恢复后的 Overlay 在 `_claim_reward()` 与 `_choose_route()` 中访问 `result.snapshot`；当前正式 `RunCommandResult` 只公开 `run_snapshot`。
- 6次错误精确对应三次领取奖励与三次选择路线；权威命令虽已提交，但 Overlay 未能在最终商店路线后继续打开 `ShopDraft`。
- 3个失败断言为：`shop UI opens authoritative ShopDraft`、`shop confirm is enabled only with live draft`、`successful shop confirmation closes overlay`。
- 18个既有门禁 runner 全部执行，共 `224 tests / 1683 assertions`，但仅 `17/18 runners` 通过；唯一门禁失败是任务12专项。
- 任务20 runner 仅作非门禁诊断，结果为7 failures / 49 assertions，反映任务20增量已撤销，不混入任务12门禁。
- 因任务12专项与18-runner门禁失败，Review按硬规则没有启动图形 Godot，也没有生成新的实际 Viewport 证据；不得把旧截图、headless输出或静态解析冒充本轮视觉验收。

任务22因此不能保持 `REVIEW`，更不能归档或进入Git检查点；现改为 `BLOCKED`。

## 13. 任务22B Overlay 最终对象纠正与任务23依赖（2026-07-31）

全新只读取证线程：`019fb7a9-0e27-7ea2-ae3c-94d32c4468a0`。该线程完整读取任务12、任务20和失败Review历史，在内存中重放原始写入参数，不修改项目、不运行Godot、不执行Git写操作。

### 13.1 决定性纠正

- `2ca3b5792890357e802fac6b86b6ed8358d1c153`（27503字节，SHA-256 `cce4473bdd09931e09afa68c8a33c05cdff2731d387dbadf726e76b4513069fd`）只是任务12 Overlay 的初始创建态，即完整写入链第0步；它不是任务12最终态，禁止再次作为最终恢复候选、验收基线或提交候选。
- 任务12 Overlay 的一次创建和随后7次补丁完整重放后，最终26785字节逐字节等于不可达Git blob `b98a9c223f87caa983bb97d14639d73c62957337`，SHA-256为 `e30e02d82ddecd6056f06a72683b7e5641013e09a8531e6be2837d7be23f6b68`。
- 非全局补丁全部唯一命中；两个 `replace_all` 分别命中69次和2次。第4个补丁明确把两处 `_snapshot = result.snapshot` 改为 `_snapshot = result.run_snapshot`。
- 最终链还包含 Token 显式 preload、69处 `UI` 本地别名、`StringName(...)` 类型转换、固定 `ACTIVE_1/2/3` 与 `PASSIVE_1` 文案、局部变量告警清理和拖拽返回补丁。因此禁止只拍脑袋替换两行；那样仍不会得到已验收最终字节。
- 任务20执行历史从精确的 `b98a…` 起步，32次成功 Overlay 补丁后得到任务20最终对象 `651ca094484dbc1e3b5fe6d309443d6ab14ded46`（40829字节，SHA-256 `9fe4f270fca47f0a4e52286f832ea50fba35bdeaafac54ebe2fc58c4672044cf`），形成独立交叉证明。
- `RunCommandResult` 的 `run_snapshot` 契约早在任务12前已存在，任务12通过前已完成两处字段修正；失败不是后续契约演进。
- CombatHUD `661d017c4bb2025541deb09d72ec55bf5a12594f` 与 CombatUiTokens `78751a2d90c88f6457861717b7781c1d8179d278` 的恢复对象正确，禁止修改。

### 13.2 后续分流

任务22保持 `BLOCKED`，依赖新的 `23_recovery_task12_overlay_final_baseline.md`。任务23必须只恢复 `scripts/ui/run_overlay_interface.gd` 到 `b98a9c223f87caa983bb97d14639d73c62957337`，重新完成静态保护对账，并由全新独立 Review 在新冷副本中执行完整门禁。任务23通过之前，任务22不得归档，不得重新评估或机械创建Git检查点。
## 14. 任务23执行交叉结果（2026-07-31）

协调者已原文下发“执行任务23”。Overlay Final Recovery Agent 1.0 按 `23_recovery_task12_overlay_final_baseline.md` 完成执行侧静态交付：

- 覆盖前活体Overlay仍精确为任务12创建态 `2ca3b5792890357e802fac6b86b6ed8358d1c153`，27503字节，SHA-256 `cce4473bdd09931e09afa68c8a33c05cdff2731d387dbadf726e76b4513069fd`，并与任务23胶囊现场逐字节相等。
- 全新胶囊 `C:\tmp\element-dungeon-task23-overlay-final-recovery-20260731` 已建立并完成只读二次复核：74/74文件只读；保存三代Overlay原始对象、任务20 35项、任务21 17项、HUD/Token、任务22/23文档、任务22旧胶囊13项映射、共享`.godot`652项和允许范围外1770项。
- 唯一游戏文件 `scripts/ui/run_overlay_interface.gd` 已直接使用新一次 `git cat-file blob b98a9c223f87caa983bb97d14639d73c62957337` 的原始字节覆盖；写后精确为 `b98a9c223f87caa983bb97d14639d73c62957337`、26785字节、SHA-256 `e30e02d82ddecd6056f06a72683b7e5641013e09a8531e6be2837d7be23f6b68`。
- 静态验收通过：`result.run_snapshot` 2处、错误 `result.snapshot` 0处、Token preload 1处、`UI.`别名69处、类型转换/固定槽位文案/变量名/拖拽补丁均与任务12最终链一致，奖励→路线→商店五项权威调用完整。
- 恢复后任务20 35/35、任务21 17/17、HUD/Token、任务22旧胶囊13/13、共享`.godot`652/652、允许范围外1770/1770与Git引用均零差异；任务23胶囊仍74/74只读。
- 执行侧未启动或连接Godot，未运行测试/scan/smoke/截图，未执行任何Git写操作、引用写入、gc/prune/maintenance，也未修改任务22原胶囊。

完整交付见 `docs/agent_tasks/evidence/task23/overlay_final_recovery_delivery.md`。任务23现只到 `REVIEW`；任务22继续保持 `BLOCKED`，等待全新独立Review按正确冷启动顺序验收。Review通过前不得归档任务22/23或评估Git检查点。