# Task 92 静态技能 HUD 概念说明

> 状态：仅概念、尚未实装。等待用户确认后，才能另立实装任务。

## 参考图与工作流

- 参考图：`docs/agent_tasks/evidence/task91/screenshots/01_water_full_same_camera.png`（1920×1080）。
- 参考图角色：内置 imagegen 精确编辑的 **edit target / structural reference**；用于锁定同场景、同机位、Task91 状态栏语言与底部中央槽位位置。
- 工作流：内置 `imagegen`（built-in image generation/editing），未使用 CLI/API fallback。
- 内置输出先保存在 `task92_imagegen_raw_1672x941.png`，再用最近邻归一到 1920×1080。为避免模型重画游戏画面，最终稿以 Task91 原图为底，仅在底部技能 HUD 的阶梯轮廓区域合成生成结果；替换区域外沿用 Task91 原图像素。
- `task92_static_skill_hud_closeup_4x_nearest.png` 由最终 1920×1080 概念图裁切后以 4×最近邻放大，未使用平滑插值。

## 设计说明

- **主动 / 被动层级**：上排 4 个被动槽更薄、更轻，仅保留纯图标空间；下排 3 个主动槽更厚重，固定承载左上键位 `1/2/3`、主体图标区与底部 `SP N`。两排由共享肩部和底板连接成一个紧凑轮廓，不再像两块分离的调试框。
- **固定装饰**：深蓝黑底、硬边阶梯像素构造、冷青内亮边与低饱和蓝灰外亮边，配少量暗纹和结构分隔。没有水滴、火苗、波纹、余烬或元素徽记。
- **动态内容区域**：被动槽保留图标 / 空槽；主动槽分别保留图标、键位、SP 消耗、冷却遮罩与数字、禁用灰度、空槽。概念中展示了填充、空槽与 `3.2` 冷却态，以验证可读空间。
- **无需水火双版本**：元素差异属于动态技能图标与状态信息，框体本身只承担布局、层级和可读性。中性固定框体可避免水火切换时整块 HUD 视觉跳变，也与 Task91 状态栏的硬边双层亮边语言协调。

## 人工核对

- 被动槽：4 个，位于上排；其中 2 个示例图标、2 个清晰空槽。
- 主动槽：3 个，位于下排；键位 `1/2/3`、`SP 10 / SP 0 / SP 8` 可读。
- 状态示例：主动槽 2 有暗色冷却遮罩与 `3.2` 数字；主动槽 3 为空槽。
- 位置：底部中央，共享中心轴；上轻下重但轮廓统一。
- 风格：与 Task91 状态栏协调；未使用水火主题徽记，也不是 Task79 作废稿的复刻。
- 尺寸：完整概念图为 1920×1080；局部特写为 2240×1160（560×290 裁切区域的 4×最近邻放大）。
- 像素隔离：将 Task91 原图与最终概念图在 HUD 包围矩形外划分为上、左、右、下四个区域，读取 32bpp ARGB 原始像素后逐区 SHA-256 对比，四区全部一致。

## 最终提示词

```text
Use case: precise-object-edit
Asset type: 1920×1080 in-game HUD concept mockup
Input images: Image 1 is the edit target and structural reference, the latest Task 91 same-camera 1920×1080 gameplay screenshot.
Primary request: change only the bottom-center skill HUD. Redesign it as one compact, visually unified neutral-theme pixel-art component with an upper row of exactly 4 passive icon slots and a lower row of exactly 3 active skill slots.
Style/medium: crisp native-resolution pixel-art game UI, hard stepped corners, deep blue-black fill, restrained sparse dark engraved texture, layered double bright rim with a thin cool cyan inner line and a quieter desaturated blue-gray outer line. Coordinate with the existing Task 91 status HUD art language without copying its water emblem.
Composition/framing: preserve the full 1920×1080 screenshot and exact same camera. Place the unified component at bottom center, above the bottom edge, centered on the same x axis. The upper passive tier is lighter, thinner and slightly recessed, holding only four square icons. The lower active tier is thicker and weightier, holding three equal slots. Join both tiers through shared side shoulders/backplate so they read as one tight silhouette while remaining immediately distinguishable.
Dynamic content shown: passive row has exactly four slots, with two filled neutral sample icons and two clearly readable empty slots. Active row has exactly three slots. Each active slot reserves a clear square icon region, a small top-left key badge with exact text "1", "2", and "3", and exact bottom text "SP 10", "SP 0", and "SP 8". Show slot 1 filled, slot 2 filled with a subtle dark cooldown overlay and readable centered cooldown number "3.2", slot 3 empty but clearly framed. Keep small text crisp and legible at gameplay scale.
Fixed decoration: neutral deep blue-black and cool steel/cyan edging only. No water droplet, flame, wave, ember, elemental crest, or color-swapping ornament.
Constraints: EDIT ONLY the bottom-center skill HUD region. Keep every other pixel, object, character, dungeon platform, background, framing, scale, lighting, left-top HP/SP status HUD, room content and all other UI unchanged from Image 1. Preserve 16:9 1920×1080 output. Exactly 4 passive slots above and exactly 3 active slots below. No extra panels, labels, logos, watermark, or invented HUD elsewhere.
Avoid: loose disconnected debug boxes; glossy modern UI; rounded vector styling; water/fire theme; Task 79 replica; illegible microtext; changing the game scene.
```
