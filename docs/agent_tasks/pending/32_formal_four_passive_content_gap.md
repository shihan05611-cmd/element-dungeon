# 任务 32：补齐正式四被动内容与 Catalog 基线

状态：PENDING
负责人：Growth/Economy Domain Agent 2.0（threadId `019fd201-d2b5-7593-afbd-d73bd1908acf`，hostId `local`；本任务临时授权静态内容与两枚被动图标）
依赖：任务 30 `ACCEPTED`；Task31 已确认 `BLOCKED`；开工基线由中枢提交后补发
回传中枢：Review 5.0，threadId `019fc6c7-85e3-77f0-a99b-9cc9ee6055a2`，hostId `local`

## 1. 目的与唯一方案

Task31 独立前置审计发现正式 catalog 只有两个不同被动 `burning`、`unending`，无法满足最高优先级需求中“四个不同被动同时装备”的正式 RunGame 门禁。Task32 只补齐该内容缺口，不新增权威、Runtime、UI 或新被动机制。

唯一接入方案：

- 正式化 `resources/skills/passive_vitality.tres`：ID `passive_vitality`，显示名“坚韧体魄”，沿用已验证的 `+20` 最大生命被动；
- 正式化 `resources/skills/passive_energy.tres`：ID `passive_energy`，显示名“元素储备”，沿用已验证的 `+10` 最大 SP 被动；
- 为两者新增正式 `SkillContentDefinition`、各自独立且与首批六技能风格一致的透明图标，并加入 `RunContentCatalog`；
- `passive_focus`、`passive_balance`、`water_lance`、`fire_lance` 继续保持旧资源，不进入正式 catalog；
- 两个新正式被动只可购买/拥有/装配，无等级、无免费奖励、无默认装备、无世界 presentation、无 runtime delivery。

正式 catalog 从“固定普通攻击 + 6 个可购买内容（4 主动 + 2 被动）”迁移为“固定普通攻击 + 8 个可购买内容（4 主动 + 4 被动）”。历史免费奖励投影仍保持现有数量与正式 `RunGame` 禁用状态；不得借本任务恢复免费奖励。

## 2. 权威与非目标

本任务只增加静态内容注册和视觉图标，并迁移被该注册数量直接覆盖的接受断言。现有 `StatModifierPassiveEffectDefinition`、`PassiveSkillController`、`RuntimeSkillLoadout`、RunSession 购买/装配事务和 Task30 UI 已具备消费能力，不得修改。

非目标：

- 不新增第三个被动、被动等级、品质、触发分支、叠层、世界 VFX 或新脚本；
- 不平衡六战梦尘/敌群，不提前执行 Task31 两条完整局；
- 不修改 Task28 四被动 Runtime、Task29 流程、Task30 HUD/商店；
- 不重新启用旧奖励、角色成长、属性点或遗物。

## 3. 精确 allowlist

除本节外一律禁止修改。

### 3.1 正式内容与图标

- `resources/content/run_content_catalog.tres`
- `resources/content/skills/passive_vitality_content.tres`（新增）
- `resources/content/skills/passive_energy_content.tres`（新增）
- `assets/generated/vfx/passive_vitality/icon.png`（新增）
- `assets/generated/vfx/passive_vitality/prompt.md`（新增）
- `assets/generated/vfx/passive_vitality/manifest.md`（新增）
- `assets/generated/vfx/passive_energy/icon.png`（新增）
- `assets/generated/vfx/passive_energy/prompt.md`（新增）
- `assets/generated/vfx/passive_energy/manifest.md`（新增）
- `docs/vfx/final_asset_manifest.md`（只追加两枚图标与无世界 VFX 说明）
- `docs/current_gameplay_design_handoff.md`（只更新正式内容表和 catalog 数量）

`resources/skills/passive_vitality.tres` 与 `resources/skills/passive_energy.tres` 是只读依赖，现有数值不得修改。

### 3.2 受影响回归与新增夹具

- `combat/tests/run_skill_content_catalog_tests.gd`（只迁移 catalog 数量、legacy 列表和两项新内容字段断言）
- `growth/tests/run_task27_run_economy_progression_tests.gd`（只迁移正式 shop content 数量和两被动购买字段断言）
- `growth/tests/run_task32_formal_four_passive_content_tests.gd`（新增）
- `combat/tests/capture_task32_formal_four_passive_visual.gd`（新增）
- `docs/agent_tasks/pending/32_formal_four_passive_content_gap.md`
- `docs/agent_tasks/evidence/task32/**`

`docs/agent_tasks/README.md` 与 Task31 任务书由中枢维护，不属于执行者 allowlist。

## 4. 内容合同

两份新 `SkillContentDefinition` 必须满足：

- `skill_id` 与各自现有 gameplay definition 完全一致；
- `display_name`/description 清楚说明严格被动槽与实际效果，不沿用旧“可放主动位置”文案；
- `icon` 指向本任务独立图标，非空、非同图、非现有六技能图标复用；
- `gameplay_definition` 分别指向现有 vitality/energy `.tres`；
- `equippable = true`、`purchase_price > 0`、`allowed_form_ids = [water, fire]`；
- `initially_owned = false`、`default_slot_id` 为空、`reward_pool = false`、`initial_reward_pool = false`；
- `active_progression = null`、`presentation_scene = null`、`runtime_delivery_scene = null`。

Catalog 必须：

- 精确 9 个 gameplay definitions：1 个固定普通攻击 + 8 个可购买内容；
- 精确 8 个 obtainable/shop contents：4 主动 + 4 被动；
- 初始拥有/默认配装继续只有 `element_bolt` 在 A1；
- 历史 reward projection 数量不因两个新内容增加；正式 RunGame 奖励仍禁用；
- `passive_focus`、`passive_balance` 和两把旧 lance 仍无法通过 `content_for` 找到。

## 5. 图标质量门禁

执行者必须先完整读取 `imagegen` skill，再为两枚图标使用内置图像生成工作流或技能允许的等价高质量流程；不得由中枢或普通脚本临时画占位图。沿用 Task17 已接受风格，无需重新向用户选择风格：2D 横版地牢、清晰轮廓、有限色阶、32/64px 可读、无文字/数字/键帽/水印。

- 坚韧体魄：以心形/护甲或生命核心为主轮廓，表达耐久，不冒充治疗触发；
- 元素储备：以容器/晶核/能量储槽为主轮廓，表达 SP 容量，不冒充即时回能；
- 不能只靠红/蓝颜色区分，必须有不同形状；透明背景，最终为与现有 icon 使用方式兼容的正方形 PNG；
- `prompt.md` 记录最终提示词与生成/去背过程，`manifest.md` 记录尺寸、alpha、SHA、来源和用途；
- 以原始尺寸、32×32 和 64×64 实际查看，两图不得混淆、糊成色块或与现有六图近似重复。

两项被动是常驻数值投影，因此本任务不新增世界 VFX；正式 `presentation_scene = null` 是合同，不得为了满足旧 Task16 的通用断言伪造空场景。应精确迁移该断言，使 Burning/Unending 继续有实际 presentation，而 vitality/energy 只要求正式图标。

## 6. 自动化与实际画面

### 6.1 冷副本纪律

1. 开始前固化 `HEAD`、完整 status、allowlist/保护文件 SHA/字节/时间、共享 `.godot` 与全部 sidecar；共享编辑器保持被动，不调用或控制。
2. 创建此前不存在的 `C:\tmp` 冷副本和独立 profile，排除 `.git/.godot/.workbuddy/cache`，逐文件核对；第一条 Godot 命令必须是 4.7.1 headless editor scan。
3. scan、全部 runner、双 smoke、图形 capture 和最终 rescan 都只在该冷副本/profile；正式日志五类错误/警告标记全 0。

### 6.2 Runner 门禁

- 新 Task32 runner 至少覆盖 9/8 catalog 形状、4主动+4被动类型、两新内容字段、非奖励/无等级、购买/余额不足/重复/陈旧、四个不同被动权威装配与跨一次真实房间 rebuild 后各注册一次。
- Task16 与 Task27 被修改 runner 必须只改变本任务直接覆盖的 catalog/content 断言；各自 tests 数保持，assertions 变化需逐项解释。
- 复跑 Task30 接受基线 26 个 runner。加入 Task32 后正式总数预期 `27/27`，tests/assertions 按实际输出精确报告；Task12/18/24 数字不得变化，Task16/27只允许上述内容断言增量。
- Task20 单列运行并继续历史 `BLOCKED`，不得计入 27 个正式 runner。
- `RunGame` 与 `TestRoom` 各 180 帧 smoke，capture 后最终 editor rescan，全部 exit 0。

### 6.3 实际 Viewport

- 使用真实非 headless `RunGame`，通过正式梦尘购买与即时装配事务获得 `burning`、`unending`、`passive_vitality`、`passive_energy`；不能向 Runtime 直接注入或使用 Task28 fixture。
- 至少生成 4 张：1920×1080 商店四被动、1920×1080 战斗 HUD P1–P4、2560×1440 商店四被动、2560×1440 战斗 HUD P1–P4。
- 保存前断言四个唯一正式 skill_id、四次各一次 Runtime 注册、权威拥有/钱包/七槽/revision、图标纹理非空且互异、正式 UI 分区和实际尺寸。
- 执行者逐张原分辨率打开，并另外查看两枚 icon 原图及 32/64px 缩放；报告裁切、透明度、辨识度、文本/图标和 HUD 遮挡。

## 7. 禁止与保护

- 禁止修改任何权威 `.gd`、Runtime/Passive controller、Player/Enemy、RunFlow、HUD/Overlay、场景、房间、VFX runtime、`project.godot` 或 Task31 游戏范围。
- 禁止修改 `resources/skills/passive_vitality.tres`、`passive_energy.tres` 的数值，禁止把 focus/balance 一并注册。
- 禁止重复技能填槽、直接写钱包/owned/loadout/revision、mock 正式 catalog、恢复免费奖励或降低四被动门禁。
- 不修改任务20或任务27～31历史 evidence；Task31 当前 BLOCKED 记录保持。
- 不删除/认领共享 `.godot`、`.gd.uid`、`.import`、`.workbuddy` 或无关文档。
- 不使用子 Agent；不执行任何 Git 写操作；不 push。

## 8. 交付与自动回传

Evidence README 必须给出：修改文件字节/SHA、两新内容完整字段、catalog 迁移表、两旧 runner 精确断言变化、新 Task32 与全部回归数字、scan/双 smoke/capture/rescan、4张正式 Viewport、两图标 QA、共享保护、风险和 Git 零写入。

开工置 `IN_PROGRESS`；全部通过只置 `REVIEW` 并冻结，不得自行 `ACCEPTED`。若旧 gameplay definition、正式商店或 UI 无法无代码修改地消费两项新内容，立即 `BLOCKED` 并回传，不能扩大 allowlist。

完成或阻塞后必须直接调用 `send_message_to_thread` 回传中枢 Review 5.0：threadId `019fc6c7-85e3-77f0-a99b-9cc9ee6055a2`，hostId `local`；不要等待用户转述。回传后保持冻结，中枢将自动启动另一全新冷副本独立验收。
