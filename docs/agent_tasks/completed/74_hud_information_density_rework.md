# 任务 74：HUD 信息密度重构

- **状态**：`DONE`
- **Review Level**：`L2`
- **依赖**：任务 72 已完成（改动在工作区，未提交）。**本任务必须排在任务 73 之前** —— 理由见 §0.2。
- **Git 基线**：`6ec3fef`，分支 `boss/task68-69-multiframe-and-timing`；任务 72 的改动尚未提交，本任务在其之上继续
- **权威依据**：`docs/art/像素美术规范_v1.md` §8.2「HUD 信息密度原则」（本任务的设计准则来源）

## 0.1 用户决定（已冻结）

1. **被动槽删除全部文字与 `P` 角标**，尺寸缩减 **≥70%**。空槽由留空表达，被动身份由分区位置表达。
2. **未生效用图标灰度表达**，不用文字。
3. **元素枢纽移到左上角状态区**，且**不带 `E` 键位提示** —— `E` 是整局不变的高频键，依赖肌肉记忆。
4. **状态栏数值内嵌进进度条**，腾出的横向空间用于承载当前元素。
5. **主动槽删除技能等级**（改 hover 展示）**与元素标识**（`Policy`）。
6. **技能槽保留键位号** —— 槽位与按键的绑定随配装变动，必须标注。
7. **修复技能等级 bug**：升级后仍显示 `Lv.1`。

## 0.2 为什么必须排在任务 73 之前

任务 73 的 F5 是「把被动槽 `Name`/`State` 归入 10px 字号，据此把槽高压到 32」。
本任务**直接删除这两个 Label**，F5 因此失去对象。

先做 73 等于为即将删除的元素做字号归一，是纯浪费。正确顺序是 **72 → 74 → 73**：
先由本任务定下槽位最终形态，73 再为真正剩余的文字（房间标题、Boss 名、HP/SP 数值）铺字体阶梯。

**执行本任务时，同步把 73 的 F5 整节标记作废**（在 `73_pixel_font_and_hud_theme.md` 的 F5 标题下加一行删除线说明即可，不要删除历史记录）。

## 0. 阅读方式

这是一次**信息架构删减**，不是排版调整。核心判断标准只有一句：**视觉已经表达的信息，不再用文字重复占用空间**。

与任务 72 / 73 最大的不同：**本任务必须修改 HUD 节点树结构**（删除子节点）。72 / 73 明令禁止这么做，本任务显式解除该约束 —— 但代价是会砸中一批既有测试断言，§1.3 已逐条列出，必须全部处理。

---

## 1. 背景事实（已验证）

### 1.1 槽位是主动/被动共用一个构建函数

`_build_compact_slot(slot_id)`（`scripts/combat_hud.gd:1086`）已全程按 `passive` 分叉，主动/被动各有一套数值。当前子节点：

| 子节点 | 主动 | 被动 | 本任务处置 |
| --- | --- | --- | --- |
| `Icon` | 32×32 | 26×26 | 保留（唯一的核心载体） |
| `CooldownMask` / `CooldownLabel` | 可见 | 可见 | 保留 |
| `Key`（含 `Text`） | 键位号 | 键位号 | 主动保留；被动删除 |
| `PassiveMark`（`P`） | 隐藏 | 可见 | **删除** |
| `Name` | 技能名 | 技能名 | **删除** |
| `Level` | `Lv.N` | `visible=false` | **删除**（改 hover） |
| `Cost` | `SP N` | `visible=false` | 主动保留 |
| `State` | 可用性文字 | `空`/`生效` | **删除**，改灰度表达 |
| `Policy` | `◆水`/`●火`/`○无` | `visible=false` | **删除** |

任务 72 已把 `PASSIVE_SLOT_SIZE` 缩到 `(96,42)`，`ACTIVE_SLOT_SIZE` 保持 `(132,54)`。

### 1.2 `Policy` 承载的语义，删除前必须有替代

`_policy_glyph()`（`combat_hud.gd:801`）有三种取值：

- `EXCLUSIVE_ELEMENT` → `●水`：该技能**只能**在特定元素下施放
- `CURRENT_ELEMENT` → `◆水`：跟随当前元素
- `NEUTRAL` → `○无`：中性

删除 `Policy` 后，「因元素不匹配而不可用」这一状态必须由 **0.1.2 的灰度表达覆盖**，否则玩家在切换元素后无法判断某技能为何用不了。这是本任务唯一有功能性风险的删除项。

### 1.3 受影响的既有测试断言（必须全部处理）

**元素枢纽移位会砸中的硬编码路径**（仅 3 处）：

- `run_compact_hud_reward_tests.gd:101` — 断言 `SlotRow.get_child_count() == 4`（CurrentElement + A1–A3），移走后为 3
- `run_compact_hud_reward_tests.gd:107` — `Root/SkillPanel/Margin/Skills/SlotRow/CurrentElement/Body/ElementShape`
- `run_compact_hud_reward_tests.gd:108` — 同上的 `ElementText`

> **关键降险点**：`element_pivot_panel()`（`combat_hud.gd:223`）是公开方法，`capture_task30_run_ui_visuals.gd` 的 179 / 399 / 405 / 452–454 全部经由它访问，**不含硬编码父路径**。因此只要**保留该方法、保留 `Body/ElementShape` 与 `Body/ElementText` 子结构，只改挂载父容器**，这些取证断言就不会失效。不要借重构之机重写元素枢纽内部。

**删除 `State` 会砸中**：`capture_task30_run_ui_visuals.gd:421`、`capture_task40_drag_compact_hud_visuals.gd:128`、`run_compact_hud_reward_tests.gd:114`

**删除 `Level` 会砸中**：`capture_task32_formal_four_passive_visual.gd:180`（断言被动槽 `Level` 不可见；节点删除后 `get_node` 返回 null，`.visible` 将报错）

**不受影响、不要动**：`run_hud_loadout_feedback_tests.gd:153` 读的是 `Margin/Box/Content/Text/Policy`，属于 task12 遗留的**兼容层槽位**（`_build_hud_slot`），与 compact slot 无关。

### 1.4 技能等级 bug 的既有线索

`_skill_level()`（`combat_hud.gd:636`）实现本身正确，从 `_host.run_session.snapshot().skills.progress_for(skill_id)` 读取。写入点仅 `combat_hud.gd:593`，只在 `_refresh_slot_view()` 内执行。

**主要嫌疑**：HUD 未连接任何技能升级 / 等级变化信号，升级后无人触发刷新，标签停留在上次刷新时的值。
**次要嫌疑**：`progress.is_active()` 为 false 时 fallback 返回 1。

执行者需自行确认真因，不要凭上述猜测直接改。

---

## 2. 改动需求

### D1 — 被动槽降为纯图标

删除 `Name`、`State`、`PassiveMark`、`Level`、`Cost`、`Policy`、`Key` 全部子节点及其在 `_slot_views` 字典中的键（被动侧）。保留 `Icon` 与冷却相关节点。

**判据**：被动槽面积 ≤ 任务 72 交付值（96×42 = 4032）的 **30%**，即 ≤ 1210 px²（如 34×34 = 1156）。

### D2 — 状态用灰度表达

技能不可用（含元素不匹配、能量不足、冷却中）时，`Icon` 降饱和至灰度；可用时恢复。主动槽与被动槽统一适用。

冷却仍保留 `CooldownMask` 扫描与数字叠加，数字叠在图标上、不另占位置。

**判据**：§1.2 的「元素不匹配」状态在无 `Policy` 文字的情况下仍可辨识。

### D3 — 元素枢纽移入状态区

把 `CurrentElement` 从 `SkillPanel` 的 `SlotRow` 移到左上角状态区（`StatusPanel` 内或与之同区）。

- **保留** `element_pivot_panel()` 方法与 `Body/ElementShape`、`Body/ElementText` 子结构（理由见 §1.3）
- **删除** 其中的 `E` 键位提示文案
- 同步修正 §1.3 列出的 3 处硬编码路径断言

### D4 — 状态栏数值内嵌

`HealthValue` / `EnergyValue` 从进度条右侧移入条内部叠加显示，回收其 `custom_minimum_size.x = 68` 的横向占位，用于承载 D3 移入的元素枢纽。

`_bar_row()`（`combat_hud.gd:982`）是 HP/SP 共用的构建函数，一处改动即可。

### D5 — 主动槽精简

删除 `Level` 与 `Policy` 子节点。保留 `Icon`、`Key`、`Cost`、冷却节点。

技能等级改为 **hover 时展示**（可用 `tooltip_text` 或按需构建的浮层，实现方式执行者自定）。

**判据**：主动槽面积较任务 72 交付值（132×54）有可观缩减，具体数值由内容决定，不预设。

### D6 — 修复技能等级 bug

按 §1.4 的线索定位真因并修复，使技能升级后 HUD（hover 展示处）显示正确等级。

**判据**：新增测试覆盖「升级后读到的等级 = 实际等级」，且该测试在修复前会失败。

---

## 3. Allowlist

- `scripts/combat_hud.gd`
- `scripts/ui/combat_ui_tokens.gd` — 允许新增灰度 / 失效态相关 token，**不得修改已有颜色 token 的值**
- `combat/tests/run_compact_hud_reward_tests.gd`、`combat/tests/capture_task30_run_ui_visuals.gd`、`combat/tests/capture_task32_formal_four_passive_visual.gd`、`combat/tests/capture_task40_drag_compact_hud_visuals.gd` — **仅允许同步 §1.3 列出的失效断言**
- `combat/tests/run_task72_hud_layout_tests.gd` — 仅允许同步因槽位尺寸变化而失效的 B5 比值断言
- 新增 `combat/tests/run_task74_hud_density_tests.gd`（+ 其 `.uid`）
- 新增 `combat/tests/capture_task74_hud_density_visuals.gd`（+ 其 `.uid`）
- 新增 `docs/agent_tasks/evidence/task74/`
- `docs/agent_tasks/pending/73_pixel_font_and_hud_theme.md` — **仅允许**按 §0.2 标记 F5 作废
- 本任务书（追加 §6）

**仅此。** 若需扩表，停下来报告。

---

## 4. 禁止项

- **不改任何战斗、成长、掉落、Boss 逻辑**。D6 修 bug 时若真因在 HUD 之外（如 run_session 未发信号），**停下来报告**，不要擅自改动权威层。
- **不换字体、不建 Theme 资源、不改已有颜色 token 的值** —— 属于任务 73。
- **不动 task12 兼容层槽位**（`_build_hud_slot`、`Margin/Box/Content/Text/*` 路径）。
- **不重写元素枢纽内部结构**，只改挂载位置（理由见 §1.3）。
- 不改任务 72 已定的顶层面板锚点与安全边距（`StatusPanel` 因 D4 内容变化而调整尺寸除外）。
- 不做任何 git 写操作。不自行标记 `ACCEPTED`。
- 不碰工作区中属于他人的改动：44 个 `.tres` 的 uid 变化（Godot 自动生成）、`docs/_discarded/` 与中枢规则文档批（另一进程）、房间场景里的碰撞体尺寸变化（**用户本人所改，已确认保留**）。

---

## 5. 验收

### 5.1 通过标准

1. 改动前存基线，改动后重跑批量 runner：
   ```bash
   <godot> --headless --path . --script res://combat/tests/test_batch_runner.gd
   ```
   除 §1.3 列出的、已在 allowlist 内同步的断言外，其余文件的测试数 / 断言数 / exit code 与基线逐一相同。
   > 已知既存失败项（与本任务无关，**不要修**）：task30 / task31 / task32 / task40，以及 task48 / task57 的 flaky。

2. `run_task72_hud_layout_tests.gd` 除 B5 比值断言外继续全绿 —— 面板不重叠、安全边距、路径存在性等仍是有效门禁。

3. `run_task74_hud_density_tests.gd` 断言：
   - D1 判据：被动槽面积 ≤ 1210 px²
   - 被动槽内已无 `Name` / `State` / `PassiveMark` / `Level` / `Policy` 节点
   - 主动槽内已无 `Level` / `Policy` 节点
   - D2：不可用状态下 `Icon` 处于灰度
   - D3：`element_pivot_panel()` 仍可解析，`Body/ElementShape` 与 `Body/ElementText` 仍存在，且其父容器已不是 `SlotRow`
   - D6：升级后读到的等级 = 实际等级（**该断言在修复前必须先复现失败**）

4. `git status` 改动集合 ⊆ §3 allowlist（扣除 §4 末列出的他人改动）。

### 5.2 视觉证据

存入 `docs/agent_tasks/evidence/task74/screenshots/`：

1. **1920×1080 Boss 战全 HUD**，与 `evidence/task72/screenshots/task72_hud_boss_room_1920x1080.png` 同机位对比；
2. **配装区 4 倍特写**：被动条与技能条并排，确认被动条已大幅收缩且层级明确；
3. **灰度状态对照**：同一技能在可用 / 不可用（元素不匹配）两种状态下的图标对比，验证 D2 覆盖了 §1.2 的功能性风险。

---

## 6. 交付（执行者填写）

- 各槽位改动前后的尺寸与子节点对照表
- D1 面积判据实测值
- D2 灰度方案说明，以及「元素不匹配」状态的可辨识性论证
- D3 元素枢纽移位后的挂载路径，及 3 处硬编码断言的同步结果
- D6 的**真因**（不是猜测）、修复方式、以及修复前失败 / 修复后通过的测试证据
- 基线 vs 改后的逐文件数字表，差异逐条归因
- 73 的 F5 作废标记确认
- Allowlist 对账
- Git 写操作为零的声明
- 发现但未做的事项
