# 局内战斗配装页面（L）视觉简化

目标：按 L 打开的局内“战斗配装页面”（`RunOverlayInterface._show_formal_combat_loadout`，`scripts/ui/run_overlay_interface.gd:1481`）去掉说明性文案，改成纯视觉表达；“本局已拥有技能 / 主动槽 / 被动槽”结构不变，但每个技能改为图标 + 名称 + 等级角标的卡片呈现。具体：

1. 标题简化为“战斗配装页面”，副标题（原“清场后可调整 · 直接提交权威 RuntimeLoadout，不创建商店草稿”）整行去掉。
2. 门禁提示（“✓ 当前房已清场…” / “战斗进行中 · 清场后可调整”）和底部状态行的初始文案去掉，改用面板整体变暗（modulate alpha）+ 边框变灰 + 按钮 disabled 灰态来表达“当前不可操作”，不使用任何解释性文字。
3. “本局已拥有技能”库存列表与“主动槽/被动槽”槽位统一改为卡片：图标（技能贴图）+ 居中技能名称（超长省略）+ 等级角标（仅主动技能显示“Lv.N”，被动技能不显示角标）。选中态用边框高亮表达，不再用“◆ ”文字前缀。
4. 空槽（未装备任何技能）完全空白，不放置“空槽”字样、槽位编号或任何占位图标。

范围：只改 `scripts/ui/run_overlay_interface.gd` 中 `_show_formal_combat_loadout` 本体，以及为它专门新增的渲染函数（`_combat_loadout_skill_card`、`_combat_loadout_slot_zone`）。不得修改 `_formal_slot_zone`、`_formal_section_panel`、`_formal_action_button`、`_build_formal_shop_card` 等被商店页（`_show_formal_shop`）、路线页、结算页共用的函数，保证除配装页外其它 formal 面板零改动、零回归。点击/拖拽/卸下的权威提交逻辑（`_formal_press_slot`、`_formal_slot_drop`、`_formal_clear_selected_slot` 等）不改动，只改它们驱动的视觉呈现。

因删除文案导致断言失效的两处测试需要同步改为断言按钮 `disabled` 状态（而非文案内容）：

- `combat/tests/capture_task43_combat_loadout_world_cleanup_visuals.gd` 第 32、56 行
- `growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd` 第 157、189 行

`docs/design/元素地牢_局内构筑与关卡流程实现契约.md` 第 1023 行对门禁提示文案的描述需同步改写为“视觉状态（变暗 + disabled）”，不改变门禁行为本身（清场前只读、清场后可点击/拖拽、权威事务规则不变）。

完成：页面标题只显示“战斗配装页面”，页面上不再出现“主动1-3”“被动1-4”“清场后可调整”一类说明性小字；已拥有技能与主动/被动槽均以图标+名称+等级角标的卡片呈现，空槽干净留白；战斗未清场时整个技能面板通过变暗与按钮 disabled 直接体现“不可操作”，清场后恢复正常可交互外观，点击/拖拽/卸下的权威提交行为与现有实现完全一致；商店页、路线页、结算页等其它 formal 面板的渲染代码与外观零改动；上述两个测试文件的断言迁移后全绿；设计契约文档第 1023 行同步更新。

---

验收备注：`growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd` 已跑通（4 tests, 105 assertions PASS），断言迁移覆盖到位。`combat/tests/capture_task43_combat_loadout_world_cleanup_visuals.gd`（截图回归，含新版页面截图）在验收时仍在后台运行、尚未拿到结果；用户已在游戏内实测确认效果符合预期，因此按用户指示直接验收，截图回归结果留待后续补充确认。DONE。
