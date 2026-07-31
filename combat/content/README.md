# 首批技能内容目录

`resources/content/run_content_catalog.tres` 是正式运行的唯一静态注册源。它统一持有七个
`SkillContentDefinition`（六个可获取技能和固定普通攻击）以及当前正式遗物目录，并从内容定义
确定性投影 Gameplay、初始拥有、默认配装和 Growth 奖励。

## ID 与运行链路

| 内容 ID | 内容定义 | Gameplay | 获取 / 奖励 | 默认配装 | Runtime |
| --- | --- | --- | --- | --- | --- |
| `element_slash` | `element_slash_content.tres` | `resources/element_slash.tres` | 固定普通攻击，不进入拥有库或奖励池 | 共享四槽之外 | Player 的目录注册普通攻击；成功命中发布类型化事件 |
| `element_bolt` | `element_bolt_content.tres` | `resources/element_bolt.tres` | 初始拥有，不进入随机奖励 | `ACTIVE_1` | `InstantDeliveryExecution` |
| `elemental_fury` | `elemental_fury_content.tres` | `resources/skills/elemental_fury.tres` | Growth 奖励投影 → 拥有库 → 商店配装 | 无 | `AllEnergyBurstExecution` + 正式 Rage Delivery |
| `elemental_laser` | `elemental_laser_content.tres` | `resources/skills/elemental_laser.tres` | Growth 奖励投影 → 拥有库 → 商店配装 | 无 | `ChannelExecution` + 正式 Beam Delivery |
| `element_reclaim` | `element_reclaim_content.tres` | `resources/skills/element_reclaim.tres` | Growth 奖励投影 → 拥有库 → 商店配装 | 无 | `ElementReclaimExecution` + 正式范围回收端口 |
| `burning` | `burning_content.tres` | `resources/skills/burning.tres` | Growth 奖励投影 → 拥有库 → 商店配装 | 无 | 固定火语义 `BurningPassiveEffectDefinition` |
| `unending` | `unending_content.tres` | `resources/skills/unending.tres` | Growth 奖励投影 → 拥有库 → 商店配装 | 无 | 固定水语义 `UnendingPassiveEffectDefinition` |

`water_lance`、`fire_lance` 和四个旧属性被动只保留给旧回归或迁移 fixture，未注册到正式目录。
固定普通攻击不进入 `RuntimeSkillLoadout`；旧 Loadout 迁移若带入该 ID，Host 会在归一化时移除，
但 Player 仍可始终从目录取得普通攻击定义。

## 表现字段

任务 17 的最终资产尚未批准，因此正式内容的 `icon` 与 `presentation_scene` 保持为空，没有临时
目录或无来源占位。`elemental_fury` 与 `elemental_laser` 的 `runtime_delivery_scene` 只指向任务 15
已验收的逻辑 Delivery；它们不是任务 17 的最终美术字段。
