# Task34 第四次接替验证矩阵

全部命令从第四次修改后的正式 after 冷副本、独立 profile 从零执行。

| 范围 | 结果 |
| --- | --- |
| delivery reuse 首项 | `10 tests / 105 assertions` |
| Task34 专项 | `11 tests / 211 assertions` |
| delivery | `16/56` |
| first batch delivery | `26/163` |
| skill execution contract | `16/102` |
| delivery/skill integration | `1/4` |
| skill content catalog | `11/231` |
| skill VFX runtime | `9/124` |
| Task27 skill level effect | `7/86` |
| Task31 正式基线 | `29/29 runners = 300 tests / 4095 assertions` |
| Task20 历史非门禁 | `7/68`，单列，不改变其历史 `BLOCKED` |
| RunGame smoke | 180 帧，exit 0 |
| TestRoom smoke | 180 帧，exit 0 |
| final after editor rescan | exit 0 |

Task34 专项继续覆盖 immutable retained Result、enemy/blocker/no-contact/invalid/query-failed 字段清洗、真实 adapter 计数、墙 tie、Fury 五类拒绝、prepare/parent/nested transaction、成功 impact lock、一次命中窗与普通 projectile reuse/cleanup。本轮新增的普通 projectile 生命周期用例跨两个真实 physics frame 后在第三次 advance 命中，且 friendly rejection 保持不变。

Fury 行为合同不变：五类拒绝均不扣 SP、不进冷却、不改 CurrentElement/phase、不发成功事件/VFX、不建真实飞行 Node或爆发 Delivery；成功只在 enemy first，锁定 impact、全 SP 一次提交、1 个爆发 Delivery、0 个隐形飞行 Node。既有 Fury 迁移断言未删减、跳过或放宽。

正式证据共有 185 份 `.log`，合计 310728 bytes；逐份扫描 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:`、`CrashHandlerException`，五类总数均为 0。29-runner 逐项原始结果见 `fourth_replacement_final_artifacts/baseline29/baseline29_summary.csv`。
