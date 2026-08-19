# 任务 60：三形态 Boss、弹体与感叹号正式美术

状态：ACCEPTED（2026-08-18 独立 L2 Review 验收通过，中枢按用户授权归档）
负责人：待指派（美术职责对话）
依赖：无
Git 基线：`main` HEAD `09057fe`
Execution Model：由用户指定为 Sonnet（用户明确覆盖 `docs/agent_tasks/README.md:11` 的 `gpt-5.6-sol` 默认值）
Execution Thinking：medium
Review Level：L2
Review Model：与执行者隔离的独立 Review 职责对话
Review Thinking：high

升级触发：素材许可条款与用户声明不一致、无法在目标逻辑尺寸稳定产出三形态、必须使用非整数世界缩放、三形态无法共用锚点/基线、或输出会覆盖/删除既有正式资产时，立即冻结为 `BLOCKED`；不得自行改方案或接线。

## 1. 玩家可观察目标

1. Boss 拥有**三套可一眼区分的形态立绘**：熔炽（火）、潮涌（水）、普通（无元素）；三形态共用骨架与基线，切换时不产生位移跳变。
2. 敌人弹体（Boss 三形态弹 + 小怪弹）替换为符合项目像素规范的正式资产，取代当前程序合成的弹体。
3. 黄色感叹号预警图标可用于所有敌人，在任何背景上均清晰可读。

## 2. 不可妥协约束

- 本任务**只交付美术资产**，不做任何工程接线：不创建或修改 `.tscn`、`.tres`、`.gd`、`project.godot`、`.import`。
- 所有运行图片使用**整数逻辑画布**、Nearest、无 mipmap；**严禁**把高分辨率母版小数缩放后冒充最终资产（`docs/art/像素美术规范_v1.md:35`）。
- 三形态必须**共用画布、锚点、基线**（规范 §2.2 末条、§9）。
- 火/水形态相对普通形态必须有**结构性差异**，不得只做色相替换（规范 `:90` 对远程怪的同类要求）。
- 不生成备选风格；沿用用户已确认的素材方向。
- 不删除、覆盖或修改任何既有正式资产。

## 3. 权威只读输入

1. `docs/art/像素美术规范_v1.md`（**§9 验收清单 12 项为硬门禁**）
2. `assets/characters/cat/**`（「同角色 → 元素变体」的既有先例，见 §5.1）
3. `assets/generated/vfx/boss_arc_projectile/prompt.md`、`manifest.md`（项目自有的成功提示词模板与 manifest 格式）
4. `assets/generated/vfx/_licensed_source/bdragon1727/LICENSE_PROVENANCE.md`（provenance 文件格式范本）
5. `assets/world/enemies/tidal_sentry/tidal_sentry_idle_v1.png` 与其 manifest（同屏尺度参考）
6. `scenes/player.tscn`、`scenes/enemy.tscn` 及其纹理（只读，用于尺度/颗粒/轮廓对齐）
7. `docs/agent_tasks/completed/53_tidal_tiles_interactables_and_ranged_enemy_art.md:145`（现有整数倍基线：玩家 `2×`、普通敌人 `3×`、潮汐哨兵 `3×`）
8. 外部素材源目录（只读，见 §4）

## 4. 素材来源与许可

来源目录（用户声明为 itch 购买、已取得许可）：

```
C:\Users\heliashi\Desktop\游戏资产\Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A
```

已确认内容（`Characters(100x100 split)\Blood Monster_A\Blood Monster_A\`）：

| 文件 | 字节 |
|---|---:|
| `Blood Monster_A_Idle.png` | 1,104 |
| `Blood Monster_A_Walk.png` | 1,455 |
| `Blood Monster_A_Attack01.png` | 1,940 |
| `Blood Monster_A_Attack02.png` | 1,949 |
| `Blood Monster_A_Hurt.png` | 1,501 |
| `Blood Monster_A_Death.png` | 1,228 |
| `Blood Monster_A.png`（合图） | 8,914 |

另有 `Blood Monster_A with shadows\` 同名一套、以及 `Blood Monster_A.aseprite` 源文件（12,166 字节）。

**第一步必须产出** `assets/world/enemies/tide_ember_sovereign/LICENSE_PROVENANCE.md`，格式对齐 `assets/generated/vfx/_licensed_source/bdragon1727/LICENSE_PROVENANCE.md`，内容须含：作者/发行者、itch 页面 URL、许可条款摘要（是否允许修改、商用、再分发）、购买与授权确认、原始文件 SHA-256 清单。**若条款禁止修改衍生，立即 `BLOCKED`。**

**选用建议**：使用**不含投影**的版本（`Blood Monster_A\Blood Monster_A\`）。规范 §4.3 要求接地阴影按地面层级决定是否拆层（`docs/art/像素美术规范_v1.md:87-90`），素材自带投影会与房间地面冲突。

## 5. 资产合同

### 5.1 沿用「猫主角」既有先例

`assets/characters/cat/` 已有成熟的「同角色 → 元素变体」模式：

```
cat_idle / cat_water_idle / cat_fire_idle
cat_walk / cat_water_walk / cat_fire_walk
cat_attack / cat_water_attack / cat_fire_attack
cat_hurt          ← 注意：hurt 无元素变体
```

**Boss 沿用同一策略**：普通形态即原始 Blood Monster 配色（对应猫的 base 版本），火/水形态为其元素变体；`hurt` 与 `death` 使用共享中性版本。总计 **11 套**（base 3 + 火 3 + 水 3 + hurt/death 2），其中实际新绘制量为 **6 套元素变体**。

### 5.2 像素规范要点

- **§9 验收清单全部 12 项**逐项自检并写入 manifest；
- §4.1 描边分域（`:74`）：火形态深棕紫、水形态深蓝黑、普通形态沿用中性深色；
- §4.2 统一左上光源；主高光只保留一簇，面积不超过主体可见面积的 10%；
- §3.3 每种材质仅暗面/主面/高光三档，整体不超过 5 个主要明度层；
- §2.2 只允许 `1× / 2× / 3× / 4×` 整数缩放；
- 火/水形态的结构性差异建议方向：火形态裂纹外露、水形态轮廓柔化与滴落。**必须能在去色后的剪影上区分**。

### 5.3 尺寸与缩放

- 源素材 `100×100`，与项目「普通敌人 100×100」基准一致（规范 `:25`）。
- Boss 需要更大的存在感。**现有 Boss 的「大」是代码伪造的**——`scripts/enemy.gd:226-242` 用运行时 1.7 倍缩放 + 紫描边 shader 实现。本任务须交付**真实更大的逻辑画布**（建议 `160×160` 或 `200×200`），并在 manifest 写明推荐整数显示倍数。
- 三形态必须共用画布、锚点、基线，并提供逐帧锚点对照图。

### 5.4 弹体美术

需交付：Boss 火弹、Boss 水弹、Boss 普通形态弹（中性色）、小怪（潮汐哨兵）弹、命中特效（建议 3~4 帧）。

**已验证可行**：中枢已按项目自有的成功提示词模板（`assets/generated/vfx/boss_arc_projectile/prompt.md`）生成过火/水弹样品，一次通过规范自检 9/10 项（水弹尾鳍偏碎为唯一瑕疵），位于 `assets/art_preview/projectile_candidates_preview/`（标注 PREVIEW ONLY、未去背、未接入）。执行者可参考其提示词结构，但**必须重新生成正式资产**，并完成：色键去背（含 despill 与 edge-contract）、整数缩放、目标尺寸手工像素清理、四色背景可读性检查。

**纹理基准朝向统一为 Right-facing**（现有资产是 Left-facing，见 `assets/generated/vfx/boss_arc_projectile/manifest.md:5`），以匹配 `Vector2.RIGHT` 默认方向，减少任务 59/61 的代码侧修正。manifest **必须明确声明朝向**。

### 5.5 感叹号预警图标

死亡细胞风格的黄色感叹号：

- `32×32` 逻辑画布（规范 §2.1 图标基准 `:29`），须在 32px 下通过剪影检查；
- **世界层资产，非 UI 图标** → 遵守 §8「不允许把高精度 UI 图标直接缩小后作为世界物件」（`:173`），颗粒度须与角色一致；
- 高饱和黄 + 深色描边；**必须在暗色、水色、火色、紫色四种背景上都清晰可读**（预警的可读性优先级最高）；
- 提供 2~3 帧轻微弹跳序列供非 reduced-motion 播放，另提供单帧静态版用于 reduced-motion 降级。

## 6. 精确输出 allowlist

```
assets/world/enemies/tide_ember_sovereign/
    LICENSE_PROVENANCE.md
    manifest_v1.md
    boss_plain_idle_v1.png / boss_plain_walk_v1.png / boss_plain_attack_v1.png
    boss_ember_idle_v1.png / boss_ember_walk_v1.png / boss_ember_attack_v1.png
    boss_tide_idle_v1.png  / boss_tide_walk_v1.png  / boss_tide_attack_v1.png
    boss_hurt_v1.png / boss_death_v1.png
assets/world/projectiles/
    manifest_v1.md
    boss_ember_bolt_v1.png / boss_tide_bolt_v1.png / boss_plain_bolt_v1.png
    sentry_tide_bolt_v1.png
    bolt_impact_v1.png（或分帧）
assets/world/ui_world/telegraph/
    manifest_v1.md
    telegraph_alert_v1.png（+ 可选弹跳帧）
docs/agent_tasks/pending/60_boss_projectile_and_telegraph_art.md
docs/agent_tasks/evidence/task60/**
```

除上述范围外全部只读。不得创建或修改 `.import`；隔离验证意外生成的 sidecar 只能留在隔离输出，不得回流共享项目。

## 7. L2 执行与验收门禁

执行侧至少交付：

1. 全部正式 PNG 的尺寸、模式、SHA-256、alpha bbox/coverage、partial-alpha 像素数；
2. **三形态共用锚点/基线的逐像素对照图**；
3. 原尺寸 + 推荐整数倍（`2×/3×`）Nearest QA 图；
4. 暗色/水色/火色/紫色四背景的轮廓可读性对照（**感叹号必须单独做这一项**）；
5. 与玩家 `2×`、普通敌人 `3×`、潮汐哨兵 `3×` 同屏的尺度复核图（标记为 QA，不冒充游戏截图）；
6. 火/水形态相对普通形态的**结构性差异证明**：并排对照 + 去色后剪影仍可区分；
7. 规范 §9 全部 12 项的逐条自检结论；
8. 全库扫描证明任何 `.tscn` / `.tres` / `.gd` / `project.godot` 对本任务新资产的引用仍为 0；
9. 原始素材包 SHA-256 与 provenance 记录一致（证明只读、未修改源素材）；
10. 本任务输出 `.import` 为 0；
11. Git 写操作为 0。

独立 L2 Review 复算尺寸、哈希、alpha、锚点对照与四色可读性，并在原尺寸下检查运行 PNG 与 QA 图。若像素资产无法由现有工具可靠验收，输出 `ESCALATE`，不降低门禁。

## 8. 保护项与禁止事项

- 用户独立 `global_instakill`：`project.godot`、`scripts/player.gd`、对应 runner/UID 与 `tmp/codex-global-instakill-validation-20260813/` 原样保护，不读取、不运行、不修改、不认领。
- 不修改 `assets/art_preview/**` 的冻结母版与色键源（宝箱 / 传送门 v2、瓦片、场景预览）。
- 不修改既有正式资产：宝箱、传送门、潮汐哨兵立绘、96 个既有 VFX import。
- 不恢复已退役的 `assets/generated/vfx/run_reward_chest/**` 与 `run_route_portal/**`（`docs/art/像素美术规范_v1.md:201`）。
- 不删除现有 `assets/generated/vfx/boss_arc_projectile/**`（退役决定由任务 61 负责）。
- 不修改 `tmp/**` 历史冷副本。
- 不使用子 Agent 修改项目文件（`docs/agent_tasks/README.md:55`）。
- 不执行 `git add/commit/push/reset/restore/checkout/clean/stash`。
- 不自行 `ACCEPTED`；完成后只更新为 `REVIEW` 并冻结，等待中枢派独立 Review。

## 9. 协调记录

- 2026-08-17 中枢立项。本任务与任务 59（工程）无文件重叠，可并行派发。
- 本任务是任务 61（三形态 Boss 实现）的美术前置；任务 61 不得在本任务 `ACCEPTED` 前消费尚未冻结的运行文件。
- 用户已确认素材为 itch 购买并取得许可；provenance 文件仍须按 §4 建立，作为可追溯记录。
- 2026-08-18 执行记录：本会话无 `image_gen` 等图像生成工具，经与用户确认后改为 Python + Pillow 程序化像素处理管线（脚本见 `docs/agent_tasks/evidence/task60/gen_boss.py`、`gen_projectiles.py`）。素材目录内未找到 README/LICENSE/URL 文件，许可条款摘要（允许修改衍生 / 仅限非商用 / 不允许再分发）经用户在对话中口头明确确认后记录于 `LICENSE_PROVENANCE.md`，未触发 BLOCKED。

## 10. 完成方式与最终交付说明

- Boss 三形态（普通/熔炽/潮涌）11 张立绘：源自 itch 购买素材 `Blood Monster_A` 的固定坐标窗口裁切 + 整数 4× 放大 + 调色板重映射像素级重绘；熔炽新增裂纹亮色像素簇、潮涌新增轮廓柔化环与悬垂水滴像素，构成非色相替换的结构性差异（并排 + 去色剪影证明见证据 05）。三形态共用 200×200 画布、固定锚点与基线（证据 02/02b）。
- 弹体×4（熔炽/潮涌/普通/哨兵）与命中特效（4 帧）：原创几何像素绘制，统一 Right-facing 朝向，色键无关（直接程序化透明背景 + 硬边 alpha）。
- 黄色感叹号预警图标：32×32 世界层资产，3 帧弹跳 + 1 帧静态降级版，暗/水/火/紫四背景独立验证可读（证据 08）。
- 与玩家 2×/普通敌人 3×/潮汐哨兵 3× 同屏尺度复核见证据 10，证明 Boss 在真实尺寸资产下具备远超普通敌人的存在感，可替代 `scripts/enemy.gd:226-242` 的运行时伪缩放（本任务未修改该文件，交由 Task61 接线）。
- 规范 §9 全部 12 项自检见 `docs/agent_tasks/evidence/task60/spec_checklist_self_review.md`，全部通过。
- 全库引用扫描=0、`.import` 产出=0、Git 写操作=0、源素材 SHA-256 全程未变，见 `docs/agent_tasks/evidence/task60/reference_scan_and_git_ops.md`。
- 输出严格限于任务书 §6 allowlist，未触碰任何既有正式资产、`art_preview` 冻结母版或保护文件。

TASK 60 | REVIEW | FROZEN | 三形态 Boss（普通/熔炽/潮涌）11 张立绘、4 弹体、命中特效、黄色感叹号预警全部交付并通过规范 §9 十二项自检，等待独立 L2 Review | DETAILS_IN_TASKBOOK

## 11. 独立 L2 Review 与中枢归档（2026-08-18）

Result：**PASS**。Review Level `L2`，由与执行者隔离的独立 Review 职责对话执行。

### 11.1 验收记录说明（留档口径）

用户于 2026-08-18 确认本任务已经过独立 Review Agent 验收并通过，并为节省上下文窗口**未逐项转述 Review 结论正文**，授权中枢直接标记 `ACCEPTED`。

因此本节**不复制** Review 的 `Reviewed Scope` / `Reproduced` / `Reused Evidence` 明细。与任务 59 §12（完整逐条留档）相比，本任务的验收明细只存在于该 Review 对话中，未进入任务书。后续复盘若需要核对本任务的具体复算项，须回溯该 Review 对话，或依据 §10 与 `docs/agent_tasks/evidence/task60/**` 的执行侧证据重新独立复核。此差异为记录完整度差异，不改变 `ACCEPTED` 的效力。

### 11.2 接受依据（执行侧冻结事实，见 §10 与证据目录）

- Boss 三形态（普通 / 熔炽 / 潮涌）11 张立绘：源自 itch 购买素材 `Blood Monster_A` 的固定坐标窗口裁切 + 整数 `4×` 放大 + 调色板重映射像素级重绘；熔炽新增裂纹亮色像素簇、潮涌新增轮廓柔化环与悬垂水滴像素，构成**非色相替换的结构性差异**（并排 + 去色剪影证明见证据 05），满足 `docs/art/像素美术规范_v1.md:90` 的硬要求；
- 三形态共用 `200×200` 画布、固定锚点与基线（证据 02 / 02b）；
- 弹体 ×4（熔炽 / 潮涌 / 普通 / 哨兵）与命中特效 4 帧：原创几何像素绘制，**统一 Right-facing 朝向**，程序化透明背景 + 硬边 alpha；
- 黄色感叹号预警图标：`32×32` 世界层资产，3 帧弹跳 + 1 帧静态降级版，暗 / 水 / 火 / 紫四背景独立验证可读（证据 08）；
- 同屏尺度复核（玩家 `2×` / 普通敌人 `3×` / 潮汐哨兵 `3×`）见证据 10；
- 规范 §9 全部 12 项自检通过（`evidence/task60/spec_checklist_self_review.md`）；
- 全库引用扫描 = 0、`.import` 产出 = 0、Git 写操作 = 0、源素材 SHA-256 全程未变（`evidence/task60/reference_scan_and_git_ops.md`）；
- 输出严格限于 §6 allowlist，未触碰既有正式资产、`art_preview` 冻结母版或保护文件。

### 11.3 已记录的执行过程偏离（均已接受）

1. **生成方式偏离**：执行会话无 `image_gen` 工具，经与用户确认后改用 Python + Pillow 程序化像素处理管线（`evidence/task60/gen_boss.py`、`gen_projectiles.py`）。与项目既有的「内置 `image_gen` + 色键去背」流程不同，但产出满足全部规范门禁，且脚本可追溯、可复现。
2. **许可条款来源偏离**：素材目录内未找到 README / LICENSE / URL 文件，条款摘要经用户在对话中口头明确确认后记录于 `LICENSE_PROVENANCE.md`，未触发 `BLOCKED`。

### 11.4 残余风险与对下游的约束

1. **许可为「允许修改衍生 / 仅限非商用 / 不允许再分发」**。这与既有先例 `assets/generated/vfx/_licensed_source/bdragon1727/LICENSE_PROVENANCE.md` 的约束同级。**若项目将来转为商用或公开发布仓库，本目录资产与 bdragon1727 目录必须一并重新审查授权**。该风险不阻塞本次验收，但应在版本发布检查点复核。
2. **Boss 真实尺寸资产已就位，但接线未做**：`200×200` 立绘可替代 `scripts/enemy.gd:226-242` 的运行时 1.7 倍伪缩放 + 紫描边 shader。本任务未修改该文件，**退役伪缩放与接入真实立绘由任务 61 负责**。
3. 感叹号正式资产已交付，任务 59 的纯文字 `Label` 占位应由任务 61 在接线时替换。

### 11.5 中枢归档决定

- 状态置为 `ACCEPTED`，文档移入 `docs/agent_tasks/completed/`；
- **任务 61 的两项前置依赖（任务 59、任务 60）现已全部满足，可以派发**；
- Git 检查点由中枢在后续阶段性提交时统一处理；本次归档未执行任何 Git 写操作。
