# 任务 23：任务 12 Overlay 最终基线纠正恢复

状态：REVIEW
负责人：Overlay Final Recovery Agent 1.0
依赖：任务22独立Review失败 `019fb78e-0c54-7ca1-beba-044c32edd1ee`；任务22B只读取证 `019fb7a9-0e27-7ea2-ae3c-94d32c4468a0`

## 1. 任务定位与唯一目标

任务22把 `scripts/ui/run_overlay_interface.gd` 恢复成了任务12的初始创建态，导致独立Review失败。本任务只纠正这一份 Overlay；不继续任务20、不修奖励页设计、不修改契约、不重写HUD/Token，也不按当前错误现象手工拼补代码。

唯一游戏文件允许写入：

- `scripts/ui/run_overlay_interface.gd`

精确恢复目标：

| 文件 | Git blob | 字节 | SHA-256 |
| --- | --- | ---: | --- |
| `scripts/ui/run_overlay_interface.gd` | `b98a9c223f87caa983bb97d14639d73c62957337` | 26785 | `e30e02d82ddecd6056f06a72683b7e5641013e09a8531e6be2837d7be23f6b68` |

当前错误对象 `2ca3b5792890357e802fac6b86b6ed8358d1c153` 只是任务12第0步创建态，禁止再作为终态、恢复目标、验收基线或提交候选。

## 2. 决定性证据与错误边界

- 任务22失败Review证明：当前 `2ca3…` 在 `_claim_reward()` 与 `_choose_route()` 两处访问 `result.snapshot`，而正式 `RunCommandResult` 只有 `run_snapshot`；任务12专项 `13/110` 中3个断言失败并产生6次 `SCRIPT ERROR`，18-runner为17/18。
- 同一Review中任务16 `11/209`、任务18 `9/124`、其余runner和180帧smoke通过；共享工作区、任务21资源、任务20保护文件与共享`.godot`最终零漂移。
- 任务22B完整重放任务12的一次 Overlay 创建和随后7次补丁，最终字节逐字节等于 `b98a…`；第4个补丁把两处 `result.snapshot` 改为 `result.run_snapshot`。
- 任务12最终链还包含 Token 显式 preload、69处 `UI` 别名、类型转换、固定槽位文案、变量名与拖拽返回修正。不能把“只改两处字段”冒充精确历史恢复。
- 任务20从 `b98a…` 起步，经32次成功补丁得到 `651ca094484dbc1e3b5fe6d309443d6ab14ded46`，独立证明 `b98a…` 是任务20接手时的任务12 Overlay 最终基线。
- CombatHUD `661d017c4bb2025541deb09d72ec55bf5a12594f` 与 CombatUiTokens `78751a2d90c88f6457861717b7781c1d8179d278` 已恢复正确，属于绝对保护对象，不得修改。

## 3. 执行授权闸门

本文档准备完成后立即停止。只有协调者在本任务中发送原文“执行任务23”后，Overlay Final Recovery Agent 1.0 才能开始任何对象审计、胶囊创建、项目脚本覆盖或 task23 交付证据写入。

没有该原文授权时，本任务必须保持 `PENDING`，不得：

- 建立任务23胶囊；
- 创建 `docs/agent_tasks/evidence/task23/` 或交付文件；
- 修改任何游戏文件；
- 启动或连接Godot、运行测试/scan/smoke/截图；
- 执行任何Git写操作。

## 4. 执行前全新外部只读胶囊

执行回合必须先在工作区外建立一个全新、此前不存在的胶囊，建议路径：

`C:\tmp\element-dungeon-task23-overlay-final-recovery-20260731`

任务22原胶囊 `C:\tmp\element-dungeon-task22-ui-recovery-20260731` 只能只读核验，不得修改、补写、改属性、重命名或复用为任务23胶囊。

任务23胶囊至少保存：

1. `b98a9c223f87caa983bb97d14639d73c62957337` 的 `git cat-file blob` 原始26785字节。
2. 当前错误对象 `2ca3b5792890357e802fac6b86b6ed8358d1c153` 的 `git cat-file blob` 原始27503字节，并在任何工作区覆盖前另存当前活体 Overlay 原始字节；两者必须逐字节对账。
3. 任务20最终 Overlay `651ca094484dbc1e3b5fe6d309443d6ab14ded46` 的原始40829字节，或任务22胶囊中能够逐字节证明该现场对象的完整只读映射；采用哪一种必须在README中明确。
4. 每个对象/现场文件的完整40位对象ID、对象类型、字节数、SHA-256、Git blob身份、UTC时间戳和Windows只读属性。
5. 任务22与任务23任务书的状态、字节、Git blob、SHA-256、UTC时间戳和只读属性；任务22交付证据也须列入保护映射。
6. 任务20不可改35项：任务20任务书1份、专项/捕获测试2份、`docs/agent_tasks/evidence/task20/**` 32份。
7. 任务21已验收17项资源：16个精确恢复资源和只校验的 `enemy_frames.tres`。
8. 当前 CombatHUD 与 CombatUiTokens 的字节、Git blob、SHA-256、UTC时间戳和只读属性。
9. 共享 `.godot/**` 的完整路径/字节/SHA-256/UTC时间戳/属性清单。
10. 除任务23明确允许路径外的共享工作区全量路径/字节/SHA-256/Git blob/UTC时间戳/属性清单，以及完整 `git status --short --untracked-files=all`。
11. README：项目绝对路径、任务22失败与任务22B纠正摘要、三代 Overlay 对象映射、允许/禁止范围、固化UTC时间、复核命令和最终结论。

胶囊闸门：

1. 所有源对象必须直接来自只读 `git cat-file`；禁止 `hash-object -w`、对象库写入、人工重建或文本重定向造成编码/换行变化。
2. 任务23胶囊全部文件设置为Windows `ReadOnly`。
3. 在只读状态下对全部对象、原始字节、清单、路径、计数、字节、SHA-256、Git blob、UTC时间与属性做第二次独立复核。
4. 当前活体 Overlay、任务20 35项、任务21 17项、CombatHUD、Token、任务22文档/证据、共享`.godot`和允许范围外全量清单在固化期间必须无漂移。
5. 任一对象不可读、类型不是blob、计数/路径/哈希不一致、目标发生新写入或胶囊只读复核失败，立即把任务转为 `BLOCKED`；不得覆盖项目文件。

## 5. 后续执行允许写入范围

协调者下发“执行任务23”后，且第4节全部通过，才允许写入：

- `scripts/ui/run_overlay_interface.gd`：唯一允许修改的游戏文件；
- `docs/agent_tasks/pending/23_recovery_task12_overlay_final_baseline.md`：追加执行记录并把状态只更新到 `REVIEW`；
- `docs/agent_tasks/pending/22_recovery_task20_ui_to_task12_baseline.md`：只允许追加任务23交叉引用/执行结果，不得删除或改写历史失败与取证记录；
- `docs/agent_tasks/evidence/task23/overlay_final_recovery_delivery.md`：仅执行回合在胶囊和恢复完成后创建；
- 第4节全新工作区外只读胶囊。

除上述路径外不得写入。任务23执行回合不更新总索引、不移动任务书、不修改任务22交付证据。

## 6. 绝对保护范围

禁止修改、删除、重命名、格式化、保存、reimport、触碰时间戳或属性：

- `scripts/combat_hud.gd`，必须保持 Git blob `661d017c4bb2025541deb09d72ec55bf5a12594f`、33597字节、SHA-256 `a04f35f058f833eb97b97a262561673195eacd3a3ec17ade3f1cb4fe8442eda5`；
- `scripts/ui/combat_ui_tokens.gd`，必须保持 Git blob `78751a2d90c88f6457861717b7781c1d8179d278`、1856字节、SHA-256 `3d5f31126c969008ad3f5265777bf0b9067b5d3a22cd8dffcd0cfd1c43058994`；
- 任务20任务书、2个测试、32个证据文件，共35项；
- 任务21的17项资源；
- 任务22任务书以外的所有任务22文档与证据；任务22任务书仅可按第5节追加任务23交叉记录；
- `scenes/combat_hud.tscn`、`scripts/combat_feedback.gd`、`scripts/test_room.gd`、`scenes/test_room.tscn`；
- `combat/**`、`growth/**`、RunSessionHost、Player、Catalog、VFX、Delivery、Targeting、Carrier、Receiver、Resolver及所有测试；
- `project.godot`、共享 `.godot/**`、场景、资源、资产、插件与任何其他游戏文件；
- 任务22原胶囊及其他既有 `C:\tmp` 恢复/Review副本。

特别禁止：

- 启动、连接或复用共享Godot/编辑器/Godot MCP；
- 执行Godot、测试、导入、editor scan、smoke、截图、保存、`ResourceSaver`、reimport、plugin reload或`ProjectSettings.save`；执行者阶段全部禁止；
- 所有Git写操作及引用写入，包括 `add`、`commit`、`stash`、`reset`、`restore`、`checkout`、`clean`、`hash-object -w`、ref创建/移动/删除、`gc`、`prune`、`maintenance`和自动维护；
- 人工拼接任务12源码、从任务20反向删补、按错误日志只改两行、从聊天文本重新编码生成目标，或把 `2ca3…` 作为终态。

## 7. 精确恢复流程

1. 完成第4节胶囊与全部前置保护对账。
2. 再次只读确认 `b98a…` 存在、可读、类型为blob、26785字节，原始字节SHA-256为指定值。
3. 覆盖前重新确认活体 Overlay 仍精确为错误对象 `2ca3…`，并逐字节等于任务23胶囊保存的现场；若不一致立即 `BLOCKED`，不得覆盖未知新写入。
4. 写入时必须直接读取 `git cat-file blob b98a9c223f87caa983bb97d14639d73c62957337` 的精确原始字节，并在内存中先与只读胶囊目标副本逐字节相等；再将这些精确字节写入唯一游戏目标。禁止人工拼接、补丁猜测、换行转换、重新编码或从显示文本复制。
5. 写后立即计算字节数、SHA-256和Git blob；三者必须分别为26785、`e30e02d82ddecd6056f06a72683b7e5641013e09a8531e6be2837d7be23f6b68`、`b98a9c223f87caa983bb97d14639d73c62957337`。任一不等立即停止，不继续文档交付以外的任何写入。
6. 完成第8节静态验收和所有保护清单前后对账。
7. 写 `docs/agent_tasks/evidence/task23/overlay_final_recovery_delivery.md`，记录胶囊、恢复前后对象、静态结果、保护对账、精确写入清单和禁止事项遵守情况。
8. 在任务22任务书只追加任务23执行交叉记录；任务23状态只更新到 `REVIEW` 后冻结全部继续写入，等待全新独立Review。执行者不得自行标记 `ACCEPTED`、归档、运行测试或评估Git检查点。

## 8. 执行者静态验收

- Overlay Git blob精确为 `b98a9c223f87caa983bb97d14639d73c62957337`，26785字节，SHA-256精确为 `e30e02d82ddecd6056f06a72683b7e5641013e09a8531e6be2837d7be23f6b68`。
- `_claim_reward()` 与 `_choose_route()` 两处均为 `result.run_snapshot`，`result.snapshot` 为0处。
- 存在 `const UI := preload("res://scripts/ui/combat_ui_tokens.gd")`，任务12最终链的69处 `UI` 本地别名完整；不得回退为仅依赖全局类名的创建态。
- `_slot_drop` 使用任务12最终 `StringName(data.get(...))` 类型转换。
- 固定槽位文案与任务12最终链一致：`PASSIVE_1` 与 `String(slot_id).to_upper()`，不得恢复为空格化 `PASSIVE 1` 或旧文案。
- `_build_slot_card` 的局部变量名修正和 `_slot_drag_data` 的显式空ID返回补丁与任务12最终链一致。
- 奖励→路线→商店链仍由 `RunSession.claim_reward()`、`RunSession.choose_route()`、`result.run_snapshot`、`open_shop_draft()`、`preview_loadout()`和`RunSession.confirm_shop()`组成；不得复制或改变权威规则。
- 当前错误对象 `2ca3…` 仅存在于只读现场胶囊/历史记录，不得作为工作区终态。
- CombatHUD和Token精确对象、字节、SHA-256、UTC时间与属性前后不变。
- 任务20 35项、任务21 17项、任务22文档/证据（仅任务书允许追加）、场景、其他游戏文件、共享`.godot`和允许范围外全量清单前后逐项零差异。
- `git status --short --untracked-files=all` 排除任务23明确允许路径后逐行完全一致。

## 9. 全新独立 Review 门禁

任务23到 `REVIEW` 后，协调者必须创建全新独立Review；不得复用任务22执行者、任务23执行者、任务22失败Review、既有冷副本或缓存。共享工作区全程只读，所有Godot写入只允许发生在一个全新、此前不存在的 `C:\tmp` 冷副本及其外层artifacts。

### 9.1 冷副本与命令顺序

1. 在共享区只读复核任务23胶囊、三代Overlay对象、恢复后Overlay、CombatHUD、Token、任务20 35项、任务21 17项、任务22/23文档证据、`git status`与共享`.godot`全清单，形成运行前不变性基线。
2. 字节复制当前共享项目到新的 `C:\tmp` 冷副本，排除 `.git`、`.godot`、项目`tmp`、`__pycache__`和其他缓存；逐项核对路径、长度、SHA-256与UTC时间。
3. 冷副本中的第一条Godot命令必须是Godot 4.7.1 headless editor scan：`--headless --editor --path <new-copy> --quit`。此前不得运行任何runner、项目或导入命令。
4. scan必须退出码0，且完整stdout/stderr/editor log中 `SCRIPT ERROR`、`Parse Error`、恢复相关error/warning均为0，否则立即 `REVIEW FAIL`。

### 9.2 自动化与运行门禁

按顺序执行并扫描完整日志：

1. 任务12专项 `combat/tests/run_hud_loadout_feedback_tests.gd`：必须 `13 tests / 110 assertions` 全通过，`SCRIPT ERROR=0`。
2. 任务16专项 `combat/tests/run_skill_content_catalog_tests.gd`：必须 `11 / 209` 全通过。
3. 任务18专项 `combat/tests/run_skill_vfx_runtime_tests.gd`：必须 `9 / 124` 全通过。
4. 已验收基线18个唯一runner，明确排除仍属 `BLOCKED` 的任务20 runner：必须 `18/18 runners`、`224 tests / 1683 assertions` 全通过。
5. 任务20 `combat/tests/run_compact_hud_reward_tests.gd` 只作为非门禁诊断单独运行并单独报告；不得混入18-runner汇总，也不得把其失败冒充任务12回归。
6. 正式主场景至少180帧smoke：退出码0，完整stdout/stderr/game/editor日志无error、warning、`SCRIPT ERROR`或`Parse Error`。

### 9.3 实际图形 Viewport 复核

只有静态、editor scan、三个专项、18-runner门禁和smoke全部通过后，才可启动一个全新、非共享、非编辑器、禁止保存的图形Godot进程。所有Review-only夹具、截图、日志与缓存只写冷副本或artifacts。

必须从实际运行的正式TestRoom、正式CombatHUD和正式`RunContentCatalog`捕获并人工打开检查任务12九类证据语义：

1. 1152×648正式固定四槽HUD、CurrentElement、目标元素层数和任务17/18正式图标；
2. 900×540响应布局无越界、重叠或槽位跳动；
3. 色觉辅助仍以颜色+形状+文字表达水/火及层数；
4. 减少动态下锁定反馈语义完整；
5. ACTIVE槽放被动合法且移除键帽、能量和冷却；
6. PASSIVE_1拒绝主动并显示原因，预览不变；
7. 0主动+4被动警告清楚且不阻塞合法确认语义；
8. 单一最终伤害数字与实际反应倍率/消耗层数；
9. 正式Catalog奖励页，以及真实奖励→路线→商店/ShopDraft链路。

每张新证据必须来自实际Godot Viewport，列出绝对路径、像素尺寸和SHA-256；不得复用旧图、headless截图、静态解析、设计稿或外部拼图。人工记录布局、文字、焦点、越界、颜色冗余编码与语义，并检查完整图形进程日志。

### 9.4 共享区最终不变性

所有冷副本运行完成后，回到共享区只读复核：

- `git status --short --untracked-files=all` 与运行前逐行一致；
- Overlay、CombatHUD、Token内容/字节/blob/SHA/UTC/属性一致；
- 任务20 35项、任务21 17项、任务22/23文档证据逐项一致；
- 共享`.godot`完整路径、长度、SHA-256、UTC时间和属性逐项一致；
- 允许范围外共享全量清单逐项一致。

任何共享漂移、门禁runner失败、恢复相关脚本错误、日志错误或实际Viewport语义/布局回归均为 `REVIEW FAIL`；Review只报告，不修复、不改任务状态。

## 10. Git与归档边界

- 任务23独立Review通过之前，任务20、22、23均不得机械提交，任务22/23不得归档，也不得把当前共享脏工作树直接当作候选。
- 只有Review通过后，才能由协调者归档任务22与任务23，并重新评估阶段性Git检查点。
- 重新评估不等于自动提交：仍须在工作区外组装精确候选，排除任务20未接受实现/测试/证据、来源未闭合改动和其他不在检查点范围的状态，完整复跑正确冷启动门禁后再决定。
- Overlay Final Recovery Agent、任务23独立Review均不得执行任何Git写操作；提交范围、时机与说明只能由协调者决定。

## 11. 文档准备阶段冻结（2026-07-31）

本回合只准备任务文档：任务22改为 `BLOCKED` 并追加失败Review/任务22B纠正记录；创建本任务书；更新总索引。没有修改任何游戏文件，没有建立任务23胶囊，没有创建 `docs/agent_tasks/evidence/task23/` 或交付文件，没有运行Godot/测试，也没有执行Git写操作。

下一步必须等待协调者原文“执行任务23”。在此之前本任务保持 `PENDING`，负责人立即停止。
## 12. Overlay Final Recovery Agent 1.0 执行记录（2026-07-31）

协调者已发送原文“执行任务23”。执行侧严格只恢复一个游戏文件，不运行Godot，不自验收。

### 12.1 对象与现场闸门

- `b98a9c223f87caa983bb97d14639d73c62957337`、`2ca3b5792890357e802fac6b86b6ed8358d1c153`、`651ca094484dbc1e3b5fe6d309443d6ab14ded46`、CombatHUD `661d017c4bb2025541deb09d72ec55bf5a12594f`、Token `78751a2d90c88f6457861717b7781c1d8179d278` 均重新确认存在、可读、类型为blob，原始字节/大小/SHA-256/计算Git blob全部命中。
- 覆盖前活体Overlay逐字节等于 `2ca3…` 和新的任务23胶囊现场副本；HUD与Token逐字节等于各自正确对象。
- 任务20计数为35、任务21为17、任务22旧胶囊为13/13只读；全部前置计数和状态闸门通过。

### 12.2 全新胶囊与二次复核

胶囊：`C:\tmp\element-dungeon-task23-overlay-final-recovery-20260731`

- 共74个文件，74/74为Windows `ReadOnly`；73个先行payload有完整自清单。
- 保存三代Overlay原始blob、活体2ca3现场、任务20 35项、任务21 17项、CombatHUD、Token、任务22/23文档副本、任务22旧胶囊13项保护映射、共享`.godot`652项、允许范围外工作区1770项、Git状态971行和引用2行。
- 在只读状态下独立二次复核全部通过：对象、现场、复制字节、路径、计数、长度、SHA-256、Git blob、UTC时间和属性均匹配。
- 任务22原胶囊未被修改、补写、改属性或复用。

### 12.3 精确覆盖与静态验收

- 覆盖事务开始前再次完成允许范围外1770项、旧胶囊13项、文档现场、Git状态/引用、活体2ca3和目标b98a逐字节闸门。
- 唯一游戏文件直接使用该事务中新读取的 `git cat-file blob b98a…` 原始字节覆盖；未人工拼接、未从聊天文本重建、未只改两处字段、未从任务20反向删代码。
- 写后Overlay精确为：Git blob `b98a9c223f87caa983bb97d14639d73c62957337`、26785字节、SHA-256 `e30e02d82ddecd6056f06a72683b7e5641013e09a8531e6be2837d7be23f6b68`，并与该次cat-file字节逐字节相等。
- 第8节静态验收全部通过：`result.run_snapshot` 2处、错误字段0处、Token preload 1处、`UI.`别名69处、类型转换1处、固定槽位标题1处、`skill_name_label` 4处、显式拖拽空ID补丁1处、奖励→路线→商店权威调用5/5。

### 12.4 保护对账与交付

- 任务20 35/35、任务21 17/17、HUD/Token、任务22旧胶囊13/13、共享`.godot`652/652、允许范围外1770/1770、Git引用2/2均零差异；胶囊保持74/74只读。
- 完整交付记录：`docs/agent_tasks/evidence/task23/overlay_final_recovery_delivery.md`。
- 执行侧未启动、连接或调用Godot；未运行测试、editor scan、smoke、截图、导入或保存；未执行任何Git写操作、引用写入、`hash-object -w`、gc/prune/maintenance。

任务状态只更新到 `REVIEW`，此后冻结全部继续写入。必须由协调者创建全新独立Review，在新的 `C:\tmp` 冷副本中从首条Godot editor scan开始完成全部门禁；执行者不得自行标记 `ACCEPTED`、归档、运行验证或评估提交。