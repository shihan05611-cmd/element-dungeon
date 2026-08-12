# Task38 clean evidence（Review 6.0 隔离修复）

## 结论

独立 Review 发现上一轮执行冷副本混入 Task40 的 `scripts/combat_hud.gd` 与 `run_task30_run_ui_tests.gd`，使旧 evidence 错报 `304 tests / 4162 assertions`，旧四张 PNG 也不是 Task38-only 候选。本轮已从固定 HEAD 重新构建 clean 候选，完整替换旧日志、summary 与四图；旧 `4162` 数字和旧四图不再作为证据。

本轮 clean 结果：

- 正式 29-runner baseline 加 Task38：`30/30 runners / 304 tests / 4161 assertions`，全部 exit 0；
- `run_task30_run_ui_tests`：固定 HEAD 版本，`9 tests / 172 assertions`；
- Task38 专项：`3 tests / 38 assertions`；8 个直接受影响 runner：`8/8`；
- Task20 历史非门禁：`7 tests / 68 assertions`，只单列；
- RunGame/TestRoom 双 180 帧 smoke：均 exit 0；
- 非 headless capture：`1 test / 43 assertions / 4 screenshots`，exit 0；
- capture 后 final editor rescan：exit 0；
- 本轮 `44` 份 `.log` 的 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:`、`CrashHandlerException` 均为 `0`。

本轮没有修改任何 Task38 玩法代码、资源、catalog、runner/capture 源码或四枚 UID；只替换 `docs/agent_tasks/evidence/task38/**` 并更新任务书的执行记录/provenance。

## clean 候选 provenance

### 冷根与叠加集合

- 固定基线：`7c217775e7ffa22aeffe6dd6a2af6694aae72d92`；由只读 `git archive` 导出，不从 live worktree 复制基线。
- clean root：`C:\tmp\element-dungeon-task38-clean-evidence-20260812-01`；创建前不存在。
- 独立 profile：`C:\tmp\element-dungeon-task38-clean-profile-20260812-01`；创建前不存在。
- 项目外首扫日志目录：`C:\tmp\element-dungeon-task38-clean-artifacts-20260812-01`。
- archive 后只叠加 Task39 `ACCEPTED` 的 `19` 个正式资产/manifest 文件，以及 Task38 §3 的 `27` 个当前冻结文件；旧 Task38 evidence 未叠加。
- Task39 叠加包括五张正式 PNG/五个 `.png.import`、各资产 prompt/manifest 与 `docs/vfx/final_asset_manifest.md`；Task38 仍只读消费元素回响 icon/import。
- Task38 叠加包括 §3 的代码、资源、legacy runner、新 runner/capture、四枚 UID 与 taskbook；没有叠加 Task40、live `docs/agent_tasks/README.md` 或两份中文保护文档。

第一条 Godot 命令为 Godot 4.7.1 headless editor scan，exit 0；原始日志为 `logs/first_editor_scan.log`。所有后续 runner、smoke、capture 与 final rescan 都只在上述 clean root/profile 中执行。共享 Godot 没有进程，本轮未启动或控制共享实例。

### Task40 排除证明

以下 candidate 文件逐一与固定 HEAD blob 相同，而不是 live Task40 diff：

| 路径 | HEAD/candidate blob |
|---|---|
| `scripts/combat_hud.gd` | `9083fdf16adbdf0de0a40ee159f66828dfce1763` |
| `scripts/ui/run_overlay_interface.gd` | `bfb486959fdec337d5f342583298babcc59f4b47` |
| `combat/tests/run_compact_hud_reward_tests.gd` | `8cee798277965738d6c8d84cd67db096eb6fde67` |
| `combat/tests/run_task24_compact_hud_reward_tests.gd` | `810d4731c004b7ed35f8a065fb7e654e9e763891` |
| `combat/tests/run_task30_run_ui_tests.gd` | `a6f9bf36e232ecf3be15a7f6665d173b214f38d6` |

Task40 的新 runner/capture、两枚 UID、taskbook 与 evidence 在首次 scan 前和最终候选中均不存在；candidate 内按文件名搜索 Task40 为 `0`。candidate 的 `docs/agent_tasks/README.md` 与 HEAD blob 相同；两份 live 中文保护文档完全未进入。

## 实现合同（源码未变）

Reclaim 仍由 `CombatTargetQuery2D.query_visible_world_rect()` 将 source 当前 Viewport visible rect 的四角经 inverse canvas transform 转为世界包围矩形，再复用既有 shape query；没有固定 160 半径与 LOS/raycast，屏外目标排除，同元素/全层/+5 SP 每层/原子事务保持。

元素回响仍是 typed `ReactionEnergyPassiveEffectDefinition/Runtime`，通过现有 `RunSessionHost → PassiveEffectAdapter → PassiveEffectRuntime` 链路处理 accepted `CombatResult`。仅玩家 root owner 对非玩家目标造成的 accepted reaction settlement 固定恢复 `10 SP`，上限钳制并以 cast/delivery/hit/target identity 去重；没有事件总线、ICD、计时器或通用框架。

正式内容仍为 `passive_reaction_energy / 元素回响`，价格 `75`，catalog 为 `10 gameplay / 9 shop / 5 reward`。Task39 接受依赖保持：

| 文件 | bytes | SHA-256 |
|---|---:|---|
| `assets/generated/vfx/passive_reaction_energy/icon.png` | 54,682 | `92186B2F58BBFE79F385C5C7FF9B7D1C18EA91012E4C5E1FC24C153D24F40A74` |
| `assets/generated/vfx/passive_reaction_energy/icon.png.import` | 960 | `1137B32128C1F4565888AB702F6510C43E4A8DC0E745BE57A60F7AED6ED60DD7` |

四枚冻结 UID 未修改：

| 路径 | UID |
|---|---|
| `combat/passives/reaction_energy_passive_effect_definition.gd.uid` | `uid://c1bi8b2atwkmr` |
| `combat/passives/reaction_energy_passive_effect_runtime.gd.uid` | `uid://bwfdv1memwsy0` |
| `combat/tests/run_task38_reclaim_reaction_energy_tests.gd.uid` | `uid://bw2ff84n733mb` |
| `combat/tests/capture_task38_reclaim_reaction_energy_visuals.gd.uid` | `uid://2afpncyvoj23` |

## 自动化

### 直接受影响 runner

| runner | 结果 |
|---|---:|
| `run_task38_reclaim_reaction_energy_tests` | 3 tests / 38 assertions |
| `run_first_batch_delivery_tests` | 26 / 163 |
| `run_skill_execution_contract_tests` | 16 / 102 |
| `run_passive_runtime_contract_tests` | 6 / 65 |
| `run_skill_content_catalog_tests` | 11 / 236 |
| `run_task27_run_economy_progression_tests` | 11 / 315 |
| `run_task31_content_balance_tests` | 9 / 312 |
| `run_task32_formal_four_passive_content_tests` | 5 / 176 |

原始直接日志位于 `logs/direct/`。正式 30 项逐项日志位于 `logs/formal30/`；机器汇总 `logs/formal30/summary.csv` 的 SHA-256 为 `81C1B61F4769528393A913B5A228891D4C85268D7C646381E2DA02584FDF3ACD`。五类标记汇总 `logs/log_scan_summary.csv` 的 SHA-256 为 `923F456E5193997A3890E65058FEEA1BC1201A75FF3DE668CC13DEA31B851692`。另有首扫、Task20、双 smoke、capture 与 final rescan 日志。本轮共享正式 evidence 精确为 `README + 44 logs + 2 CSV + 4 PNG = 51 files`；所有正式生成证据均来自 clean root，没有与旧 evidence 混合。Godot 派生的 `summary.Exit.translation`、`summary.Runner.translation`、`summary.Summary.translation` 与 `.import` 一样仅留在冷副本，不纳入共享正式 evidence。

## clean 四图与人工 QA

四图都由 clean Task38-only TestRoom 非 headless Viewport 重生，保存前完成目标位置、SP 前后、被动 ID/runtime 与 authority 断言。四图字节与 SHA 均不同于被替换的旧污染图，并已逐张按原始分辨率打开检查。

| 文件 | 尺寸 | bytes | SHA-256 | QA |
|---|---:|---:|---|---|
| `viewport/01_reclaim_visible_far_1920x1080.png` | 1920×1080 | 154,582 | `E043DC0EAA14301CFD63FFF2CA14D95B1ABC4DF5271E0090231D8FF61EC7BC37` | 固定 HEAD HUD；玩家与 350 距离目标同屏，SP 65、A3 回收可见 |
| `viewport/02_reaction_energy_1920x1080.png` | 1920×1080 | 157,861 | `B6AE26DBAE60C3B2F2B4BDCE484D6673F5F4C684F16560872A5062D0BEF0C341` | 固定 HEAD HUD；P1 元素回响 icon/生效与 SP 50 可见 |
| `viewport/03_reclaim_visible_far_2560x1440.png` | 2560×1440 | 212,506 | `9D4244F049B2C3275EE698415F085BDAB0BCAC570E2660D40605C057A3437D01` | 大分辨率下玩家/目标、回收槽与 SP 清晰 |
| `viewport/04_reaction_energy_2560x1440.png` | 2560×1440 | 219,312 | `7CEE4B0650A393AD45AEED4AC6E9BE2D8E9A9F62CCA3AFEC490D123E43C2A182` | 大分辨率下 P1/runtime/+10 证据清晰 |

clean root 的 final rescan 为四图生成的 `.import`、为 summary 生成的 `.translation` 全部留在冷副本；共享 Task38 evidence 中两类派生文件均为 `0`。

## 共享外部状态与保护

- 本轮无 Git 写操作，不修改/恢复/删除/认领任何 Task38 evidence/taskbook 之外的共享变化。
- 共享 Godot/godot-ai 进程当前为 `0`；本轮没有自行重启。
- 共享 `.godot` 当前为 `990 files / 42,684,249 bytes / latest 2026-08-12T06:26:34.9868811Z`，与 Task38 原开工基线相同。
- 共享 sidecar 当前外部现状为 `617 files / 291,063 bytes / latest 2026-08-12T07:57:02.2853962Z`；本轮没有复制、恢复、修改或认领任何 sidecar。
- `AI协作中枢规则_浓缩版.md` 当前外部 SHA-256 为 `CB104DDA391DE0F3933AE97A55560AE182F7AEA45306E00E1CD6F4F768D69037`；`AI协作中枢运行协议_通用版.md` 为 `3745D2725AC0F484CFE447196D387F5D5E888A59BFC0F75A052DEBF6A8A55870`。两者原样保护、未进入 clean 候选、未修改/删除/认领/暂存。
- Task39/Task40/中枢的并行或外部变化均保留在共享区；clean 候选只用于证据，不回写其文件。
