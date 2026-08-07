# Task34 第四次接替最终 Review 交付

日期：2026-08-07（Asia/Shanghai）

状态：`REVIEW`，等待中枢使用另一份全新冷副本独立验收；本接替未自行标记 `ACCEPTED`。即使后续验收通过，Task35～37 仍按用户决定冻结。

## 修复结论

本轮只优化普通 projectile 的生产默认热路径：

- `PhysicsProjectileSweepQuery2D` 在 consumer 配置时缓存角色存在性、margin、wall tie 和候选上限；逐 step 不再反复跨对象读取稳定 profile 值。
- 每次 query 只重置决定当前公开返回值的 status，不再逐 step 清理不会泄漏到 immutable public Result 的私有引用 scratch；release 时仍完整清理。
- `ProjectileDelivery` 在 ready 时缓存 space state、方向、速度和最大距离，advance 不再逐 step 遍历 world/profile/direction getter；cleanup 清空全部缓存。
- 专项测试增加跨两个真实 physics frame 后第三次 advance 命中的覆盖，证明缓存的 space state 在普通生产生命周期内有效。

未减少任何 initial/cast/rest/probe、候选、排序、step、敌人或输出校验；未修改 gameplay。公共 `ProjectileSweepResult2D` 继续保持 getter-only、逐公共调用新建、按 status 清洗字段，SHA-256 仍为 `B4C680EE83C240DE4D01D7BA4642417EA44D7BBC906B3A71F716C24691BDF943`。

## 最终门禁

- runner SHA-256：`83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`，本轮未修改。
- seed `4107`；projectile 与 Fury 各自 `5 warmup + 30 measured`，两侧交错，共 140 个性能进程；全部 exit 0、valid。
- projectile trace 前后唯一且相同；真实计数/legacy 对照除 build 外完全相同；build `24200 -> 800`，下降 `96.694%`。
- projectile median `143674us -> 110659us`，改善 `22.979%`；p95 `202065us -> 191064us`，改善 `5.444%`，全部通过。
- Task34 专项 `11/211`；delivery reuse `10/105`；7 个直接 runner 全部通过。
- 正式 29-runner 基线 `29/29 = 300 tests / 4095 assertions`；Task20 历史非门禁单列 `7/68`。
- RunGame/TestRoom 各 180 帧、最终 rescan、六张真实 Viewport 均通过。
- 185 份正式日志中 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。

## 上下文与冻结

派发时为 `GREEN`；全部正式输入、实现、冷副本测量和原始日志已固化后发生一次 context compaction，最终为 `YELLOW`。没有第二次压缩，未触发强制 `BLOCKED`。回传后本交付冻结。
