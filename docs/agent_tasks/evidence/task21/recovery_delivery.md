# 任务 21：资源基线恢复交付证据

状态：`REVIEW`

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

## 附表：任务 20 保护清单

| 路径 | 字节 | UTC 时间戳 | SHA-256 | Git blob |
| --- | ---: | --- | --- | --- |
| `scripts/combat_hud.gd` | 53510 | `2026-07-31T06:41:36.9241150Z` | `ef77b7d0cda39cbb7363197a0a20425ae3b6ae7be00482b2920d5fe6ea4674dd` | `b061dea669df99e9dbbbb7dff73090c5f5457aae` |
| `scripts/ui/combat_ui_tokens.gd` | 2017 | `2026-07-31T05:47:22.1444376Z` | `f15229f3e4b3c4dc821c1562169c6beabc312c69f2c1d85c0b948cef3ea0c3a0` | `f7bd19d12ec3fe980046f3d7baa1ee576d242f06` |
| `scripts/ui/run_overlay_interface.gd` | 40829 | `2026-07-31T06:24:24.9204497Z` | `9fe4f270fca47f0a4e52286f832ea50fba35bdeaafac54ebe2fc58c4672044cf` | `651ca094484dbc1e3b5fe6d309443d6ab14ded46` |
| `combat/tests/run_compact_hud_reward_tests.gd` | 16502 | `2026-07-31T06:32:26.8613830Z` | `e305f7a154afeda1bf3bfcec4c46ee98ae0f85728a8e032cf4d1c943c5e7e5b2` | `25d651580fbda7c8b08d711330239fcce5b1980f` |
| `combat/tests/capture_task20_visuals.gd` | 8685 | `2026-07-31T06:37:47.3733827Z` | `2aab6859dedea2f3f1da7ee2f6b50d4e3b7de59deddec4f9330375a29db6f50c` | `ae324f2f9814641496560e8530417d9eb89bb721` |
| `docs/agent_tasks/evidence/task20/01_hud_1152x648.png` | 34506 | `2026-07-31T06:34:58.8452543Z` | `daa1d7ab38dd98ca1fe91b80d5e63b14835a403b09defa170f3dc62fed0a8778` | `6c2428ca872e923c0cee3bb39649db474958b442` |
| `docs/agent_tasks/evidence/task20/01_hud_1152x648.png.import` | 982 | `2026-07-31T06:38:13.9310394Z` | `e9138d4b59a0a9724bdd121597c329c9b4aa400e48a3fabbac651c20658f2027` | `1629bc04f5598b187aa69a8a77a864169ffb291a` |
| `docs/agent_tasks/evidence/task20/01_hud_1920x1080_main.png` | 69607 | `2026-07-31T06:38:06.8891908Z` | `bcfc9baaa6481d15c8de1619db7b302d3ac181e8b75f12dc97127247ac1c88c7` | `95599152699e3717ba3d982077045f315487717a` |
| `docs/agent_tasks/evidence/task20/01_hud_1920x1080_main.png.import` | 999 | `2026-07-31T06:38:14.4498171Z` | `52415c4ff5ad65c1782d1d4956b2c47ad1346a18f6ca82768f2d8a8082b4ba71` | `b41f4652f5dd185b66f9c7b8c3fcb3010f7a8cf8` |
| `docs/agent_tasks/evidence/task20/01b_hud_2560x1440_scale.png` | 97389 | `2026-07-31T06:38:07.0656308Z` | `52f0793080be2612bcd2ca8107c94932e3e993530b0cc25c850c5dcdec1a0680` | `7534721a582d0cd4c8f53d7f51e7670afbc63b52` |
| `docs/agent_tasks/evidence/task20/01b_hud_2560x1440_scale.png.import` | 1005 | `2026-07-31T06:38:14.5209714Z` | `724c497c5a7230d8e9df135857ae7743873b972dd62650fff70b8c956fc0d893` | `7932d08beb7315010a5cda1120148943ea3638f9` |
| `docs/agent_tasks/evidence/task20/01c_hud_3840x2160_scale.png` | 158687 | `2026-07-31T06:38:07.4260471Z` | `a0d9c9cf52db979cb4200fc7dc51dffe300ca6b96c174465b4c6528f0c2f58d7` | `f6384830a55e744f66e06196c537688e5587d41e` |
| `docs/agent_tasks/evidence/task20/01c_hud_3840x2160_scale.png.import` | 1006 | `2026-07-31T06:38:15.4519619Z` | `8fc5038c227e86971440c6c4bb60b81583361ca39f42f27b8fcad7486eb47d85` | `057bfb48e18d09af84ff2a26ad3686c933a6c0b9` |
| `docs/agent_tasks/evidence/task20/01d_hud_1152x648_logic.png` | 34570 | `2026-07-31T06:38:07.4871910Z` | `c9f2200ed28a2cac2c4d5a43f64a86ff211f02853de5a7db13f76f40b67b77db` | `1ec3c48f023b9f928018816720cb1db8e08e0cc1` |
| `docs/agent_tasks/evidence/task20/01d_hud_1152x648_logic.png.import` | 1003 | `2026-07-31T06:38:13.9310394Z` | `bfb4b4bb2c3172c0a2a81ae0e0fae085b8abc846be1680b8b13d2dbe39dc13f4` | `f9ef08b7e5b9f27a6917296b3e038ffa20653596` |
| `docs/agent_tasks/evidence/task20/02_hud_900x540.png` | 35447 | `2026-07-31T06:38:07.5462756Z` | `1a0f4fb0e335118af3eb32c2e6335c564e4da7f3cdafd9c3df9c02d9ffca8cee` | `401e22cf651682e9bbb8a60564b2a769604ffe54` |
| `docs/agent_tasks/evidence/task20/02_hud_900x540.png.import` | 979 | `2026-07-31T06:38:14.0147926Z` | `593311fee5db5f136633dc536597beb8800dff4f83d8648e6917226c0e359ebe` | `b653f66848466bfd021057ceae514e70b4315f4a` |
| `docs/agent_tasks/evidence/task20/03_states_cooldown_energy_busy_failure.png` | 114546 | `2026-07-31T06:38:07.6927921Z` | `7e15296c1552f9c6929f3a391803f780a5f65e461be8407ce3f826cf717b1a77` | `d4e73971643268cff89306e0c2bd98b060447c3f` |
| `docs/agent_tasks/evidence/task20/03_states_cooldown_energy_busy_failure.png.import` | 1051 | `2026-07-31T06:38:14.4427974Z` | `95df7ef1125539005d454ab604bd7cf17d8558b2f72e0f93109ac6b994be5b0d` | `d6bbff749d7bae633072aabc73b6c5b24fc12410` |
| `docs/agent_tasks/evidence/task20/04_target_follow.png` | 115799 | `2026-07-31T06:38:07.8088793Z` | `d8b501236f61d06db7ef5dea4f577c1a794da73238d248f3b1db8aed43e25c38` | `57ffea795b0f6a805763137759ac87603a1d5a44` |
| `docs/agent_tasks/evidence/task20/04_target_follow.png.import` | 983 | `2026-07-31T06:38:14.3987439Z` | `ea34e713b6d0ed951d11ceb521822f12075ba03dea5a190eb2277ceaf90d11f7` | `1aff0d1aa2caa4f78ad4efff47c14e0f54b62ca5` |
| `docs/agent_tasks/evidence/task20/05_target_fallback.png` | 111564 | `2026-07-31T06:38:07.9245029Z` | `396cc9f406e9b8edada751037d2fc902865e8d916ac1428bc265d5e624ed2522` | `d15e6bebdfffd38c3c5043dc9403e4dcbf94e853` |
| `docs/agent_tasks/evidence/task20/05_target_fallback.png.import` | 991 | `2026-07-31T06:38:14.5317021Z` | `27a7c3e07d1295601271427109d2edaa7b44c1b199749edc3ce7c95877686171` | `8acf8c8b1f43e6bfa8e59fc87573755ca02e3575` |
| `docs/agent_tasks/evidence/task20/06_reward_three.png` | 287564 | `2026-07-31T06:38:08.0901999Z` | `e15ddea133a7ae6a28055d4e8ad9530eb3abae327e7cd1f27c6c78f1228dbc63` | `9099fd56d709fda06c3203d47a4b0071e7036b5d` |
| `docs/agent_tasks/evidence/task20/06_reward_three.png.import` | 982 | `2026-07-31T06:38:14.9140600Z` | `dc75ba7053c68712fd69f845d313d0dbdf2231a480e9de0ef04694ac49ed716a` | `59c3b72e6a14d5cf15d6d6871203378216ee7339` |
| `docs/agent_tasks/evidence/task20/07_reward_two.png` | 227491 | `2026-07-31T06:38:08.2371982Z` | `aa1f0a3b2f45b1844b6ff08e82e9fcb2585a1ded062cde38345a2d87aa8c627f` | `aa30a339357fbebf5491fc55d45905339cc5f221` |
| `docs/agent_tasks/evidence/task20/07_reward_two.png.import` | 976 | `2026-07-31T06:38:14.9646994Z` | `615d9debb221220d89f0edd87d4e08326b96fb8138e94c3c2670a44d65c33d79` | `fe9f666f4c6bef1b87c7e29fd15302fe71cdcfab` |
| `docs/agent_tasks/evidence/task20/08_reward_one_explicit_confirm.png` | 163808 | `2026-07-31T06:38:08.3706890Z` | `cbd56c5de5475d0403ce5c3bb7a4c1841f5fbed1455fdb0976142948146f375f` | `290ba5e4a0170f6702dac61370618d8789a45073` |
| `docs/agent_tasks/evidence/task20/08_reward_one_explicit_confirm.png.import` | 1027 | `2026-07-31T06:38:14.9570349Z` | `b30236af91f20cc7dad4dfd207be5a92144c694be2a212b6bc805c7191dc811b` | `9b3c3b531a7b663a6f1cad953c4820008f895bde` |
| `docs/agent_tasks/evidence/task20/09_reward_long_copy.png` | 453619 | `2026-07-31T06:38:08.5580806Z` | `d35897d29e8ea560439595b8775882507a9000e716e653a14bf43afd696afd11` | `7711d01808dfd433ca7507a241cc0eba3e7b1e7b` |
| `docs/agent_tasks/evidence/task20/09_reward_long_copy.png.import` | 994 | `2026-07-31T06:38:15.1041991Z` | `6c141a1f1226ba1641589aa6dda8155b3e5c2960abeeb4c73d441bd04b8f56cb` | `90d0a9ad5f92742217022888b9206f794cfd3af8` |
| `docs/agent_tasks/evidence/task20/10_colorblind.png` | 126806 | `2026-07-31T06:38:08.6971296Z` | `513cea9e983039d922073df6b365b4fdc9086a041546af61f35b0fc8efb1c54d` | `025f1a06af02d24ab42ed5b9e7d8ec6f103afcde` |
| `docs/agent_tasks/evidence/task20/10_colorblind.png.import` | 976 | `2026-07-31T06:38:15.0626913Z` | `9d334350508f9bab7ae99673dcc747ed88cbfab0b050d909d46cde7368cd6aa8` | `e5cb060bfb6fc233b78809f16c4f6065db19ccd5` |
| `docs/agent_tasks/evidence/task20/11_reduced_motion.png` | 126912 | `2026-07-31T06:38:08.8312972Z` | `674a0380683a780563602e45e787bdeec77a42595d95dc7d36d3c142d0083931` | `899c655a284eae56a6575117e215ebb7f82fa724` |
| `docs/agent_tasks/evidence/task20/11_reduced_motion.png.import` | 988 | `2026-07-31T06:38:15.4686593Z` | `8496e004814fc9be681db8a36bded2ff0503a2795634e188ffb8b8eb93f266da` | `5272a514c6bf4e9fed7b35e6a9dc3a0699025306` |
| `docs/agent_tasks/evidence/task20/12_task18_vfx_unobscured.png` | 128472 | `2026-07-31T06:38:08.9838688Z` | `02cd8188a9a85183133266ff7b022f9b04ef8dacaeff40f903073d4dceb2de22` | `992114bf767b47247d3b701a82e5d403d81df596` |
| `docs/agent_tasks/evidence/task20/12_task18_vfx_unobscured.png.import` | 1008 | `2026-07-31T06:38:15.5235133Z` | `af84ea0152b5d2b423b104f97e6859920e564c17ff7c502c5c68e189b58251f3` | `7b59ea81c0a4ec6a95be9551c65a4872bf5f3994` |

