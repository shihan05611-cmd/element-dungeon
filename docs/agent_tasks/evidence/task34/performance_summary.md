# perf_projectile_cast_v1 最终结果

状态：普通 projectile 的确定性、容量与耗时门禁全部通过。以下数据来自零 mask 兼容修补后的全新 final-before/final-after，未复用前一执行对话的 after 数据。

## 固定环境

- Godot：`4.7.1.stable.official.a13da4feb`
- seed：`4107`
- runner SHA-256（共享/before/after 完全相同）：`C134999607A3579F8420C0C8391AC34825ED7E4BD00C42FF45F86EB746489905`
- projectile fixture：200 个普通 ProjectileDelivery × 60 固定 step = 12000 step/sample
- 顺序：双方各 5 warmup + 30 measured；warmup 为 before→after，measured 奇数 before→after、偶数 after→before
- 70 个 projectile 进程均 exit 0、JSON `valid=true`；双方 measured 均为 30 个有效样本
- 同一 Godot 可执行文件、机器、平衡电源计划和进程参数；双方分别使用独立 cold copy/profile

## 普通 projectile 结果

- 全部 70 样本行为 trace 唯一且相同：`67ec8c0d02b36bc5d3de4a7d5383b3d71b42d788ae5313f444487d4252b1b798`
- count vector 唯一且相同：query calls `12000`、intersect shape `24200`、cast motion `24000`、rest/probe/candidate scan 各 `200`、sort comparisons `0`、terminal hits `200`
- parameter builds：`24200 -> 800`，下降 `96.694%`（门槛至少下降 95%）
- median：`129815us -> 110131.5us`，改善 `15.163%`（门槛至少改善 10%）
- p95 nearest-rank：`137523us -> 117751us`，改善 `14.377%`（未回退）

before measured elapsed_usec：

`132983,133484,131963,129517,126531,129325,128104,131637,130110,126895,142962,129913,128937,128082,128523,126506,130304,127755,130893,129780,130454,128015,130760,128896,128768,127677,129850,137523,133134,132684`

after measured elapsed_usec：

`110246,109557,111433,111032,109281,108501,109077,109423,111485,107298,110108,108717,108831,108372,110694,107833,111404,114198,113831,124642,109128,111098,109812,107572,113060,117751,108691,113640,113564,110155`

原始 70 行样本表：`final_artifacts/perf_projectile_cast_v1/projectile/projectile_samples.csv`；逐进程日志在相邻 `before/`、`after/` 目录。

## Fury 补充 fixture

同一双兼容 runner 另以相同交错方式执行 Fury 双侧各 `5+30`。派发 HEAD 没有 Task34 Fury sweep 事务，runner 在 before 明确输出 `supported=false`，因此不伪造 before/after Fury 语义或耗时对比；after 的 30 measured 全部有效且行为稳定。

- after median：`553474us`
- after p95 nearest-rank：`612939us`
- after 行为 trace 唯一：`79ba36dedffc52034d931ed433d51c99d7037c20211df3466029da7027ebb649`
- before unsupported trace 唯一：`033b6c4489b89646d402f140ac0748ea50fdaecd7aafc836013e0e6870459b9c`
- 每个 after 样本：enemy `2000`、blocker `1000`、miss `1000`、invalid `0`、failed `0`、transaction `2000`、rejected Delivery `0`、query calls `4000`、parameter builds `4`、instantiate/add `2000`、tie stable `true`

after measured elapsed_usec：

`544514,555804,552504,548242,553427,578015,559691,559478,555314,553521,612939,551618,552755,550514,550882,546402,550262,566457,594554,551660,547755,567985,557117,554979,547485,555772,550442,650814,546236,568137`

原始 70 行样本表：`final_artifacts/perf_projectile_cast_v1/fury/fury_samples.csv`；逐进程日志在相邻 `before/`、`after/` 目录。
