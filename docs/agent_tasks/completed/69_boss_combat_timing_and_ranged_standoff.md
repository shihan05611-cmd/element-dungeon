# 任务 69：Boss 战攻击时序对齐与远程停火距离

状态：ACCEPTED（2026-08-20 独立验收 PASS）
负责人：执行 Agent（Claude Opus 5）
依赖：**任务 68（Boss 多帧动画补齐）必须先 `ACCEPTED`**。本任务消费其 `v2` sheet 与 manifest 声明的命中帧索引。
Git 基线：`main` HEAD `3184f4f`
Review Level：L2
升级触发：任务 68 的命中帧索引与实际 sheet 不符、或 §2.2 的时序对齐无法在不修改 `scripts/enemy.gd` 公共签名的前提下达成（`TidalSentry` 依赖该签名且在 allowlist 外）时，冻结为 `BLOCKED` 上报，不得自行改动共享基类接口。

## 0. 阅读方式

四项改动（§2.1~§2.4）都源自用户实机观察到的具体不协调，不是重构。§2.1 与 §2.2 是同一个问题的两半（资产接线 + 时序对齐），必须一起做；§2.3 与 §2.4 相对独立但共享同一段控制流。

预警与伤害的对齐**当前是正确的**（两者都由 `melee_telegraph_duration` 驱动），本任务不得破坏这一点。要修的是动画相对这两者的错位。

---

## 1. 背景事实（已验证）

### 1.1 近战：动画早于预警整整一个前摇窗

`scripts/run/enemies/boss_tide_ember.gd:308` `_start_melee_attack()` 在同一帧内做三件事：

| 时刻 | 事件 | 代码 |
|---|---|---|
| t=0 | 播 attack 动画 → 单帧资产立刻定格为「已挥出」 | `sprite.play(_animation_name(&"attack"))` |
| t=0 → T | 头顶 `!` 预警 | `telegraph_indicator.start(form.melee_telegraph_duration)` |
| t=T → T+0.14 | 伤害判定生效 | `DelayedAreaDelivery.trigger_delay = T` |

T = `melee_telegraph_duration`：熔炽 0.45s、潮涌 0.4s、普通 0.4s。

预警与伤害精确对齐，**只有动画早了整整 T**。观感即用户描述的「先出攻击动画，再预警，再出伤害」。

根因是任务 60 交付的单帧 attack 资产没有前摇帧可播（详见任务 68 §1）。任务 68 补齐多帧后本任务才有修复条件。

### 1.2 远程：贴脸开火，无视距离

`scripts/run/enemies/boss_tide_ember.gd:157` 的近战触发条件要求 `attack_cooldown <= 0.0`，而形态近战冷却是 2.2~2.6s。一旦近战进入冷却，控制流直接落到同文件 `:177` 的 `_advance_ranged_attack_cycle()`，**该函数完全不检查距离**。

结果：玩家贴身时 Boss 仍在脸上倾泻扇形弹。潮涌形态尤其严重——`resources/run/projectiles/boss_tide_bolt_profile.tres` 是 `spread_count = 5`、`spread_angle_degrees = 60`、`aim_mode = AIM_AT_PLAYER`，贴身几乎封死全部闪避角。

距离基准（用于定阈值）：

| 量 | 值 | 出处 |
|---|---:|---|
| 玩家普攻覆盖到身前 | **78px** | `scenes/transient_melee_delivery.tscn`：`query_offset.x = 42` + 命中盒半宽 36 |
| Boss 近战触发距离 | 88px | `boss_form_*.tres` 的 `melee_range` |
| Boss 近战命中盒覆盖到 | 100px | `scenes/run/boss_melee_delivery.tscn`：`query_offset.x = 50` + 半宽 50 |

用户口径为「比玩家普攻范围大一点」。

### 1.3 远程攻击在视觉上不存在

`scripts/enemy.gd` 的 `_advance_ranged_attack_cycle()` / `_begin_ranged_attack_telegraph()` / `_launch_ranged_projectile()` **全程没有一次 `sprite.play()` 调用**。Boss 在 0.4~0.5s 的远程前摇里保持着上一个动画（通常是 walk，因 `velocity.x` 被清零而原地踏步），发射瞬间也没有攻击姿势。整套远程动作只有头顶一个 `!` 表示。

### 1.4 贴身真空期（§2.3 的连带风险）

加入远程停火距离后，会出现新的空档：玩家贴身且 Boss 近战处于 2.2~2.6s 冷却时，Boss 将**完全无输出**。必须在同一任务内一并处理，否则手感会从「太强」直接翻到「站桩白打」。

---

## 2. 改动需求

### 2.1 接线多帧动画

把 `resources/animations/boss_tide_ember_frames.tres` 的 11 个动画从单帧改为消费任务 68 的 `v2` sheet，按项目惯例用 `AtlasTexture` + `region` 切帧（先例：`player_frames.tres` 97 个 AtlasTexture、`enemy_frames.tres` 24 个）。

- 每帧 region 为 200×200，横向等距；
- `loop`：idle / walk 为 `true`，attack / hurt / death 为 `false`（沿用现状）；
- 帧率参考同类角色量级（普通敌人 walk 8 帧 @11fps、attack 6 帧 @11fps；玩家 attack 8 帧 @20fps），attack 的具体节拍由 §2.2 反推决定；
- 接线完成并通过验收后，`v1` 单帧 PNG 不再被引用，**其删除不在本任务范围**，只需在交付报告中列出可退役清单。

### 2.2 近战动画对齐预警与判定

目标时序（以熔炽形态为例，T = `melee_telegraph_duration`）：

```
帧 0 ─────────────── 命中帧 ──────── 末帧
│<──── 前摇段 = T ────>│<── 命中+收招 = 0.36s ──>│
│<──── 预警 ! 窗口 ───>│
                       ↑ 伤害判定在此生效
```

即：**attack 动画的前摇帧段时长必须等于 `melee_telegraph_duration`，命中帧落在判定生效的同一时刻**。命中帧索引取自任务 68 manifest 的声明（§2.4 接口契约）。

`MELEE_ACTIVE_DURATION = 0.14` 与 `MELEE_RECOVERY_DURATION = 0.22`（`boss_tide_ember.gd:22-23`）保持不变，`attack_time` 的总长计算方式不变。

三形态的 `melee_telegraph_duration` 目前是 0.45 / 0.4 / 0.4，而三者共用同一份 attack 动画节拍。**推荐方案：把三形态的 `melee_telegraph_duration` 统一为动画前摇段的实际时长**，形态差异改由已有的 `melee_damage` / `melee_range` / `attack_cooldown` 承担——这三个字段本来就已经按形态分化。若执行者认为必须保留前摇差异，可改用 `sprite.speed_scale` 在播放时按 `T / 动画前摇段时长` 缩放，但须在交付报告中说明选择理由，并证明缩放后帧节拍在三形态下都不出现跳帧或拖尾。

命中帧索引须**配置化**，建议加到 `BossTuning`（三形态共用同一节拍，属全局节拍参数），并纳入 `validation_error()` 校验；不得在 `.gd` 里硬编码魔数。

### 2.3 远程停火距离

**新增配置**：`BossFormDefinition` 增加导出字段

```gdscript
@export_range(0.0, 1000000.0, 0.001, "or_greater") var ranged_minimum_distance: float = 130.0
```

默认 130px：大于玩家普攻覆盖的 78px（用户口径「比玩家普攻范围大一点」），也大于 Boss 近战命中盒的 100px，形成清晰的「贴身 = 近战区」分层。三个 `boss_form_*.tres` 均须显式写入该字段。`validation_error()` 增加对应校验（有限、非负）。

**控制流**：在 `boss_tide_ember.gd` 侧 gate，**不修改 `scripts/enemy.gd` 的 `_advance_ranged_attack_cycle()` 签名**（`scripts/run/enemies/tidal_sentry.gd` 依赖它且在 allowlist 外）。

两条硬性行为要求：

1. **只 gate「开始新的 telegraph」，不中断已激活的 telegraph。** 玩家在预警途中冲进贴身范围时，该次远程照常打完。否则贴身进出会让预警反复闪烁，且「冲进去」会退化成无成本的取消技。实现上意味着 `_telegraph_active` 为 true 时仍须调用推进逻辑，只有非激活状态才跳过。
2. **停火期间远程冷却继续递减。** 玩家拉开距离后 Boss 可立即开火，形成「贴身安全 / 拉开有风险」的张力。若执行者认为该惩罚过重，可将其配置化，但默认值须为「继续递减」，并在报告中给出实测判断。

### 2.4 消除贴身真空期

`BossFormDefinition` 增加：

```gdscript
@export_range(0.001, 1.0, 0.001) var melee_cooldown_close_range_scale: float = 0.6
```

含义：当玩家水平距离 < `ranged_minimum_distance` 时，`attack_cooldown` 的递减按该系数加速（值越小恢复越快）。熔炽形态 2.4s 冷却在贴身时约为 1.44s，把 §1.4 的空档压到可接受范围，且不引入新状态机或新动作。

不得改为「贴身直接重置冷却」——那会让贴身变成 Boss 的连续近战输出，比现状更糟。

### 2.5 远程攻击补动画

- **前摇期**（`_begin_ranged_attack_telegraph` 到发射）：播放可识别的蓄力表现，不得停留在 walk 的原地踏步。复用 attack 动画的前摇帧段是可接受方案（本任务不申请新美术资产）。
- **发射瞬间**：切到攻击姿势（attack 动画的命中帧），与弹体生成同帧。
- 因 §2.3 的 gate 而未开始的远程周期，不得播放任何攻击动画。

实现须落在 `boss_tide_ember.gd` 内（可通过覆写或在其 `_physics_process` 中围绕基类调用处理），保持 `TidalSentry` 行为完全不变。

---

## 3. 精确输出 allowlist

```
combat/definitions/boss_form_definition.gd
combat/definitions/boss_tuning.gd
resources/run/enemies/boss_forms/boss_form_ember.tres
resources/run/enemies/boss_forms/boss_form_tide.tres
resources/run/enemies/boss_forms/boss_form_plain.tres
resources/run/enemies/boss_forms/boss_tuning.tres
resources/animations/boss_tide_ember_frames.tres
scripts/run/enemies/boss_tide_ember.gd
combat/tests/run_task61_boss_three_form_tests.gd（按新行为更新）
combat/tests/run_task69_boss_timing_and_standoff_tests.gd（新建）
project.godot（仅为注册新测试入口）
docs/agent_tasks/pending/69_boss_combat_timing_and_ranged_standoff.md
docs/agent_tasks/evidence/task69/**
```

`scripts/enemy.gd`、`scripts/run/enemies/tidal_sentry.gd`、`scenes/run/enemies/boss_tide_ember.tscn`、`scenes/run/boss_melee_delivery.tscn`、全部弹体 profile `.tres` 为**只读参考**。确有必要修改时先冻结上报（§升级触发）。

---

## 4. 禁止事项

- 不修改 `scripts/enemy.gd` 的公共签名或既有行为；`TidalSentry` 必须逐字保持现有表现。
- 不破坏预警与伤害判定的现有对齐关系（两者同由 `melee_telegraph_duration` 驱动）。
- 不改动形态切换状态机、克制计数、韧性（poise）、层数回补、同元素减伤等任务 61 已验收的机制。
- 不调整弹体的 `damage` / `spread_count` / `speed` 等数值平衡——潮涌 5 发扇形的平衡性问题另立任务，本任务只解决距离门控。
- 不在 `.gd` 中硬编码命中帧索引、停火距离或冷却系数；全部配置化到 Resource。
- 不删除 `v1` 单帧 PNG（只在报告中列出可退役清单）。
- 不读取、运行或修改 `tmp/**` 与用户独立 `global_instakill` 相关文件。
- 不执行任何 Git 写操作；不自行标记 `ACCEPTED`。

---

## 5. 验收条件

### 5.1 程序化断言（新建 `run_task69_*` 测试入口）

1. `BossFormDefinition` / `BossTuning` 新字段的 `validation_error()` 正负例覆盖；
2. 三个形态 `.tres` 均显式声明 `ranged_minimum_distance` 与 `melee_cooldown_close_range_scale`，且加载后通过校验；
3. 玩家水平距离 < `ranged_minimum_distance` 且远程 telegraph 未激活时，推进若干物理帧后**弹体生成数为 0**；
4. 同一距离下若 telegraph 已激活，该次远程**仍完整发射**（§2.3 要求 1）；
5. 玩家退到 > `ranged_minimum_distance` 后远程恢复开火，且因冷却持续递减而在预期帧内即开火（§2.3 要求 2）；
6. 贴身时 `attack_cooldown` 的递减速率符合 `melee_cooldown_close_range_scale`；
7. `boss_tide_ember_frames.tres` 的 11 个动画帧数与任务 68 manifest 一致（断言帧数 > 1，防止再次回退到单帧）；
8. attack 动画前摇段时长与 `melee_telegraph_duration` 相等（允许一个物理帧的误差），命中帧时刻与 `DelayedAreaDelivery` 判定生效时刻一致。

### 5.2 回归

`combat/tests/run_task61_boss_three_form_tests.gd` 与 `combat/tests/run_task51_boss_projectile_spawn_clearance_tests.gd` 全绿；主场景 smoke 退出码 0、运行日志干净。测试入口总数与断言总数按项目基线口径记录在交付报告。

### 5.3 视觉证据

1. 近战一次完整攻击的**逐帧截图序列**，标出前摇起点、预警窗、命中帧、判定生效帧，证明三者对齐；
2. 远程一次完整攻击的逐帧序列，证明前摇有蓄力表现、发射帧有攻击姿势；
3. 走路循环的连续帧截图，证明不再是平移；
4. 贴身站位下的连续录制/截图，证明 Boss 不再发射远程，且在 `melee_cooldown_close_range_scale` 生效后恢复近战输出（不存在长时间零输出）；
5. 分辨率按 L2 口径：`1920×1080` + `2560×1440`。

L2 Review 独立复算测试计数、复核帧对齐证据链，并实机确认贴身场景无「站桩白打」空窗。

---

## 6. 交付记录（执行侧，`REVIEW` 冻结）

### 6.1 修改文件

**修改（tracked）**

| 文件 | 内容 |
|---|---|
| `resources/animations/boss_tide_ember_frames.tres` | 11 个动画全部改为消费 `v2` sheet，74 个 `AtlasTexture`，每帧 `region = Rect2(i*200, 0, 200, 200)` |
| `scripts/run/enemies/boss_tide_ember.gd` | 近战动画从帧 0 重启；远程停火 gate；贴身冷却加速；远程蓄力/发射动画 |
| `combat/definitions/boss_form_definition.gd` | 新增 `ranged_minimum_distance`、`melee_cooldown_close_range_scale` + 两条 `validation_error()` 分支 |
| `combat/definitions/boss_tuning.gd` | 新增 `melee_attack_impact_frame_index` + `validation_error()` 分支 |
| `resources/run/enemies/boss_forms/boss_form_ember.tres` | `melee_telegraph_duration` 0.45 → 0.4；显式写入两个新字段 |
| `resources/run/enemies/boss_forms/boss_form_tide.tres` | 显式写入两个新字段（`melee_telegraph_duration` 本就是 0.4，未动） |
| `resources/run/enemies/boss_forms/boss_form_plain.tres` | 同上 |
| `resources/run/enemies/boss_forms/boss_tuning.tres` | 显式写入 `melee_attack_impact_frame_index = 4` |

**新增（untracked）**

- `combat/tests/run_task69_boss_timing_and_standoff_tests.gd`
- `assets/world/enemies/tide_ember_sovereign/boss_*_v2.png.import` × 11（本任务职责，任务 68 被明令禁止生成）
- `docs/agent_tasks/evidence/task69/**`

`project.godot` **未修改**：本项目没有测试入口注册表，全部 `run_*.gd` 均以 `--headless --path . --script res://combat/tests/<name>.gd` 直接按路径运行，新增 runner 无需注册。

`scripts/enemy.gd`、`scripts/run/enemies/tidal_sentry.gd`、Boss `.tscn`、`boss_melee_delivery.tscn`、全部弹体 profile `.tres` **一字未改**（`git status` 为 clean）。

### 6.2 时序方案与理由（§2.2）

采纳任务书推荐的 **「统一 `melee_telegraph_duration` + SpriteFrames 逐帧 duration 倍数」** 方案，未使用 `speed_scale` 缩放近战：

- `*_attack` 动画：`speed = 10.0`，帧 0~3 `duration = 1.0`（各 0.1s），帧 4~7 `duration = 0.9`（各 0.09s）。
- 前摇段（帧 0→3）= **0.40s**；命中帧 4 起至末帧（4→7）= **0.36s** = `MELEE_ACTIVE_DURATION (0.14) + MELEE_RECOVERY_DURATION (0.22)`。
- 三形态 `melee_telegraph_duration` 统一为 **0.4**（仅熔炽由 0.45 下调；潮涌/普通本就是 0.4）。
- 整条 attack 片段总长 0.76s **恰好等于** `attack_time = max(T,0.05) + 0.14 + 0.22`，动画播完的同一刻 `attack_time` 归零并切回 idle，不出现截断或定格。

选择理由：

1. 逐帧 duration 让前摇 0.4s / 收招 0.36s 两段各自落在整数毫秒上，全部是可读的圆整值，不需要 `speed = 11.111…` 这种为凑 0.09s 而来的丑数；
2. `speed_scale` 方案会同时缩放收招段，破坏「收招 = 0.36s」这一与 `MELEE_ACTIVE/RECOVERY` 的对应关系，并让三形态的 attack 节拍互不相同（跳帧风险）；
3. 形态差异已由 `melee_damage`（13/15/17）、`melee_range`（84/88/88）、`attack_cooldown`（2.2/2.4/2.6）承担，前摇 0.45 vs 0.4 的 0.05s 差异本就不可感知。

命中帧索引配置在 `BossTuning.melee_attack_impact_frame_index = 4`，代码里**没有任何一处魔数**：`attack_windup_duration()` / `attack_recovery_duration()` 直接从 `SpriteFrames` 的逐帧 duration 与 fps 求和推出，索引是唯一输入。

其余三项：

- **§2.3 停火 gate**：`_physics_process` 中 `if _telegraph_active or not in_close_range:` 才调用 `_advance_ranged_attack_cycle()`；被 gate 时手动 `_boss_projectile_cooldown -= delta`（与基类同 delta），冷却继续递减，默认即「继续递减」，未配置化为可关闭。`scripts/enemy.gd` 签名零改动。
- **§2.4 贴身冷却**：`attack_cooldown -= delta / melee_cooldown_close_range_scale`，即等效冷却 = 原冷却 × 系数（熔炽 2.4 × 0.6 = 1.44s）。不是重置。
- **§2.5 远程动画**：覆写 `_begin_ranged_attack_telegraph()`（super 之后播 attack 前摇段，`speed_scale = 动画前摇 0.4s / profile.telegraph_duration`，三形态分别为 0.889 / 0.8 / 1.0，均为轻微减速，无跳帧）与 `_launch_ranged_projectile()`（super 之后 `speed_scale` 复位 1.0、跳到命中帧、`attack_time = attack_recovery_duration()` 让命中姿势有 0.36s 的收招而不是被下一帧的 walk 立刻覆盖）。被 gate 而未开始的周期完全不进这两个覆写，不播任何攻击动画。另覆写 `_cancel_ranged_attack_telegraph()` 仅用于复位 `speed_scale`，行为不变。

### 6.3 测试与回归

**新增** `combat/tests/run_task69_boss_timing_and_standoff_tests.gd`：**8 tests / 272 assertions**，exit 0，逐条覆盖 §5.1 的 1~8。

**回归**（46 个 runner 全量重跑，`run_global_instakill_tests` 按保护要求排除；日志见 `docs/agent_tasks/evidence/task69/logs/`）：

| runner | 结果 |
|---|---|
| `run_task61_boss_three_form_tests` | **17 tests / 87 assertions PASS**，exit 0（与改动前基线数字完全相同，未按新行为修改该文件） |
| `run_task51_boss_projectile_spawn_clearance_tests` | **2 tests / 49 assertions PASS**，exit 0 |
| 其余 42 个绿的 runner | 全部 exit 0 |
| 4 个既有失败 runner | `run_task30_run_ui_tests` 11/9、`run_task40_drag_compact_hud_tests` 9/4、`run_task31_content_balance_tests` 12/9、`run_task32_formal_four_passive_content_tests` 61/5 |

这 4 个失败已做**受控 A/B 复核**：把本任务全部 8 个 tracked 改动文件临时还原为 `HEAD` 版本重跑同 4 个 runner，失败条目 `diff` **逐行完全一致**，随后按 SHA-256 校验还原本任务版本（`sha256sum -c` 全 OK）。均为购物 UI / 房间几何的历史问题，与 Boss 无关。全部 sweep 日志中 `ERROR:` 仅出现在这 4 个 runner 内，Boss 相关 runner 日志干净、无 `WARNING`、无 `invalid UID`。

**Smoke**：`docs/agent_tasks/evidence/task61/smoke_main_and_boss_room_180.gd` 双 180 帧（主场景 `run_game.tscn` + 正式 Boss 房 `combat_06_final_boss.tres`）重跑 —— `main_scene: player_alive=true`、`boss_room: alive=true is_physics_processing=true form=ember deliveries_created=3`、`SMOKE PASS`、**exit 0**，与任务 61 记录的基线数字一致。

### 6.4 视觉证据（§5.3）

采集脚本 `docs/agent_tasks/evidence/task69/capture_task69_boss_timing_and_standoff.gd`（真实 Boss `.tscn` + 真实 `player.tscn` + 地面，非 headless，`--display-driver windows`），输出 `docs/agent_tasks/evidence/task69/screenshots/`，日志 `logs/capture_task69.log`。

每个序列输出**一张带逐格标注的 contact sheet**，每格是跟随 Boss 的裁切窗，格内叠加当帧实测值（动画名 / 帧号 / 段落 / `!` 预警 / `DelayedAreaDelivery` 相位 / 各计时器），因此标注来自实测而非脚本自算。1920×1080 与 2560×1440 各一套，共 8 张：

> **独立验收澄清（口径）**：交付的 8 张文件本身是 2880×1600 / 2880×2000 的**合成 contact sheet**，不是 1920×1080 / 2560×1440 的原生整屏截图。采集确实在两种窗口分辨率下各完整跑了一遍（capture log 为双段落、两套 PNG 哈希互异、每格覆盖的物理帧数不同），§5.3.5 的双分辨率意图已达成；但审阅者无法从图像本身反推源分辨率，故在此点明。不构成缺陷。

| 文件（各 `_1920x1080` / `_2560x1440` 两版） | 证明 |
|---|---|
| `task69_melee_sequence_*` | 28 格覆盖一次完整挥击。格 00~13：`segment=WINDUP`、`! telegraph=ON`、`hitbox=WAITING`、帧 0→3；格 14：帧 **4** = `IMPACT`（`attack_time=0.360` → 已过 0.400s）；格 15：`hitbox=ACTIVE`、`! telegraph=off`、仍是帧 4；其后帧 5→7 收招，`attack_time` 归零同帧回 idle |
| `task69_ranged_sequence_*` | 32 格。格 00~14：`phase=CHARGE`、`anim=ember_attack` 帧 0→4、`speed_scale=0.889`、`bolts_spawned=0`、`telegraph_left` 由 0.450 递减到 0.000；格 15：`telegraph_left=-0.017`、`speed_scale=1.000`、**帧 4 命中姿势**、`bolts_spawned=3`（发射与姿势同格）；其后帧 5→7 收招且可见 3 发弹体飞出 |
| `task69_walk_loop_*` | 32 格走了完整两轮 8 帧循环（帧序 1→7→0→…），同期 Boss 只位移 69px 且裁切窗跟随 Boss，格间的差异只能来自动画本身 |
| `task69_point_blank_standoff_*` | 40 格 / 10.0s 贴身（60px，ring 130px）：`ranged volleys=0`、`bolts=0` 全程为 0；`melee swings` 由 0 递增到 7，`cooldown` 逐格可见按 ~1.44s 周期回落，`longest gap between swings = 1.37s`（< 熔炽等效冷却 1.44s），不存在长时间零输出 |

**无读回控制测量**（截图读回会拉长每物理帧的真实耗时，contact sheet 的格索引因此略粗于物理帧；下列数字取自同一次运行中不做任何 framebuffer 读回的对照挥击/射击）：

- `melee(no-readback): hitbox went ACTIVE after 25 physics frames (0.417s), sprite frame=4, configured impact index=4` —— 判定生效的那一物理帧，精灵**正好停在配置的命中帧 4**；25 帧 = 0.417s = `melee_telegraph_duration 0.400s` + 1 物理帧（`DelayedAreaDelivery` 在 delay 耗尽后的下一帧才切相位，属既有行为）。
- `ranged(no-readback): charge started on anim=ember_attack frame=0; telegraph ran 28 physics frames (0.467s); at launch sprite frame=4` —— 蓄力从 attack 帧 0 起播，发射瞬间精灵在帧 4。
- 两个分辨率下这两组数字完全一致。

### 6.5 v1 单帧资产可退役清单（未删除）

接线完成后以下 11 组 `v1` 文件在全库已**零引用**（`grep -rn "_v1\.png"` 仅命中 `.import` 自身与 `manifest_v1.md`）：

```
assets/world/enemies/tide_ember_sovereign/boss_plain_idle_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_plain_walk_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_plain_attack_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_ember_idle_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_ember_walk_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_ember_attack_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_tide_idle_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_tide_walk_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_tide_attack_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_hurt_v1.png(+.import)
assets/world/enemies/tide_ember_sovereign/boss_death_v1.png(+.import)
```

（`manifest_v1.md` 作为历史事实建议保留。）本任务未删除任何一个。

### 6.6 共享工作区与副作用披露

- 生成 11 个 `v2` `.import` 需要真实导入管线。先用 MCP `filesystem_manage(op="reimport")` 定向尝试（未生成 `.import`），再执行一次 `filesystem_manage(op="scan")`。扫描**前后 `git status` 逐行 diff**：新增仅 11 个 `boss_*_v2.png.import`，外加 Godot 自动补齐的两个 sidecar `combat/tests/test_batch_runner.gd.uid`、`combat/tests/test_harness.gd.uid`；**没有任何 tracked 文件被修改**（未出现任务 59/61 记录过的 `uid=` 注入 / 默认值丢弃现象）。11 个 `.import` 的 `[params]` 与既有 `v1` `.import` **逐行完全一致**。
- `boss_tide_ember_frames.tres` 的 `ext_resource` **不写 `uid=`**，与该文件在 `HEAD` 中的原有写法一致。
  > **独立验收更正**：本条原表述（「首版曾写入 uid…去掉 uid 后…」）描述的是本任务内部的一段试错过程，容易被误读为相对基线移除了 `uid=`。核实 `git show HEAD:resources/animations/boss_tide_ember_frames.tres`：**HEAD 版本本就没有 `uid=`，当前版本也没有，该属性的净改动为零**，不存在任何移除，因此也不存在「在他人机器或 CI 上引发问题」的风险。（过程事实仍属实：中途写入 uid 时，headless 进程因共享 `.godot/uid_cache.bin` 未落盘而报 3 条 `invalid UID` WARNING。）Godot 4 在缺少 `uid=` 时按 `path=` 解析，uid 仅为缓存加速器。附带记录：同目录 `player_frames.tres` / `enemy_frames.tres` 均带 uid，本文件与兄弟文件风格不一致——该不一致早于本任务，不由本任务修正。
- **Git 写操作为零**：全程未执行 `add/commit/push/reset/restore/checkout/clean/stash`。A/B 复核用的是 `git show HEAD:<path>`（只读）+ 文件复制，并已用 SHA-256 校验回滚完整性。
- 未读取、运行或修改 `tmp/**`；未触碰 `global_instakill` 相关文件（回归 sweep 已显式跳过 `run_global_instakill_tests`）。
- 工作树中 `docs/agent_tasks/CENTRAL_REVIEW_RULES.md` 的修改与 `65_*.md` 的移动**在本任务开始前即存在**，非本任务引入。
  > **独立验收补充**：本清单原先遗漏了 untracked 文件 `docs/agent_tasks/PROMPT_allowlist_cost_model.md`。其内容为 allowlist 成本模型的中枢政策文档，与 Boss 无关，mtime（22:37）早于本链路 v2 素材生成时刻（23:01），判定为同样属本任务开始前即存在的预存在改动。披露清单据此补全。

### 6.7 建议 Review 重点复核的存疑点

1. **远程发射后新增了 0.36s 的收招定身**（`_launch_ranged_projectile` 覆写里 `attack_time = attack_recovery_duration()`）。任务书 §2.5 只要求「发射瞬间切到攻击姿势、与弹体生成同帧」，若不加这个 hold，命中姿势会被下一物理帧的 walk 立刻覆盖，实际只存在 1/60s。时长取自动画收招段（非魔数），但它确实是一处超出字面要求的行为改动，请确认是否接受。
2. **熔炽 `melee_telegraph_duration` 由 0.45 降为 0.40**。这是 §2.2 推荐方案的直接后果，但确实轻微削弱了熔炽的近战预警时间（-0.05s），属数值面变化。
3. **远程蓄力使用 `speed_scale` 缩放**（0.889 / 0.8 / 1.0）。任务书对近战明确要求说明缩放理由；远程侧我选择缩放是为了让命中帧精确落在发射帧上（弹体 telegraph 0.4/0.45/0.5 三者不同，而动画前摇固定 0.4s）。最大缩放为 0.8（减速 20%），不会跳帧，但会让潮涌形态的蓄力略慢。
4. **`melee_attack_impact_frame_index` 的校验只检查 `>= 0`**，没有与实际 `SpriteFrames` 帧数交叉校验（`BossTuning` 作为纯数据 Resource 无法访问动画资源）。越界由运行时 `clampi` 兜底，并由 `run_task69` 的第 8 条断言在资源层面把关。
5. **contact sheet 的「格」不等于「物理帧」**：截图读回会拉长每帧真实耗时（1920 下约 2.5 物理帧/格，2560 下约 4~5 物理帧/格）。逐格标注的是实测状态因此仍然自洽，但严格的帧对齐结论请以 §6.4 的「无读回控制测量」与 `run_task69` 第 8 条断言为准。


---

## 7. 验收记录（2026-08-20）

Result：**PASS**。由未参与执行的独立验收 Agent 完成（中途因服务端 529 中断一次，带上下文恢复后续完）。

### 7.1 中断前挂起的疑点：虚惊

验收方一度怀疑 `_on_death_candidate` 的 `sprite.play(&"death")` 经新的 `_play_pose()` 会变成播放不存在的 `"ember_death"`。核实 `_animation_name()`（`scripts/run/enemies/boss_tide_ember.gd:330`）对 `hurt`/`death` 有直通分支且本任务未改动它，`boss_tide_ember_frames.tres` 的 11 个动画名恰为 9 个 `{form}_{pose}` + 裸名 `hurt`/`death`，完全吻合；逐一核对 8 个播放调用点无一错位。`_play_pose()` 每次强制 `speed_scale = 1.0`，远程蓄力的 0.8~0.889 缩放无法泄漏到 death/hurt/idle/walk 任何路径。

### 7.2 独立复算结论

- **时序对齐（精确相等，非近似）**：attack `speed=10.0`，帧 0~3 `duration=1.0` → 前摇 **0.400s**；帧 4~7 `duration=0.9` → 收招 **0.360s** = `MELEE_ACTIVE 0.14 + MELEE_RECOVERY 0.22`。三形态 `melee_telegraph_duration` 均为 0.4。实机：hitbox 于 25 物理帧（0.417s = 0.400s + 1 帧，`DelayedAreaDelivery` 既有行为）转 ACTIVE，此刻 sprite frame=4。
- **预警/判定原有对齐未破坏**：`telegraph_indicator.start()` 与 `delivery.trigger_delay` 两行在 diff 中未被触碰，仍同源。
- **远程停火两条硬性行为均正确**：贴身不开新周期（弹体 0）；已激活 telegraph 完整发射且是「发射后转 false」而非被 cancel；停火期冷却按同 delta 手动递减，拉开后 4 帧内开火。
- **贴身真空期**：实现为 `attack_cooldown -= delta / scale`（非重置）；实测 10s 内远程齐射 0、近战 7 次、最长空档 1.37s < 熔炽等效冷却 1.44s。
- **边界**：`scripts/enemy.gd`、`tidal_sentry.gd`、Boss `.tscn`、`boss_melee_delivery.tscn`、全部弹体 profile 经 `git diff --exit-code` + SHA-256 双验**逐字节未变**；TidalSentry 回归 task58 3 tests/104 assertions PASS。
- **无硬编码**：对代码行 grep `130|0\.6|0\.45` 零命中，三个量全部经 Resource 读取。
- **零 git 写**：HEAD 仍 `3184f4f`，`git stash list` 空，`git reflog` 仅 8 条历史 commit、无 checkout/reset/restore 记录。
- **测试**：run_task69 **8 tests / 272 assertions exit 0**，断言非空转（第 7 条同时校验帧数>1、帧数==manifest、每帧 200×200 AtlasTexture 且 region 偏移正确、loop 标志未变；第 8 条既做资源层复算又驱动真实挥击测实机相位）。回归 task61 17/87、task51 2/49，另加跑 task41/58/59/56/34 与 run_combat_tests 全绿。Smoke exit 0，日志无 ERROR/WARNING/invalid UID。
- **4 个预存在失败（task30/40/31/32）**：验收方未采信执行者的自证式 A/B，改用早于 Task 68/69 的第三方基线 `docs/agent_tasks/evidence/task61/logs/baseline_before_task61/` 逐条比对失败名与断言数，完全一致；并补一条结构性证据——全库仅 `run_task69_*` 引用 `melee_telegraph_duration`/`BossFormDefinition`/`BossTuning`，熔炽 0.45→0.40 在架构上不可能触发其它断言。

### 7.3 对执行者五个存疑点的裁定

| 存疑点 | 裁定 |
|---|---|
| 远程发射后 0.36s recovery hold | **接受，不返工**。不加则命中姿势仅存活 1/60s，等于没做；时长取自动画收招段非魔数；且远程只在距离 ≥130px 时发生（远超 `melee_range` 88），「这 0.36s 不能近战」在几何上基本不可能生效。不建议改为可配置。 |
| 熔炽近战预警 0.45→0.40 | **接受**。−0.05s = 3 物理帧，在 0.4s 量级预警窗上不可感知；替代方案会破坏「收招 == ACTIVE + RECOVERY」恒等式并让三形态节拍互不相同。熔炽**远程** telegraph 仍为 0.45（profile 未动），节奏辨识度未全失。 |
| 蓄力 `speed_scale` 低至 0.8 | **接受**。`<1.0` 是减速，跳帧算术上不可能；实测帧序 `0,0,0,0,1,1,1,2,2,2,2,3,3,3,4` 严格单调无缺失。 |
| impact index 仅校验 `>= 0` | **防护足够**。三层兜底：`@export_range(0,63,1)` 编辑器封顶、运行时 `clampi`、断言 8（越界会让前摇时长偏离 telegraph，测试会响而非静默）。让纯数据 Resource 反向依赖 `SpriteFrames` 是更糟的耦合。 |
| 移除 `ext_resource` 的 `uid=` | **安全，且实际并未发生**。HEAD 版本本就无 uid，净 diff 为零。详见 §6.6 更正。 |

### 7.4 验收方登记的两处未披露轻微行为变化（均可接受）

- 远程 0.36s hold 不只定住动画，也冻结了 Boss 的追击移动（`attack_time > 0` 早返回清零 `velocity.x`）。
- `_start_summon` 从帧 0 重启 attack 且 `speed_scale=1.0`，而 `attack_time=0.5` < 片段 0.76s，召唤动画约在帧 5 处被截断切回 idle。相对旧单帧资产的「定格」属改善，非回归。

### 7.5 提交时须一并纳入

11 个 `boss_*_v2.png.import`，以及 `combat/tests/test_batch_runner.gd.uid`、`combat/tests/test_harness.gd.uid`。后两者虽不在 §3 allowlist，但仓库已有 54 个同类 `.gd.uid` 被 tracked 属既定约定，且系 §6.6 披露的 `filesystem_manage(scan)` 自动补齐产物，验收方判定可接受。新建的 `run_task69_boss_timing_and_standoff_tests.gd` 尚无配套 `.uid`，下次开编辑器时会自动生成。
