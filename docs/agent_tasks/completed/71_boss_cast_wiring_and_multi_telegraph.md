# 任务 71：远程施法动作接线与多型预警系统

状态：ACCEPTED（2026-08-20 独立验收 PASS）
负责人：待指派（工程职责对话）
依赖：**任务 70 必须先 `ACCEPTED`**。本任务消费其 cast sheet（含发射帧索引）与三型预警图标。
Git 基线：`boss/task68-69-multiframe-and-timing` HEAD `1cfb1c8`
Review Level：L2
升级触发：`EnemyTelegraphIndicator` 的改造无法在保持普通敌人与潮汐哨兵**现有表现完全不变**的前提下完成时，冻结为 `BLOCKED` 上报，不得为了 Boss 的新功能改变另外两个消费者的行为。

## 0. 阅读方式

五项改动，共享同一段控制流，但可按 C1 → C2 → C3 → C4 → C5 顺序增量落地。

C1 是用户明确点名的「远程不要借用近战动作」。C2~C5 是「多预警模式」。C2 是一个纯粹的历史欠账（资产早就在磁盘上，从没接过线），做完它 C3 才有意义。

---

## 1. 背景事实（已验证）

### 1.1 远程攻击目前借用近战动作

任务 69 让远程第一次有了动画，但用的是**近战 attack 剪辑的前摇段 + `speed_scale` 拉伸**（熔炽 0.889 / 潮涌 0.800 / 普通 1.000），发射时 snap 到 attack 的命中帧 4。这是当时没有施法资产的权宜之计。任务 70 已交付独立的 cast 动作（8 帧，源自此前完全未使用的 `Blood Monster_A_Attack02`）。

### 1.2 预警图标交付了但从未接线

`assets/world/ui_world/telegraph/telegraph_alert_v1.png`（96×32，3 帧弹跳）与 `telegraph_alert_static_v1.png`（32×32，reduced-motion 降级）由任务 60 交付，其 manifest 末行写着「工程接线由后续任务负责」——**该任务从未派发**。全库 `grep telegraph_alert` 命中 0。

游戏里现在显示的感叹号是 `scenes/combat/enemy_telegraph_indicator.tscn` 中一个 `font_size = 40`、`text = "!"` 的 **Label 节点**。

### 1.3 预警不分类型

近战、远程、召唤共用同一个黄色 `!`，玩家无法判断该后退、侧闪还是抢打断。

### 1.4 召唤完全没有预警

`scripts/run/enemies/boss_tide_ember.gd` 的 `_start_summon()` 是瞬发的：设 `attack_time = 0.5`、播 attack 动画，**同一函数内立刻 `instantiate()` 并 `add_child()`**，没有任何预警窗，也没有打断机会。

### 1.5 共享组件的消费者范围（决定改造边界）

| 组件 | 消费者 |
|---|---|
| `EnemyTelegraphIndicator` | `scenes/enemy.tscn`（普通敌人）、`scenes/run/enemies/tidal_sentry.tscn`、`scenes/run/enemies/boss_tide_ember.tscn`、`scripts/enemy.gd` |
| `DelayedAreaDelivery` | 仅 Boss（`scenes/run/boss_melee_delivery.tscn` + `boss_tide_ember.gd`）与三个测试 |

**`EnemyTelegraphIndicator` 有三个消费者，改造必须向后兼容**：不传类型时的默认行为 = 现有的远程黄色感叹号，普通敌人与潮汐哨兵的表现必须逐帧不变。

`DelayedAreaDelivery` 只有 Boss 在用，但仍优先在 Boss 侧扩展而非改它（见 C4）。

---

## 2. 改动需求

### C1 — 远程使用独立 cast 动作

把 `boss_{plain,ember,tide}_cast_v1.png` 接入 `resources/animations/boss_tide_ember_frames.tres`，新增 3 个动画（`{form}_cast`，`loop = false`），用 `AtlasTexture` + `region` 切帧，规格同任务 69 已建立的做法。

远程攻击周期改为：

- 蓄力期播 `{form}_cast` 的前摇段，**不再复用 attack 剪辑，不再使用 `speed_scale` 拉伸**（任务 69 的 0.889/0.800/1.000 三个缩放值全部移除）；
- 弹体生成对齐 cast 的**发射帧索引**（取自任务 70 manifest，配置化，建议放 `BossTuning`，纳入 `validation_error()`，不得硬编码）；
- 发射后播收招段。任务 69 为远程加的 `attack_time = attack_recovery_duration()` 保留同等效果，但时长改为从 **cast** 剪辑的收招段推导。

各形态的 `telegraph_duration` 不同（熔炽 0.45 / 潮涌 0.5 / 普通 0.4，见对应弹体 profile），而 cast 剪辑只有一份。**优先方案**：像任务 69 处理近战那样，用逐帧 `duration` 倍数把 cast 前摇段编排成一个固定时长，再把三个 profile 的 `telegraph_duration` 统一到它。若判断远程必须保留形态差异，可保留 `speed_scale`，但须说明理由并证明无跳帧。

> 任务 69 的验收登记过一处副作用：远程发射后的 hold 会连带冻结 Boss 的追击移动（`attack_time > 0` 早返回清零 `velocity.x`）。本任务沿用该结构时，请确认这一行为在换成 cast 后仍可接受，并在报告中说明。

### C2 — 接线真实预警贴图（历史欠账）

把 `scenes/combat/enemy_telegraph_indicator.tscn` 里的 `Mark` Label 换成真实贴图节点：

- 非 reduced-motion：播放 `telegraph_alert_v1.png` 的 3 帧弹跳；
- reduced-motion：显示 `telegraph_alert_static_v1.png` 单帧，无动画。

`enemy_telegraph_indicator.gd` 现有的 `set_reduced_motion()` / `_play_show_animation()` / `_stop_animation()` 契约、`start()`/`advance()`/`cancel()` 的调用方式、`telegraph_completed`/`telegraph_cancelled` 信号、以及 `_clamp_to_viewport_margin()` 的行为**全部保持不变**——只换视觉载体。

⚠️ 现有的 tween 弹跳（`scale` 1.08/0.95 循环）与图片自带的 3 帧弹跳序列**不要叠加**，会变成双重抖动。二选一并说明选择。

### C3 — 预警分型

`EnemyTelegraphIndicator` 支持三种预警类型（近战 / 远程 / 召唤），显示任务 70 交付的对应图标。

- 类型通过 `start()` 的可选参数或一个显式的 setter 传入；
- **不传时默认为远程**（现有黄色感叹号），保证 `scripts/enemy.gd` 里普通敌人与潮汐哨兵的调用点**一行不改、表现逐帧不变**；
- Boss 在近战 / 远程 / 召唤三处分别传对应类型。

### C4 — 近战地面范围预警

近战预警窗内，在**实际判定区域**画出范围提示，让玩家能判断往哪躲。

判定区域是确定可知的：`scenes/run/boss_melee_delivery.tscn` 的 `hit_shape`（`RectangleShape2D` 100×70）+ `query_offset`（`Vector2(50, 0)`），朝向由 Boss 的 `facing` 决定。

- 预警框的位置/尺寸**必须从 delivery 的实际参数推导**，不得另写一份硬编码的框——两者一旦不同步，预警就在骗玩家；
- 生命周期与 `trigger_delay` 对齐：预警窗内显示，判定生效时消失；
- 形态切换 / 死亡 / poise 破防导致近战取消时，预警框必须一并清除（复用 `_clear_active_deliveries()` 附近的既有清理路径）；
- 优先在 Boss 侧新增表现节点实现，**不改 `DelayedAreaDelivery`**；确需修改时先冻结上报。
- 尊重 reduced-motion：该设置开启时不做闪烁/缩放动画，用静态描边。

### C5 — 召唤预警窗

给召唤加预警，把「抢打断召唤」变成一个真实决策：

- 新增 `BossFormDefinition.summon_telegraph_duration`（默认 **0.9**，明显长于近战的 0.4，让玩家来得及反应），纳入 `validation_error()`；
- 预警窗内播 cast 或 attack 的前摇段（自选并说明），显示召唤类型预警图标；
- **实际 `instantiate()` + `add_child()` 推迟到预警窗结束**，不再在 `_start_summon()` 内立即执行；
- **打断规则保守处理**：预警期间发生 poise 破防（`poise_stun_time` 被设置）则召唤取消且**不消耗** `summon_cooldown`；普通命中不打断（Boss 的 poise 设计本就如此，任务 61 已验收，不得改动）。不引入任何新的打断机制。
- 召唤被取消时，已显示的预警必须清除。

---

## 3. 精确输出 allowlist

```
combat/definitions/boss_form_definition.gd
combat/definitions/boss_tuning.gd
combat/presentation/enemy_telegraph_indicator.gd
scenes/combat/enemy_telegraph_indicator.tscn
resources/animations/boss_tide_ember_frames.tres
resources/run/enemies/boss_forms/boss_form_ember.tres
resources/run/enemies/boss_forms/boss_form_tide.tres
resources/run/enemies/boss_forms/boss_form_plain.tres
resources/run/enemies/boss_forms/boss_tuning.tres
resources/run/projectiles/boss_ember_bolt_profile.tres
resources/run/projectiles/boss_tide_bolt_profile.tres
resources/run/projectiles/boss_plain_bolt_profile.tres
scripts/run/enemies/boss_tide_ember.gd
scenes/run/enemies/boss_tide_ember.tscn（仅为挂载 C4 的预警表现节点）
combat/tests/run_task71_boss_cast_and_telegraph_tests.gd（新建）
docs/agent_tasks/pending/71_boss_cast_wiring_and_multi_telegraph.md
docs/agent_tasks/evidence/task71/**
```

弹体 profile 仅允许修改 `telegraph_duration`（C1 统一节拍需要）；`damage` / `speed` / `spread_count` / `spread_angle_degrees` 等数值**禁止改动**。

`scripts/enemy.gd`、`scripts/run/enemies/tidal_sentry.gd`、`scenes/enemy.tscn`、`scenes/run/enemies/tidal_sentry.tscn`、`combat/delivery/delayed_area_delivery.gd`、`scenes/run/boss_melee_delivery.tscn` 为**只读参考**。

---

## 4. 禁止事项

- **不改变普通敌人与潮汐哨兵的任何表现**。`EnemyTelegraphIndicator` 的改造必须向后兼容（C3 的默认类型）。
- 不破坏任务 69 已验收的近战时序对齐：attack 前摇段 `0.400s` == `melee_telegraph_duration`，命中帧 4 == 判定生效帧。**这条有测试守着（`run_task69_*` 断言 8），不得让它变红。**
- 不改动任务 61 已验收的机制：形态切换状态机、克制计数、韧性 poise（C5 只是读取破防状态，不改判定规则）、层数回补、同元素减伤。
- 不调整弹体伤害/速度/扇形数值（潮涌 5 发 60° 的平衡性另立任务）。
- 不在 `.gd` 中硬编码发射帧索引、召唤预警时长、预警框尺寸/偏移（C4 必须从 delivery 参数推导）。
- 不删除 `v1` 单帧 Boss 立绘（已零引用，退役另议）。
- 不读取或修改 `tmp/**`；不碰 `global_instakill` 相关文件。
- **不执行任何 git 写操作。** 不自行标记 `ACCEPTED`。

---

## 5. 验收条件

### 5.1 程序化断言（新建 `run_task71_*`）

1. 新增字段（发射帧索引、`summon_telegraph_duration`）的 `validation_error()` 正负例；三个形态 `.tres` 均显式声明并通过校验。
2. `{form}_cast` 三个动画存在、帧数 == 任务 70 manifest、每帧为 200×200 AtlasTexture 且 region 偏移正确、`loop == false`。
3. 远程蓄力播放的是 `{form}_cast` 而**非** `{form}_attack`；`speed_scale` 若已移除则恒为 1.0。
4. 弹体生成的那一物理帧，精灵正停在配置的发射帧索引上。
5. C3 向后兼容：不传类型调用 `start()` 时，指示器状态与改造前一致（远程图标）；分别传三种类型时得到三种不同图标。
6. C4：预警框的世界位置/尺寸与 `boss_melee_delivery.tscn` 的 `hit_shape` + `query_offset` 推导值一致（左右朝向各验一次）；判定生效时预警框已消失；形态切换/死亡时被清除。
7. C5：召唤在预警窗结束前 `_alive_summon_count()` 不增加，窗结束后才增加；预警期间触发 poise 破防则召唤取消、`summon_cooldown` 未被消耗、预警已清除。
8. reduced-motion 开启时，预警使用静态图且无 tween。

### 5.2 回归（全部必须绿）

`run_task69_boss_timing_and_standoff_tests.gd`（**近战时序断言不得变红**）、`run_task61_boss_three_form_tests.gd`、`run_task51_boss_projectile_spawn_clearance_tests.gd`、`run_task58_formal_interactables_crown_sentry_tests.gd`（潮汐哨兵未受影响）、`run_task59_enemy_projectile_profile_tests.gd`。主场景 smoke 退出码 0、日志干净。

预存在失败的判定请对照 `docs/agent_tasks/evidence/task61/logs/baseline_before_task61/`（任务 69 验收确认过的第三方基线），不要用自证式 A/B。

### 5.3 视觉证据（1920×1080 + 2560×1440）

1. 远程一次完整攻击的逐帧序列，标出用的是 `cast` 动画、发射帧、弹体生成帧；
2. 三型预警图标的实机对照（近战/远程/召唤各一张），能一眼区分；
3. 近战预警框与实际判定区域的**叠加对照**——框住的地方就是会被打到的地方；
4. 召唤完整流程：预警窗 → 生成；以及预警期间被 poise 破防打断的那一次；
5. 普通敌人与潮汐哨兵的预警**改造前后对照**，证明表现未变（C3 向后兼容的可视证据）。

L2 Review 重点复核：C3 的向后兼容（三个消费者共用一个组件，最容易在这里出回归）、C4 预警框与真实判定区的一致性（不一致等于骗玩家）、以及任务 69 的近战时序断言是否仍然成立。

---

## 6. 交付记录（执行方填写，状态 REVIEW 冻结）

### 6.1 修改文件

allowlist 内：

- `combat/definitions/boss_tuning.gd`（新增 `ranged_cast_launch_frame_index`，默认 5，纳入 `validation_error()`）
- `combat/definitions/boss_form_definition.gd`（新增 `summon_telegraph_duration`，默认 0.9，纳入 `validation_error()`）
- `combat/presentation/enemy_telegraph_indicator.gd`（C2/C3：Label → AnimatedSprite2D，新增 `TelegraphType` 枚举、`start()` 可选类型参数与 `set_telegraph_type()`）
- `scenes/combat/enemy_telegraph_indicator.tscn`（Mark 由 Label 换成 AnimatedSprite2D + 内嵌 SpriteFrames，6 个剪辑：三型动/静各一）
- `resources/animations/boss_tide_ember_frames.tres`（新增 `plain_cast`/`ember_cast`/`tide_cast`，各 8 帧、`loop = false`、200×200 AtlasTexture）
- `resources/run/enemies/boss_forms/boss_form_{ember,tide,plain}.tres`（`summon_telegraph_duration = 0.9`）
- `resources/run/enemies/boss_forms/boss_tuning.tres`（`ranged_cast_launch_frame_index = 5`）
- `resources/run/projectiles/boss_{ember,tide,plain}_bolt_profile.tres`（**仅** `telegraph_duration` → 0.5，中枢裁决 1）
- `scripts/run/enemies/boss_tide_ember.gd`（C1/C4/C5）
- `scenes/run/enemies/boss_tide_ember.tscn`（挂载 `MeleeRangeTelegraph`（`top_level`）+ `Fill`(Polygon2D) + `Outline`(Line2D)）
- `combat/tests/run_task71_boss_cast_and_telegraph_tests.gd`（新建，8 组断言）
- `docs/agent_tasks/evidence/task71/**`

中枢事后授权加入 allowlist：

- `combat/tests/run_task61_boss_three_form_tests.gd` —— 仅修复 `summon_cap_and_death_cleanup` 的测试退化（中枢裁决 2），见 §6.4.2。

allowlist 外（中枢已批准，见 §6.7 存疑点 1）：

- `combat/tests/run_task69_boss_timing_and_standoff_tests.gd` —— 仅测试数据，见 §6.4.1。

新增 `.import`（Task 70 明令留给本任务生成，由 Godot 编辑器 `filesystem scan` 生成，参数与既有同目录 `.import` 逐字一致）：
`boss_{plain,ember,tide}_cast_v1.png.import`、`telegraph_{melee,summon}{,_static}_v1.png.import`（4 个）。

### 6.2 C1 节拍方案（按中枢裁决 1 定稿为 0.5）

采用任务书的「优先方案」：cast 剪辑全 8 帧统一 `duration = 1.0`、`speed = 10.0`（每帧 **0.100s**）。

- 前摇段 frames 0→4（5 帧）= **0.500s**；发射帧 5；发射帧+收招段 frames 5→7（3 帧）= **0.300s**。
- 三个弹体 profile 的 `telegraph_duration` 统一为 **0.5**。

| 形态 | 原 `telegraph_duration` | 现值 | 变化 |
|---|---:|---:|---|
| 熔炽 ember | 0.45 | 0.5 | +0.05s（预警变长） |
| 潮涌 tide | 0.5 | 0.5 | 不变 |
| 普通 plain | 0.4 | 0.5 | +0.10s（预警变长） |

选 0.5 而非三者均值 0.45 的依据是中枢裁决 1：正确的约束是**不缩短任何形态的预警**。潮涌是 `spread_count=5` / 60° 扇形、已被标记为疑似超模的形态，减少它的反应时间方向错误；用户对本 Boss 的全部反馈都是「不协调 / 读不懂」，没有「太简单」。0.5 之后没有任何形态变难。

- 实测（`logs/capture_task71.log`）：`telegraph=0.500s cast_windup=0.500s cast_recovery=0.300s launch_frame=5 speed_scale=1.000`。
- 两段时长仍然**全部从 SpriteFrames 读取**（`_clip_segment_duration()` 按 per-frame duration / animation speed 求和），代码里没有 0.5 / 0.3 的字面量。
- Task 69 的 `speed_scale` 拉伸（0.889/0.800/1.000）**整体删除**，`_play_attack_from_frame(frame, scale)` 泛化为 `_play_clip_from_frame(pose, frame)`，`speed_scale` 在所有入口被钉死为 1.0。
- 发射后的 hold 由 `cast_recovery_duration()`（0.300s）推导，取代 Task 69 的 `attack_recovery_duration()`（0.360s）。任务书登记的副作用（发射后 `attack_time > 0` 冻结追击）仍然存在，但**冻结时间由 0.36s 缩短到 0.30s**，方向上是改善（中枢已顺带认可）。

### 6.3 C2 双重抖动取舍

**保留图片自带的 3 帧弹跳，删除 tween 的循环缩放**（`set_loops()` + scale 1.08/0.95 全部移除）。理由：3 帧弹跳是 Task 60/70 美术授权的位移量（1px），tween 的缩放是当年没有美术时的占位。仅保留原 tween 的**一次性 alpha 淡入**（0.08s）作为出现感——它是淡入不是弹跳，与图片弹跳不构成叠加。reduced-motion 分支既不播剪辑也不建 tween。

### 6.4 测试文件改动说明

#### 6.4.1 `run_task69_boss_timing_and_standoff_tests.gd`（allowlist 外，中枢已批准）

`combat/tests/run_task69_boss_timing_and_standoff_tests.gd` 的第 7 组断言把 Boss SpriteFrames 冻结为「恰好 11 个动画」，并用 `not contains("_v1.png")` 作为「不得回退到 v1 单帧资产」的守卫。C1 强制要求把三个 cast 动画加进同一个 `SpriteFrames`，这两条必然变红，且该文件不在 allowlist 内、任务书 §5.2 又要求该套件全绿——两者不可兼得。

采取的处理是**最小测试数据更新**，不放松任何守卫：

- `EXPECTED_FRAME_COUNTS` 补入 `{plain,ember,tide}_cast: 8`（仍是精确集合断言，14 个动画）；
- 把 `_v1.png` 子串守卫换成逐一列举 11 个**已退役单帧**表名的守卫（Task 70 的 cast sheet 合法地叫 `_v1` 且是 8 帧，子串守卫会误报并因此掩盖这条守卫真正要保护的东西）。

Task 69 的全部时序断言（含第 8 组「前摇 0.400s == `melee_telegraph_duration`、命中帧 4 == 判定生效帧」）**一行未改**，仍然全绿（8 tests / 342 assertions）。

#### 6.4.2 `run_task61_boss_three_form_tests.gd`（中枢裁决 2 授权）

C5 把召唤改成延迟生成后，`_test_summon_cap_and_death_cleanup` 在 `_start_summon()` 之后立即读 `_alive_summon_count()`，恒为 0——测试仍绿但不再证明上限，属真实测试退化。

修改（仅限该测试 + 一个新私有 helper，未触碰该文件其他任何测试）：

| | 修改前 | 修改后 |
|---|---|---|
| 第 1 次施放后 | `_start_summon()` → 立即读计数（恒 0） | `_start_summon()` → `await _resolve_summon_window(boss)` → 再读计数（实测 2） |
| 反退化守卫 | 无 | 新增 `_expect(count_after_first > 0, ...)`，使该测试无法再悄悄变空 |
| 第 2 次施放后 | `_start_summon()` → 立即读计数 | `_start_summon()` → `await _resolve_summon_window(boss)` → 再读计数 |
| 上限/死亡清理断言 | 原文 | **原文逐字保留，未放宽** |

新 helper `_resolve_summon_window(boss)`：临时把 `ai_enabled` 打开、推进物理帧直到 `_summon_pending_form == null`、再恢复原值。预警窗期间 Boss 的 `_physics_process` 走 `attack_time > 0` 的早返回分支，不可能触发其它行为，因此不会把 AI 依赖引入该 fixture。

结果：`run_task61` 仍为 **17 tests 全绿**，断言数 87 → **88**（+1 = 新增的反退化守卫）。

### 6.4.3 原 allowlist 外改动说明（历史记录）

### 6.5 测试与回归

- 新建 `run_task71_boss_cast_and_telegraph_tests.gd`：**8 tests / 259 assertions 全绿**。
- §5.2 指定回归全绿：task69（8 tests / 342 assertions）、task61（17 tests / **88** assertions）、task51（2/49）、task58（3/104）、task59（10/116）。
- 全库 47 个套件（跳过 `run_global_instakill_tests`，属禁止接触范围）见 `docs/agent_tasks/evidence/task71/logs/`。4 个失败套件（task30 / task40 / task31 / task32）失败条目与 `docs/agent_tasks/evidence/task61/logs/baseline_before_task61/` **逐条一致**（11 / 9 / 12 / 61），均为预存在失败，与本任务无关。
- 主场景 + Boss 房 180 帧 smoke：退出码 0，日志干净（`logs/smoke_main_and_boss_room_180.log`）。

### 6.6 视觉证据

`docs/agent_tasks/evidence/task71/screenshots/`（每项均有 1920×1080 与 2560×1440 两份），采集脚本 `capture_task71_cast_and_telegraphs.gd`，运行日志 `logs/capture_task71.log`：

| 文件 | 对应 §5.3 | 内容 |
|---|---|---|
| `task71_ranged_cast_sequence_*` | 1 | 32 格逐帧，标注 `anim=ember_cast`、帧号、cast 段（WINDUP/LAUNCH/RECOVERY）、`speed_scale=1.000`、弹体数；弹体在 LAUNCH（frame 5）出现 |
| `task71_telegraph_types_*` | 2 | 实机三型图标：近战红双三角 / 远程黄感叹号 / 召唤紫镂空环 |
| `task71_melee_range_box_{right,left}_*` | 3 | 橙色预警框 + **独立重算**的青色探针框叠加；判定 ACTIVE 那一格橙框已消失、玩家在框内被命中 |
| `task71_summon_flow_*` | 4 | 预警窗 0.9s 倒计时（summons=0）→ 窗结束同一格 summons=2、预警消失 |
| `task71_summon_interrupt_*` | 4 | cell 05 poise 破防：pending=false、warning=false、20 格内 summons 恒为 0（**冷却退还不由本图证明，见下方更正**） |

> **独立验收更正（证据标注，非代码缺陷）**：本表原先声称 `task71_summon_interrupt_*` 中的 `summon cooldown=0.000 (0=refunded)` 证明了冷却退还——**它不能**。采集脚本在 AI 已开启召唤窗**之后**才执行 `_boss._summon_cooldown_remaining = 0.0`，把已武装的 16.0 覆盖为 0，导致该字段在破防前后**都读作 0.000**，对「是否退还」毫无区分力。
>
> **退还行为本身是真实的**，由另外两条证据支撑：`run_task71` 的断言做了正确的前后对照（破防前 `> 0.0` 已武装 → 破防后 `== 0.0`），验收方的独立实机探针也测到冷却确被武装为 `16.000`（运行中 `15.900`）。故结论不变，仅本图的证明力主张被撤回。
| `task71_indicator_before_after_*` | 5 | 普通敌人 + 潮汐哨兵，退役 Label「!」与新贴图并排同帧对照 |

日志中的 no-readback 对照测量：`charge on anim=ember_cast frame=0；telegraph ran 31 physics frames (0.517s)；at launch anim=ember_cast frame=5（configured 5），bolts=3，speed_scale=1.000`。

### 6.7 中枢裁决记录

中枢对执行方提出的 7 个存疑点逐条裁决，2 项要求返工（已完成）、5 项认可：

| # | 存疑点 | 裁决 | 处理 |
|---|---|---|---|
| 1 | 越界修改 `run_task69_*` | **批准**（71 的 allowlist 疏漏；C1 与断言 7 设计上互斥）。前提：Task 69 时序断言逐字未改，由验收方独立复核 | 保持，见 §6.4.1 |
| 2 | `telegraph_duration` 统一值 | **返工**：统一到 **0.5**，不是 0.45。约束是不缩短任何形态的预警 | 已改，见 §6.2 |
| 3 | `run_task61` 召唤测试退化 | **返工 + 临时授权**该文件进入 allowlist，仅修这一处 | 已改，见 §6.4.2 |
| 4 | C4 + poise 破防不清框 | **认可偏差**：poise 破防不取消已生成的 delivery，伤害照落，隐藏框才是 C4 禁止的「骗玩家」 | 保持现状 |
| 5 | §5.3.5「表现未变」措辞 | **认可执行方理解**：指 C3 范围（类型/位置/时机/信号/生命周期不变），像素必然变，C2 与 C3 不冲突 | 保持现状 |
| 6 | 删除 `delivery.query_offset` 硬编码 | **认可**：让场景成为唯一真源是 C4 成立的必要条件，行为等价 | 保持现状 |
| 7 | 召唤 channel 播完停末帧再跳回发射帧 | **保持现状**：读作「引导 → 释放」合理；停在前摇帧属 polish，不在本任务返工 | 登记备查 |
| — | 发射后追击冻结缩短 | 顺带认可，方向正确 | 保持（0.36s → 0.30s） |


---

## 7. 验收记录（2026-08-20）

Result：**PASS**。由未参与执行的独立验收 Agent 完成（中途因账号用量限制中断一次，带上下文恢复后续完）。

### 7.1 独立复算结论

- **C1 节拍**：直接解析 `.tres` 并实测函数返回值——cast 8 帧 `duration` 全 1.0、`speed=10.0` → 前摇 **0.5000s**、收招 **0.3000s**；attack 前摇仍为 **0.4000s**（未受影响）。
- **三 profile `telegraph_duration` 均为 0.5**，逐文件 diff 确认每文件仅 1 行改动，`damage`/`speed`/`spread_count`/`spread_angle_degrees` 未被触碰。熔炽 0.45→0.5、普通 0.4→0.5（均变长），潮涌原本即 0.5。**无任何形态的预警被缩短。**
- **cast 非 attack**：全库 `sprite.speed_scale` 仅 3 处赋值且全为 `1.0`，Task 69 的 0.889/0.800/1.000 仅存于注释；实机 charging 全程 `anim=ember_cast speed_scale=1.000`。
- **发射帧 = 5**：证据图 cell 18 `frame=5 bolts=0` → cell 19 `frame=5 bolts=3`；测试对三形态断言精确相等而非近似。
- **C4 框 = 判定区（核心项）**：验收方**自写探针并用自己手算的期望值**比对（100×70 居中于 boss±(50,0)）——Boss@(300,200) 时右向框 `(300,165)–(400,235)`、左向框 `(200,165)–(300,235)`，**与独立期望逐值精确相等**；判定 ACTIVE 时框已消失。
- **C5**：窗口 0.9s 内 `summons=0`、窗关同格 `summons=2` 且预警消失；poise 破防后 20 格内 summons 恒 0；冷却退还由测试前后对照与实机探针共同证实（见 §6.6 的证据更正）。
- **C3 向后兼容**：`scripts/enemy.gd`、`tidal_sentry.gd`、`scenes/enemy.tscn`、`tidal_sentry.tscn`、`delayed_area_delivery.gd`、`melee_delivery.gd`、`boss_melee_delivery.tscn` **零改动（连 EOL 变动都没有）**。`start(duration, kind := RANGED)` 内对 `_telegraph_type` 无条件赋值 → 不传即复位，Boss 的近战/召唤预警不会泄漏到下一次远程。
- **C2**：`set_loops()` 与 1.08/0.95 循环缩放已删除，仅保留一次性 0.08s alpha 淡入（是淡入非弹跳，不构成双重抖动）；reduced-motion 分支不建 tween。既有契约、两信号、`_clamp_to_viewport_margin()` 均未变。
- **`query_offset` 删除行为等价**：场景确实声明同值，真实判定走 `MeleeDelivery._build_query_transform()` 读取该导出属性，Boss 预警框从同一 delivery 实例推导，探针数值证实重合。
- **无硬编码**：发射帧索引来自 `tuning.ranged_cast_launch_frame_index`、召唤窗来自 `form.summon_telegraph_duration`、框尺寸/偏移来自 delivery 实例；脚本内仅剩两个纯装饰性闪烁常量。
- **Task 61 机制未动**：形态切换仅新增 `_cancel_pending_summon(false)` 一行；poise 为追加式 override（先 `super()` 再判断 `poise_stun_time` 是否上升），未改判定规则。
- **零 git 写**：HEAD 仍 `1cfb1c8`，reflog 无新 commit，`git stash list` 空。

### 7.2 测试与回归（验收方全部自跑）

`run_task71` 8/259、`run_task69` 8/342、`run_task61` 17/88、`run_task51` 2/49、`run_task58` 3/104、`run_task59` 10/116 —— 全绿，与执行者声明一致。

验收方额外加跑了执行者未列、但覆盖被改动共享路径的套件：`run_delivery_tests` 16/56、`run_delivery_reuse_tests` 10/105、`run_combat_tests` 27/124、`run_task41` 4/96、`run_task43` 4/105 —— 全绿。

4 个预存在失败（task30/40/31/32）条目数 11/9/12/61，与第三方基线 `evidence/task61/logs/baseline_before_task61/` 一致；验收方进一步剥离 Task 62 引入的 `testname:` 前缀后做集合内容 diff，四套均 `IDENTICAL`。Smoke 退出码 0，日志 3 行、零 ERROR/WARNING。

**新断言非空转**：抽查 C1/C3/C4/C5/reduced-motion 五组断言体。C4 尤其可靠——测试独立 `instantiate()` 一份 delivery 探针读出 `hit_shape.size` 与 `query_offset`，再与 delivery 自身 query 原点交叉校验，左右朝向各一次，是真正的第三方推导。C1 另附源码文本守卫（禁止 `_play_attack_from_frame`、禁止字面量、要求配置字段至少出现 3 次）。

### 7.3 两处授权越界的判定：均严格限定在授权范围内

**授权 A（`run_task69_*`）**：diff **+30 / −2**，删除的仅有那 2 行。精确集合断言仍为 `_expect_eq(names.size(), EXPECTED_FRAME_COUNTS.size())`（现 14），**未放宽为「至少 N 个」**。子串守卫换成的 11 项显式退役清单经磁盘核对完整无遗漏（该目录共 14 个 `*_v1.png`，减去 Task 70 的 3 张 cast 正好 11 张）。**Task 69 全部时序断言根本不在 diff 里**；验收方另行通读断言 8 函数体确认其仍在断言 `attack_windup_duration() == melee_telegraph_duration` 与命中帧 ±1 帧，且 attack 剪辑的 per-frame duration 未被改动、探针实测 `attack_windup_duration()=0.4000`。**批准前提成立。**

**授权 B（`run_task61_*`）**：diff **+24 / −0**，零删除，原有 cap/相等/死亡清理断言逐字保留，未触碰该文件其余 16 个测试。断言效力真实恢复（helper 推进物理帧至 `_summon_pending_form == null` 才读计数），并新增 `count_after_first > 0` 反退化守卫使其无法再悄悄变空。helper 临时开 `ai_enabled` 是安全的：`attack_time = 0.9 + 0.3 = 1.2s > 窗口 0.9s`，pump 期间物理走早返回分支。87→88 算术自洽。

### 7.4 记录精度

§6.1 列 `boss_tide_bolt_profile.tres` 为已修改，实际是 CRLF-only 重存、内容零差异（原本就是 0.5）。无害，记录于此。

### 7.5 登记备查（不阻断）

- **普通敌人/潮汐哨兵的预警像素确实变了**（Label「!」→ 32×32 贴图，视觉尺寸明显变大）。任务书 §4「不改变任何表现」与 §1.2「该 Label 是待替换的占位」字面冲突，中枢 §6.7 #5 已裁决「表现未变」仅指 C3 范围（类型/位置/时机/信号/生命周期），执行者亦在证据图上明写未藏。验收方认为这是 C2 的题中之义，不是缺陷。
- **召唤 channel 的帧回跳**：cast 剪辑 0.8s < 召唤窗 0.9s，故停在末帧 `frame=7` 后跳回 `frame=5` 释放，肉眼可见。属真实观感瑕疵，已裁决不在本任务返工，建议另立 polish 任务。
- `run_task69_boss_timing_and_standoff_tests.gd.uid` 为 Godot 生成的新 sidecar，编辑器产物，无害。
