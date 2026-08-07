# Task34 第四次接替性能证据

## 固定环境与次序

- before：`C:\tmp\element-dungeon-task34-fourth-final-before-20260807-01`
- after：`C:\tmp\element-dungeon-task34-fourth-final-after-20260807-01`
- 独立 profile：`C:\tmp\element-dungeon-task34-fourth-final-before-profile-20260807-01`、`C:\tmp\element-dungeon-task34-fourth-final-after-profile-20260807-01`
- 固定 HEAD：`102720086c53a84901b788726ad609d15263d64a`
- Godot：`4.7.1.stable.official.a13da4feb`
- runner SHA-256：`83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`
- seed：`4107`
- projectile 与 Fury 分别执行 5 轮 warmup 和 30 轮 measured；warmup 为 before→after，measured 奇数 before→after、偶数 after→before。每套 70 个独立进程，全部 exit 0、valid。

## 普通 projectile 主门禁

fixture 为 200 个普通 ProjectileDelivery × 60 step，共 12000 step。production elapsed 内使用默认热路径；after 的诊断 replay 位于 elapsed 外，使用相同对象、相同 Physics fixture，runner 只读取 adapter instrumentation。

| 指标 | before | after | 结论 |
| --- | ---: | ---: | --- |
| trace SHA-256 | `67ec8c0...1b798` | `67ec8c0...1b798` | 30/30 唯一且前后相同 |
| query | 12000 | 12000 | 等价 |
| intersect | 24200 | 24200 | 等价 |
| cast | 24000 | 24000 | 等价 |
| rest | 200 | 200 | 等价 |
| probe | 200 | 200 | 等价 |
| candidate | 200 | 200 | 等价 |
| sort | 0 | 0 | 等价 |
| parameter build | 24200 | 800 | 下降 96.694% |
| median | 143674us | 110659us | 改善 22.979% |
| p95（nearest-rank） | 202065us | 191064us | 改善 5.444% |

before 的计数来源明确标记为 `legacy_code_formula`；after 来源为 `adapter_instrumentation_replay`。全部 30 轮 measured 的 trace 与计数向量各自唯一稳定。

## Fury 独立容量与事务

before HEAD 不支持 Task34 Fury API，样本按双兼容 runner 合法返回 `supported=false`，未用语义差异做性能对比。after 30 轮 measured：

- median `593192us`，p95 `709707us`；trace 唯一为 `79ba36dedffc52034d931ed433d51c99d7037c20211df3466029da7027ebb649`。
- 每轮计数：query/intersect/cast/rest/probe/candidate/sort/build/scratch = `4000/12000/8000/4000/4000/5000/1000/4/4`。
- enemy/blocker/miss/invalid/failed = `2000/1000/1000/0/0`；成功事务 `2000`；拒绝后 Delivery `0`；tie stable `true`；instantiate/add = `2000/2000`。

原始 CSV 和 140 份逐进程日志位于 `fourth_replacement_final_artifacts/perf_projectile_cast_v1/`。
