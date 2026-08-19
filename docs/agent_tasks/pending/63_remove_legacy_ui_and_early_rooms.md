# 任务 63：删除 legacy UI 路径、test_room 与古早房间

## 0. 阅读方式

本任务书只规定**删什么**、**什么不能连带删掉**、**怎么证明没删错**。
实现方式自定。硬约束是 §4 allowlist 与 §5 禁止项。

**前置**：任务 62 已完成（共享 `TestHarness` + 批量 runner 已就位）。本任务涉及的测试改动一律以
`combat/tests/test_harness.gd` 为准，不要再引入新的样板。

---

## 1. 背景事实（已验证，可直接采用）

- `scripts/ui/run_overlay_interface.gd`（2504 行 / 137 函数）靠 `_formal_mode` 分叉成两套并行实现。
  `_formal_mode` 由 `configure()` 的 `formal_coordinator != null` 决定（`:90`）。
- 正式主场景 `scenes/run/run_game.tscn` 经 `RunFlowCoordinator` 传入 coordinator，**永远 formal**。
  legacy 分支只有 `scenes/test_room.tscn` 会走到，而 test_room 只被测试脚本引用。
- 已知 6 对孪生函数：`_skill_drag_data` / `_slot_drag_data` / `_slot_can_drop` / `_slot_drop` /
  `_select_skill` / `_clear_selected_slot`，各有一个 `_formal_` 前缀版本。
- 古早房间（几何体手拼、无全屋背景图）：`room_arena_corridor.tscn`、`room_arena_platforms.tscn`。
  任务 57 迁移后的新式房间是另外 4 个，正式流程 `prototype_five_stage_demo.tres` **只用新式房间**。
- **测试宿主的既定方向：一律用真实房间**。`test_room.tscn` 是简化的几何体宿主，与正式房间在碰撞、
  相机、背景、出生点上都不一致，测试保真度低于真实房间，没有保留价值。

---

## 2. 改动需求

### D1 — 删除 overlay 的 legacy 分支

删掉 `_formal_mode == false` 的整条路径，包括其独占的成员、UI 构建函数、拖拽回调与 6 个孪生函数中的 legacy 版本。

删完后 `_formal_mode` 标志本身应当消失，`configure()` 的 `formal_coordinator` 变为必填。

**判据**：文件内不再出现 `_formal_mode`；`_formal_` 前缀因为不再需要区分而可以去掉（去不去随意，不强制）。

### D2 — 删除 test_room，测试改用真实房间

删 `scenes/test_room.tscn` + `scripts/test_room.gd`。

**连带处理 19 个依赖它的测试脚本**（9 个 `capture_*` + 10 个 `run_*`，均 `preload("res://scenes/test_room.tscn")`）。
这批文件**必须先分类再动手**：

| 类别 | 判定 | 处理 |
| --- | --- | --- |
| A. 测的就是 legacy UI | 断言对象是 legacy 的奖励卡/槽位卡/路线面板 | 随 D1 一起删 |
| B. 只是借 test_room 当轻量宿主 | 断言对象是战斗、VFX、闪避、元素回收、技能等级等 | **迁到真实房间，不许删** |

**B 类的迁移目标是真实房间，不要新建简化宿主。** 现成范式见
`combat/tests/run_task29_real_room_flow_tests.gd`：实例化 `res://scenes/run/run_game.tscn` 得到
`RunFlowCoordinator`，等 `coordinator.host` / `active_room` 就绪且 `route.phase == RunPhase.COMBAT`，
再在 `coordinator.active_room` 里取玩家与敌人。`capture_task29/30/31/…` 等一批脚本也已经是这个写法，可直接参照。

迁移时**只换宿主装配，断言正文一行不改**。若某条断言依赖 test_room 特有的几何（如硬编码的地面 Y、
平台坐标），改成从真实房间实际读取对应值，并在 §7 逐条列出改了哪些、为什么。

> ⚠️ 注意：`run_growth_tests.gd`、`run_task31_content_balance_tests.gd`、`run_task32_formal_four_passive_content_tests.gd`
> 只是函数名里含 `_test_room_` 字样，**不依赖 test_room.tscn**，不要误伤。

**判据**：全项目 grep `test_room` 零命中；B 类测试的测试数/断言数与迁移前一致。

### D3 — 删除古早房间与孤儿房间定义

删场景：`scenes/run/rooms/room_arena_corridor.tscn`、`scenes/run/rooms/room_arena_platforms.tscn`

删定义（已验证为零引用孤儿，不在任何 flow 中）：

- `resources/run/rooms/combat_02_pressure.tres` → 指向 platforms
- `resources/run/rooms/combat_03_layer_elite.tres` → 指向 platforms
- `resources/run/rooms/combat_05_risk.tres` → 指向 corridor
- `resources/run/rooms/combat_05_stable.tres` → 孤儿，但指向**新式** flat 场景，删定义不删场景

**判据**：`prototype_five_stage_demo.tres` 引用的 4 个房间定义（`combat_01_entry` / `combat_02_swarm` / `combat_04_validation` / `combat_06_final_boss`）及其场景全部完好；正式跑图能从头走到尾。

---

## 3. 必须活下来的东西

删除面很大，以下是**红线**，删掉任何一条即为任务失败：

1. 正式流程 5 关跑图可完整通关（`run_game.tscn` → 4 个房间定义 → boss → 结算）。
2. `room_arena_flat` / `room_arena_tidal_battle_02` / `room_arena_boss` / `room_shop_formal` 四个新式房间。
3. B 类测试的全部覆盖 —— 闪避、元素回收、技能 VFX、技能等级、技能内容目录、成长集成。
4. `combat/tests/run_global_instakill_tests.gd`（保护项，不改不删）。

---

## 4. Allowlist

允许改动/删除：

| 目标 | 允许的操作 |
| --- | --- |
| `scripts/ui/run_overlay_interface.gd` | 删 legacy 分支 |
| `scripts/combat_hud.gd` | **仅**在因 D1/D2 而必须改的调用点上改（如 `configure` 签名） |
| `scenes/test_room.tscn`、`scripts/test_room.gd` | 删除 |
| `scenes/run/rooms/room_arena_{corridor,platforms}.tscn` | 删除 |
| `resources/run/rooms/combat_{02_pressure,03_layer_elite,05_risk,05_stable}.tres` | 删除 |
| A 类测试脚本 | 删除 |
| B 类测试脚本 | 仅换宿主装配，断言正文不改 |
| 本任务书 | 追加 §7 交付小结 |

清单外一律不动 —— 尤其 `combat/` 生产代码、`growth/` 全部、其余 `.tres`。
**本任务不新建任何场景或脚本**：B 类一律迁到既有的 `run_game.tscn` 路径。

---

## 5. 禁止项

- **不做范围外重构**。overlay 删完剩下的代码即使很丑也不要顺手整理，记在 §7。
- **不改任何 B 类测试的断言语义**，不靠删用例让数字变好看。
- 分类结果有疑问时**停下来问**，不要猜着删。删错测试比留着 legacy 代码严重得多。
- 不跑 `--headless --editor --quit` 全项目扫描（会批量生成 `.uid` sidecar 污染 diff）。
  注：用 `--headless --script res://...` 跑测试时 Godot 会为缺 `.uid` 的脚本自动生成 sidecar，
  那是运行测试的正常副作用，照实披露即可，不必回滚。
- 不动 git 历史，不提交（除非另行要求）。

---

## 6. 验收

**第 0 步（动手前必做）**：输出 19 个测试脚本的 A/B 分类表，连同判定依据。这张表就是本任务的施工图。

**改动前**用批量 runner 存基线，改动后重跑逐一比对：

```bash
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://combat/tests/test_batch_runner.gd
```

通过标准：

1. **B 类测试的测试数 / 断言数 / exit code 与基线逐一相同。** A 类测试整体消失，需在 §7 列明删了哪几个、各带走多少条用例。
2. 未涉及本任务的其他 `run_*.gd` 数字与基线**完全不变**。
3. 正式跑图实机验证一次（非 headless），走完 5 关到结算，附截图。
4. `git status` 的改动文件集合 ⊆ §4 allowlist。
5. grep 零命中：`test_room`、`_formal_mode`、`room_arena_corridor`、`room_arena_platforms`。

> 已知前提：任务 62 交付时的基线有 5 个失败文件（`run_task30_run_ui_tests`、`run_task31_content_balance_tests`、
> `run_task32_formal_four_passive_content_tests`、`run_task40_drag_compact_hud_tests`、`run_task58_*`）。
> **这 5 个没有一个属于 legacy UI —— 已实跑取证：task30 / task32 / task40 都跑在 `run_game.tscn`
> 的 formal 路径上，task31 是房间几何断言，task58 是 `tmp/` 冷副本污染。本任务一个都消不掉，
> 也一个都不要去修。它们归任务 65 处理。**
> 另外 `run_task34_performance_tests` 输出 JSON、runner 里显示 `n/a`，属正常。

---

## 7. 交付（执行者填写）

- 19 个测试的 A/B 分类表（含判定依据）
- 删除清单：文件 + 各自带走的用例数
- B 类迁移清单：逐个列出宿主换法；若有依赖 test_room 几何的断言被改，逐条说明
- 基线 vs 改后的逐文件数字表（B 类与无关项分开列）
- 正式跑图截图
- Allowlist 对账：有无越界；越界原因
- 发现但未做的事项
