# 任务 39：宝箱、传送门、元素回响与 Boss 弹体资产

状态：ACCEPTED
负责人：ImageGen Asset Agent（threadId `019ff4cd-92b5-7792-9ba1-7075d3426fcc`，hostId `local`）
依赖：Task32 `ACCEPTED` 资产风格；派发基线 `7c217775e7ffa22aeffe6dd6a2af6694aae72d92`
回传中枢：Review 6.0，threadId `019fd7fd-4476-7f73-b121-76760fabf284`，hostId `local`

## 1. 目标

使用 `imagegen` skill 的内置生成流程，为 Task38/41 提供五张可直接接入的透明 PNG：

- 普通结算宝箱：关闭、开启两种一致状态；
- 路线传送门：一个清晰的紫蓝元素门主体，后续由引擎做轻微呼吸/旋转；
- 新被动“元素回响”图标：反应爆点 + 回流能量核心，不能与现有“元素储备”容量罐混淆；
- Boss 简单远程攻击弹体：低空紫色弧形/新月弹体，便于玩家跳跃躲避。

只产出最终位图与来源说明，不接场景、不写脚本、不实现动画/碰撞/流程。质量目标是当前已接受 2D 横版地牢风格和 32/64px 或世界缩放后的清楚轮廓，不追求角色立绘级细节。

本任务还独占维护 `docs/vfx/final_asset_manifest.md`。该文件现有 Frozen visual contracts 中的 `Reclaim: query radius 160` 已被 Task38 正式合同替代；必须在本任务内同步改为“当前 Viewport 经 canvas transform 得到的世界可见矩形；矩形内无墙体 LOS 阻挡，屏外排除”。这里只同步合同文字，不实现或测试 Task38 逻辑；若 Task38 后续调整，以 Task38 正式任务书和接受实现为权威。

## 2. ImageGen 工作流与视觉合同

开始前必须完整阅读并遵守 `C:\Users\heliashi\.codex\skills\.system\imagegen\SKILL.md` 及其要求的提示参考；用原尺寸实际查看 Task17/32 已接受 icon 和现有游戏截图作为风格参考。

- 默认使用内置 `image_gen`，每个不同资产独立调用；不得用脚本绘制占位图，也不得擅自切换 CLI/API/model。
- 透明图按 skill 的内置 chroma-key + 官方 `remove_chroma_key.py` 流程处理。为赶进度，所有主体设计为清晰、基本不透明的像素绘制 cutout；不要求复杂烟雾/玻璃/半透明软边，不触发 true-native transparency fallback。
- 宝箱两态必须保持同一机身、角度、比例和配色；开启态只改变箱盖/内部光，不重新设计宝箱。
- 传送门为无文字、无角色、无场景背景的单体 cutout，中心和外轮廓在暗色房间都能读清。
- 元素回响图标必须靠形状表达“反应后能量回流”，不得画成单纯蓝色电池、储槽、治疗心或已有图标换色。
- Boss 弹体采用横向运动轮廓，避免像角色、武器拾取物或 UI 图标；最终碰撞由 Task41 代码负责。
- 无文字、数字、键帽、徽标、水印、完整背景或投影污染；保留足够透明 padding。

## 3. 精确 allowlist

```text
assets/generated/vfx/run_reward_chest/chest_closed.png
assets/generated/vfx/run_reward_chest/chest_closed.png.import
assets/generated/vfx/run_reward_chest/chest_open.png
assets/generated/vfx/run_reward_chest/chest_open.png.import
assets/generated/vfx/run_reward_chest/prompt.md
assets/generated/vfx/run_reward_chest/manifest.md
assets/generated/vfx/run_route_portal/portal.png
assets/generated/vfx/run_route_portal/portal.png.import
assets/generated/vfx/run_route_portal/prompt.md
assets/generated/vfx/run_route_portal/manifest.md
assets/generated/vfx/passive_reaction_energy/icon.png
assets/generated/vfx/passive_reaction_energy/icon.png.import
assets/generated/vfx/passive_reaction_energy/prompt.md
assets/generated/vfx/passive_reaction_energy/manifest.md
assets/generated/vfx/boss_arc_projectile/projectile.png
assets/generated/vfx/boss_arc_projectile/projectile.png.import
assets/generated/vfx/boss_arc_projectile/prompt.md
assets/generated/vfx/boss_arc_projectile/manifest.md
docs/vfx/final_asset_manifest.md
docs/agent_tasks/pending/39_chest_portal_boss_vfx_assets.md
docs/agent_tasks/evidence/task39/**
```

不保留生成器默认目录中的未选 variants、chroma-key 中间图或临时 QA 图到项目正式资产目录；evidence 可保留尺寸对比拼图与 SHA 清单。上述五个 `.png.import` 必须由本任务此前不存在的冷副本与独立 Godot 4.7.1 profile 的首次 editor scan 为对应最终 PNG 生成，再逐项核对源 PNG 路径/UID 后精确复制纳入交付；不得手写、不得在共享项目运行 Godot 生成、不得修改或认领任何既有 `.import`。Task39 仍不得创建 `.gd.uid` 或复制共享 `.godot` 内容。

`docs/vfx/final_asset_manifest.md` 除追加本任务五张资产及其用途外，只允许修改上述 Reclaim 旧 `160` 半径条目；不得改写其他冻结视觉合同。

## 4. 质量与验证门禁

- 最终均为正方形 RGBA PNG，建议 256×256；主体不贴边，透明角落和 alpha 有效。
- 原图逐张打开；宝箱与传送门额外按约 96/128px 世界显示检查；被动图标按 64/32px 检查；弹体按 96×48 左右显示检查。轮廓不可糊成色块。
- 至少一张暗色房间风格 QA 拼图同时展示：关闭/开启宝箱、传送门、Boss 弹体；至少一张 icon 32/64px 对比。QA 只评资产，不伪造正式游戏接入。
- `prompt.md` 保存最终提示词和参考角色；`manifest.md` 保存生成方式、去背步骤、尺寸、模式、alpha、文件字节/SHA 和用途。
- 最终对账必须确认 `docs/vfx/final_asset_manifest.md` 不再保留 `Reclaim: query radius 160`，并准确写明 Viewport 世界矩形、无 LOS、屏外排除；Task38/Task39 不得并行写同一文件。
- 最终对账必须确认五张新 PNG 与五个对应 `.png.import` 为 `5/5` 一一匹配，且 HEAD 中既有 94 个正式 PNG import sidecar 全部零修改。
- 不要求运行完整 29 runner，但必须在 Task39 自己此前不存在的 `C:\tmp` 冷副本与独立 profile 中运行 Godot 4.7.1，且第一条 Godot 命令必须是 headless editor scan。该 scan 必须成功导入五张最终 PNG、生成对应五个 `.png.import`；逐项核对源 PNG 路径/UID 后再精确复制回共享交付。不得把 import 生成责任转给 Task38/41，不得触碰共享编辑器。

## 5. 状态与自动回传

开工前只读固化 HEAD/status、allowlist、共享 `.godot`/sidecar/进程；保护两个未跟踪中文协作规则文档，不删除、不认领。禁止子 Agent、Git 写操作和共享 Godot 控制。

开工置 `IN_PROGRESS`；完成只置 `REVIEW` 并冻结，阻塞置 `BLOCKED`。完成或阻塞后直接 `send_message_to_thread` 回传中枢 `019fd7fd-4476-7f73-b121-76760fabf284`（hostId `local`）；回传需列最终路径、提示词/流程、尺寸/alpha/SHA、QA 和保护对账，不得自行 `ACCEPTED`。

## 6. Review 6.0 独立验收（2026-08-12）

结论：`PASS / ACCEPTED`。

- 独立 Review 从固定 HEAD `7c217775e7ffa22aeffe6dd6a2af6694aae72d92` 的 Git 对象只读导出候选，并只叠加 Task39 冻结 allowlist 30 个文件；Task38/40 live diff、两份中文协作文档和中枢 README 改动均未进入候选。30 个叠加对象与共享冻结源 SHA 全匹配。
- 候选位于此前不存在的 `C:\tmp\element-dungeon-task39-review-20260812-02\project`，使用同根独立 profile。第一条 Godot 命令严格为 4.7.1 headless editor scan，exit `0`；最终 rescan exit `0`。两份独立日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 `0`。
- 五张最终 PNG 均为 256×256 RGBA、透明四角、有效 partial alpha、visible bbox 留边、严格 `#00ff00` 像素 `0`；bytes/SHA 与冻结证据一致。新 PNG/import 为 `5/5`，五个 UID 各全局唯一且 source_file 精确对应；既有 96 个 VFX import（其中正式口径 94 个）逐文件零修改，`.gd.uid` 相对 HEAD 新增/缺失均为 `0`。
- Review 独立重算 `SHA256SUMS.csv` 为 `29/29`；原尺寸逐张查看五图和两张 QA。宝箱开关态主体一致，传送门暗底清楚，元素回响在 32/64px 与元素储备罐可凭形状区分，Boss 弹体在 96×48 保持横向跳避轮廓；未发现文字、水印、背景或投影污染。
- `docs/vfx/final_asset_manifest.md` 仅同步 Reclaim 的 Viewport/canvas-transform 世界矩形、无 LOS、屏外排除合同并追加五资产章节；其余冻结合同未改。执行/Review 均未控制共享 Godot，未做 Git 写操作。

Task39 资产现可由 Task38/41 只读消费。运行时接线、碰撞和完整流程仍分别属于 Task38/41，不由本任务验收结论代替。
