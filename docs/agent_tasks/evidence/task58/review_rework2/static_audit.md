# Task58 rework2 静态与测试门禁审计

## 生产入口

- `scripts/combat_hud.gd` 与固定基线 blob 完全一致；rework2 没有新增 page/scene/node。物理 L 继续走真实 `CombatHUD._unhandled_input()`，再调用无参 `RunOverlayInterface.toggle_loadout()`。
- `RunOverlayInterface.toggle_loadout()`（冷根第 110 行）在 SHOP 隐藏态只显示既有 `combat_loadout`；不创建/提交 draft，不显示 `leave_shop`、purchase 或 upgrade 控件。第二次 L 关闭该内容。
- 显式 merchant 入口 `show_formal_shop_from_world_interaction()` 定义于 overlay 第 1407 行。生产调用点全库唯一：`RunFlowCoordinator._open_shop_ui_from_crown()` 第 508 行；该函数仅由皇冠交互分支调用（第 420 行）。
- `_render_formal_phase()`（第 1419 行）在 SHOP snapshot 上只刷新当前已可见的 merchant 或 loadout；隐藏态不会自动显示 merchant。既有 `_show_formal_shop()` 其他内部调用仅刷新已显示商店或处理已进入商店后的正式事务。
- Review-only 42-check 诊断通过真实 L/F 路径复核：初始 SHOP callback 为 `active_room=false / visible=false / draft=0`；物理 L 只开 loadout；远离皇冠 F 不开；近距皇冠 F 创建唯一 draft；重复 F 不新增 draft；purchase 与 upgrade callback 分别保持 `kind=shop / visible=true / same draft`；关闭后 L 只开 loadout，F 可重新打开同一 merchant draft。

## Task41 逐行 diff

- 与固定基线相比只有 shop-entry 单一 hunk和一个物理 L helper 发生变化；波次、真实移动、Boss projectile、经济、配装、奖励、出口和几何代码没有删除或绕过。
- 唯一删除的 10 行是旧合同的两次 `overlay.toggle_loadout()`、对应两次 `await process_frame`，以及“L 重新打开 merchant/复用 draft/footer/再次关闭”的 6 条断言。
- 替代断言要求：SHOP 初始隐藏且无 draft；真实 CombatHUD 物理 L 只打开现有 loadout、无 merchant 控件/新 draft/事务/权威变化；皇冠近距 F 才打开 merchant 并创建唯一 draft；关闭后 L 仍只开 loadout并保留原 shop session/draft。正式结果保持 `4 tests / 95 assertions`。

## Task31 逐行 diff

- 固定基线的 383 条断言无一删除；safe/risk 两条路径各新增一次 `_open_physical_shop_from_crown()`。
- helper 等待真实 shop room，移动真实 Player 到实体 wishing crown，再通过 `_press_interact_input()` 投递正式 interact 输入；没有调用 Overlay 内部 merchant 方法或测试 accessor 开店。
- 每条路径执行 5 条新断言，共新增 10 条，正式结果为 `4 tests / 393 assertions`。购买、配装、经济守恒、失败/新权威、五阶段与 `4/1/0` 结果保持。

## 其余冻结边界

- `project.godot`、Player、Enemy、CombatHUD、RunGame scene 与 Task57 Battle02 scene 均与基线和冷根三方一致；`scripts/enemy.gd` 未改。
- Task58 专项独立验证真实 chest/portal 双纹理、皇冠、Sentry 静态/三发 projectile lifecycle/死亡奖励清房，以及 Battle02 SpawnA `55 HP / 15` 奖励。
- Task57 `5/205` 与 Task31 `4/393` 均通过；保护文件及正式六 PNG 详见对应 reconciliation CSV。
