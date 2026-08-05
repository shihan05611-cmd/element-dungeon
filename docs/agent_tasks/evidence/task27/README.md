# Task 27 执行侧证据

状态：`REVIEW`（执行侧冻结，等待中枢 Review 5.0 独立验收）

## 1. 最终冷副本

- 项目：`C:\tmp\element_dungeon_task27_reviewfix_cold_20260805_01\project`
- 独立 profile：`C:\tmp\element_dungeon_task27_reviewfix_profile_20260805_01`
- 创建前两条路径均不存在；复制排除 `.git`、`.godot`、`.workbuddy`、项目 `tmp` 和缓存目录。
- 逐文件路径/长度/SHA-256 对账：源 `1256 files / 39,047,834 bytes`，冷副本 `1256 / 39,047,834`，`0 mismatch`。
- 冷副本第一条 Godot 命令是 `Godot 4.7.1 --headless --editor --quit` scan，exit 0；scan 后才运行 runner。

## 2. 自动门禁

| 门禁 | 结果 |
| --- | --- |
| Task27 经济/成长 runner | 11 tests / 291 assertions，exit 0 |
| Task27 战斗等级效果 runner | 7 tests / 86 assertions，exit 0 |
| Task27 新增合计 | 2/2 runners；18 tests / 377 assertions |
| 任务25已接受基线 | 20/20 runners；242 tests / 2115 assertions |
| Task27 + 接受基线总计 | 22/22 runners；260 tests / 2492 assertions |
| Task12 专项 | 13 tests / 110 assertions，exit 0 |
| Task16 专项 | 11 tests / 209 assertions，exit 0 |
| Task18 专项 | 9 tests / 124 assertions，exit 0 |
| Task24 专项 | 10 tests / 190 assertions，exit 0 |
| editor scan | Godot 4.7.1，exit 0 |
| 180 帧 smoke | exit 0 |
| 非 headless Viewport capture | exit 0；OpenGL 3.3 / NVIDIA GeForce RTX 2060 |

正式日志共 25 份：`editor_scan.log`、22 份 `gate_*.log`、`main_scene_smoke_180.log`、`visual_capture.log`。全量日志统计：`SCRIPT ERROR=0`、`Parse Error=0`、`ERROR:=0`、`WARNING:=0`。

任务20 runner 未运行、未修改、未混入门禁，也未因本任务通过而改变其历史 `BLOCKED` 状态。

## 3. 权威合同覆盖

- 梦尘钱包记录余额、总获得、购买支出、升级支出和返还，始终满足 `balance = earned + refunded - purchases - upgrades`。
- 开局冻结角色成长/遗物功能模式；`DISABLED` 保持 Lv1/XP0/属性0/遗物中性，`OBSERVE_ONLY` 只累计诊断观测，`ENABLED` 保留旧兼容行为。旧资源继续由 editor scan 和 catalog runner 验证可加载。
- 商店购买、主动升级、主动重置统一验证 command id、expected run revision、shop session、offer/skill、拥有权、余额、等级和内容定义；拒绝零写入，成功 revision/通知各一次，精确 command replay 不重复扣款/返款/通知。
- 重置返还 `floor(累计实际升级支出 × 0.70)`，回 Lv1、累计支出清零；购买价不返、拥有权和装配不变、重复重置无收益。被动可购买但恒 Lv1/零升级支出。
- 接受时等级效果由窄端口冻结。元素弹/之怒/激光只缩放伤害，回收只缩放专属资源收益；已接受执行不受后续升级污染，端口缺失/内容无等级时中性，SP、反应、冷却、范围、元素层数和行为保持不变。
- Task25 即时装配草稿重基线和最终属性确认语义继续由已接受 runner 覆盖；Task24 奖励聚焦不领取、独立确认语义未回退。

## 4. 实际 Viewport

| 文件 | 尺寸 | bytes | SHA-256 | capture 内断言状态 |
| --- | ---: | ---: | --- | --- |
| `01_authoritative_lv2_element_bolt_1920x1080.png` | 1920×1080 | 155,594 | `812E01F6BA1729E0B3D06E42A90E8227803BA819CBDC011073014194B49AB324` | 真实 TestRoom/RunSession；元素弹 Lv2；damage 12.5；梦尘 25；revision 16；施法后 SP 90；面板可见像素门禁通过 |

PNG 由最终冷副本中的非编辑器、非 headless Godot 4.7.1 图形进程直接保存实际 Viewport，不是 mockup 或重绘图；像素格式为 `Format32bppArgb`。截图只证明实际接线和可读集成状态，数值权威来自两个 runner 的断言。

独立 Review 首次失败指出旧脚本把 1920 物理坐标直接用于 1152×648 逻辑画布，面板被 stretch 推到屏外。本轮改为 `CanvasLayer → 全屏 Control → 右上锚点 + 逻辑 offset`，面板限制在逻辑画布顶部25%安全带；capture 还会在面板超出逻辑安全区、金色边框少于200像素或亮色文字少于300像素时直接 exit 1。

正式 `visual_capture.log` 记录 `border_pixels=2734`、`text_pixels=8345`。在独立 Review 使用的物理区域 `x=1050..1919, y=20..339` 中额外逐像素核对：精确 `RGB(215,181,109)` 金色边框 `2278` 像素，边界 `x=1270..1879, y=20..205`；亮色文字阈值 `8515` 像素。执行侧通过对话内 Base64 缩略预览完成主观布局检查：四行 Task27 信息完整可读，面板与顶部中央 HUD、玩家/敌人区域和紫色弹道均不重叠。

## 5. 保护与边界对账

- allowlist 声明：50 条。
- allowlist 外：`1182 files / 38,601,409 bytes / 6DF903AACD42AE78C767D01D5E5C958F8E5F530E6F0BDB52417A6C162DB2063E`，与执行前相同。
- 共享 `.godot`：`702 files / 34,663,328 bytes / C61FA422F168F1B3BBFD5FE48D43CE480ABD8AAA14221D2BD3F5E24AB89F579E`，与执行前相同。
- 任务20/21～26保护集：`120 files / 4,885,165 bytes / 48A9C73400F72DF5F76132A34D18A46390F3CA2D756558C45969A1AF6BC685BC`，与执行前相同。
- 六个历史 Growth runner 无需迁移；没有删测、跳过或降低断言。任务20继续历史非门禁。
- 未实现或提前修改七槽/四被动 Runtime、正式关卡流程、新主场景、最终 HUD、VFX、图片资产、正式场景或 `project.godot`。
- 未使用子 Agent；未运行任何 Git 写操作；未在共享项目运行 Godot、scan、runner、smoke 或 capture；共享 `.godot` 未被触碰。

## 6. 文件清单

`SHA256SUMS.txt` 列出全部 Task27 修改/新增实现、资源、harness、任务书、正式日志、PNG 与本 README 的最终 SHA-256。该标准清单文件自身不做自引用哈希。

## 7. Review 修正范围

- 本轮只修改 `combat/tests/capture_task27_skill_level_visual.gd`、`docs/agent_tasks/evidence/task27/**` 与任务27任务书；核心游戏实现和两个专项/20个基线 runner 均未修改。
- 视觉修正前核心保护集为 `47 files / 296,901 bytes / F5E5413B59AEA9D866B69FB84D7E60A5592C19D3B32A8C16713EF94C7B2B4ED2`；最终复核必须保持一致。
- 冷副本 scan 由于复制了旧 PNG 会生成 `01_authoritative_lv2_element_bolt_1920x1080.png.import`；该冷副本缓存副产物未复制回共享 evidence，也不属于正式证据清单。
