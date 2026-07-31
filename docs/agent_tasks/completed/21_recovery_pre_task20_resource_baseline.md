# 任务 21：任务 20 前资源基线精确恢复

状态：ACCEPTED
负责人：Recovery Agent 1.0
依赖：任务 12、16、18 已验收；任务 20 已阻塞；独立只读取证 `019fb6f5-0a9f-7081-89c5-ee93d2ab6d2d` 已完成

执行固化记录（2026-07-31 15:42:36 +08:00）：

- 工作区外恢复胶囊：`C:\tmp\element-dungeon-task21-recovery-20260731`
- 固化结果：16/16 个完整源 blob、17/17 个事故现场副本、17 行主清单、37 行任务 20 保护清单均逐项复核通过。
- 只读状态：胶囊共 37 个文件，37/37 已设为只读，并在只读状态下再次通过 SHA-256、Git blob、对象类型、路径和字节数校验。
- 覆盖闸门：任务前 17 个目标的 Git blob、SHA-256 与 UTC 时间戳已记录；胶囊固化前后均未发现目标新写入。本记录写入时尚未覆盖任何游戏文件。

## 1. 任务目标

本任务只处理 2026-07-31 14:31:48.xxx 共享 Godot 编辑器整批序列化事故：

1. 在任何覆盖前固化事故现场和 16 个不可达 Git blob；
2. 将 16 个发生内容变化的 `.tscn/.tres` 精确恢复到 14:19 覆盖前对象；
3. 对未发生内容变化的 `enemy_frames.tres` 只校验、不改写；
4. 形成可供全新独立 Recovery Review 2.0 验收的交付记录。

本任务不处理任务 20 的 HUD/奖励 UI 撤销，不修改任何 GDScript、测试、任务 20 证据或游戏逻辑。

## 2. 事故与恢复事实

- 仓库只有旧初始提交 `5424f48`；任务 05～20 的大量合法成果未提交或未跟踪，禁止恢复 HEAD。
- 14:31 批次共 17 个源文件；其中 16 个内容变化文件均有 14:19 覆盖前精确 blob。
- `resources/animations/enemy_frames.tres` 当前与 HEAD 字节一致，不需要恢复。
- `resources/animations/player_frames.tres` 的恢复对象保存完整 13 组动画及其纹理、Atlas 区域、帧序、速度与循环参数。
- 14:31 批次没有 `.gd`；资源恢复与三个任务 20 UI 脚本的撤销必须分为两个任务。

## 3. 完整恢复对象映射

执行前必须逐项确认对象类型为 `blob`、对象可读、对象内容与路径类型吻合。下表使用完整 40 位对象 ID，禁止缩写、猜测或替换：

| 目标文件 | 覆盖前精确 blob |
| --- | --- |
| `scenes/test_room.tscn` | `60fbc702e43ea772935ca76b76591d861aa19cb9` |
| `resources/element_slash.tres` | `6ca133e07aa4a283dc1e128690758d14712276da` |
| `resources/element_bolt.tres` | `4061fe15b016883aaf29fee7dea3fea4b37eee38` |
| `resources/skills/burning.tres` | `2ed01fc44d743c982aa78c7c3e5188ba8221fb18` |
| `resources/skills/element_reclaim.tres` | `ac9d7c0abdcd05a65c171002b8dacdb29248d4ae` |
| `resources/skills/elemental_fury.tres` | `860010bbd013d48a539fd23a168e892cb070b32b` |
| `resources/skills/elemental_laser.tres` | `7de02066db9405288d51707f91345ed70fe1233b` |
| `resources/skills/unending.tres` | `70b0ac637c55fd33a200d6edc7d805ff942c09eb` |
| `resources/content/skills/element_bolt_content.tres` | `b51d12bffd5b7301d55242667233cf0a0eeaaf63` |
| `resources/content/skills/elemental_fury_content.tres` | `18410d216a3afb2f1c5d58cf7d4f0baef984ec69` |
| `resources/content/skills/elemental_laser_content.tres` | `88956016035ada93ceb988935d43f371b99055b7` |
| `resources/content/skills/element_reclaim_content.tres` | `7d64d513f0c39860436b2098c2c261bbc7ddfdeb` |
| `resources/content/skills/burning_content.tres` | `c6b4801223d65a1efbcc3b9861f2c3fbb97343c4` |
| `resources/content/skills/unending_content.tres` | `21e31fefb03df4f8cf4970a0da6b1bf181ab4dd2` |
| `resources/animations/player_frames.tres` | `9c06c9c0d290c806f9f8c89b70d8b2c9e10f464b` |
| `resources/animations/element_projectile_frames.tres` | `cb82af84cfad1deff55e33ce35dd219122007d33` |

只校验、不改写：

| 文件 | 必须保持的 Git blob 哈希 |
| --- | --- |
| `resources/animations/enemy_frames.tres` | `5968dcef98517d7880c8d71d260fa927b0d5b187` |

## 4. 恢复前保护方案

执行 Agent 禁止 Git 写操作，因此本任务不创建 Git ref。恢复前必须在工作区外建立双份恢复胶囊：

`C:\tmp\element-dungeon-task21-recovery-20260731\`

至少包含：

- `source_blobs/`：按完整对象 ID 保存上述 16 个 blob 的原始字节；
- `incident_current/`：按原相对路径保存覆盖前当前工作区的 17 个事故文件；
- `manifest.tsv`：逐项记录路径、完整对象 ID、对象类型、源 blob 字节数、源 blob SHA-256、事故现场 SHA-256；
- `README.md`：记录生成时间、项目绝对路径、事故说明、禁止 `git gc/prune`、恢复工具与验证结果。

保护步骤必须在任何项目文件覆盖前全部完成：

1. 只读记录 `git status --short`；
2. 计算 17 个当前文件的 SHA-256 与 Git blob 哈希；
3. 从对象库提取 16 个源 blob 到 `source_blobs/`；
4. 复制当前 17 文件到 `incident_current/`；
5. 对外部副本重新计算 SHA-256，确认与源一致；
6. 将恢复胶囊内文件设为只读；
7. 把完整映射、胶囊路径和验证摘要写入本任务交付记录及 `docs/agent_tasks/evidence/task21/recovery_delivery.md`。

若任一对象不可读、类型不是 blob、外部副本哈希不一致、目标路径状态发生未知变化，立即停止；不得开始部分恢复。

全任务禁止 `git gc`、`git prune`、任何自动维护、`git add/commit/stash/reset/restore/checkout/clean`，也不得创建、移动或删除 Git 引用。

## 5. 允许修改范围

游戏项目文件仅允许精确覆盖第 3 节列出的 16 个目标。

交付记录仅允许：

- `docs/agent_tasks/pending/21_recovery_pre_task20_resource_baseline.md`
- `docs/agent_tasks/evidence/task21/recovery_delivery.md`
- 第 4 节指定的 `C:\tmp` 工作区外恢复胶囊

`resources/animations/enemy_frames.tres` 只允许读取和哈希校验，不允许保存、格式化、触碰时间戳或重写。

## 6. 绝对禁止范围

禁止修改、删除、重命名或格式化：

- `scripts/combat_hud.gd`
- `scripts/ui/combat_ui_tokens.gd`
- `scripts/ui/run_overlay_interface.gd`
- `combat/tests/run_compact_hud_reward_tests.gd`
- `combat/tests/capture_task20_visuals.gd`
- `docs/agent_tasks/evidence/task20/**`
- `docs/agent_tasks/pending/20_agent_e_compact_hud_reward_runtime.md`
- 任何其他 `.gd`、`.tscn`、`.tres`、`.godot/**`、`project.godot`、资产、测试或任务文档

不得启动或连接共享 Godot 编辑器，不得运行 Godot、测试、导入、扫描、截图或 smoke；不得调用保存、ResourceSaver、reimport、plugin reload 或 ProjectSettings.save。任务 21 的运行验证由后续全新独立 Review 在隔离副本中完成。

## 7. 精确恢复步骤

1. 完成第 4 节恢复胶囊并验证。
2. 再次确认 16 个目标与 `enemy_frames.tres` 没有在固化后发生新写入。
3. 从已验证的 `source_blobs/` 外部副本逐字节覆盖 16 个目标；不得手工重建、重新序列化或按默认值改写。
4. 每写一个目标立即计算 Git blob 哈希和 SHA-256；Git blob 哈希必须精确等于第 3 节对象。
5. 完成后再次校验 `enemy_frames.tres` 仍为 `5968dcef98517d7880c8d71d260fa927b0d5b187`。
6. 做纯静态验收并记录结果；不运行 Godot。
7. 只将任务状态更新为 `REVIEW`，冻结继续写入，向协调者回传交付摘要。

不得把 Git blob ID 当作普通文件 SHA-1；最终必须使用 Git blob 哈希算法或 `git hash-object` 验证对象等同，同时另记 SHA-256 供外部副本校验。

## 8. 执行 Agent 纯静态验收

- 16 个目标的 Git blob 哈希逐项精确等于第 3 节映射。
- `enemy_frames.tres` 保持 `5968dcef98517d7880c8d71d260fa927b0d5b187`。
- `player_frames.tres` 列出且仅列出以下 13 组动画：
  - `attack`
  - `fire_attack`
  - `fire_idle`
  - `fire_jump`
  - `fire_walk`
  - `water_attack`
  - `water_idle`
  - `water_jump`
  - `water_walk`
  - `hurt`
  - `idle`
  - `jump`
  - `walk`
- `player_frames.tres` 引用的 13 张纹理路径全部存在。
- `scenes/test_room.tscn` 中只有一个 `SkillVfxCoordinator` 节点/脚本接线。
- 六份内容资源均保留各自 `gameplay` 引用和任务 18 的正式 `icon`；Fury、Laser、Reclaim、Burning、Unending 保留正式 `presentation_scene`，Element Bolt 继续不复制第二套 presentation。
- `git status --short` 的任务 21 新变化只能来自 16 个恢复目标与本任务两份文档；其他条目与任务前记录逐项一致。
- 三个任务 20 UI 脚本及任务 20 测试/证据哈希与任务前一致。

## 9. 独立 Recovery Review 2.0 验收要求

执行 Agent 不得自验收。提交 `REVIEW` 后，由协调者冻结执行任务并新开全新独立 Recovery Review 2.0 对话。Review 至少完成：

1. 独立复核恢复胶囊、完整对象映射、16 个目标 Git blob 哈希及 `enemy_frames.tres`。
2. 独立复核 13 组玩家动画、13 张纹理、唯一 `SkillVfxCoordinator`、六内容资源的 gameplay/icon/presentation 引用。
3. 严格核对任务前后工作树 allowlist，确认三个 UI 脚本、任务 20 证据和其他来源不明改动未被触碰。
4. 在工作区外新建完整验证副本；所有 Godot 导入、`.godot` 写入、headless 测试与视觉运行只发生在该副本。
5. 在验证副本独立运行任务 12、16、18 专项及仓库全部 `run_*.gd` 无头入口，报告 runners/tests/assertions；必要的 editor scan 与至少 180 帧 smoke 也只在副本运行。
6. 使用全新非共享 Godot 进程、禁止保存，实际运行核验水/火 `idle / walk / jump / attack`；检查 editor/game 日志并提供可核验截图或逐项观察记录。

只有全新独立 Review 报告通过后，协调者才能把任务 21 标记为 `ACCEPTED` 并评估阶段性 Git 检查点。任务 21 验收前不得立项任务 22，也不得恢复任务 20 实现。

## 10. 交付

交付必须报告：

- 工作区外恢复胶囊绝对路径和只读状态；
- 16 个完整对象映射、源 blob SHA-256、事故现场 SHA-256、恢复后 SHA-256；
- 16 个恢复后 Git blob 哈希与 `enemy_frames.tres` 校验；
- 13 组动画、13 张纹理、唯一 Coordinator、六内容资源引用的静态结论；
- 精确修改文件清单；
- `git status --short` 任务前后差异；
- 未运行 Godot、未执行 Git 写操作、未触碰任务 20 UI/证据的明确声明；
- 任何异常、未决项或被迫停止原因。

执行完成只提交 `REVIEW`，不得自行标记 `ACCEPTED`、移动任务书或继续修复。

## 11. Recovery Agent 1.0 交付记录（2026-07-31）

交付状态：`REVIEW`。本任务只完成任务 20 前资源基线恢复，不自行验收，不继续处理 HUD/奖励 UI。

### 11.1 外部恢复胶囊

- 绝对路径：`C:\tmp\element-dungeon-task21-recovery-20260731`
- 生成时间：`2026-07-31 15:42:36 +08:00`。
- 内容：16 个 `source_blobs`、17 个按原相对路径保存的 `incident_current`、17 行 `manifest.tsv`、37 行 `protected_task20_manifest.tsv`、任务前 `git status --short` 与 `README.md`。
- 只读：胶囊共 37 个文件，37/37 的 Windows `ReadOnly` 属性已设置；设为只读后再次逐项验证，16/16 源对象身份、17/17 事故副本 SHA-256 和路径均通过。
- 对象闸门：17/17 对象可读且类型为 `blob`；16 个恢复对象均由 `git cat-file blob` 原始字节固化，未从默认值、编辑器或重序列化重建。

### 11.2 16 个精确恢复对象

| 目标 | 完整 Git blob | 源字节 | 源 blob SHA-256 | 事故现场 SHA-256 | 恢复后 SHA-256 |
| --- | --- | ---: | --- | --- | --- |
| `scenes/test_room.tscn` | `60fbc702e43ea772935ca76b76591d861aa19cb9` | 4840 | `429541744196ab74d12beb7e7033052e73afc11058f6e9867e7564411e887405` | `1e4d9dff7162a5a11bef01178136c878f6a7b11c59532df59fd60978fcc10b33` | `429541744196ab74d12beb7e7033052e73afc11058f6e9867e7564411e887405` |
| `resources/element_slash.tres` | `6ca133e07aa4a283dc1e128690758d14712276da` | 1112 | `2471d5b8bdc8a4742fd9cc4091fbab7ec402109b319ba311d90088be52a20e36` | `ba4cab466492aff23dd2fe84f9f5287a002d1a45d1176b1669d2d766d4b32bfe` | `2471d5b8bdc8a4742fd9cc4091fbab7ec402109b319ba311d90088be52a20e36` |
| `resources/element_bolt.tres` | `4061fe15b016883aaf29fee7dea3fea4b37eee38` | 1139 | `5a6c8ac4a064abeb814a7a0a1a67605452317e2cb75bb41cd9fb59e8fa215413` | `7a6a626468b33f47e366df26d53177969b5adfb710324485e89013810285c910` | `5a6c8ac4a064abeb814a7a0a1a67605452317e2cb75bb41cd9fb59e8fa215413` |
| `resources/skills/burning.tres` | `2ed01fc44d743c982aa78c7c3e5188ba8221fb18` | 618 | `d935addbceb436b1c0ba2f15e43b31d57ce995fd3adefedfb3b78c45f95c1dc3` | `080c6815d2033fe879051705a29fe380382e156ca85ee9283f6da81cdd4fa845` | `d935addbceb436b1c0ba2f15e43b31d57ce995fd3adefedfb3b78c45f95c1dc3` |
| `resources/skills/element_reclaim.tres` | `ac9d7c0abdcd05a65c171002b8dacdb29248d4ae` | 517 | `c2914bfcf6545cd7ded30b5bbf7a2be5969abf31fcc44f65e4ec0669e6b8595c` | `71c58feb3fad628b50dee56337d956fa7af91b5773a717e6f2cf3f083b689918` | `c2914bfcf6545cd7ded30b5bbf7a2be5969abf31fcc44f65e4ec0669e6b8595c` |
| `resources/skills/elemental_fury.tres` | `860010bbd013d48a539fd23a168e892cb070b32b` | 695 | `7b1151997debe3583a7d0f7b9e99dc1ce8e566ae4795dae7e41eb16990f14e5c` | `c1822e0588eb7e63cfcd50161b4c819bf92ec41bb6b4d76ab874efbbfb0c2727` | `7b1151997debe3583a7d0f7b9e99dc1ce8e566ae4795dae7e41eb16990f14e5c` |
| `resources/skills/elemental_laser.tres` | `7de02066db9405288d51707f91345ed70fe1233b` | 658 | `7f2b76817c661558947a7bad2ae31d8d64b67c9dc1a52f2fa63cde29c4da490f` | `521960df73f15a0c486758a283defdaeb64306d378cbb0e99bdddd34a32d427a` | `7f2b76817c661558947a7bad2ae31d8d64b67c9dc1a52f2fa63cde29c4da490f` |
| `resources/skills/unending.tres` | `70b0ac637c55fd33a200d6edc7d805ff942c09eb` | 589 | `30ed8a436547e561a0d78ee6535f2a44f638419c7af2826bd43a15a88aa9d797` | `90c46aac71a4a55520984ef5816b82bbefe27d88171132299d82a8cf7fa42b68` | `30ed8a436547e561a0d78ee6535f2a44f638419c7af2826bd43a15a88aa9d797` |
| `resources/content/skills/element_bolt_content.tres` | `b51d12bffd5b7301d55242667233cf0a0eeaaf63` | 782 | `5c3bf8f041fea91c9f26b3b4e750e0f535b9b6449d14e8c177f2b145a0b1e276` | `b81653af9575ab3b380679c827127a481411bb5c85a93baf3de955f29fad430f` | `5c3bf8f041fea91c9f26b3b4e750e0f535b9b6449d14e8c177f2b145a0b1e276` |
| `resources/content/skills/elemental_fury_content.tres` | `18410d216a3afb2f1c5d58cf7d4f0baef984ec69` | 1126 | `3a3e24aea84fdc0dd4fa6a7991ae620559828985eb03d3e5bd59cfbba102c8b3` | `d2fad6dce61d1c04b601f93753363830f1e573a35db9c879aa9a9a5df7743a57` | `3a3e24aea84fdc0dd4fa6a7991ae620559828985eb03d3e5bd59cfbba102c8b3` |
| `resources/content/skills/elemental_laser_content.tres` | `88956016035ada93ceb988935d43f371b99055b7` | 1136 | `06872ba2aff32fbf2eb1a894586b6b4ee20f08e648a6efa318e2e3f1c6276606` | `8ecaf921a982cc2f5671766ffb5fc51fb143f660950c773b5a317abdf5b2652a` | `06872ba2aff32fbf2eb1a894586b6b4ee20f08e648a6efa318e2e3f1c6276606` |
| `resources/content/skills/element_reclaim_content.tres` | `7d64d513f0c39860436b2098c2c261bbc7ddfdeb` | 972 | `95bc4d7b62de788652d9a117e47d460dad68c2f6e05f620b842577b65d14b96c` | `0ad1c47b5f09890059e0e9717f320322468dba38dd49e32efe3997e54accccb0` | `95bc4d7b62de788652d9a117e47d460dad68c2f6e05f620b842577b65d14b96c` |
| `resources/content/skills/burning_content.tres` | `c6b4801223d65a1efbcc3b9861f2c3fbb97343c4` | 913 | `af94ce6546cd70bbbbf9b8733aeafb84fd872177fa0305e55067d156e872a7c9` | `27284693e992d1b6f01c05bd75e8573e074fd9805b04553d2fb3a19998a614eb` | `af94ce6546cd70bbbbf9b8733aeafb84fd872177fa0305e55067d156e872a7c9` |
| `resources/content/skills/unending_content.tres` | `21e31fefb03df4f8cf4970a0da6b1bf181ab4dd2` | 931 | `fb37ba5c7c70dac40c10b20a25735c3af873488e09a0bb0979b78fa4f473e9db` | `e1849b5f5700cb8c7a9099619510c2c603046cbb79e6a95f04ee74f1b448b058` | `fb37ba5c7c70dac40c10b20a25735c3af873488e09a0bb0979b78fa4f473e9db` |
| `resources/animations/player_frames.tres` | `9c06c9c0d290c806f9f8c89b70d8b2c9e10f464b` | 19621 | `3c31be9f29079360c6a3592a931ae51ddc252de4a2c8184822f66ef2fdf4d3db` | `8800ac093185335b3b1a8a1b0b99c30bc9d1d5c5c278e882c9d84d2256285a88` | `3c31be9f29079360c6a3592a931ae51ddc252de4a2c8184822f66ef2fdf4d3db` |
| `resources/animations/element_projectile_frames.tres` | `cb82af84cfad1deff55e33ce35dd219122007d33` | 1815 | `69aa9fbb25638decb739a1a3b1e495971ccee25c332961d0d59fa120f0dda8aa` | `1ca1a7d8e8db2b53c6931dcd523a36d5b7af085143960c1c3ed1ea8c04937a3a` | `69aa9fbb25638decb739a1a3b1e495971ccee25c332961d0d59fa120f0dda8aa` |

只校验、未改写：

| `resources/animations/enemy_frames.tres` | Git blob `5968dcef98517d7880c8d71d260fa927b0d5b187` | SHA-256 `20c34357cda6fd70d235d9386a5e851d5a9f6b024316c031552d725ee6bbbe93` | UTC 时间戳 `2026-07-31T06:31:48.8128133Z`，与任务前及胶囊事故副本一致。

### 11.3 纯静态验收

- 16/16 恢复目标的最终 Git blob 逐项精确等于任务书第 3 节完整对象 ID；`enemy_frames.tres` 保持 `5968dcef98517d7880c8d71d260fa927b0d5b187`。
- `player_frames.tres` 恰好 13 组且无重复/额外动画：`attack`、`fire_attack`、`fire_idle`、`fire_jump`、`fire_walk`、`water_attack`、`water_idle`、`water_jump`、`water_walk`、`hurt`、`idle`、`jump`、`walk`。
- 13 张 Texture2D 路径全部存在：`cat_attack.png`、`cat_hurt.png`、`cat_idle.png`、`cat_walk.png`、`cat_jump.png`、四张 fire 动画图和四张 water 动画图。
- `test_room.tscn` 只有 1 个 `SkillVfxCoordinator` 节点、1 个 coordinator PackedScene 引用和 1 个对应实例；被实例化场景内部只有 1 个 coordinator 根节点、1 个正式脚本路径和 1 个脚本赋值。
- 六份内容资源均保留各自唯一 `gameplay_definition` 与任务 18 正式 `icon`；Fury、Laser、Reclaim、Burning、Unending 各保留 1 个正式 `presentation_scene`，Element Bolt 保持 0 个第二 presentation 并继续复用既有投射物表现。

| 内容 | gameplay | icon | presentation |
| --- | --- | --- | --- |
| `element_bolt` | `res://resources/element_bolt.tres` | `res://assets/generated/vfx/element_bolt/icon.png` | 无第二套 |
| `elemental_fury` | `res://resources/skills/elemental_fury.tres` | `res://assets/generated/vfx/elemental_fury/icon.png` | `res://scenes/vfx/elemental_fury_presentation.tscn` |
| `elemental_laser` | `res://resources/skills/elemental_laser.tres` | `res://assets/generated/vfx/elemental_laser/icon.png` | `res://scenes/vfx/elemental_laser_presentation.tscn` |
| `element_reclaim` | `res://resources/skills/element_reclaim.tres` | `res://assets/generated/vfx/element_reclaim/icon.png` | `res://scenes/vfx/element_reclaim_presentation.tscn` |
| `burning` | `res://resources/skills/burning.tres` | `res://assets/generated/vfx/burning/icon.png` | `res://scenes/vfx/burning_presentation.tscn` |
| `unending` | `res://resources/skills/unending.tres` | `res://assets/generated/vfx/unending/icon.png` | `res://scenes/vfx/unending_presentation.tscn` |

### 11.4 工作树与任务 20 保护

- 任务前与恢复后 `git status --short` 均为 463 行，逐行比较差异为 0；任务 21 的恢复目标和两份文档位于既有状态条目/未跟踪目录表示内，没有出现 allowlist 外新状态条目。
- 任务 20 保护清单 37/37 的字节数、UTC 时间戳、SHA-256 和 Git blob 均与任务前一致：3 个 UI 脚本、2 个任务 20 测试、32 个任务 20 证据文件（含 `.import`）。完整清单保存在胶囊 `protected_task20_manifest.tsv`，并复制到本交付证据的附表。
- 三个 UI 脚本 SHA-256：`combat_hud.gd` = `ef77b7d0cda39cbb7363197a0a20425ae3b6ae7be00482b2920d5fe6ea4674dd`；`combat_ui_tokens.gd` = `f15229f3e4b3c4dc821c1562169c6beabc312c69f2c1d85c0b948cef3ea0c3a0`；`run_overlay_interface.gd` = `9fe4f270fca47f0a4e52286f832ea50fba35bdeaafac54ebe2fc58c4672044cf`。
- 两个任务 20 测试 SHA-256：`run_compact_hud_reward_tests.gd` = `e305f7a154afeda1bf3bfcec4c46ee98ae0f85728a8e032cf4d1c943c5e7e5b2`；`capture_task20_visuals.gd` = `2aab6859dedea2f3f1da7ee2f6b50d4e3b7de59deddec4f9330375a29db6f50c`。

### 11.5 精确修改文件

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
- `docs/agent_tasks/pending/21_recovery_pre_task20_resource_baseline.md`
- `docs/agent_tasks/evidence/task21/recovery_delivery.md`

除此之外未修改任何项目文件；`resources/animations/enemy_frames.tres` 仅读取和校验，未打开写句柄、未改时间戳。

### 11.6 明确声明、异常与未决项

- 未启动、连接或调用 Godot；未运行测试、editor scan、smoke、截图、导入、保存、ResourceSaver、reimport、插件重载或 ProjectSettings.save。
- 未执行任何 Git 写操作；只使用了 `status`、`hash-object`、`cat-file` 等只读取证命令。未执行 add/commit/stash/reset/restore/checkout/clean、ref 写入、gc/prune/maintenance。
- 未修改三个任务 20 UI 脚本、两个任务 20 测试、`docs/agent_tasks/evidence/task20/**`、任何 GDScript、`project.godot`、`.godot/**` 或其他游戏文件。
- 工具层异常：最初两次单条超长 PowerShell 胶囊命令在创建胶囊目录前对 `elemental_fury_content.tres` 产生比较误报并立即中止；独立逐值复核显示其字节数、时间戳、连续 5 次 SHA-256 与 Git blob 始终匹配，指定胶囊路径仍不存在。随后改为短步骤、显式退出码和前后夹验，最终胶囊完整通过；这两次中止没有项目写入或部分胶囊。
- 未决项仅为任务书第 9 节明确移交的独立 Recovery Review 2.0：在工作区外副本运行 Godot/全量测试并实际视觉核验水火动画。本执行任务不包含这些运行验证。
- 写入本记录后立即冻结继续写入；状态只到 `REVIEW`，未标记 `ACCEPTED`。

交付记录生成时间：`2026-07-31 15:50:52 +08:00`。
## 12. 协调者独立验收（2026-07-31）

结论：`ACCEPTED`。任务 21 的任务 20 前资源基线精确恢复已通过全新独立 Recovery Review 2.1，允许归档。任务 20 仍保持 `BLOCKED`；本次验收只接受资源恢复，不授权继续或提交任务 20 的 UI 实现。

### 12.1 两轮 Review 的结论边界

- 首轮 Recovery Review 2.0：流程性 `REVIEW FAIL`。它在排除 `.godot` 的冷副本中没有先执行 editor scan，而是直接运行任务 12 runner，因全局脚本类缓存尚未建立而产生连锁 Parse Error，并按失败停止边界终止。该结果只证明验收命令顺序不正确，不构成资源回归、恢复对象错误或任务 21 实现失败的结论。
- 最终 Recovery Review 2.1：由全新独立 Review 从零开始，不继承首轮副本、缓存、静态数字或测试结论；在新的冷副本中把 Godot headless editor scan 作为第一条 Godot 命令，随后完成专项、全量、smoke、实际 Viewport 视觉和共享区不变性复核，最终 `REVIEW PASS`。
- 首轮报告：thread `019fb729-ea97-7ab1-a3ab-dcbe2e2a5f3d`，host `local`。
- 最终报告：thread `019fb734-5b80-7a22-b618-4de382748b63`，host `local`。

### 12.2 最终独立验收结果

- 外部恢复胶囊 `C:\tmp\element-dungeon-task21-recovery-20260731`：37/37 文件存在且均为只读；16/16 `source_blobs`、17/17 `incident_current`、17 行主清单和 37 行任务 20 保护清单均由 Review 2.1 独立重算通过。
- 16 个恢复目标与 1 个只校验资源的完整 Git blob、SHA-256 和对象身份全部通过；`enemy_frames.tres` 保持 `5968dcef98517d7880c8d71d260fa927b0d5b187`。
- `player_frames.tres` 恰好 13 组动画，13 张对应纹理全部存在；TestRoom 保持唯一 `SkillVfxCoordinator`；六份正式内容资源的 gameplay、icon 与 presentation 引用全部符合任务 18 基线。
- 全新冷副本第一条 Godot 命令为 headless editor scan：退出码 0，完整日志中 `SCRIPT ERROR=0`、`Parse Error=0`、`ERROR=0`、`WARNING=0`。
- 专项全部通过：任务 12 为 `13 tests / 110 assertions`，任务 16 为 `11 / 209`，任务 18 为 `9 / 124`。
- 全量 19/19 个唯一 runner 全部通过，共 `234 tests / 1797 assertions`；专项重复没有二次计入。
- 主场景 180 帧 smoke 退出码 0，日志无错误或 warning。
- 全新非共享、非编辑器图形 Godot 从实际运行 Viewport 捕获并人工复核 12 项正式玩家动画：水、火、基础各自的 `idle / walk / jump / attack` 全部通过；无空白帧、缺动画回退、元素串色、Atlas 裁切错位或基础动画回归。
- 共享工作区运行前后不变：`git status`、16+1 资源、37 项任务 20 保护文件和共享 `.godot` 完整清单逐项一致；Review 未修改共享项目、未执行 Git 写操作、未使用共享编辑器、未保存 Godot 场景或资源。

任务 21 至此验收闭环。后续若要撤销任务 20 的三个正式 UI 脚本，必须使用新的任务 22，并继续保护本任务已验收的 16+1 资源基线。