# Agent D 新任务书：共享技能栏、成长系统与正式场景集成

状态：ACCEPTED
负责人：Agent D
依赖：06、08、09 均完成 Review 并验收通过

## 1. 任务定位

把成长域、共享 3+1 技能栏、CurrentElement、被动注册和锁定 Delivery 接入正式 Player、Enemy 与房间流程。本任务完成数据流和可玩闭环，完整 HUD/配装视觉由下一份 D 任务负责。

## 2. 开工前检查

- 确认 E/B/C 依赖任务均已 Review 验收通过。
- 若 player.gd、player.tscn、技能 Resource 或动画正由其他任务修改，先报告协调者，不得覆盖。
- 阅读 docs/design/共享技能槽与元素释放规则.md。

## 3. 独占范围

可以修改：

- scripts/player.gd
- scripts/enemy.gd
- scripts/test_room.gd
- 与 RunSessionHost、PlayerGrowthAdapter、ElementEventBridge、PassiveEffectAdapter 相关的新 scripts/**
- scenes/player.tscn
- scenes/enemy.tscn
- scenes/test_room.tscn
- 本轮正式内容 Resource 与集成测试
- project.godot 中本任务需要的 InputMap 动作和窄场景配置

不得修改 growth 核心、Agent B 技能契约、Agent C Delivery 内部、Agent A Resolver 或 completed 文档。

## 4. 正式数据流

- 每局创建一个明确归属的 RunSessionHost，不使用永久全局单例保存本局状态。
- RuntimeLoadoutPort 实现/适配 Agent E 的共享 slot_id → skill_id 快照。
- Player 的三个主动输入动作始终请求 ACTIVE_1～3；普通攻击保持在共享栏之外。
- 被动位置没有释放按键。
- InputMap action 与 UI 显示解耦，脚本不得硬编码具体键帽文本。
- CurrentElement 变化由桥接层转换为 Agent E FormChangedEvent，完整映射 MANUAL / SKILL_AUTO、sequence 和 timestamp。
- CombatResult、击杀、房间完成继续只在提交后投影给成长域。
- 元素变化不能改写 Runtime Loadout。

## 5. 被动与遗物接入

- PassiveEffectAdapter 与 Relic GrowthEffectPort 使用窄接口访问生命、能量和临时攻击修正。
- 每个装备被动只注册一次；active slot 中的 passive 同样注册。
- 换装提交整体更新注册，外部不能观察到新旧效果同时生效。
- 死亡、重生、换层、重载新局不重复叠加。
- 监听元素变化的效果必须声明响应 ALL / MANUAL_ONLY / SKILL_AUTO_ONLY。
- 同元素专属技能不产生事件，因此不能刷切换收益。

## 6. 房间、奖励和商店

- 第一战固定技能奖励，后续技能/遗物路线沿用 RunDirector。
- 商店只编辑共享四槽 ShopDraft，不再显示水火两套 Loadout。
- 使用 Agent B 的一次性迁移器读取旧元素独立配置；成功后只保存新格式。
- 0 主动 + 4 被动能够确认、进入战斗、换层和重建。
- 领取专属技能后可以装备；其自动切换发生在实际释放接受时，不发生在装备或领取时。
- 角色等级、属性点和 PlayerGrowthAdapter 继续遵守上一轮成长规则。

## 7. 输入与状态

- 手动元素切换继续使用独立 InputMap action，不耗能、不占槽。
- Player 根据当前动作状态决定即时请求或交给 Agent B 缓冲接口。
- 失败释放只处理结构化失败，不播放自动切换反馈。
- 受击、死亡、暂停和换层按契约清理缓冲与被动注册。
- 已接受攻击和已生成攻击不能被后续手动切换污染。

## 8. 必测用例

- 正式 Player 只有一个共享 Runtime Loadout 和一个 CurrentElement 状态源。
- 三个主动 action 在水火状态下始终解析同一 skill_id。
- ACTIVE 位置中的 PASSIVE 按键不释放、不扣能、不进冷却。
- 0 主动 + 4 被动可保存、载入、进入战斗并完成房间。
- 专属技能失败不切换，接受成功才自动切换。
- 手动/自动事件来源桥接和遗物过滤正确。
- 同元素专属连续施法不刷事件收益。
- 通用投射物在切换后保持锁定元素。
- 被动死亡、重生、换层、读档后不重复注册。
- 旧配置迁移后只有共享格式。
- 成长、战斗、技能、Delivery 全部回归测试通过。
- 主场景 headless smoke test 无脚本错误。

## 9. 交付

- 报告测试结果、修改文件清单和剩余限制。
- 不执行任何 Git 命令；由用户统一提交。

## 10. Agent D 实施证据（2026-07-22）

- 房间级 `RunSessionHost` 已接通共享 `RuntimeSkillLoadout`、`CurrentElement` 事件桥、成长/被动适配、提交后战斗事件、击杀、房间完成与首战技能奖励。
- 正式 Player 使用 `ACTIVE_1～3` 三个动作；普通攻击独立于共享栏；被动槽没有释放动作。
- 已加入水/火专属主动技能、四个被动、六项技能奖励元数据和三件正式遗物资源。
- 正式 `RunSessionHost` 统一经 `SharedLoadoutPersistenceAdapter` 恢复模板、保存快照或旧配置迁移；换装后同步保存，正式房间重载会传回共享快照。
- 敌人事件身份使用“内容 ID + 房间内实例路径”，同房间多个 `orc_1` 可分别结算击杀并完成房间。
- 已覆盖 ACTIVE_1～3 在水火状态下逐一释放且技能身份不变、失败释放不切元素、成功释放自动切换、同元素不重复触发、主动槽被动不可释放、被动生命周期、旧配置一次性迁移及 `0 主动 + 4 被动` 正式载入/双敌战斗闭环。
- 任务 10 专项：10 tests / 121 assertions，全通过。
- 全量回归：12 个入口，143 tests / 887 assertions，全通过。
- 主场景 headless smoke：退出码 0，无脚本错误。
- 未执行任何 Git 命令；状态仅推进到 `REVIEW`，等待用户/协调者验收。
