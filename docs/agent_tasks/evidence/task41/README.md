# Task41 current-final evidence — physical shop usability rework

## Supersession

- 第三项独立验收确认上一轮 formal SHOP 面板无法关闭，玩家看不到或无法走向右侧世界出口；旧 06/07 两图像素完全相同，07 不是世界 F 提示。上一轮 67-file evidence 与 formal `312/4547` 整体作废。
- 本轮生产变更仅 `scripts/ui/run_overlay_interface.gd`；验证变更仅 Task41 runner、Task31 E2E 与 Task41 capture。本目录只包含最终 fresh 候选 07 重新生成的正式证据。

## Provenance

- 固定基线：`87dceba3167365665cc726777a6fca78d7ae7d8e`。
- fresh 冷根：`C:\tmp\element-dungeon-task41-shopux-20260812-07`。
- 独立 profile：`C:\tmp\element-dungeon-task41-shopux-profile-20260812-07`。
- 候选由固定 HEAD ZIP archive 只读解包后仅叠加 Task41 §8 当前 allowlist；候选 `docs/agent_tasks/README.md` 为 HEAD blob，SHA-256 `38DCBB2C23981E67E95846811B0FB657A2558B6AEA8C265BE2C25E33D93A204B`。第一条 Godot 命令为 4.7.1 headless editor scan。
- 早期窄跑候选 06 因测试等待未显式使用 physics frame 而废弃；它的日志、截图和生成物均未进入本目录。

## Shop usability contract

- formal SHOP 仍自动打开交易面板；header 新增可点击、可聚焦的“关闭商店界面 / 返回世界  L”，并注册为 `formal_control(&"close_shop_panel")`。点击只隐藏 overlay，不调用 `leave_shop`，不改变 wallet/loadout/revision/shop draft。
- formal SHOP 的 `toggle_loadout()` 现在真正 toggle：可见时关闭回世界，隐藏时以同一 snapshot、shop session 与 draft 重开。footer `leave_shop` 保持 disabled；路线、结算与 legacy 行为不变。
- Task41 专项、Task31 safe/risk 完整局与正式 capture 都在关闭面板后用 `move_right` 输入和真实 physics frames 从出生点走入 `exit_portal.can_interact` 范围，再发送 interact/F 输入；三条路径都不直接修改商店内 player position。
- SHA-256：overlay `BB3A86E1507F6885D825641DC5234FA90F596BB2C8D91619F9DC522FC8D970F5`；Task41 runner `74F771FA9BAA8E1E300D6759B1199ADF2CFB6917763AD3D957366FA57A5ECA42`；Task31 E2E `19D84D16D05A66BBE0B4343A57AFF69E94F47C960D6B7DEDD195E944E5A21EC1`；capture `071ED494F326577A965C09A1F4272C9AF42128104F15AA5FC77D0E128CB625F6`。

## Final gates

- Task31 三个独立进程均 exit 0、4 tests / 557 assertions；safe 为 `300 + element_reclaim|burning|elemental_fury + 895/225/300/475`，risk 为 `450 + element_reclaim|elemental_fury + 1150/420/115/615`，三次逐项一致。
- direct8：8/8、42/1779；formal32：32/32、312/4574，其中 Task31 4/557、Task41 4/110。全部 exit 0。
- Task20 历史单列 7/68；RunGame/TestRoom 双 180 帧；final editor rescan：均 exit 0。
- 非 headless capture 11 张全部重新生成并按冻结预期严格核验尺寸。06 交易面板 SHA `32B378B2BC5964701F75F3182C4FECB3A80679E131B4EB43CBE0CE07B1965DAC`，07 世界门/F提示 SHA `186527C08E5148836F2C1077D740DE72E823A196DD412356D482DAE33324F746`，明确不同；两张均为 1366×768，07 清楚显示世界商店房、玩家、portal 与 `F · 离开商店`。
- 49 个正式日志的 `SCRIPT ERROR` / `Parse Error` / `ERROR:` / `WARNING:` / `CrashHandlerException` 合计 0。

## Isolation

- 相对上一轮冻结候选仅 overlay、Task41 runner、Task31 runner、capture 四项变化；其余实现/测试/设计 39/39 不变。生产变更只有 overlay。
- Task39 五 PNG/五 import 10/10 SHA 一致；五个 Task41 UID 不变；共享 `.godot`、sidecar、中枢 README 和两份中文保护文档保持外部原状。
- 共享 evidence 精确为本 README + 49 logs + 6 CSV + 11 PNG = 67 files；冷根生成的 `.import/.translation` 不回流。
- 无共享 Godot、无 Git 写操作、无子 Agent。
