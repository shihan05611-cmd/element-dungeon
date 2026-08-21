# 任务 72：HUD 布局骨架收敛与房间标题归位

- **状态**：`PENDING`
- **Review Level**：`L2`（升级到 L3 的触发：出现公共接口变更、随机/偶发失败、或 §5 的布局断言无法稳定复现）
- **依赖**：无。**必须排在任务 73（像素字体与 Theme）之前** —— 73 会改变全部 Label 的文本度量，先做 73 会污染本任务「测试零差异」的验收基线。
- **Git 基线**：`6ec3fef`，分支 `boss/task68-69-multiframe-and-timing`
- **无关工作树文件**（不得纳入本任务改动）：`docs/agent_tasks/CENTRAL_REVIEW_RULES.md`、`docs/agent_tasks/completed/65_*.md` 的重命名、未跟踪的 `docs/agent_tasks/PROMPT_allowlist_cost_model.md`
- **模型**：`gpt-5.6-sol`，推理等级 `medium`

## 0.1 用户决定（已冻结）

1. **被动条下移到技能条上方**（原方案 b）。曾评估过的「留在上半区、移到状态条下方」（原方案 g）已被否决，不再作为备选。
2. **被动槽在视觉上要明显弱于主动槽**，不只是位置分离。落实为 §2 B5。

## 0. 阅读方式

这是一次**布局属性重排**，不是 UI 重写。目标是让 HUD 从「四个角各自硬编码坐标」变成「一套安全边距 + 网格 + 互不重叠的锚区」。

其中 §2 B1 修的是一个**确定的显示缺陷**（面板互相遮挡），不是审美偏好。

最容易踩的坑是 §2 B2：**大量测试依赖 HUD 的完整节点路径**，改树结构会一次性砸掉 6 个测试文件。硬约束是 §3 allowlist 与 §4 禁止项。

---

## 1. 背景事实（已验证）

### 1.1 HUD 是纯代码构建的

`scenes/combat_hud.tscn` 只有 7 行（`CanvasLayer` + `layer = 10` + 挂脚本），全部界面由 `scripts/combat_hud.gd` 的 `_build_ui()`（第 900 行）运行时构建。逻辑画布 **1152×648**，`window/stretch/mode = "canvas_items"`，`aspect = "expand"`。

### 1.2 BossPanel 与 PassivePanel 横向重叠 196px

| 面板 | 代码位置 | 锚点 / position / size | 逻辑横向占位 |
| --- | --- | --- | --- |
| `BossPanel` | `combat_hud.gd:1278-1280` | `PRESET_CENTER_TOP` `(-260,16)` `520×90` | 316 → 836 |
| `PassivePanel` | `combat_hud.gd:1035-1037` | `PRESET_TOP_RIGHT` `(-512,16)` `496×56` | 640 → 1136 |

交集 `[640, 836]` = **196px**。`_build_ui()` 中 `_build_passive_panel` 先于 `_build_boss_panel` 调用，故 Boss 面板绘制在上层、盖住被动条。

`PASSIVE_SLOT_SIZE = (116,42)`，4 槽横排，槽起点 646。因此 **P1 槽被完全遮挡、P2 槽被遮挡约 68/116**。实测见 `docs/agent_tasks/evidence/task61/screenshots/task61_02_hud_boss_panel_1920x1080.png`（1920 宽，缩放比 1.667，Boss 面板左缘实测约 528px ÷ 1.667 ≈ 317，与算式吻合）。

### 1.3 StatusPanel 不贴任何边

`combat_hud.gd:928` 硬编码 `position = Vector2(16, 168)`，`STATUS_SIZE = (264, 76)`。它悬在左侧半空，既不贴边也不与其他面板对齐。原注释称是为了「让开房间标题条」—— 而房间标题条本身的位置问题见 1.4。

### 1.4 房间标题在世界空间，不属于 HUD

`RoomTitle` 是 **6 个房间场景**里的 `Label`，父节点是房间根 `Node2D`，房间场景内**没有 CanvasLayer**：

`room_arena_boss.tscn:79`、`room_arena_corridor.tscn:61`、`room_arena_flat.tscn:130`、`room_arena_platforms.tscn:93`、`room_arena_tidal_battle_02.tscn:130`、`room_shop_formal.tscn:73`

由 `scripts/run/run_room_instance.gd:129` 用 `get_node_or_null("RoomTitle")` 取到后写入文本。

`scenes/run/run_game.tscn:27` 的 `Camera2D` 是**静态的**（全项目无相机跟随脚本），`zoom = Vector2(0.75, 0.75)`。后果：

1. 标题字号 18/19 经 0.75 缩放后实际渲染为 **13.5 / 14.25 px 非整数**，必然发虚 —— 这是它看起来比 HUD 其他文字更糊的直接原因；
2. 它不参与 HUD 的 `canvas_items` 适配，与 HUD 面板不共用安全边距，各房间的 `offset` 与配色也不一致（boss 房 `font_color = (0.8,0.9,1)` / flat 房 `(0.77,0.94,1)`，字号 19 / 18）。

### 1.5 测试依赖 HUD 的完整节点路径（本任务最重要的约束来源）

以下路径**必须继续解析成功**：

- `Root/StatusPanel/Margin/Status/TitleRow/Title` — `run_agent_d_integration_tests.gd:56`
- `Root/StatusPanel/Margin/Status/TitleRow/ElementBadge/BadgeMargin/BadgeRow/ElementText` — `run_hud_loadout_feedback_tests.gd:78`
- `Root/SkillPanel/Margin/Skills/SlotRow` — `run_compact_hud_reward_tests.gd:89`、`run_task24_*:96`、`run_task30_run_ui_tests.gd:56`
- `Root/PassivePanel/Margin/SlotRow` — `run_compact_hud_reward_tests.gd:90`、`run_task24_*:97`、`run_task30_run_ui_tests.gd:57`
- `Root/SkillPanel/Margin/Skills/SlotRow/CurrentElement/Body/ElementShape` 与 `.../ElementText` — `run_compact_hud_reward_tests.gd:95-96`

以下路径**必须继续解析为 null**（两处显式断言「不存在」）：

- `Root/SkillPanel/BusyOverlay/BusyStrip` — `run_task40_drag_compact_hud_tests.gd:52`、`capture_task40_drag_compact_hud_visuals.gd:127`

以下取值点在 B3 之后**需要同步改**：

- `capture_task30_run_ui_visuals.gd:685`、`capture_task40_drag_compact_hud_visuals.gd:131` — 均从 room 上取 `RoomTitle`

### 1.6 间距 token 已存在但形同虚设

`scripts/ui/combat_ui_tokens.gd` 定义了 `GAP_XS/SM/MD = 4/8/12`，而 `combat_hud.gd` 的构建代码里散落着 `6`、`7`、`10`、`14` 等硬编码值（如 `_margin("Margin", 14, 10)`、`separation = 6/7`）。

---

## 2. 改动需求

### B1 — 消除面板重叠，四角归位

全部顶层面板改为「四角锚定 + 统一 16px 安全边距 + 4px 网格」。

**硬性目标**（验收按此断言，不按具体坐标）：

1. 在 1152×648 逻辑画布下，**任意两个同时可见的顶层面板，其矩形交集为空**；
2. 每个面板到最近屏幕边的距离 ≥ 16px；
3. **顶层面板**的 position / size 以及面板之间的间距均为 **4 的倍数**。
   > 该网格约束**只作用于顶层面板**。槽位内部的数值（如被动槽高 42）受文字度量制约，其归一延后到任务 73 字号阶梯落地之后，本任务不强求，理由见 B5。

**参考布局**（自洽、已验算，执行者可微调但必须满足上述三条）：

| 面板 | 锚点 | position | size | 逻辑占位 |
| --- | --- | --- | --- | --- |
| `StatusPanel` | `TOP_LEFT` | `(16, 16)` | `232×56` | x 16→248, y 16→72 |
| `BossPanel` | `CENTER_TOP` | `(-260, 16)` | `520×90` 不变 | x 316→836, y 16→106 |
| `PassivePanel` | `CENTER_BOTTOM` | `(-212, -148)` | `424×52` | x 364→788, y 500→552 |
| `SkillPanel` | `CENTER_BOTTOM` | `(-266, -88)` 不变 | `532×72` 不变 | x 310→842, y 560→632 |

即：**被动条从右上角下移到技能条上方**，与主动技能合成一个「配装区」，右上角空出。被动条宽度 424 由 B5 的槽位缩小推导而来（4 槽 × 96 + 3 间距 × 8 + 2 边距 × 8 = 424），与技能条 532 居中对齐后自然形成宽度层级。

> **为什么必须移走被动条**：Boss 面板居中占 316→836，右上区只剩 316px 宽。即便按 B5 缩小后被动条仍有 424px，右上角放不下。移动位置是唯一解。

`STATUS_SIZE`、`PASSIVE_STRIP_SIZE` 等常量允许调整。

### B2 — 节点树结构一律不变（硬约束）

只允许修改**布局属性**：`position`、`size`、`custom_minimum_size`、锚点预设、`separation` / `margin_*` 常量、`size_flags`。

**不得**新增、删除、重命名、重新挂接 §1.5 列出路径上的任何节点，也不得改变 `SlotRow` 等容器的子节点数量与顺序。

判据：§1.5 的全部路径断言在改动后逐条成立。

### B3 — 房间标题归位到 HUD

1. 6 个房间场景删除 `RoomTitle` 节点及其 `TitleStyle` SubResource；
2. `scripts/combat_hud.gd` 新增 `Root/RoomTitle`（贴左上或顶部左侧，需满足 B1 的三条硬性目标），并提供一个设置标题文本的公开方法；
3. `scripts/run/run_room_instance.gd:129` 改为调用该方法，不再 `get_node_or_null("RoomTitle")`；
4. `capture_task30_run_ui_visuals.gd:685`、`capture_task40_drag_compact_hud_visuals.gd:131` 的取值点同步改到 HUD。

标题文本内容与拼接格式（`"%s · %s"`）保持不变。

**判据**：标题不再受相机 `zoom = 0.75` 影响，字号为整数像素渲染；6 个房间的标题样式统一。

### B4 — 间距走 token

消除 §1.6 的散值，全部改用 `UI.GAP_XS/SM/MD` 或 4 的倍数。若现有 token 不够用，允许在 `combat_ui_tokens.gd` 中**新增** `GAP_LG` 一类常量，但**不得修改已有 token 的数值**。

槽位内部的间距（`_build_compact_slot` 里的 `_margin("Margin", 4, 3)` 等）**本任务不动**，与 B1 硬性目标 3 的说明一致，延后到任务 73。

### B5 — 被动槽相对主动槽降级（用户决定 0.1.2）

移到底部后，被动槽必须在视觉上明显弱于主动槽，不能只靠位置区分。

**现状**：`_build_compact_slot`（`combat_hud.gd:1086`）已全程按 `passive` 分叉，主动/被动各有一套尺寸值。当前 `PASSIVE_SLOT_SIZE = (116,42)` vs `ACTIVE_SLOT_SIZE = (132,54)`，宽度比 88% —— 并排后层级不足。

**本任务只缩宽度**：

| 数值 | 现值 | 目标 | 位置 |
| --- | --- | --- | --- |
| `PASSIVE_SLOT_SIZE` | `(116, 42)` | `(96, 42)` | `combat_hud.gd:17` |
| 被动 `Body.custom_minimum_size` | `(104, 36)` | `(88, 36)` | `combat_hud.gd:1104` |
| 被动 `text_width` | `68.0` | `56.0` | `combat_hud.gd:1145` |

`text_x`（32.0）与 `Icon`（26×26）保持不变：`32 + 56 = 88`，正好填满新的 Body 宽度。`Name` 已有 `OVERRUN_TRIM_ELLIPSIS`，长技能名照常省略。

**高度为什么不一起缩**：被动槽内 `Name`（y 0，高 17）与 `State`（y 17，高 17）两行文字合计 34px，槽高 42 扣除上下 margin 3 后 Body 仅 36 —— 余量只有 2px。在字号仍为 11 / 12 时，槽高降到 40 即溢出。高度压缩**延后处理**。

> **后续修正（用户新决定）**：原计划由任务 73 的 F5 压缩高度，现已作废。任务 **74** 会直接删除被动槽的 `Name` 与 `State` 两个 Label，被动槽降为纯图标，最终面积 ≤ 本任务交付值的 30%。执行顺序为 **72 → 74 → 73**。本节的宽度收缩仍然有效，作为 74 的起点。

**判据**（验收按此断言，不按具体数值）：

1. 被动槽宽度 ≤ 主动槽宽度 × 0.8；
2. 被动条面板总宽 ≤ 技能条面板总宽 × 0.85；
3. 被动条与技能条水平居中对齐（两者中心 x 相同）；
4. 4 个被动槽的内容均未溢出 Body 边界。

---

## 3. Allowlist

- `scripts/combat_hud.gd`
- `scripts/ui/combat_ui_tokens.gd` — **仅允许新增间距常量**，颜色 token 的值一律不动
- `scripts/run/run_room_instance.gd` — 仅 B3 涉及的标题推送改动
- `scenes/run/rooms/room_arena_boss.tscn`、`room_arena_corridor.tscn`、`room_arena_flat.tscn`、`room_arena_platforms.tscn`、`room_arena_tidal_battle_02.tscn`、`room_shop_formal.tscn` — **仅允许删除 `RoomTitle` 节点与其 `TitleStyle` SubResource**
- `combat/tests/capture_task30_run_ui_visuals.gd`、`combat/tests/capture_task40_drag_compact_hud_visuals.gd` — 仅 B3 涉及的取值点改动
- 新增 `combat/tests/run_task72_hud_layout_tests.gd`（+ 其 `.uid`）
- 新增 `combat/tests/capture_task72_hud_layout_visuals.gd`（+ 其 `.uid`）
- 新增 `docs/agent_tasks/evidence/task72/`
- 本任务书（追加 §6）

**仅此。** 若发现某处非改不可而不在表内，说明分类有误 —— 回到 §2 重判，或标记 `BLOCKED`，不要擅自扩表。

---

## 4. 禁止项

- **不换字体、不新建 Theme 资源、不改任何颜色 token 的值** —— 全部属于任务 73。
- **不改技能槽 / 被动槽 / 元素枢纽的内部结构** —— 即 `_build_compact_slot`、`_build_element_pivot` 的**树形与子节点**：不得增删、重命名、重新挂接子节点，不得改动 `visible = not passive` 一类的可见性分叉，不得改 `_slot_views` 字典的键。
  > **例外**：B5 明确列出的三处尺寸数值可以改。判断标准是「改数值可以，改结构不行」。主动槽的任何数值本任务一律不动。
- **不改主动槽的形态**（改方形图标 + 角标属 P1 另案）。本任务对主动槽只做位置调整。
- 不改任何战斗、成长、掉落、Boss 逻辑，不碰 `combat/` 与 `growth/` 下的非测试代码。
- 不改 `StyleBoxFlat` 的圆角、描边宽度、阴影等材质属性 —— 本任务只动位置和尺寸。
- 不删除 §1.5 中要求「必须解析为 null」的路径之外的任何节点。
- 不做任何 Git 写操作（`add/commit/push/reset/restore/checkout/clean/stash`）。
- 不自行标记 `ACCEPTED`。完成后更新为 `REVIEW` 并冻结。
- 不碰 §0 头部列出的三个无关工作树文件。

---

## 5. 验收

### 5.1 先存基线

改动前跑批量 runner 存基线：

```bash
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://combat/tests/test_batch_runner.gd
```

> 已知基线（任务 65 交付记录）：`TOTAL: 45 files, 4 failed`，失败项为 `run_task30_run_ui_tests`、`run_task31_content_balance_tests`、`run_task32_formal_four_passive_content_tests`、`run_task40_drag_compact_hud_tests`。**这 4 个不在本任务范围，不要修**。

### 5.2 通过标准

1. **除新增文件外，每个 `run_*.gd` 的测试数 / 断言数 / exit code 与基线逐一相同。** TOTAL 应为 `46 files, 4 failed`（45 → 46 系新增 `run_task72_*`，它必须 `exit 0`）。
2. 上述 4 个已知失败项**失败的方式也必须与基线一模一样**。
   > `run_task30` 与 `run_task40` 都是 HUD 相关且当前失败。若它们的失败方式因 B3 的取值点迁移而改变，**必须在 §6 写明原因并论证是预期内的**，不得掩盖，也不得顺手去修。
3. `run_task72_hud_layout_tests.gd` 断言：
   - §1.5 的全部节点路径逐条成立（必须存在的存在、必须为 null 的为 null）；
   - **任意两个同时可见的顶层面板矩形交集为空** —— 至少覆盖「Boss 面板可见」与「Boss 面板隐藏」两种状态；
   - 每个面板到最近屏幕边距离 ≥ 16；
   - 房间标题可从 HUD 取到且文本格式未变；
   - **B5 的四条判据**逐条成立（被动/主动槽宽比 ≤ 0.8、被动/技能条总宽比 ≤ 0.85、两条中心 x 相同、4 个被动槽内容未溢出 Body）；
   - 主动槽的 `ACTIVE_SLOT_SIZE` 与其内部数值**与改动前完全相同**（防止顺手改主动槽）。
4. `git status` 的改动文件集合 ⊆ §3 allowlist（扣除 §0 的三个无关文件）。

### 5.3 视觉证据（L2 要求）

用 `capture_task72_hud_layout_visuals.gd` 出图，存入 `docs/agent_tasks/evidence/task72/screenshots/`：

- 分辨率三档：**1152×648（逻辑原生）、1920×1080、2560×1440**；
- 场景必须是 **Boss 战**，即同一屏内同时可见：房间标题 + 状态条 + Boss 面板 + 被动条 + 技能条；
- 附一张与 `evidence/task61/screenshots/task61_02_hud_boss_panel_1920x1080.png` 的**前后对比**，用于确认 P1/P2 槽不再被遮挡；
- **配装区特写**：被动条与技能条并排区域的 4 倍放大图，用于人工判断 B5 的层级差是否成立 —— 判据 1/2 只保证数值达标，视觉上够不够弱要靠这张图确认。若中枢复核认为层级仍不足，按 §6 记录，作为任务 73 压缩高度时的调整依据，本任务不反复调参。

---

## 6. 交付（执行者填写）

- 各面板改动前后的锚点 / position / size 对照表
- B5 三处尺寸数值的改动确认，以及 4 个被动槽的实测内容边界（证明未溢出）
- 主动槽数值未变的对账
- §1.5 路径断言逐条结果
- 基线 vs 改后的逐文件数字表
- 6 个房间场景的 `RoomTitle` 删除确认
- Allowlist 与无关工作树文件对账
- 视觉证据清单
- Git 写操作为零的声明
- 发现但未做的事项

---

## 7. 协调记录

用户已指示**本任务不走中枢规则流程**（不派职责对话、不做 threadId 登记、不做 REVIEW/ACCEPTED 状态流转），改为直接派子 agent 执行 + 最简化验收。本节其余项不适用。

验收已简化为四项，取代 §5：批量 runner 对比基线、保留 `run_task72_hud_layout_tests.gd`、一张 1920×1080 Boss 战全 HUD 截图、allowlist 对账。§5.3 的三档分辨率 / 前后对比 / 4 倍特写证据包不做。

---

## 8. 执行进度快照（2026-08-20 20:56 中断）

**中断原因**：用户主动停止，准备换模型接力。**不是失败中止**。执行者为 sonnet 子 agent，工作时段 20:35–20:53。

### 8.1 已完成（已落盘在工作区，未提交）

| 需求 | 状态 | 落点 |
| --- | --- | --- |
| B1 StatusPanel 贴左上 | 完成 | `combat_hud.gd` `_build_status_panel`，`(16,168)` → `PRESET_TOP_LEFT` + `(16,16)` |
| B3 房间标题归位 | 完成 | 新增 `set_room_title()` / `room_title_label()` / `_build_room_title()` / `ROOM_TITLE_SIZE`；`run_room_instance.gd:129` 改为经 `find_child("CombatHUD")` 推送；6 个房间场景已删 `RoomTitle` + `TitleStyle`；2 个 capture 脚本取值点已改 |
| B4 间距走 token | 部分完成 | 已见 `_margin("BadgeMargin", UI.GAP_SM, UI.GAP_XS)`、`separation = UI.GAP_XS` 等替换，**是否覆盖全部散值未核实** |
| B5 被动槽缩宽 | 完成 | `PASSIVE_SLOT_SIZE` `(116,42)` → `(96,42)` |
| 新增回归测试 | 已写完 192 行 | `combat/tests/run_task72_hud_layout_tests.gd`，**未跑通** |
| 新增取证脚本 | 已写完 156 行 | `combat/tests/capture_task72_hud_layout_visuals.gd`，**未执行** |

### 8.2 关键实现发现（接力者请勿推翻重来）

`PASSIVE_STRIP_SIZE` 最终取 **`(448, 56)`，不是任务书 §2 B1 表格里手推的 424**。执行者的论证（见 `combat_hud.gd:14` 上方注释）：`PanelContainer.set_size()` 会向上钳到自身计算出的最小尺寸，而每个嵌套 panel 的 stylebox 边框会贡献内容边距，真实下限是 442（每槽含 2px 边框后占 100px，+16 行边距 +2 外框），424 达不到。448 留了几像素余量，同时仍满足 B5 判据 2（≤ 532 × 0.85 = 452.2）。

**这个发现是对的，任务书 §2 B1 表格的 424 应视为已被修正为 448。** 若接力者重算布局，`PassivePanel.position.x` 需从 `-212` 相应改为 `-224` 才能保持居中。

### 8.3 未完成 / 阻塞点

1. **`run_task72_hud_layout_tests.gd` 未跑通**。执行者中断前的最后判断是：这不是断言不匹配，而是「script error cascade」（脚本错误连锁）。**具体原因未查明**，它当时正准备用 `git stash` 隔离改动来对比基线 —— 该操作被禁止，且已随中止未执行（已核验 `git stash list` 为空）。接力者需自行定位。
2. **批量 runner 的改后对比未完成**，基线 `45 files, 4 failed` 是否保持未知。
3. **截图未产出**，`docs/agent_tasks/evidence/task72/` 目录尚不存在。
4. B4 是否覆盖全部散值未核实。

### 8.4 ⚠️ 工作区污染警告（接力者提交前必须甄别）

`git status` 有 52 个改动文件，**远多于本任务 allowlist**。已分三类查明，**不要整体提交**：

| 类别 | 文件 | 性质 | 处置 |
| --- | --- | --- | --- |
| **A. 任务内** | `scripts/combat_hud.gd`、`scripts/run/run_room_instance.gd`、6 个 `room_arena_*.tscn` / `room_shop_formal.tscn`、2 个 `capture_task*.gd`、2 个新增 `*_task72_*.gd` | 本任务产出 | 保留 |
| **B. Godot 自动重写** | 44 个 `resources/**/*.tres`，以及房间 `.tscn` 里的 `uid=` / `unique_id=` / `load_steps` 变化 | 跑 headless 时 Godot 补 uid 的副作用，非人为 | 与用户确认后再决定收编或还原 |
| **C. 与本任务无关** | `AI协作中枢规则_浓缩版.md`、`AI协作中枢运行协议_通用版.md`、`docs/agent_tasks/README.md`、`REVIEW_AGENT_RULES.md`、`REVIEW_L3_PLAYBOOK.md`、`CENTRAL_REVIEW_RULES.md`、未跟踪的 `docs/_discarded/`、`PROMPT_allowlist_cost_model.md` | 时间戳 20:31–20:34:35，**早于**子 agent 动工（20:35:05），来自另一进程的文档精简工作 | 不要碰 |

**D. 碰撞体尺寸变化 —— 已查明，保留**：房间场景 diff 里的碰撞体几何变更（如 `room_arena_flat.tscn` 的 `size = Vector2(204,16)` → `(264,16)`、`(138,16)` → `(193,16)`）**是用户本人所改**，与本任务无关但已由用户确认**纳入提交清单**。不得还原，不得「修正」，也不要计入 allowlist 超范围告警。

### 8.5 Git 状态

**未发生任何 git 写操作**。已核验：`git stash list` 为空，`git reflog` 最新仍为 `6ec3fef`，无新 commit / checkout / reset。全部改动留在工作区。

### 8.6 恢复后最终结果（2026-08-21 11:0X，接力自查确认）

**§8.3 阻塞点逐条勘误与清零**：

1. **「`run_task72_hud_layout_tests.gd` 未跑通 / script error cascade」是误判，已订正**。自查重跑 `run_task72_hud_layout_tests.gd`：`PASSED: 8 tests, 72 assertions`，全绿，无脚本错误。真正出现「Invalid access to property or key 'pressed' on a base object of type 'Nil'」脚本错误的是 **`run_task40_drag_compact_hud_tests.gd:132`**（`_test_formal_drag_click_and_authority_recovery`），与本任务无关。已用 `git show`/scratchpad 干净 clone（`6ec3fef`，未打本任务任何补丁）复现同一崩溃、同一 9 条失败，逐字一致，**证实为任务 72 之前已存在的缺陷**（购物界面 `purchase:burning` 按钮查找返回 null），非本次改动引入。
2. **批量 runner 对比已完成**，重跑三次结果一致（`48 files, 8 failed`）。逐文件 diff 见下。
3. **截图已产出**：`docs/agent_tasks/evidence/task72/screenshots/task72_hud_boss_room_1920x1080.png`（1920×1080）。**关键环境事实**：`--headless` 在本机走 `dummy` 渲染驱动，`root.get_texture()` 恒为 null、`RenderingServer.frame_post_draw` 恒不触发——这是 `--headless` 本身的限制，不是脚本 bug（已用最小复现脚本逐层排除：单独 HUD 场景、单独房间场景、二者叠加，均在 `await RenderingServer.frame_post_draw` 处卡死；`texture_2d_get` 报 `Parameter "t" is null`，来自 `dummy` 渲染后端）。任务 61 文档（`61_boss_three_form_implementation.md:347,377`）已记录同一结论并给出解法：截图类脚本一律需要 `--display-driver windows --audio-driver Dummy --resolution 1920x1080`（非 `--headless`）。本次照此改用非 headless 命令跑通 `capture_task72_hud_layout_visuals.gd`：`PASSED: 1 tests, 7 assertions`。`test_batch_runner.gd`／全部 `run_*.gd` 断言验证仍然全程用 `--headless`，未变。
4. **B4 复核完成**：`combat_hud.gd` 内全部 `_margin(...)` / `separation` 调用点已过一遍。仅剩两处有意保留原始字面量，均已加注释说明：
   - `_build_compact_slot` 的 `_margin("Margin", 4, 3)`（combat_hud.gd:1152）——任务书原文点名「本任务不动」。
   - `_build_skill_panel` 的 `_margin("Margin", 10, 6)`（combat_hud.gd:1059）——实测这是**精确匹配**：`SKILL_STRIP_SIZE.y(72) - 2*6 = 60`，恰好等于 `CurrentElement` 实际渲染高度（56 内容 + 其自身 stylebox 2px 边框×2）。改成 `GAP_SM(8)` 会让可用高度跌破 60，触发 `PanelContainer` 向上钳位，`SkillPanel` 被迫长高，直接违反「532×72 不变」与「主动槽位置不动」两条红线。已在代码内加详细注释说明，不属于遗漏。
   其余散值（badge、bar_row、passive_panel、boss_panel、target/feedback/debug_panel、compat 卡片）均已替换为 `UI.GAP_XS/SM/MD` 或保持已是 4 的倍数。

**批量 runner 最终逐文件 diff**（基线 `47 files, 8 failed` → 改后 `48 files, 8 failed`，43 个文件逐字节相同）：

| 文件 | 基线 | 改后 | 归因 |
| --- | --- | --- | --- |
| `run_compact_hud_reward_tests.gd` | 7t/68a/exit0 | 7t/68a/**exit1** | 新增失败，唯一未解决的冲突点，见下 |
| `run_task24_compact_hud_reward_tests.gd` | 10t/237a/exit0 | 10t/237a/**exit1** | 同上，同一根因 |
| `run_task48_dodge_integration.gd` | 5t/56a/exit1 | 5t/56a/**exit0** | 已用干净 clone 复现：同一未改代码两次运行结果不同，**证实为既存 flaky，与本任务无关** |
| `run_task57_full_room_background_collision_tests.gd` | 5t/**157a**/exit1 | 5t/**205a**/exit0 | 同上，干净 clone 里同一未改代码产出 205（与改后一致），**证实为既存 flaky** |
| `run_task72_hud_layout_tests.gd` | 不存在 | 8t/72a/exit0 | 新增回归门禁，全绿 |
| `run_task40_drag_compact_hud_tests.gd` | 4t/75a/exit1 | 4t/75a/exit1（**失败明细新增 4 条**，均为 `passive belt` 尺寸相关） | exit/计数不变；失败明细因 B5 被动条宽度收缩而新增 4 条，其余 9 条与干净 clone 基线逐字相同 |
| 其余 41 个文件 | — | — | 逐字节相同 |

**唯一未解决事项（需用户决策，未擅自扩大 allowlist）**：

`run_compact_hud_reward_tests.gd` 与 `run_task24_compact_hud_reward_tests.gd`（均不在 allowlist、均非既知失败项）各硬编码断言 `passive_rect.size.x >= 496.0`。B5 判据 2 要求「被动条面板总宽 ≤ 技能条面板总宽×0.85 = 452.2」，与 496 的下限**数学互斥**，无法同时满足。已排除所有可通过本任务allowlist内文件解决的路径（含把 `PASSIVE_STRIP_SIZE` 从任务书原表格的 424 修正到 Godot 实际下限之上的 448）。唯一解法是把这两个文件的硬编码断言纳入 allowlist 一并更新，但这需要扩表，按规矩停在这里，留给用户判断：(a) 扩 allowlist 顺手把这两处断言同步到新布局；(b) 保留现状，接受这两个文件从「通过」变「失败」，作为 B5 的已知代价记录在案；(c) 其它方案。

**Git 状态**：全程未发生任何 git 写操作，`git stash list` 为空，`git reflog` 最新仍为 `6ec3fef`，未产生新 commit。
