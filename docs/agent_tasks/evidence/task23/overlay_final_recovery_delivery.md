# 任务23 Overlay 最终基线纠正恢复交付记录

状态：`REVIEW`（仅执行者静态交付；不得据此自行 `ACCEPTED`）

日期：2026-07-31  
执行者：Overlay Final Recovery Agent 1.0

## 1. 结论

任务23严格恢复了且仅恢复了 `scripts/ui/run_overlay_interface.gd`。当前工作区 Overlay 的原始字节精确等于任务12最终不可达Git blob `b98a9c223f87caa983bb97d14639d73c62957337`：26785字节，SHA-256 `e30e02d82ddecd6056f06a72683b7e5641013e09a8531e6be2837d7be23f6b68`。

当前错误对象 `2ca3b5792890357e802fac6b86b6ed8358d1c153` 已在覆盖前作为现场和原始blob保存在全新工作区外只读胶囊中；它只作为任务12创建态历史保留，未作为终态、补丁来源或写入来源。写入没有人工拼接、没有从聊天文本重建、没有只改两处snapshot，也没有从任务20代码反向删除增量。

执行侧未启动或连接任何Godot，未运行测试、scan、smoke、截图或导入；未执行任何Git写操作、引用写入、`hash-object -w`、`gc`、`prune`或`maintenance`。

## 2. 授权与实际写入范围

协调者已发送原文“执行任务23”。任务23首先从 `PENDING` 更新为 `IN_PROGRESS`，随后完成全部对象/现场审计、胶囊、二次复核和覆盖前保护闸门。

唯一游戏文件写入：

- `scripts/ui/run_overlay_interface.gd`

允许的交付文档写入：

- `docs/agent_tasks/pending/23_recovery_task12_overlay_final_baseline.md`
- `docs/agent_tasks/pending/22_recovery_task20_ui_to_task12_baseline.md`（仅追加任务23交叉结果）
- `docs/agent_tasks/evidence/task23/overlay_final_recovery_delivery.md`

工作区外只创建任务23指定胶囊。没有更新总索引，没有修改任务22交付证据或任何其他游戏/任务文件。

## 3. 三代Overlay对象与覆盖前现场

| 角色 | Git blob | 字节 | SHA-256 | 结论 |
| --- | --- | ---: | --- | --- |
| 任务12最终目标 | `b98a9c223f87caa983bb97d14639d73c62957337` | 26785 | `e30e02d82ddecd6056f06a72683b7e5641013e09a8531e6be2837d7be23f6b68` | 唯一写入目标 |
| 任务12创建态/覆盖前错误现场 | `2ca3b5792890357e802fac6b86b6ed8358d1c153` | 27503 | `cce4473bdd09931e09afa68c8a33c05cdff2731d387dbadf726e76b4513069fd` | 禁止终态；已只读保存 |
| 任务20最终Overlay交叉证明 | `651ca094484dbc1e3b5fe6d309443d6ab14ded46` | 40829 | `9fe4f270fca47f0a4e52286f832ea50fba35bdeaafac54ebe2fc58c4672044cf` | 仅取证保护；未写入 |

三个对象覆盖前均重新确认存在、可读、类型为`blob`；对 `git cat-file blob` 原始字节独立计算字节、SHA-256和Git blob身份均命中。活体Overlay覆盖前逐字节等于新的 `2ca3…` 原始对象和胶囊现场副本。

## 4. 全新工作区外只读胶囊

绝对路径：`C:\tmp\element-dungeon-task23-overlay-final-recovery-20260731`

- 胶囊共74个文件，74/74均为Windows `ReadOnly`；`capsule_payload_manifest.tsv`之前的73个payload全部有路径、字节、SHA-256、Git blob、UTC时间和属性封存记录。
- `source_blobs/`保存 `b98a…`、`2ca3…`、`651ca…` 三份直接由只读 `git cat-file` 提取的原始字节。
- `live_before/`保存覆盖前活体 `run_overlay_interface.gd`，逐字节等于 `2ca3…`。
- 完整复制并封存任务20的35项：任务书1份、测试2份、证据32份。
- 完整复制并封存任务21的17项资源。
- 完整复制并封存CombatHUD、CombatUiTokens，以及任务22任务书/交付证据和任务23任务书；任务状态冻结为任务22 `BLOCKED`、任务23 `IN_PROGRESS`。
- 任务22原胶囊只读清单为13项，13/13均保持只读且逐项未变；任务23没有修改、补写或复用旧胶囊。
- 共享`.godot`清单为652项；任务23允许范围外共享工作区清单为1770项。
- 覆盖前 `git status --short --untracked-files=all` 为971行；Git引用只读快照为2行。

在全部胶囊文件设为只读后进行了第二次独立复核：74/74只读、三个对象、活体现场、35/17/2/3份保护副本、旧胶囊13项、`.godot`652项、工作区1770项、Git状态与引用全部通过。

## 5. 精确恢复

覆盖事务开始前再次确认：

- 胶囊仍为74/74只读；
- 允许范围外1770项、任务22旧胶囊13项、任务22/23文档现场、Git状态与引用均未漂移；
- 活体Overlay仍逐字节等于 `2ca3…` 和胶囊现场；
- 新一次只读 `git cat-file blob b98a…` 与胶囊目标逐字节相等，且身份为26785字节、指定SHA-256和指定Git blob。

写入直接使用该次 `git cat-file blob b98a…` 捕获的原始字节，经内存逐字节对账后用二进制写入唯一目标。写后立即读取并复核：

| 文件 | 写前 | 写后 |
| --- | --- | --- |
| `scripts/ui/run_overlay_interface.gd` | `2ca3b5792890357e802fac6b86b6ed8358d1c153` / 27503 / `cce447…69fd` | `b98a9c223f87caa983bb97d14639d73c62957337` / 26785 / `e30e02…f6b68` |

写后字节与刚读取的目标blob逐字节相等；没有部分覆盖或编码/换行转换。

## 6. 第8节静态语义验收

- Overlay身份：`b98a…`、26785字节、指定SHA-256，全部通过。
- `result.run_snapshot`恰好2处；`result.snapshot`为0处。
- `const UI := preload("res://scripts/ui/combat_ui_tokens.gd")`恰好1处；`UI.`别名恰好69处。
- `_slot_drop`中的 `StringName(data.get("skill_id", &""))` 类型转换恰好1处。
- 槽位标题使用 `PASSIVE_1 · 仅被动` 与 `String(slot_id).to_upper()`；最终模式恰好1处。
- `skill_name_label`修正为4处引用；旧局部变量遮蔽未恢复。
- `_slot_drag_data`使用 `_working_loadout.get_skill_id(slot_id)`，并显式执行空ID `return null` 后返回拖拽字典；最终模式恰好1处。
- 奖励→路线→商店链的 `claim_reward`、`choose_route`、`open_shop_draft`、`preview_loadout`、`confirm_shop` 五项调用均存在；权威规则未复制或修改。
- `2ca3…`仅保留在只读胶囊与历史记录，不是工作区终态。

## 7. 恢复后保护对账

- 任务20不可改35/35零差异。
- 任务21资源17/17零差异。
- CombatHUD保持 `661d017c4bb2025541deb09d72ec55bf5a12594f`；CombatUiTokens保持 `78751a2d90c88f6457861717b7781c1d8179d278`。
- 任务22旧胶囊13/13零差异且仍全部只读。
- 共享`.godot`652/652零差异。
- 排除任务23明确允许路径后的共享工作区1770/1770，路径、字节、SHA-256、Git blob、UTC时间与属性零差异。
- 覆盖后、写交付文档前，完整Git状态仍为971行且与胶囊逐行一致；Git引用2/2不变。
- 任务23胶囊仍为74/74只读。

## 8. 工具层异常与边界

- 内置`apply_patch`更新既有任务书时继续遭遇Windows沙箱登录错误；状态/追加记录使用带唯一前置断言的UTF-8写入，仅作用于允许文档。
- 第一次对象现场比对因PowerShell泛型 `SequenceEqual` 重载解析失败而在写入前中止；改用显式逐字节循环后通过。
- 第一次胶囊创建命令因对象清单表达式多余分号而在PowerShell解析阶段中止，目标路径尚未创建；修正后一次完整创建成功。
- 第一次静态验收对槽位/拖拽函数使用了过度严格的格式正则，产生检查器假阴性；只读展开 `b98a…` 实际函数后按精确终态结构复核通过。Overlay对象身份始终命中。

上述异常均发生在对应写入前或只读检查器中，没有造成额外项目写入、部分恢复、旧胶囊变化、Godot运行或Git写入。

## 9. Review移交

任务23只到 `REVIEW`，执行者不自验收、不归档、不运行Godot、不评估提交。协调者必须创建全新独立Review，在新的 `C:\tmp` 冷副本中把Godot 4.7.1 headless editor scan作为第一条Godot命令，再按任务书执行任务12/16/18专项、18/18 runners与224/1683、任务20非门禁诊断、180帧smoke、任务12九类实际Viewport证据及共享区最终不变性。

任务23独立Review通过前，任务22/23不得归档，禁止机械提交或创建Git检查点。
