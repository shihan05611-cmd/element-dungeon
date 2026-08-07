# Task34 最终验证矩阵

所有命令均在 `C:\tmp\element-dungeon-task34-final-after-20260807-01` 和独立 profile 中执行。

## 首项与专项

| 项目 | 结果 |
|---|---:|
| 零 mask 首项 `run_delivery_reuse_tests.gd` | 10 / 105 |
| Task34 专项 | 10 / 159 |
| direct delivery | 16 / 56 |
| direct first batch | 26 / 163 |
| direct skill execution | 16 / 102 |
| direct delivery/skill integration | 1 / 4 |
| direct content catalog | 11 / 231 |
| direct VFX runtime | 9 / 124 |
| direct Task27 skill level | 7 / 86 |

所有行 exit 0。专项 10 项为：fake enemy locked impact；wall/miss/invalid/query failure 原子拒绝；prepare/parent 失败；nested busy；services narrow update；公共 try_cast；共享正式 profile；真实 physics wall tie/stable order；普通 projectile 信号/cleanup；真实 Fury 一次命中且无 flight node。

## 完整 29-runner 基线

| # | Runner | Tests | Assertions |
|---:|---|---:|---:|
| 1 | agent_d_growth_integration | 10 | 145 |
| 2 | agent_d_integration | 9 | 73 |
| 3 | combat | 27 | 124 |
| 4 | delivery_reuse | 10 | 105 |
| 5 | delivery_skill_integration | 1 | 4 |
| 6 | delivery | 16 | 56 |
| 7 | first_batch_delivery | 26 | 163 |
| 8 | growth_06_contract | 10 | 84 |
| 9 | growth_contract_edge | 4 | 10 |
| 10 | growth_session_isolation | 1 | 5 |
| 11 | growth | 25 | 155 |
| 12 | hud_loadout_feedback | 13 | 113 |
| 13 | passive_runtime_contract | 5 | 55 |
| 14 | reward_authority | 3 | 15 |
| 15 | skill_content_catalog | 11 | 231 |
| 16 | skill_execution_contract | 16 | 102 |
| 17 | skill | 28 | 144 |
| 18 | skill_vfx_runtime | 9 | 124 |
| 19 | task24_compact_hud_reward | 10 | 237 |
| 20 | task25_immediate_shop_equip | 8 | 242 |
| 21 | task27_run_economy_progression | 11 | 307 |
| 22 | task27_skill_level_effect | 7 | 86 |
| 23 | task28_seven_slot_passive | 6 | 154 |
| 24 | task29_real_room_flow | 1 | 93 |
| 25 | task29_run_flow_contract | 6 | 166 |
| 26 | task30_run_ui | 9 | 172 |
| 27 | task32_formal_four_passive_content | 5 | 173 |
| 28 | task31_content_balance | 9 | 310 |
| 29 | task31_full_run_e2e | 4 | 447 |
| **总计** | **29/29 runners** | **300** | **4095** |

逐 runner 原始日志：`final_artifacts/baseline29/`。

## 非门禁与运行态

- Task20 历史单列：`7 tests / 68 assertions`，exit 0；不追认 Task20 状态。
- RunGame smoke：180 frames，exit 0。
- TestRoom smoke：180 frames，exit 0。
- 初始 after scan、初始 before scan、最终 after rescan：全部 exit 0。
- Viewport final capture：6/6 `save_error=0`，结构化 JSON 结果符合 enemy success、wall rejection、empty rejection。

## 日志扫描

递归扫描 `final_artifacts/**` 的 186 个 `.log`：

| 类别 | 计数 |
|---|---:|
| `SCRIPT ERROR` | 0 |
| `Parse Error` | 0 |
| `ERROR:` | 0 |
| `WARNING:` | 0 |
| `CrashHandlerException` | 0 |

## 性能

| 指标 | Before | After | 结果 |
|---|---:|---:|---:|
| parameter builds | 24200 | 800 | -96.694% |
| median elapsed_usec | 129815 | 110131.5 | +15.163% |
| p95 elapsed_usec | 137523 | 117751 | +14.377% |

行为 trace 与 count vector 在全部 70 个普通 projectile 样本中唯一且前后相同。
