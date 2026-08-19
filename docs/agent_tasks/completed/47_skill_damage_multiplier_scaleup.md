# 任务 47：所有技能伤害倍率统一上调为原值的 1.5 倍

状态：CANCELLED_BY_USER
负责人：独立执行任务（中枢派发）
依赖：任务 46（ACCEPTED）
Git 基线：`main` HEAD `fc7b531`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L2
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级触发：发现清单外生产技能伤害倍率、必须修改 allowlist 外文件、伤害公式/公共接口变化、随机不稳定或性能问题时立即停线回传，不得自行扩项。

## 1. 冻结需求与目标值

把生产资源中所有技能伤害贡献倍率改为原值的 `1.5` 倍。覆盖直接倍率、每能量倍率、每层倍率和技能内容等级 `damage_scale`；不覆盖治疗量、基础攻击力、元素反应倍率、敌人伤害或测试夹具。

1. `resources/element_bolt.tres`：`damage_multiplier 1.0 -> 1.5`
2. `resources/element_slash.tres`：`damage_multiplier 0.5 -> 0.75`
3. `resources/skills/elemental_laser.tres`：`damage_multiplier 0.5 -> 0.75`
4. `resources/skills/elemental_fury.tres`：`damage_multiplier_per_energy 0.08 -> 0.12`
5. `resources/skills/burning.tres`：`damage_multiplier_per_layer 0.05 -> 0.075`
6. `resources/skills/fire_lance.tres`：`damage_multiplier 1.4 -> 2.1`
7. `resources/skills/water_lance.tres`：`damage_multiplier 1.4 -> 2.1`
8. `resources/content/skills/element_bolt_content.tres`：全部 `damage_scale 1.25 -> 1.875`、`1.55 -> 2.325`
9. `resources/content/skills/elemental_laser_content.tres`：全部 `damage_scale 1.2 -> 1.8`、`1.45 -> 2.175`
10. `resources/content/skills/elemental_fury_content.tres`：全部 `damage_scale 1.2 -> 1.8`、`1.45 -> 2.175`

`resources/skills/unending.tres` 只有治疗字段，明确不改。旧/占位生产技能资源仍属于“所有技能”，不得自行排除。

## 2. 执行前漏项门禁

先只读扫描 `resources/` 中 `damage_multiplier`、`damage_multiplier_per_*`、`damage_scale` 及等价生产技能伤害系数，与上述十项逐项对账。发现额外生产倍率时停止并回传中枢补写任务书；测试夹具同名字段仅记录。

## 3. 精确 allowlist

1. 上述十个 `.tres`，仅对应倍率字段
2. `combat/tests/run_skill_content_catalog_tests.gd`
3. `combat/tests/run_skill_execution_contract_tests.gd`
4. `combat/tests/run_passive_runtime_contract_tests.gd`
5. `combat/tests/run_combat_tests.gd`
6. `combat/tests/capture_task27_skill_level_visual.gd`
7. `growth/tests/run_task27_run_economy_progression_tests.gd`
8. `combat/tests/run_task27_skill_level_effect_tests.gd`
9. `combat/tests/run_task34_projectile_cast_transaction_tests.gd`
10. `docs/agent_tasks/pending/47_skill_damage_multiplier_scaleup.md`
11. `docs/agent_tasks/evidence/task47/**`

测试文件仅可更新本任务直接影响的旧生产倍率预期常量或断言；新增的三处授权分别限于元素弹 Lv2/Lv3 `damage_scale` 与 Fury 生产执行倍率的旧值断言。若需改变测试控制流、公共夹具或框架则升级。

## 4. 禁止项

不改伤害计算、技能控制流、公共接口、场景、UI、输入、资源结构或 UID；不处理 Task 20/48；不删除、暂存、认领共享未跟踪产物；不连接、关闭或控制共享 Godot/editor/godot-ai；不执行 Git 写操作，不 push，不自行 `ACCEPTED`。

## 5. L2 验收

1. 十项目标值和生产漏项扫描完全对账。
2. 在全新隔离副本与独立 profile 运行直接相关专项及影响域 runner，回填命令、退出码、tests/assertions、日志标记。
3. 证明治疗、基础攻击、反应倍率、敌人伤害及非目标资源未变。
4. 执行开始改为 `IN_PROGRESS`，交付改为 `REVIEW`；中枢独立验收后才能 `ACCEPTED`。

## 6. 串行约束

Task 48 在 Task 47 独立 Review 与 Git 检查点完成前不得启动，避免共享项目同时出现两组候选 overlay。

## 7. 中枢范围对齐（2026-08-13）

- 首轮执行在生产漏项扫描后发现三个 allowlist 外 runner 冻结旧生产倍率，按升级触发正确停线；十个生产资源和测试均未修改。
- 中枢确认三者均为本需求的直接依赖断言，已精确加入 allowlist，并仅授权更新对应旧生产值；这不构成公共接口、控制流或需求范围扩张。
- Task 47 恢复为 `IN_PROGRESS`；继续使用 `gpt-5.6-sol`、thinking=`high`。Task 48 继续强串行冻结。

## 8. 用户撤销（2026-08-13）

- 用户明确决定不再修改技能伤害倍率，中枢立即停线并取消 Task 47。
- 执行者确认十个生产资源、全部测试/capture、Task 48 文件均为零修改；未创建 evidence、冷根、profile，未启动 Godot/runner 或执行 Git 写操作。
- 本任务未形成任何游戏候选，无需回退生产文件；任务书仅作为取消审计记录归档，不得标记 `ACCEPTED`。

## 7. 执行阻塞回填（2026-08-13）

- 实际执行模型：`gpt-5.6-sol`，推理等级：`high`。
- 生产资源漏项扫描：`resources/` 中 `damage_multiplier`、`damage_multiplier_per_*`、`damage_scale` 共命中任务书列出的十个生产文件，无清单外同类生产倍率。广义扫描额外命中 `passive_balance.tres`、`passive_focus.tres`、`reaction_focus.tres` 的 `attack_multiplier`；调用链确认它们是基础攻击属性被动或反应触发临时攻击属性，属于本任务明确排除项。
- 阻塞原因：至少三个 allowlist 外 runner 直接消费将被修改的生产资源并冻结旧倍率。`growth/tests/run_task27_run_economy_progression_tests.gd` 断言元素弹 Lv2/Lv3 `damage_scale = 1.25/1.55`；`combat/tests/run_task27_skill_level_effect_tests.gd` 通过生产 Fury 执行资源断言 `damage_multiplier = 1.6`；`combat/tests/run_task34_projectile_cast_transaction_tests.gd` 通过生产 catalog 断言最小 Fury `damage_multiplier = 1.6`。实施目标倍率后这些断言会确定性失效；修改它们又违反精确 allowlist。
- 处置：按“必须修改 allowlist 外文件立即停线回传”升级触发冻结。未修改十个生产资源、未修改任何测试、未创建验证副本、未运行 Godot/runner、未触碰 Task 48 文件、未执行 Git 写操作。
- 需要中枢决定：把上述三个直接依赖 runner 加入 Task 47 allowlist 并重新派发，或明确这些既有 runner 的处置口径；在任务书修订前不得继续实现。
