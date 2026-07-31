# Agent D 2.0 任务书：技能内容目录与首批正式内容集成

状态：ACCEPTED
负责人：Agent D 2.0
协调线程：Agent D 2.0 专用新任务（任务 15 已验收，现已正式下发）
依赖：14_agent_b2_skill_execution_contracts、15_agent_c_first_batch_deliveries 已通过 Review
表现依赖：17_vfx_agent_first_skill_assets 的可入库资产清单；逻辑接线可先开始，最终表现字段不得指向临时目录

## 1. 任务定位

建立唯一的技能内容注册源，把任务 14 的执行契约、任务 15 的具体行为、成长奖励、拥有库、共享配装和正式 Host 接成首批六技能闭环。

本任务负责内容和集成，不重新实现 B 的执行策略、C 的 Delivery，也不修改战斗公式。

## 2. SkillContentDefinition

新建不可变 `SkillContentDefinition` 或等价 Resource，至少包含：

- 权威 skill_id。
- 中文显示名和描述。
- 图标、VFX/presentation 引用或明确的可选表现引用。
- 获取方式：固定普通攻击、初始拥有、奖励池、未来解锁条件。
- 是否允许装备及默认槽位建议；槽位合法性仍由 RuntimeSkillLoadout 决定。
- 唯一 `SkillDefinition` gameplay 引用。
- 从本内容生成 Growth 所需奖励投影的静态信息。

它不得保存冷却剩余、当前能量、施法者、目标、计时器、拥有状态或装备状态。

显示名、描述、允许元素和奖励池标志不能再由另一份手写 Resource 与同一 skill_id 重复维护。若 Growth 仍需要 `SkillRewardDefinition`，应由内容定义确定性投影，而不是保留两套独立事实。

## 3. 单一 RunContentCatalog

新建一个正式 `RunContentCatalog` Resource，统一提供：

- 全部 Gameplay SkillDefinition。
- 可获取 SkillContentDefinition。
- 初始拥有技能 ID。
- 奖励池投影。
- 固定普通攻击定义。
- 当前正式遗物目录。

目录构建时一次性验证：

- skill_id 唯一且非空。
- Content、Gameplay 和奖励投影 ID 一致。
- 初始拥有、默认装备和奖励池只引用已注册内容。
- 固定普通攻击不可进入共享四槽或随机奖励。
- 被动和主动的执行定义、槽位类型和元素策略合法。
- 所有正式 Delivery 场景满足任务 11/14/15 的协议。

`scripts/test_room.gd` 不再维护三组散落 preload 数组；`RunSessionHost` 接受单一目录或目录生成的类型化快照。

## 4. 首批正式技能

稳定 ID 与规则如下，不得自行改名或调整数值：

### 4.1 `element_bolt` / 元素弹

- CURRENT_ELEMENT 主动，初始拥有并默认装备到 ACTIVE_1。
- 固定消耗 10 能量。
- 100% 攻击力伤害，小型投射物，附着 1 层。
- 无冷却。

### 4.2 `elemental_fury` / 元素之怒

- CURRENT_ELEMENT 主动，关卡宝箱奖励池。
- 最低 20 能量，接受时消耗全部当前能量。
- 倍率、附着和半径严格使用任务 14 快照与任务 15 Delivery。

### 4.3 `elemental_laser` / 元素激光

- CURRENT_ELEMENT 主动，关卡宝箱奖励池。
- 每 0.5 秒消耗 5 能量、造成 50% 攻击力伤害、附着 1 层。
- 穿透全部合法目标，引导期间允许移动。

### 4.4 `element_reclaim` / 回收

- CURRENT_ELEMENT 功能型主动，关卡宝箱奖励池。
- 不消耗能量，冷却 5 秒。
- 吸收范围内全部当前元素层数，每层理论恢复 5 能量。
- 无匹配层数或玩家满能量时释放失败。

### 4.5 `burning` / 燃烧

- 固定火元素语义的被动，关卡宝箱奖励池。
- 每秒对有火附着的敌人造成 `火层数 × 5%` 攻击力伤害。
- 不消耗火层，不受角色 CurrentElement 影响。

### 4.6 `unending` / 不息

- 固定水元素语义的被动，关卡宝箱奖励池。
- 固定普通攻击成功命中目标时，按该目标水层数 × 1 恢复生命。
- 不消耗水层，不受角色 CurrentElement 影响。

固定普通攻击 `element_slash` 继续位于共享四槽之外。它必须注册到目录供 Player 使用，但不计入上述六个可获取技能。

## 5. 旧原型内容

- `water_lance`、`fire_lance` 和四个旧属性被动不再作为首批正式奖励池。
- 若现有回归或旧配置迁移仍依赖它们，可保留为明确标注的 legacy/test fixture；不得与正式 Catalog 双重注册。
- 不得删除任务 11 保留的一次性旧 Loadout 迁移能力。
- 首批正式目录保存后只写共享新格式。

## 6. 正式接线

- TestRoom 只引用一个 RunContentCatalog。
- Host 从目录创建唯一 RuntimeSkillLoadout、初始拥有库、奖励池和遗物目录。
- 初始拥有 `element_bolt`，默认 ACTIVE_1；ACTIVE_2、ACTIVE_3、PASSIVE_1 可为空。
- 固定普通攻击始终可用，不依赖拥有库和共享槽。
- 宝箱奖励可以生成其余五技能，领取后进入拥有库。
- 商店/配装遵守 ACTIVE 可放主动或被动、PASSIVE_1 只放被动、0 主动 + 4 被动合法。
- 换装后被动 Runtime 原子替换；死亡、换层、读档和新局不重复注册。
- Player 使用任务 14 的移动策略，使激光引导不锁水平移动；其他技能按各自策略处理。
- 普攻命中成功后发布不息需要的类型化事件。
- 燃烧使用正式敌人查询/伤害提交接线，不得由 HUD 或动画驱动。

## 7. 表现资产接线

- 内容字段只引用任务 17 已进入仓库的最终文件。
- 元素弹、元素之怒、激光和回收的动态元素表现必须根据锁定元素着色，不能读取实时 CurrentElement。
- 燃烧固定火语义；不息固定水语义。
- VFX 尺寸不得反向改变任务 15 的逻辑范围。
- 若任务 17 尚未完成，可先用明确的开发占位引用验证逻辑，但任务最终验收前必须删除临时路径和无来源占位。

## 8. 文件范围

可修改：

- 新建内容定义和目录 Resource/脚本。
- `resources/**` 中首批正式技能、目录及奖励投影资源。
- `scripts/run_session_host.gd`
- `scripts/test_room.gd`
- `scripts/player.gd`
- `scripts/passive_effect_adapter.gd`，仅做任务 14 契约的正式端口接线
- TestRoom/Player 必要场景接线
- Growth 目录输入的窄适配层
- Agent D 2.0 集成测试和内容说明

不得修改：

- `SkillExecutor` 的费用、事务和 Channel 内部。
- 任务 15 已验收的 Delivery、范围和原子消费规则。
- 水火反应、DamageResolver 和 CombatReceiver。
- RunSession 的奖励、商店、路线核心规则；若目录适配发现缺口，先报告 Review。
- HUD 布局和任务 12 的完整界面工作。
- 任务 17 的源图、提示词或美术资产。

## 9. 自动与端到端验收

- Catalog 对重复 ID、缺 Gameplay、奖励指向未知技能、固定普攻进入奖励池等配置明确拒绝。
- TestRoom 和 Host 不再手写多份技能/奖励数组。
- 六个正式技能数值、元素策略、行为类型和获取方式逐项验证。
- 元素弹初始拥有并装备；其余五技能能经正式奖励/拥有/商店/配装闭环使用。
- 元素之怒 19 能量失败、20/100 能量结果正确。
- 激光持续移动、穿透多敌人、0.5 秒扣能和伤害正确。
- 回收无附着和满能量失败；有效范围原子消耗并恢复。
- 燃烧按火层每秒结算；不息只在固定普攻命中时按水层回血。
- 两个被动均不受角色 CurrentElement 影响，且死亡/换层/读档不重复注册。
- 共享 3+1 槽、0 主动配置、旧 Loadout 迁移和任务 10 闭环无回归。
- 全量测试和主场景 smoke 通过，无脚本错误或新增警告。

## 10. 协作限制

- 不得与任务 12 同时修改 HUD、Host、TestRoom、Player 或正式场景。
- 可与任务 17 的纯资产生产并行，但双方只能通过资产清单和稳定路径对接，不能同时修改同一 `.tres`。
- 若任务 17 资产未完成，D 2.0 先完成逻辑和测试，等待最终清单后再收口表现引用。

## 11. 交付

- 报告 Catalog 结构、六技能资源、旧原型内容处理和所有接线路径。
- 提供“内容定义 → Gameplay → 奖励 → 拥有 → 配装 → Runtime”的 ID 对照表。
- 报告专项、全量和 smoke 结果及尚未完成的表现项。
- 不执行任何 Git 命令，不自行把任务标为 `ACCEPTED`。

## 12. 协调者下发记录（2026-07-24）

- 前置任务 14、15 均已由协调者独立复验并归档为 `ACCEPTED`。
- 当前回归基线为 15/15 个无头入口、`191 tests / 1238 assertions`；任务 15 专项为 `26 tests / 163 assertions`。
- 任务 15 的正式场景路径、逻辑范围、Beam 时序与 VFX 只读基准以 `combat/delivery/FIRST_BATCH_DELIVERIES.md` 为准，不得在本任务中反向修改。
- 本任务已正式下发给 Agent D 2.0。先完成不依赖最终美术的 Catalog、六技能资源、Growth/Host/Player 接线和测试；任务 17 的最终资产未获批准前，不得把临时路径写入正式内容字段。
- 完成后将本任务状态改为 `REVIEW` 并向协调线程回传；不得自行验收或归档。

## 13. Agent D 2.0 交付记录（2026-07-24）

### 13.1 目录、资源与正式接线

- 新增不可变静态内容类型 `combat/content/skill_content_definition.gd`，集中维护 ID、中文名称和描述、可选表现引用、获取方式、默认槽位、唯一 Gameplay 引用及 Growth 奖励投影信息；未保存任何运行态。
- 新增 `combat/content/run_content_catalog.gd` 与唯一正式资源 `resources/content/run_content_catalog.tres`。目录一次性验证 ID、Gameplay、奖励、固定普通攻击、默认槽位、执行类型、被动固定元素语义、Delivery 协议和遗物注册。
- 新增六个正式 Gameplay 资源和对应内容资源；`element_bolt` 已校正为消耗 10、100% 攻击力、附着 1 层。固定普通攻击 `element_slash` 注册在目录，但不进入拥有库、奖励池或 `RuntimeSkillLoadout`。
- `scripts/test_room.gd` 只预载一个 `RunContentCatalog`。`scripts/run_session_host.gd` 从该目录投影 RuntimeSkillLoadout、初始拥有、奖励池、遗物和默认配装，并保留旧 Loadout 一次性迁移；迁移结果会移除误入共享槽的固定普通攻击。
- `scripts/player.gd` 从目录取得固定普通攻击，按任务 14 的移动策略驱动主动技能，接通 Fury/Rage、Laser/Beam、回收端口和类型化普攻命中事件。`scripts/passive_effect_adapter.gd` 接通正式敌人查询、伤害提交、生命恢复与被动生命周期。
- `resources/shared_skill_loadout.tres` 仅保留共享 3+1 空槽结构；正式默认装备由目录唯一投影为 `element_bolt → ACTIVE_1`。
- 旧 `water_lance`、`fire_lance` 和四个属性被动未进入正式目录，仅由旧回归或迁移 fixture 显式使用。内容说明见 `combat/content/README.md`。

### 13.2 ID 对照表

| 内容定义 / ID | Gameplay | 奖励 → 拥有 → 配装 | Runtime |
| --- | --- | --- | --- |
| `element_slash_content.tres` / `element_slash` | `resources/element_slash.tres` | 固定普通攻击；不进入奖励、拥有或共享四槽 | Player 目录注册；成功命中发布类型化事件 |
| `element_bolt_content.tres` / `element_bolt` | `resources/element_bolt.tres` | 初始拥有；默认 `ACTIVE_1` | `InstantDeliveryExecution` |
| `elemental_fury_content.tres` / `elemental_fury` | `resources/skills/elemental_fury.tres` | 正式奖励投影 → 拥有库 → 商店配装 | `AllEnergyBurstExecution` + Rage Delivery |
| `elemental_laser_content.tres` / `elemental_laser` | `resources/skills/elemental_laser.tres` | 正式奖励投影 → 拥有库 → 商店配装 | `ChannelExecution` + Beam Delivery |
| `element_reclaim_content.tres` / `element_reclaim` | `resources/skills/element_reclaim.tres` | 正式奖励投影 → 拥有库 → 商店配装 | `ElementReclaimExecution` + 范围回收端口 |
| `burning_content.tres` / `burning` | `resources/skills/burning.tres` | 正式奖励投影 → 拥有库 → 商店配装 | 固定火语义被动 Runtime |
| `unending_content.tres` / `unending` | `resources/skills/unending.tres` | 正式奖励投影 → 拥有库 → 商店配装 | 固定水语义被动 Runtime |

### 13.3 验证结果

- 任务 16 专项 `combat/tests/run_skill_content_catalog_tests.gd`：`11 tests / 209 assertions`。
- 当前全部 16 个无头入口：`202 tests / 1449 assertions`，全部通过。原 15 个入口现为 `191 tests / 1240 assertions`；较下发基线增加的 2 个断言用于任务 10 旧 fixture 与正式 Catalog 隔离回归。
- 任务 15 专项保持 `26 tests / 163 assertions`；任务 14 执行专项 `16 / 102`、被动专项 `5 / 55` 均通过。
- Godot 4.7.1 `--headless --editor --quit`：退出码 0，无脚本错误或新增警告。
- Godot 4.7.1 主场景 `--headless --quit-after 180`：退出码 0。另经已连接编辑器启动主场景，game log 仅有 helper 注册信息，editor cursor 6 后无新增错误，随后正常停止。

### 13.4 剩余表现项

- 任务 17 最终资产仍未获批准；七份正式内容的 `icon` 和 `presentation_scene` 均有意保持为空，未写入临时目录或无来源占位。
- Fury 与 Laser 的 `runtime_delivery_scene` 仅引用任务 15 已验收的逻辑 Delivery，不代表最终美术。锁定元素着色、最终图标和正式 presentation 资源待任务 17 批准清单后接入。
- 本任务未修改任务 14 的费用、事务、冷却或 Channel 内部，未修改任务 15 的 Delivery、范围或原子消费规则，也未修改战斗公式或 HUD。
- 未执行任何 Git 命令；本任务仅提交 `REVIEW`，未自行标记 `ACCEPTED`。

## 14. Review 最终验收（2026-07-24）

- 静态复核通过：`RunContentCatalog` 是 TestRoom/Host 的唯一正式静态注册源；七项内容由六个可获取技能和固定普通攻击组成，Growth 奖励由 `SkillContentDefinition` 确定性投影。
- 资源与边界通过：六技能数值、元素策略、默认拥有/配装及五项奖励池配置符合任务书；旧原型未进入正式目录；任务 17 未批准的七份 icon/presentation 字段保持为空。
- 正式接线通过：固定普通攻击独立于共享四槽；Fury、Laser、回收和两项被动均经任务 14/15 已验收的类型化契约接入；未发现对费用/Channel、Delivery 范围、战斗公式或 HUD 的越界实现。
- 协调者独立复跑任务 16 专项通过：`11 tests / 209 assertions`。
- 协调者独立复跑 16/16 个无头入口全部通过，合计 `202 tests / 1449 assertions`；任务 15 专项保持 `26 / 163`。
- Godot 4.7.1 headless 编辑器扫描和 180 帧主场景 smoke 均退出码 0，扫描与运行日志均无错误或警告。
- 任务 17 的最终表现资产仍是明确的后续依赖；本次验收只接受空表现字段，不把未批准资产视为任务 16 缺陷。

结论：任务 16 验收通过，状态改为 `ACCEPTED`，由协调者归档。
