# Task 94 技能 HUD 层级与状态概念说明

> 状态：**仅概念、尚未实装**。本任务没有修改实现代码、正式资源或测试。

## 最终用户选择

- 用户提供 `C:/Users/heliashi/AppData/Local/Temp/codex-clipboard-a3ae8695-e110-40e5-a9bf-49bf2acf8073.png` 作为主动槽样式参考，并要求直接更新、不再回传来源中枢。
- 最终主动区采用参考图的结构：三个相邻但各自闭合的厚重像素框，每槽保留内层长方形描边，槽间保留紧密的成对阶梯接缝。
- 这一直接用户选择覆盖此前 Review 要求的“统一外框 + 单线分隔”方向；任务卡未改动，本文件记录最终概念证据的实际状态。
- 被动区继续采用用户此前明确选择的右下 `4×1` 横排。

## 参考图角色与工作流

- 原始场景 / edit target 底图：`docs/agent_tasks/evidence/task91/screenshots/01_water_full_same_camera.png`（1920×1080）。
- 当前 Task94 完整图：内置 imagegen 编辑调用的局部 edit target。
- 用户附图：主动三槽结构、比例、外框、内层矩形、键位片与文字布局的 style reference。
- 使用内置 `imagegen` 精确局部编辑流程，未使用 CLI/API fallback。
- 最终 imagegen 原始输出为 1672×941；保存 1920×1080 最近邻归一稿用于追溯。
- 最终以 Task91 原图为底图，只合成主动区、既有调试槽清理区和被动区；已确认的被动 `4×1` 像素直接从上一版复用。
- 两张特写均直接从最终完整图裁切并以最近邻放大，确保像素对应。

## 最终设计规则

### 主动区

- 位于底部中央，横排准确 3 槽，整体矮、厚重、紧凑。
- 三个槽位分别使用独立闭合的阶梯像素外框；每槽内保留一条较细的长方形描边。
- 相邻槽紧密排列，内部接缝表现为参考图中的成对阶梯边。
- 键位片固定在每槽左上，显示 `1/2/3`；`SP N` 固定在槽内右下。
- 槽 1 为正常态：白色斩击图标与 `SP 10`。
- 槽 2 为冷却态：`3.2` 始终居中，`SP 0` 固定右下；动态冷却覆盖层自底向上推进。
- 槽 3 图标区域完全空白，无图标、符号、占位点或幽灵标记，仅保留键位 `3` 和 `SP 8`。

### 被动区

- 位于右下，准确 `4×1` 横排；右下锚点和安全边距固定，仅向左生长。
- 与主动框使用同源中性蓝黑材质，但轮廓更细、亮度更低、视觉层级更弱。
- 被动槽无键位数字、SP、冷却数字或文字。
- 四个样例依次为：内凹虚线空槽、小锁未解锁态、盾牌细亮边响应态、安静已装备态。
- 响应脉冲只改变细边亮度，不缩放、不闪白、不增加徽记。

### 主题与动态层

- 框体固定使用中性蓝黑像素主题，不随水火切换。
- 静态层包括外框、内层描边、键位片、SP 锚点与被动锚点。
- 动态层仅包括主动冷却自底向上擦除、居中读秒以及被动边缘微脉冲。

## 输出

- 完整场景：`task94_skill_hud_hierarchy_states_full_concept_1920x1080.png`（1920×1080）。
- 主动特写：`task94_active_hud_closeup_4x_nearest.png`（2160×568）。
- 被动特写：`task94_passive_4x1_closeup_4x_nearest.png`（1660×464）。
- 状态规则图：`task94_state_rules_1920x1080.png`（1920×1080）。
- 生成追溯：`task94_imagegen_raw.png` 与 `task94_imagegen_raw_normalized_1920x1080.png`。

## 无损合成与像素隔离

- Task91 旧紫色调试槽清理区：`x=800..1119, y=864..933`。
- 主动区合成包围矩形：`x=690..1229, y=918..1059`。
- 被动 `4×1` 合成包围矩形：`x=1420..1834, y=934..1049`。
- 将以上三块区域掩蔽后，Task91 edit target 与最终完整概念图的其余 RGBA 像素 SHA-256 完全相同：
  - edit target：`cde243b33bb9354353429f41b1818f465fbd2c7fd96fa4f50da33c0ed5c5a93e`
  - Task94 final：`cde243b33bb9354353429f41b1818f465fbd2c7fd96fa4f50da33c0ed5c5a93e`
- 掩蔽后差分包围盒为 `None`，即三块允许区域外逐像素完全一致。
- Task91 edit target 全图 RGBA SHA-256：`d19d11aa89689a98b21866366ab310f395a8a908301d7216fd92c7337c30a271`。
- Task94 final 全图 RGBA SHA-256：`e9adb3bd4e3d807d2b4781aa242b762e0bc78908d795536692a38eeca43e76c8`。
- 被动特写 RGBA SHA-256：`2b0a9b386d8ad6f3587f32c7d99603045cae2567b0b32b1efb85f5100c575afd`，与更新前完全相同。

## 最终 imagegen 提示词

```text
Use case: precise-object-edit
Asset type: Task94 pixel-art active skill HUD style replacement
Input images: Image 1 is the current full-scene Task94 concept and the sole edit target. Image 2 is the user's preferred visual reference for the ACTIVE skill slots only.
Primary request: Replace ONLY the bottom-center active skill HUD in Image 1 so it matches Image 2's active-slot structure and proportions as closely as possible.
Required active structure from Image 2:
- exactly three adjacent but individually closed, heavy blue-black stepped pixel frames;
- each slot has its own closed outer stepped frame with visible corner construction;
- each slot also keeps the thin inset rectangular inner border shown in Image 2;
- the three frames touch closely with paired stepped seams between them, matching Image 2;
- key tabs "1", "2", "3" remain at the top-left inside each slot;
- slot 1 has the white slash icon and exact "SP 10";
- slot 2 has exact centered "3.2" and exact "SP 0", retaining the cooldown state;
- slot 3 has a completely blank icon area and exact "SP 8".
Style/medium: crisp hard-edged pixel art, neutral deep blue-black fill, cool cyan highlights and dark outer edge; match Image 2's exact frame-within-frame visual hierarchy and compact dimensions.
Preserve completely unchanged: the lower-right passive 4×1 HUD and its four states; the dungeon scene, characters, top-left HP/SP status HUD, camera, lighting, scale, and all non-active-HUD pixels.
Constraints: Change only the active HUD. Do not use the previous unified single-container frame. Do not remove the inner rectangles. Do not change text, icons, cooldown, passive layout, or scene. No extra labels, ornaments, badges, watermark, or layout shift.
```

## 边界声明

本任务仍只输出概念候选，**仅概念、尚未实装**。Task91–93、代码、正式资源和测试保持只读；没有运行或声称完成实装。按用户要求，本次更新不向来源中枢回传。
