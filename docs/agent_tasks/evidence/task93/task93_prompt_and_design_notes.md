# Task 93 分离式技能 HUD 概念说明

> 状态：**仅概念、尚未实装**。等待用户确认后，才能另立实装任务。

## 参考与工作流

- Image 1 / edit target：`docs/agent_tasks/evidence/task91/screenshots/01_water_full_same_camera.png`（1920×1080）。
- Image 2 / style reference：`docs/agent_tasks/evidence/task92/task92_static_skill_hud_closeup_4x_nearest.png`。
- 使用内置 `imagegen` 编辑流程，未使用 CLI/API fallback。
- 内置生成原图为 1672×941，先以最近邻归一到 1920×1080，再以 Task91 原图作为最终底图，仅合成主动区和被动区的局部像素。被动框使用硬边八边形像素掩模整体上移 28 px，以增加最终底部安全边距，不改变槽位内容。
- Task91 原有紫色调试槽由同一原图中相同行的原生地面像素清除，不使用平滑或生成式扩图。
- Task92 的上下连体方案已被本版分离式方案取代；Task92 历史稿保留且未被覆盖或删除。

## 设计说明

- **主动区**：位于底部中央，外框约 608×176 px，横排准确 3 个大槽。主动区是视觉中心，保留键位 `1/2/3`、技能图标、`SP N`、冷却数字、禁用灰度与空槽表达空间。
- **被动区**：位于右下角，外框约 444×125 px，横排准确 4 个紧凑方槽。仅展示图标、冷却/禁用覆盖与空槽；不显示键位、SP 或文字说明。
- **明确分离**：主动区与被动区之间保留大段可见空隙，无连接件、共享肩部或共同背板，且无重叠。
- **层级与安全边距**：主动区居中且面积更大；被动区更矮、更安静，距右侧约 98 px、距底边约 49 px，没有贴边，也不遮挡主动区、角色主要活动区或左上状态 HUD。
- **固定静态框体**：两区统一使用深蓝黑底、硬边阶梯像素结构、冷青内亮边、低饱和蓝灰外亮边和稀疏暗纹。框体是固定中性主题，不含水滴、火苗、波纹、余烬或元素徽记。
- **未来动态内容区**：主动槽 1 展示已填充态；主动槽 2 展示暗色冷却/禁用覆盖与 `3.2`；主动槽 3 展示空槽。被动槽 1–2 展示已填充态，槽 3 展示冷却覆盖与 `5`，槽 4 展示空槽。

## 输出

- 完整场景：`task93_split_skill_hud_full_concept_1920x1080.png`（1920×1080）。
- 主动区特写：`task93_active_hud_closeup_4x_nearest.png`（2432×704，608×176 裁切后 4× 最近邻放大）。
- 被动区特写：`task93_passive_hud_closeup_4x_nearest.png`（1776×500，444×125 裁切后 4× 最近邻放大）。
- 原始生成与归一化中间稿保留在本 Task93 evidence 目录，便于追溯合成来源。

## 无损合成与像素隔离

- 旧调试槽清理区：`x=796..1123, y=860..898`。
- 主动区合成包围矩形：`x=656..1263, y=894..1069`。
- 被动框生成来源矩形：`x=1378..1821, y=934..1058`；最终合成包围矩形：`x=1378..1821, y=906..1030`。
- 将以上三个局部区域掩蔽后，对 Task91 edit target 与最终完整概念图的其余 RGBA 原始像素进行 SHA-256：
  - edit target：`989c7bc1cb652b847d4eba0a7527ddc8361938a6e2c8330e9758ab5f4e2974ac`
  - Task93 final：`989c7bc1cb652b847d4eba0a7527ddc8361938a6e2c8330e9758ab5f4e2974ac`
- 掩蔽区外差分包围盒为 `None`，即三个局部区域以外像素逐像素完全一致。
- Task91 edit target 全图 RGBA SHA-256：`d19d11aa89689a98b21866366ab310f395a8a908301d7216fd92c7337c30a271`。
- Task93 final 全图 RGBA SHA-256：`655417fd7edc138b974ebc0610d919e015214b03063d84d4a9832efcdcf59e78`。

## 最终提示词

```text
Use case: precise-object-edit
Asset type: 1920×1080 in-game HUD concept mockup
Input images: Image 1 is the edit target and structural reference: the exact Task91 1920×1080 same-camera gameplay screenshot. Image 2 is style reference only: the Task92 close-up for pixel-art frame language, colors, edge treatment, slot proportions, icon treatment, and small-text readability.
Primary request: Change only the bottom skill HUD of Image 1. Replace its current bottom-center debug skill boxes with TWO CLEARLY SEPARATED neutral-theme pixel-art HUD frames: (A) one active-skill frame at bottom center with exactly 3 larger horizontal slots; (B) one passive-skill frame in the lower-right corner with exactly 4 compact square slots in a horizontal row. The two frames must have visible empty space between them, must not touch, connect, share a backplate, or form the joined upper/lower silhouette from Image 2.
Style/medium: crisp native-resolution hard-edged pixel-art game UI. Match Image 2's deep blue-black fill, hard stepped corners, sparse dark engraved texture, and double blue bright rim with a thin cool-cyan inner line and a quieter desaturated blue-gray outer line. Both frames belong to one visual family but remain physically separate. Fixed neutral theme only.
Composition/framing: Preserve Image 1's full exact 16:9 same-camera composition. Active frame is visually dominant, centered on x=960 near the bottom with safe margin above the bottom edge, about 470–520 px wide and 120–145 px high. It contains exactly 3 equal large slots in one row. Passive frame is quieter, located at lower right with at least 70 px from the right edge and at least 70 px from the bottom edge, about 300–340 px wide and 80–100 px high. It contains exactly 4 compact equal square slots in one row. Passive frame must not overlap the active frame, character activity area, or other HUD.
Dynamic content shown: Active slot 1: top-left key badge exact text "1", readable neutral sample skill icon, bottom exact text "SP 10". Active slot 2: top-left key badge exact text "2", readable neutral sample skill icon, dark cooldown/disabled overlay, centered cooldown exact number "3.2", bottom exact text "SP 0". Active slot 3: top-left key badge exact text "3", clearly empty framed icon area, bottom exact text "SP 8". Passive frame: exactly 4 compact square slots; no key badges, no SP, no labels or prose. Show first two with quiet neutral sample passive icons, third with a subtle cooldown/disabled overlay and a small readable cooldown number "5", fourth as a clearly empty slot.
Fixed decoration: Both frames use identical static neutral deep blue-black construction and cool steel/cyan double edging with sparse dark texture. No water droplet, flame, wave, ember, elemental crest, or theme-switching ornament.
Constraints: EDIT ONLY the two local HUD regions described above. Keep every other pixel, object, character, dungeon platform, background, framing, scale, lighting, left-top HP/SP status HUD, room content, and all other UI unchanged from Image 1. Exactly 3 active slots at bottom center. Exactly 4 passive slots at lower right. Two separate frames with no connector and no overlap. Preserve practical screen-safe margins. Keep text crisp and legible at gameplay scale. No extra panels, labels, logos, watermark, or invented HUD elsewhere.
Avoid: joined stacked frame; shared shoulders or backplate; loose purple debug boxes; glossy modern UI; rounded vector styling; water/fire-themed frame; oversized passive panel; tiny illegible text; changing the game scene.
```

## 边界声明

本任务只输出概念证据，没有修改实现代码、正式资源或测试，也没有运行或声称完成实装。独立 Review Agent 的结论应作为验收依据；本说明不构成执行者自验收。
