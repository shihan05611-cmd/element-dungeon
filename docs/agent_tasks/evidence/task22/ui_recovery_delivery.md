# 任务22 UI 恢复交付记录

状态：`REVIEW`（仅执行者静态交付；不得据此自行 `ACCEPTED`）

日期：2026-07-31  
执行者：UI Recovery Agent 1.0

## 1. 结论

任务22严格恢复了且仅恢复了三个正式 UI 脚本到任务12已验收基线。三文件当前字节的 Git blob 与指定完整对象逐一精确相等；任务12固定四槽、CurrentElement、目标层数、Overlay、结构化反馈及可访问性接口完整，任务20的目标跟随/离屏回退、底部元素枢纽、冷却遮罩、紧凑响应布局与奖励焦点增量均已从这三份正式脚本中移除。

执行侧未启动或连接 Godot，未运行测试，未执行任何 Git 写操作，未保存、reimport 或 reload；任务状态只到 `REVIEW`，等待全新独立 Review。

## 2. 取证更正与候选证明

新的只读取证线程 `019fb764-5209-7900-abe9-f23bc65c13a4`（host `local`）证明唯一可信的任务12 CombatHUD 是 `661d017c4bb2025541deb09d72ec55bf5a12594f`：任务12线程的一次完整创建和随后11次补丁在内存中顺序重放后，与该对象33597字节逐字节相等。旧对象 `51b5c0828b18f583870f1a307467149c82fbec2d` 保留为已排除的旧 `primary/melee` HUD，未用于恢复、拼接或任何写入。

三个候选在覆盖前均确认对象类型为 `blob`，并按函数、常量、预载、公开接口与任务12任务书、专项测试、九张证据和交付记录交叉核对：

| 文件 | 任务12目标 Git blob | 字节 | SHA-256 | 结论 |
| --- | --- | ---: | --- | --- |
| `scripts/combat_hud.gd` | `661d017c4bb2025541deb09d72ec55bf5a12594f` | 33597 | `a04f35f058f833eb97b97a262561673195eacd3a3ec17ade3f1cb4fe8442eda5` | 唯一可信任务12 HUD |
| `scripts/ui/run_overlay_interface.gd` | `2ca3b5792890357e802fac6b86b6ed8358d1c153` | 27503 | `cce4473bdd09931e09afa68c8a33c05cdff2731d387dbadf726e76b4513069fd` | 任务12 Overlay 基线 |
| `scripts/ui/combat_ui_tokens.gd` | `78751a2d90c88f6457861717b7781c1d8179d278` | 1856 | `3d5f31126c969008ad3f5265777bf0b9067b5d3a22cd8dffcd0cfd1c43058994` | 任务12 Token 基线 |

详细人工证明与旧候选排除链见任务书 §11.1～§11.9；§11.7 是新取证更正的决定性记录。

## 3. 恢复前外部只读胶囊

胶囊：`C:\tmp\element-dungeon-task22-ui-recovery-20260731`

覆盖前完成创建、移动到最终路径和二次复核：

- 胶囊共13个文件，13/13 均为 Windows `ReadOnly`；恢复后复核仍为13/13。
- `source_task12_blobs` 保存三个目标对象的 `git cat-file blob` 原始字节，3/3 的对象、字节、SHA-256 与 Git blob 身份命中。
- `task20_current` 保存恢复前三个任务20脚本的原始字节，3/3 与现场的字节、SHA-256、Git blob、UTC 文件时间一致；胶囊副本随后设为只读。
- `manifest.tsv` 保存目标对象和恢复前现场双向映射；另保存工作区状态、任务20双口径清单及任务21的17项保护清单。
- 未创建 Git 引用，未运行 `git gc`、`git prune`、`git maintenance` 或其他 Git 写操作。

## 4. 37 / 35 / 38 保护口径

原任务21“任务20保护项37项”的逐路径原始口径是：3个允许恢复的 UI 脚本 + 2个任务20测试 + 32个任务20证据文件，且不含任务20任务书。胶囊以 `task20_original37_manifest.tsv` 完整保留该37项映射。

本任务“35项不可改保护清单”是：2个测试 + 32个证据 + 1份任务20任务书；三个允许恢复脚本不在这35项内，因为其任务20原始字节另存于 `task20_current`。两种口径并非缩减或漏项，唯一并集为38条路径：3脚本 + 2测试 + 32证据 + 1任务书。

最终对账：原37项中34个非目标现场文件不变，3个目标的任务20原始字节在胶囊中3/3精确保留；新35项不可改清单35/35不变。任务20任务书、两个测试和全部32个证据均未漏保。

## 5. 恢复前后精确映射

| 文件 | 恢复前字节 / Git blob / SHA-256 | 恢复后字节 / Git blob / SHA-256 |
| --- | --- | --- |
| `scripts/combat_hud.gd` | 53510 / `b061dea669df99e9dbbbb7dff73090c5f5457aae` / `ef77b7d0cda39cbb7363197a0a20425ae3b6ae7be00482b2920d5fe6ea4674dd` | 33597 / `661d017c4bb2025541deb09d72ec55bf5a12594f` / `a04f35f058f833eb97b97a262561673195eacd3a3ec17ade3f1cb4fe8442eda5` |
| `scripts/ui/run_overlay_interface.gd` | 40829 / `651ca094484dbc1e3b5fe6d309443d6ab14ded46` / `9fe4f270fca47f0a4e52286f832ea50fba35bdeaafac54ebe2fc58c4672044cf` | 27503 / `2ca3b5792890357e802fac6b86b6ed8358d1c153` / `cce4473bdd09931e09afa68c8a33c05cdff2731d387dbadf726e76b4513069fd` |
| `scripts/ui/combat_ui_tokens.gd` | 2017 / `f7bd19d12ec3fe980046f3d7baa1ee576d242f06` / `f15229f3e4b3c4dc821c1562169c6beabc312c69f2c1d85c0b948cef3ea0c3a0` | 1856 / `78751a2d90c88f6457861717b7781c1d8179d278` / `3d5f31126c969008ad3f5265777bf0b9067b5d3a22cd8dffcd0cfd1c43058994` |

写入使用重新读取的精确 `git cat-file blob` 字节，并先与只读 `source_task12_blobs` 逐字节相等；每个文件写后立即计算 Git blob 与 SHA-256，三者均精确命中目标，无部分覆盖。

## 6. 静态验收

- CombatHUD 为55个函数；存在固定 `ACTIVE_1 / ACTIVE_2 / ACTIVE_3 / PASSIVE_1`、`slot_panel()`、`feedback_text()`、`set_reduced_motion()`、`set_colorblind_mode()`、`cast_acceptance_feedback()`、`run_overlay`、Overlay/Token preload、`_enter_tree()`、`_build_ui()`、TargetPanel 与 ElementBadge。
- Overlay 为49个函数；保留四槽配装/预览、0主动警告、奖励领取、路线、商店与色觉接口。
- Token 保留任务12的19个语义常量和 `panel()`、`flat_panel()`、`button_style()`；HUD/Overlay 对 Token 的22个引用全部可解析。
- `scenes/combat_hud.tscn` 仍为194字节的最小场景，并仍引用 `res://scripts/combat_hud.gd`；未修改场景。
- 三份基线之间的预载、公开接口及 Token 引用静态兼容。
- 未发现任务20的权威目标投影/离屏回退、底部 CurrentElement 枢纽、冷却遮罩、紧凑断点/面积响应布局、奖励卡焦点与独立确认增量；`SIZE_EXPAND_FILL + SIZE_SHRINK_CENTER` 的任务20下沉实现不在恢复后的任务12基线。

## 7. 恢复后保护对账

首次最终对账（写交付记录前）全部通过：

- 允许范围外共享工作区：1767/1767，文件集合、字节、SHA-256、Git blob、UTC 时间和只读状态零差异。
- 其中共享 `.godot`：652/652，前后不变。
- 任务20不可改清单：35/35，零差异。
- 原始37项映射：34个非目标现场文件零差异；3个允许恢复目标的任务20原始副本3/3精确且只读。
- 任务21已验收16+1资源：17/17，完整 Git blob、字节、哈希及元数据零差异。
- 胶囊目标源：3/3；胶囊总文件：13/13只读。
- `git status --short --untracked-files=all`：覆盖前969行，脚本恢复后仍969行；排除本任务允许路径后均为965行且逐行差异为0。

交付记录与任务书状态写入后的同口径最终复核已通过：任务书首部为 `状态：REVIEW`；允许范围外仍为1767/1767零差异，`.godot` 652/652、任务20不可改35/35、原37项的34个非目标与3个原始只读副本、任务21的17/17、三个恢复目标及胶囊13/13只读均零失败。Git status 由覆盖前969行变为970行（新增本任务允许的交付文件）；排除任务22允许路径后前后均为965行，逐行差异0。该结果作为本记录的最终保护结论。

## 8. 实际允许写入与冻结

共享工作区实际写入仅限：

1. `scripts/combat_hud.gd`
2. `scripts/ui/run_overlay_interface.gd`
3. `scripts/ui/combat_ui_tokens.gd`
4. `docs/agent_tasks/pending/22_recovery_task20_ui_to_task12_baseline.md`
5. `docs/agent_tasks/evidence/task22/ui_recovery_delivery.md`

工作区外仅创建并冻结上述 `C:\tmp` 胶囊。未触碰任务20任务书/测试/证据、任务21的16+1资源、场景、TestRoom、CombatFeedback、其他脚本资源、`project.godot` 或 `.godot`。

任务22现交付 `REVIEW`。执行者停止继续写入；独立 Review 必须在新冷副本中按任务书要求从首条 Godot `editor scan` 开始，并由协调者决定后续状态。