# 任务 55：潮汐地牢分层房间背景与独立平台美术

状态：CANCELLED_BY_USER
负责人：美术资产职责对话 `threadId=019ffb00-0624-76a1-85b0-946bdce0f982`，`hostId=local`
依赖：Task53 `ACCEPTED`；Task54 `CANCELLED_BY_USER`
Git 基线：`5c0f2ee24ab8c1e494e1e185666c94edd7b79228`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L2
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

## 1. 用户决策与玩家可观察目标

用户已明确停止 `TileSet + TileMapLayer` 运行时路线，改用“固定房间分层背景图片 + 独立平台/碰撞”。本任务只交付首个平台房的正式分层美术，不做任何工程接线。

玩家最终应看到更远视野下的潮汐地牢大房间：连续、安静的暗色背景墙提供纵深；拱门、石柱、链条、碎石等装饰与墙体分层；平台具有清晰可站立顶线。背景不能自带灯光或光晕，角色、敌人和交互物仍是视觉焦点。

## 2. 冻结运行画布与分层合同

- 目标世界房间：`1536×832`；像素美术源画布：`768×416`，运行时只允许 `2× Nearest` 整数显示。
- 三张整房图片必须同尺寸、同原点、像素级对齐：
  1. `background_wall_v1.png`：墙体/远处暗面；允许不透明底色；禁止灯具、火焰、晶灯、照明锥、泛光、光斑、环境光晕或局部烘焙提亮。
  2. `back_decor_v1.png`：透明 RGBA；拱门、柱、凹槽、链条、裂纹、碎石、非发光雕刻等后景装饰；禁止任何烘焙灯光。
  3. `front_decor_v1.png`：透明 RGBA；少量前景遮挡轮廓；禁止灯光，且不得大面积遮挡玩家主要活动带。
- 平台/地面是独立透明 Sprite 资产，不烘进上述三层，不使用 TileSet：
  - `ground_floor_v1.png`：`768×64`，运行 `2×`；完整房间地面视觉。
  - `platform_short_v1.png`：`160×32`，运行 `2×`。
  - `platform_medium_v1.png`：`224×32`，运行 `2×`。
  - `platform_long_v1.png`：`320×32`，运行 `2×`。
- 四张平台图统一 top-center/bottom-center 对齐规则和可站立顶线；顶线连续、轮廓明确，碰撞建议单独写入 manifest，后续由场景 `StaticBody2D/CollisionShape2D` 或等价简单碰撞承载。
- 灯具若未来需要，只能另做无光灯具 Sprite + 运行时 Light 节点；本任务不交付灯光层，也不得把灯光混进墙或装饰图。
- Task53 atlas 可作为材质/色板/追溯输入，但不得直接放大拼成运行背景，不得创建新的 atlas/TileSet/TileMapLayer。

## 3. 精确输出 allowlist

1. `assets/world/rooms/tidal_dungeon/platform_room_v1/background_wall_v1.png`
2. `assets/world/rooms/tidal_dungeon/platform_room_v1/back_decor_v1.png`
3. `assets/world/rooms/tidal_dungeon/platform_room_v1/front_decor_v1.png`
4. `assets/world/rooms/tidal_dungeon/platform_room_v1/ground_floor_v1.png`
5. `assets/world/rooms/tidal_dungeon/platform_room_v1/platform_short_v1.png`
6. `assets/world/rooms/tidal_dungeon/platform_room_v1/platform_medium_v1.png`
7. `assets/world/rooms/tidal_dungeon/platform_room_v1/platform_long_v1.png`
8. `assets/world/rooms/tidal_dungeon/platform_room_v1/manifest_v1.md`
9. `docs/art/潮汐地牢_分层背景与平台美术交付合同.md`
10. `docs/agent_tasks/pending/55_layered_room_background_and_platform_art.md`
11. `docs/agent_tasks/evidence/task55/**`

除上述范围外全部只读。不得创建或修改 `.import/.tscn/.tres/.gd/project.godot`；不得改写 Task53 已接受文件或删除旧资产。

## 4. L2 美术与自动门禁

- 7 张运行 PNG 尺寸/模式/SHA/alpha bbox/partial-alpha 报告；三张整房层逐像素尺寸与原点一致。
- 自动内容门禁至少证明：`background_wall` 与两张 decor 中不存在明显发光核心/光晕的高亮团块；该门禁只能辅助，最终必须原尺寸人工确认“无烘焙灯光”。
- `back_decor/front_decor` 必须真透明，不得把整张背景复制后改名；分别给出 alpha coverage，FrontDecor 保持稀疏。
- 原尺寸 `768×416` 三层单独图、三层叠加图，以及 `1536×832` 2× Nearest 合成 QA；合成 QA 中放入玩家、普通敌人、Tidal Sentry、宝箱、传送门和三种平台做尺度检查，但不得冒充运行截图。
- 交付可视化拆层图：Wall / BackDecor / gameplay silhouettes / FrontDecor 四栏；能明确证明装饰可以单独关闭或替换。
- 平台分别做原尺寸与 2× QA；可站立顶线差异不超过 1 源像素，四张资产的材质与厚度一致，不靠拉伸生成长平台。
- 视觉门禁：大暗面与低频结构为主，避免细碎等距砖墙、随机马赛克和固定贴图节拍；装饰稀疏，画面留出玩法空间。
- 全库允许范围扫描证明新资产引用为 0，Task53/49/52 SHA 不变，旧资产仍在；Git 写操作为 0。

## 5. 保护与交付

- 用户 `global_instakill`、历史 evidence `.import` 删除、Task20、Task47、Task49/52、Task53、translation/import/.godot/中文保护文档与共享 Godot/editor 全部保护。
- 不使用子 Agent，不运行/控制 Godot，不做 Git 写操作，不自行 `ACCEPTED`。
- 完成后只更新为 `REVIEW/BLOCKED` 并在美术任务内交付、冻结；禁止 `send_message_to_thread` 跨对话回传中枢，中枢使用 `wait_threads/read_thread` 主动收取。

## 6. 后续拆分（本任务不实现）

- Task56：只把平台房接入三层整图、独立平台 Sprite 与简单碰撞，验证真实跳跃/遮挡；默认 L2。
- Task57：统一放远 Camera 与扩大其余固定房间，接入不同房间背景变体；跨域时升级 L3。
- Task58：静态远程怪逻辑与平台布置，复用 `ProjectileDelivery`。
- Task59：宝箱/传送门正式素材接线、全库引用迁移、验收后精确删除旧资产。

## 7. 协调记录

- 2026-08-14 复用既有美术专用对话，显式 `model=gpt-5.6-sol`、`thinking=high`；Task55 任务书包含完整新方向，旧 TileSet 讨论只作为历史输入，不得覆盖用户最新决策。
- 执行对话：`threadId=019ffb00-0624-76a1-85b0-946bdce0f982`，`hostId=local`；中枢仅通过 `wait_threads/read_thread` 主动跟踪。

## 8. Task55 执行交付（2026-08-14）

### 8.1 正式运行图片

| 文件 | 尺寸 | SHA-256 | 状态 |
|---|---:|---|---|
| `background_wall_v1.png` | 768×416 RGBA | `E4EF73A15F3EFB39D8FC88CCC01081F56C331BD185D489332ACA007AD38A48E4` | REVIEW CANDIDATE |
| `back_decor_v1.png` | 768×416 RGBA | `0E75805A1C959889A0F07C8F879D20EBFA65903176F67D3E4CE114749291C449` | REVIEW CANDIDATE |
| `front_decor_v1.png` | 768×416 RGBA | `F79B5C1A679CAD7209036328D6AB7A969146785F6D6CDEF16E484AB959130F45` | REVIEW CANDIDATE |
| `ground_floor_v1.png` | 768×64 RGBA | `20BC95128605EDFF3EA93F02481A43E9842D0FE91922FDD17C401B71A4EE42F9` | REVIEW CANDIDATE |
| `platform_short_v1.png` | 160×32 RGBA | `DC74F20CBA4EE8DD7509185D4D19C96E6AB9AB070CBCECC74331954A50564B68` | REVIEW CANDIDATE |
| `platform_medium_v1.png` | 224×32 RGBA | `FF7A05672F186FDF67DA4CC3B8BB1732A6550A7382C2E4E0844E7427ABEA8583` | REVIEW CANDIDATE |
| `platform_long_v1.png` | 320×32 RGBA | `3AC1C0EED33D069E6E7271344D4A77150B1293DD073DAB630EE96B7DED047716` | REVIEW CANDIDATE |

所有正式文件位于 `assets/world/rooms/tidal_dungeon/platform_room_v1/`。三层房间图同尺寸、同 `(0,0)` 原点；运行目标固定为 2× Nearest 到 1536×832。

### 8.2 美术与 QA 结论

- Wall 使用跨越多格的大石块和宽暗面，不含等距小砖、随机马赛克或循环墙纸；Task53 atlas 未被放大拼入背景。
- BackDecor 只有暗拱、石柱、链条、裂纹与碎石；alpha coverage `0.139817`。FrontDecor 只占左右边缘与极少上角，coverage `0.088232`。
- 三层运行图最高 luminance 分别为 `49 / 81 / 81`；luminance >110 像素及最大四连通高亮团块均为 `0`。
- 已在 768×416 原尺寸人工检查 Wall、BackDecor、FrontDecor 与叠加图：无灯具、晶灯、灯座、照明锥、光池、泛光、光斑、暗角或局部光晕。人工记录为 `reports/manual_no_baked_light_review.md`；自动门禁没有替代人工结论。
- Ground、short、medium、long 追溯到四张独立 ImageGen 源，不以拉伸复用同一平台；四张 standable top 均为 local `y=0`，逐列差异 `0` 像素。
- 已提供三层原尺寸单图、768×416 叠加、1536×832 精确 2× 合成、Wall/BackDecor/gameplay/FrontDecor 四栏拆层、四种平台 2× 与顶线/尺度 QA。
- 自动门禁 `16/16 PASS`；7 张运行 PNG 均为 exact RGBA、hard alpha；新运行引用 `0`，Task55 `.import` 为 `0`。
- Task53/49/52 任务文件、Task53 atlas、宝箱、传送门与 Tidal Sentry SHA 均与构建前一致。

### 8.3 边界声明

- 未创建或修改 `.import/.tscn/.tres/.gd/project.godot`，未运行或控制 Godot/editor；
- 未创建 TileSet/TileMapLayer、碰撞、灯光或工程引用；未清理 Task54 或任何旧资产；
- 未修改 Task53、Task49、Task52、`global_instakill` 或其他保护项；
- 未执行 Git 写操作，未使用子 Agent，未调用跨线程回传；
- 当前只置为 `REVIEW`，等待中枢派独立 L2 Review；本对话不得自行 `ACCEPTED`。

## 9. 用户退回与停线（2026-08-14）

- 用户原尺寸感受后判断该方向仍“不对味”，转为亲自探索地图绘制；中枢未启动独立 Review，也未做工程接线。
- 本任务标记 `CANCELLED_BY_USER`。现有输出仅作为被退回的方向稿/取材参考，不是正式资产，不得被后续工程消费或误记为 `ACCEPTED`。
- 美术对话已停止图像生成、文件写入与 QA；当前未提交文件原样冻结，不删除、不回退、不暂存。
