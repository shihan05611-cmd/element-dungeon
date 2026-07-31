# Agent D 3.0 任务书：首批 VFX 正式接线与表现运行时

状态：ACCEPTED
负责人：Agent D 3.0
协调线程：`019fb324-d4d7-7010-b87c-967ba9338e3b`（Agent D 3.0：首批 VFX 正式接线）
依赖：15_agent_c_first_batch_deliveries、16_agent_d2_skill_content_catalog、17_vfx_agent_first_skill_assets 已通过 Review
互斥：12_agent_d_hud_loadout_feedback 保持 PENDING；任务 18 验收前不得与其并行修改 TestRoom 或表现接线

## 1. 任务定位

将任务 17 已验收的稳定图标和 VFX 资产接入任务 16 的正式内容目录与运行时表现层。所有表现只能观察已提交快照、成功事件和正式 Delivery 信号，不拥有战斗、成长、目标查询、费用或碰撞规则。

本任务是新的窄范围接线任务，不重开任务 16，也不修改任务 15 已冻结的空间行为。

## 2. 冻结输入

- 总清单：`docs/vfx/final_asset_manifest.md`。
- 每技能参数：`assets/generated/vfx/<skill_id>/manifest.md`。
- 任务 17 稳定资产为只读输入，不得重绘、改名、覆盖或重新生成。
- Fury 权威半径为信号提供的 96～192；Beam 为 320×24、每 0.5 秒权威 Tick；Reclaim 查询半径为 160。
- 动态元素表现必须使用本次施法锁定元素；不得在播放时读取实时 CurrentElement。

## 3. Catalog 与纯表现资源

- 六个可获取技能的 `SkillContentDefinition.icon` 指向对应稳定 `icon.png`；固定普通攻击 `element_slash` 不伪用元素弹图标。
- 为 Fury、Laser、Reclaim、Burning、Unending 建立纯视觉 presentation 场景或等价 Resource，并接入对应 `presentation_scene`。
- 元素弹继续使用既有 `element_projectile_frames.tres` 和 `element_projectile.tscn`；不得复制第二套投射物运行时。其内容图标正常接入，presentation 字段是否留空必须在说明中明确。
- Fury/Laser 的 `runtime_delivery_scene` 仍指向任务 15 的逻辑 Delivery；不得用 presentation 场景替换。
- 所有 SpriteFrames、材质、Shader、粒子参数和动画资源置于新的 `resources/vfx/**` 或 `scenes/vfx/**`，不能写回任务 17 的源资产目录。

## 4. 主动技能表现接线

### 4.1 元素之怒

- 观察 `ElementRageDelivery.burst_submitted(origin, radius, target_count)`，按信号半径缩放并只播放一次 8 帧爆发。
- 决定性帧与 `burst_submitted` 对齐；表现不得产生 HitRequest、额外命中窗或延迟逻辑提交。
- 结束、取消、离树和换层时无残留节点。

### 4.2 元素激光

- 使用 5 个 64×24 段组成 320×24，不把纹理宽高作为碰撞来源。
- 跟随 Beam 的锁定方向和当前世界起点，保持穿透表现，不在首个目标处截断。
- 每次 `tick_submitted` 只做亮度脉冲和合法目标命中闪光；不得自建 0.5 秒伤害时钟。
- `delivery_finished`、取消、死亡、离树和换层后立即清理 Beam 与 Tick 子表现。

### 4.3 元素回收

- 仅在原子回收事务成功提交后播放；满能量、无匹配层、目标失效或事务拒绝时不得播放成功 VFX。
- 若现有事件缺少目标位置，使用 `scripts/vfx/**` 中的表现端口/事务装饰器包装正式回收端口：委托原事务完成验证与提交，仅在成功发布后暴露只读目标位置和锁定元素。不得复制查询、能量或层数规则。
- 每个成功目标生成 2～4 个对应元素粒子，从目标视觉中心飞向玩家，建议 0.30～0.48 秒；最后粒子到达后播放一次汇聚闪光。

## 5. 被动表现接线

- Burning：仅在被动实际注册且敌人火层大于 0 时显示敌人附着循环；确认的一秒伤害 Tick 播放 `burning_tick`。
- Unending：仅在被动实际注册且敌人水层大于 0 时显示敌人附着循环；固定普通攻击成功回血事件播放 `unending_trigger`。
- 两者均固定火/水语义，不读取玩家 CurrentElement，不根据层数重复创建循环节点，不暗示或执行层数消耗。
- 配装替换、目标层数归零、敌人死亡/释放、玩家死亡、换层、读档和新局时原子清理或重建；不得重复注册、重复显示或保留悬空 WeakRef。

## 6. 表现架构与生命周期

- 新建独立的 `SkillVfxCoordinator` 或等价表现协调器，由 TestRoom 以单一入口配置 Player、Host/Runtime 和敌人。
- 优先监听 `delivery_created`、提交后事件、Runtime loadout 快照和 `ElementCarrier.elements_changed`；不得轮询并猜测战斗规则。
- 如需在 `Player` 或 `PassiveEffectAdapter` 增加信号，只允许发布已成功提交的只读表现事件，不能改变原方法返回值、提交顺序或失败语义。
- 表现节点可池化，但复用必须清空元素、帧、目标、Tween、信号和父节点状态。
- 所有新增逻辑必须在 headless 环境安全；缺少可视视口时不得影响战斗流程。

## 7. 文件范围

可以修改：

- `resources/content/skills/*.tres`，仅六技能的 `icon` / `presentation_scene` 字段
- 新建 `resources/vfx/**`
- 新建 `scenes/vfx/**`
- 新建 `scripts/vfx/**`
- `scripts/player.gd`，仅接入表现事件或回收表现装饰端口
- `scripts/passive_effect_adapter.gd`，仅增加提交后表现事件
- `scripts/test_room.gd`、`scenes/test_room.tscn`，仅配置单一 VFX 协调器
- `scenes/player.tscn`，仅在确有必要时增加纯表现节点
- 任务 18 专项测试、截图和接线说明

不得修改：

- `assets/generated/vfx/**` 与 `docs/vfx/**` 的任务 17 最终资产及 QA 证据
- `combat/**` 中的 SkillExecutor、Execution、Delivery、Targeting、Carrier、Receiver、Resolver 或契约
- `growth/**`、RunSession、奖励、商店和遗物规则
- `scripts/run_session_host.gd`
- `scripts/combat_hud.gd`、`scripts/combat_feedback.gd`、HUD 场景或任务 12 的界面范围
- 碰撞形状、逻辑范围、伤害、元素层数、费用、冷却、Tick 和移动策略

若缺口只能通过修改禁止文件解决，停止并提交 Review 说明，不得自行越界。

## 8. 自动与视觉验收

- Catalog 六技能图标路径准确；presentation 场景均可实例化且不含碰撞体、伤害脚本或战斗规则。
- 元素之怒 96/192 半径缩放正确、一次提交只播放一次；切换实时元素不改变已生成表现。
- 激光严格 320×24，穿透显示；0.49/0.50/1.00 秒只响应权威 Tick；结束后无残留。
- 回收成功时每个目标从敌人到玩家播放；无目标、满能量和事务失效时零成功表现。
- Burning/Unending 的注册、层数条件、固定元素、Tick/回血触发及死亡/换层/读档清理正确。
- 元素弹继续使用既有 SpriteFrames 与场景，无第二套投射物或回归。
- 在 1152×648 TestRoom 深色背景完成实际运行截图；主体不遮挡角色/敌人，范围不反向改变逻辑。
- 任务 16 专项、任务 15 专项、全量无头入口、Godot editor scan 和至少 180 帧主场景 smoke 全部通过，无新增脚本错误或 warning。

## 9. 交付

- 报告 Catalog 字段、presentation 场景、表现协调器、所有信号和清理路径。
- 提供“技能 → 稳定资产 → presentation 场景 → 权威事件 → 生命周期”的对照表。
- 报告专项、全量、editor scan、smoke 和实际运行截图。
- 报告任务 12 可继续消费的图标/表现状态，但不得修改任务 12 文档。
- 不执行任何 Git 命令，不自行把任务标为 `ACCEPTED`。
- 完成后把本任务更新为 `REVIEW` 并向协调线程回传，由协调者独立验收。
## 10. 协调者下发记录（2026-07-30）

- 已新建独立 Agent D 3.0 任务并直接下发，线程：`019fb324-d4d7-7010-b87c-967ba9338e3b`。
- 任务 17 已独立验收并归档；冻结输入基线为 25 个最终 PNG、Laser alpha 遮罩 4/4 精确一致、Stage 2 QA 0 failures。
- 任务 16 已验收基线保持为 16 个无头入口、202 tests / 1449 assertions；任务 15 专项保持 26 tests / 163 assertions。
- Agent D 3.0 须在同一共享工作区实施，不执行 Git；完成后只提交 `REVIEW`，由协调者独立运行测试、检查边界与视觉证据后决定是否 `ACCEPTED`。
- 任务 12 继续保持 `PENDING`，任务 18 验收前不启动。
## 11. Agent D 3.0 交付记录（2026-07-30）

- 六个可获取技能已接入任务 17 稳定图标；Fury/Laser/Reclaim/Burning/Unending 已接入纯视觉 `presentation_scene`，Element Bolt 明确保留空 presentation 并继续复用既有投射物场景与 SpriteFrames。
- 新增单一 `SkillVfxCoordinator`，由 TestRoom 在 Host 配置完成后以 Player、Runtime/被动适配器和敌人列表配置。Fury/Laser 只监听正式 Delivery；Reclaim 由表现事务装饰器在正式原子事务发布成功后发只读事件；Burning/Unending 只观察实际注册、Carrier 变化和提交后事件。
- 未修改 Player、PassiveEffectAdapter、RunSessionHost、HUD、growth 或任何 combat gameplay 文件；未改变费用、事务、冷却、Channel、命中、范围、Tick、层数消费、碰撞或移动语义。
- 专项：任务 18 `9 tests / 124 assertions`；任务 15 `26 / 163`；任务 16 `11 / 209`。
- 全量：17/17 个无头入口通过，合计 `211 tests / 1573 assertions`。
- Godot 4.7.1 最终 editor scan 退出码 0；180 帧主场景 smoke 退出码 0。连接编辑器实际运行 game log 无错误；editor 中仅有任务 18 之前已存在且不指向本任务文件的 combat/growth warning。
- 1152×648 实际 TestRoom 证据与完整“技能 → 资产 → 场景 → 权威事件 → 生命周期”对照表见 `docs/agent_tasks/evidence/task18/README.md`，截图为 `fury_192_runtime.png`、`laser_fire_tick_runtime.png`、`reclaim_water_runtime.png`、`passives_enemy_attached_runtime.png`。
- 任务 12 后续可直接从 Catalog 消费六技能图标与五项 presentation；本任务未修改任务 12 文档或 HUD。
- 遗留风险：Reclaim 表现装饰器只读消费任务 15 已冻结事务内的目标计划，因为 combat 冻结契约未公开表现目标 accessor；若未来替换该具体事务表示，需要同步复核装饰器。当前专项覆盖失败零表现、成功目标位置、锁定元素及原子消费不回归。
- 未执行任何 Git 命令；本任务只更新为 `REVIEW`，未自行标记 `ACCEPTED`。
## 12. Review 最终验收（2026-07-30）

- 文件边界通过：近期实现变更仅落在任务书允许的 `scripts/vfx/**`、`scenes/vfx/**`、`resources/vfx/**`、六份内容资源的图标/表现字段、TestRoom 接线及专项测试/证据；未发现对任务 17 源资产、HUD、growth、Host 或 combat gameplay/Delivery/Targeting 契约的越界修改。
- 协调者独立复跑任务 18 专项 `9 tests / 124 assertions`、任务 15 专项 `26 / 163`、任务 16 专项 `11 / 209`，全部通过。
- 协调者独立复跑全部 17 个无头入口，合计 `211 tests / 1573 assertions`，0 failed。
- Godot 4.7.1 headless editor scan 与 180 帧主场景 smoke 均退出码 0；连接编辑器重新扫描后实际运行，当前 run 的 game log 仅 helper 注册信息，editor 增量日志无错误。
- 协调者在 1152×648 实际 TestRoom 中独立复核：Fury 192 半径按 `4.5×` 展示；Laser 为五段连续 320×24 Beam；Reclaim 三粒子沿敌人到玩家曲线运动；Burning/Unending 同时附着时敌人轮廓仍可辨认。
- Element Bolt 继续复用原投射物；Fury/Laser 仍使用任务 15 正式 Delivery；动态元素均锁定施法快照。未发现额外命中窗、表现时钟、查询、能量或层数规则。
- 接受 Reclaim 表现装饰器对任务 15 `_target_plans/_receiver_ref` 的只读耦合为已记录技术债；它只在正式事务成功 publish 后读取位置，当前失败零表现与原子语义均有专项及任务 15 回归覆盖。
- 结论：任务 18 通过 Review，状态更新为 `ACCEPTED` 并归档；任务 12 前置依赖解除。