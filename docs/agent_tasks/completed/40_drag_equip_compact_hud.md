# 任务 40：正式商店拖拽装配与紧凑 HUD

状态：ACCEPTED
负责人：UI/HUD Agent（threadId `019ff4cd-a965-7be3-93fd-36e42560582c`，hostId `local`）
依赖：Task30/31 `ACCEPTED`；派发基线 `7c217775e7ffa22aeffe6dd6a2af6694aae72d92`
回传中枢：Review 6.0，threadId `019fd7fd-4476-7f73-b121-76760fabf284`，hostId `local`

## 1. 目标与唯一交互方案

1. 正式 RunGame 商店增加拖拽装配，同时完整保留当前“点击技能 → 点击槽位”的装配方式。两套入口调用同一个现有权威 `apply_shop_loadout` 事务；成功即时生效，离店不二次提交。
2. 战斗技能槽进一步减小遮挡：常态不显示“可用”，角色忙碌时不显示顶部紫色忙碌条。保留真实冷却遮罩/秒数、SP 不足提示、施放失败短反馈、键帽、图标、短技能名、主动等级与 SP 成本；被动继续无键帽/SP/假冷却。
3. 顺手修复 Task31 已记录的非阻塞问题：2560×1440 狭廊战中 HP 面板不再压住房间标题最左侧。不得为此改房间/标题权威或重构整个 HUD。

本任务是 UI 小步整理，不重建响应式布局系统、拖拽框架或 MVVM，不复制配装合法性/钱包/revision 权威。

## 2. 拖拽合同

- 正式商店中，已拥有技能卡可拖入同类型槽；已装备槽也可拖到另一同类型槽完成换槽。
- 主动只能进 A1–A3，被动只能进 P1–P4；非法 drop、未拥有内容、陈旧/权威拒绝均不改变 snapshot/钱包/七槽，并显示现有短反馈。
- drop 成功只发送一次权威事务，revision 只增加一次；不得先本地改槽再提交。
- 拖拽预览只需 icon + 短名/类型，清晰可用即可，不做复杂动画。鼠标取消拖拽无状态变化。
- 原点击选择、点击槽位、卸下、购买/升级/重置和键盘焦点路径保持可用。

## 3. HUD 合同

- 正常可施放状态的 `State` 文案为空/隐藏，不再显示“可用”；空槽仍明确可辨。
- 忙碌紫色 `BusyStrip` 不再创建或永不作为正式视觉显示；忙碌按键被拒绝时仍可在既有短反馈中说明原因，无需常驻条。
- 冷却中的主动技能仍显示真实 cooldown mask + 数字；SP 不足、失败/锁定等短状态仍可辨。不得用删状态掩盖不可施放原因。
- 缩小技能/被动条的高度或内部留白，让主要战斗视野更空；文字和 32/64px 图标仍清楚，不产生新裁切。
- HP/SP 面板位置或尺寸做最小调整，在 2560×1440 既有狭廊房标题场景不重叠；同时在 1920×1080、1366×768 不越界。

## 4. 精确 allowlist

```text
scripts/combat_hud.gd
scripts/ui/combat_ui_tokens.gd
scripts/ui/run_overlay_interface.gd
scenes/combat_hud.tscn
combat/tests/run_compact_hud_reward_tests.gd
combat/tests/run_task24_compact_hud_reward_tests.gd
combat/tests/run_task30_run_ui_tests.gd
combat/tests/run_task40_drag_compact_hud_tests.gd
combat/tests/run_task40_drag_compact_hud_tests.gd.uid
combat/tests/capture_task40_drag_compact_hud_visuals.gd
combat/tests/capture_task40_drag_compact_hud_visuals.gd.uid
docs/agent_tasks/pending/40_drag_equip_compact_hud.md
docs/agent_tasks/evidence/task40/**
```

`run_compact_hud_reward_tests.gd` 仍属于 Task20 历史边界；这里只允许迁移被 Task40 明确冻结的视觉变化直接击中的断言：常态“可用”/BusyStrip，以及 status `264×76`、active `532×72`、passive 紧凑高度与由这三组尺寸直接派生的占用面积公式。`run_task24_compact_hud_reward_tests.gd` 同样只允许迁移上述 ready 与紧凑几何/占用断言；`run_task30_run_ui_tests.gd` 只迁移 ready 为空/隐藏的状态语法。不得改奖励、权威、流程或历史场景断言，也不得据此追认 Task20。若 `scenes/combat_hud.tscn` 实际无需改动则保持不变。

上述两个 `.gd.uid` 仅允许由本任务此前不存在的冷副本与独立 Godot 4.7.1 profile 在 editor scan 中为对应新脚本生成，再按精确文件复制纳入交付；不得手写 UID、在共享项目运行 Godot 生成、认领或改动任何既有 `.gd.uid`/`.import` sidecar。Task39 没有新增 GDScript，继续禁止创建或纳入任何 `.gd.uid`。

## 5. 非目标与禁止

- 不改 RunSession/RunDirector/RuntimeSkillLoadout/经济/等级/槽位规则、RunFlow、房间、敌群或资源。
- 不做触摸拖拽、手柄虚拟拖拽、复杂动画、自动吸附历史、拖拽撤销栈或新的 UI 架构。
- 不移除真实冷却、SP 不足、失败反馈或被动分区；不恢复免费奖励/经验/遗物 UI。
- 不修改 Task31 截图或历史 evidence；不使用子 Agent，不做 Git 写操作，不控制共享 Godot/editor/godot-ai。

## 6. 验证门禁（聚焦用户路径）

1. 在此前不存在的 `C:\tmp` 冷副本/独立 profile 验证；第一条 Godot 命令为 4.7.1 headless editor scan。
2. Task40 专项至少覆盖：技能卡拖至合法槽、槽到槽换位、非法主动/被动 drop、取消、一次 drop 一次 revision、点击路径继续生效、权威拒绝恢复；常态无“可用”、无紫色 BusyStrip、真实 cooldown/SP 不足/短失败仍显示。
3. 只迁移直接受影响的 Task20/24/30 HUD 断言。复跑正式 29 个接受 runner，加 Task38/Task40 的实际 runner 数由中枢串行冻结；本任务至少复跑全部当前可见正式 runner，并精确报告。Task20 `7/68` 单列、继续 `BLOCKED`。
4. `RunGame`、`TestRoom` 各 180 帧 smoke，capture 后 final rescan；正式日志五类标记 0。
5. 非 headless 真实 RunGame 生成 6–8 张即可：1920×1080、2560×1440、1366×768 的战斗 HUD；商店点击前后与拖拽前后；2560×1440 狭廊标题场景。保存前断言尺寸、phase、revision、七槽和节点可见性，逐张原尺寸检查。
6. 6–8 张截图数量保持不变；另由 Task40 专项或单个聚合 capture 对 `2560×1600`、`3840×2160`、`3440×1440` 逐档做程序化布局断言：核心 HUD 在安全区内、不越界、不因物理宽度被横向拉伸，关键文字/图标保持可读，16:10/超宽扩展战场而不移动中央关键内容。无需为每档生成多张正式截图；仅在断言失败、需要诊断时生成临时图，临时图不冒充最终证据。

不扩大为全 UI 重验或二十余张截图矩阵；以拖拽权威一致、关键状态可读和不遮挡为通过标准。

## 7. 保护、状态与自动回传

开工前固化 HEAD/status、allowlist SHA、共享 `.godot`/sidecar/进程。两个未跟踪中文协作规则文档属于保护输入，不修改、删除、认领或暂存。

开工置 `IN_PROGRESS`；完成全部门禁只置 `REVIEW` 并冻结，阻塞置 `BLOCKED`。完成或阻塞后直接 `send_message_to_thread` 回传中枢 `019fd7fd-4476-7f73-b121-76760fabf284`（hostId `local`），不得等待用户转述，不得自行 `ACCEPTED`。

## 8. 执行记录（2026-08-12）

- 正式商店已接入技能卡→槽与同类型槽→槽鼠标拖拽；原点击路径保留，两者只调用既有 `apply_shop_loadout` 权威事务。非法类型、未拥有、陈旧来源与权威拒绝均保持 revision/钱包/七槽不变并恢复权威快照。
- HUD 已隐藏常态 ready 文案、移除 BusyStrip 创建、收紧固定几何，并将 HP/SP 胶囊下移避开 2560×1440 狭廊标题；冷却、SP 不足与短失败反馈保留。
- 两枚新 `.gd.uid` 由此前不存在的 `C:\tmp\element-dungeon-task40-exec-20260812-02` 和独立 Godot 4.7.1 profile 首次 editor scan 生成，再逐文件精确复制回共享交付；没有回流其他 sidecar。
- 最终门禁使用此前不存在的 `C:\tmp\element-dungeon-task40-final-20260812-03`：31/31 runners、308 tests / 4256 assertions；Task40 4/94；Task20 单列 7/68；双 180 帧 smoke；真实 capture 1/140/7；final rescan 全部 exit 0。37 logs 五类标记均为 0。
- `2560×1600`、`3840×2160`、`3440×1440` 三档已做程序化安全区、固定宽度/不横向拉伸、中央稳定与关键可读性断言；7 张正式截图逐张原尺寸检查通过。
- 完整日志、机器汇总、截图 SHA、UID 来源与边界对账见 `docs/agent_tasks/evidence/task40/README.md`。本任务未执行 Git 写操作，未控制共享 Godot/editor/godot-ai。

## 9. 中枢验收记录（Review 6.0，2026-08-12）

- 独立 Review 以固定 HEAD + Task39/38 ACCEPTED + Task40 精确冻结叠加构建全新冷副本；候选隔离、12 个源文件、两枚 UID、既有 sidecar 与 46 个 evidence 文件逐项对账通过。
- 商店卡→槽、槽→槽换位与原点击入口均只调用一次既有权威配装事务；取消、非法类型、未拥有、陈旧来源和权威拒绝保持钱包/revision/七槽不变并恢复权威快照。购买、升级、重置、卸下和键盘焦点未回归。
- HUD 常态 ready 为空/隐藏且不创建 BusyStrip；冷却、SP 不足、短失败、键帽/icon/短名/等级/成本仍可读。`2560×1600`、`3840×2160`、`3440×1440` 程序化安全区与固定尺寸断言通过，七张原尺寸截图确认 1366 不越界、2560 狭廊标题不再与 HP/SP 胶囊重叠。
- 正式 `31/31 runners / 308 tests / 4256 assertions`，Task40 `4/94`，Task20 单列 `7/68`，双 180 帧 smoke、`1/140/7` capture 与 final rescan 全通过；37 份成功正式日志五类标记均为 0。
- 旧 runner 几何迁移的任务书矛盾已由中枢窄范围澄清，独立纯 diff 复核确认没有奖励、权威、流程或历史场景断言变化。商店正文未显式写“也可拖拽”仅记为非阻塞可发现性抛光项。
- 中枢据此将 Task40 置为 `ACCEPTED` 并归档；Task20 继续历史 `BLOCKED`，不执行 Git push。
