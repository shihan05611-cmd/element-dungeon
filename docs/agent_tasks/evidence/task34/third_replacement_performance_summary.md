# Task34 第三次接替性能结果

## 固定方法

- before：HEAD `102720086c53a84901b788726ad609d15263d64a`
- runner SHA：`83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`
- seed：`4107`
- 顺序：5 次 warmup 均 before→after；30 次 measured 奇数 before→after、偶数 after→before。
- 普通 fixture：200 ProjectileDelivery × 60 step = 12000 step/sample。
- after 的计数来自计时结束后的同对象/同 fixture instrumentation replay；runner 只读取 `sweep_metrics_snapshot()` 并验证精确向量，不覆盖任何 after metric。`elapsed_usec` 只覆盖默认生产热路径。before 无 instrumentation，明确标注 `legacy_code_formula`。

## projectile_step_reuse

| 指标 | Before | After | 变化 |
|---|---:|---:|---:|
| query | 12000 | 12000 | 相同 |
| intersect | 24200 | 24200 | 相同 |
| cast | 24000 | 24000 | 相同 |
| rest / probe / candidate | 200 / 200 / 200 | 200 / 200 / 200 | 相同 |
| sort | 0 | 0 | 相同 |
| parameter build | 24200 | 800 | -96.694% |
| median elapsed_usec | 135703.5 | 121600 | +10.393% |
| p95 nearest-rank | 144445 | 131987 | +8.625% |

30 个 measured 的 before/after trace 唯一且相同：`67ec8c0d02b36bc5d3de4a7d5383b3d71b42d788ae5313f444487d4252b1b798`。双方 count vector 各自唯一；全部 70 个进程 exit 0、`valid=true`。

## fury_atomic_batch

before 明确 `supported=false`，不伪造旧语义比较。after 30 个 measured：

- median `603391us`，p95 `739314us`；
- trace 唯一：`79ba36dedffc52034d931ed433d51c99d7037c20211df3466029da7027ebb649`；
- query/intersect/cast/rest/probe/candidate/sort/build/scratch：`4000/12000/8000/4000/4000/5000/1000/4/4`；
- enemy/blocker/miss/invalid/failed：`2000/1000/1000/0/0`；
- transaction/rejected delivery/instantiate/add/free：`2000/0/2000/2000/2000`；
- tie stable 30/30。

原始 CSV、逐进程日志和 JSON summary：`third_replacement_final_artifacts/perf_projectile_cast_v1/`。
