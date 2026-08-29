# 默认回归门禁

默认门禁只保护公开运行行为，使用 `test_batch_runner.gd` 中的显式清单执行 `core + feature`。它不会按文件名自动执行目录中新出现的 `run_*.gd`。

## 分层

| 层级 | 默认执行 | 归属原则 |
| --- | --- | --- |
| `core` | 是 | Combat/Growth 公共契约、事务原子性、Delivery/命中规则和会话隔离。不得绑定 UI 文案、私有节点路径或某一历史 Task 的默认夹具。 |
| `feature` | 是 | 仍受支持的玩家可观察功能与跨模块流程。当前保护奖励路线权威；后续功能只有在断言面向公开结果且不依赖旧兼容结构时才能进入此层。 |
| `snapshot` | 否 | 文案、节点树、尺寸/颜色/字体、视觉表现、精确内容数值和默认 catalog/场景夹具。它们用于对应功能或美术任务的定向验收，不阻塞普通生产修改。 |
| `archive` | 否 | 旧 Agent/Task 兼容结构、退役夹具、保护性历史入口和性能报告。仅在追查历史或迁移相关结构时定向运行。 |

当前 55 个 `run_*.gd` 均在入口清单中且只有一个归属：`core=6`、`feature=1`、`snapshot=25`、`archive=23`。默认清单为 7 个 runner、82 tests、430 assertions。历史精确断言没有删除；它们已移出默认门禁并归入 `snapshot` 或 `archive`。包含公开行为与历史私有绑定的混合 runner 整体归入非默认层，直至另案拆分。后续新增 runner 必须经评审后手工加入一个层级。

## 命令

项目只使用 Godot 4.7.1。外层进程必须显式提供唯一日志；批量入口还会在 `.godot/regression-gate-logs/<本次运行>/` 为每个 Godot 子进程创建独立日志。

```powershell
$godot = 'C:\Users\heliashi\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'

# 默认零失败门禁：core + feature
& $godot --headless --path . --log-file .godot/regression-default.log --script res://combat/tests/test_batch_runner.gd

# 查看完整归属，不运行测试
& $godot --headless --path . --log-file .godot/regression-list.log --script res://combat/tests/test_batch_runner.gd -- --list

# 定向运行，可重复传 --tier
& $godot --headless --path . --log-file .godot/regression-snapshot.log --script res://combat/tests/test_batch_runner.gd -- --tier=snapshot

# 全部历史入口；snapshot/archive 的失败不属于默认门禁失败
& $godot --headless --path . --log-file .godot/regression-all.log --script res://combat/tests/test_batch_runner.gd -- --all

# 清单维护检查；有未归类 run_*.gd 时失败，但不会执行它
& $godot --headless --path . --log-file .godot/regression-manifest.log --script res://combat/tests/test_batch_runner.gd -- --list --strict-manifest
```

默认运行发现未归类文件时只输出 `UNLISTED (not executed by default)`，不执行也不因此失败；维护者可用 `--strict-manifest` 把归类遗漏转成显式失败。清单中的文件缺失或重复归属始终视为配置错误。

## 断言边界

若一个默认层 runner 同时包含公开行为与以下绑定，应先拆分或把整份 runner 降到 `snapshot/archive`，不可用历史精确断言阻塞默认门禁：

- 展示文案或错误字符串的逐字匹配；
- `get_node()` 路径、私有字段/方法、具体子节点类型；
- 已退役兼容入口或旧 Task 内部结构；
- 默认 catalog、默认场景、默认商品/奖励集合的精确排列与数量；
- 像素位置、尺寸、颜色、字体、动画帧和性能基线。

默认层可以检查稳定公开标识、结构化状态/拒绝原因、事务结果、公开信号以及玩家可观察的最终行为。
