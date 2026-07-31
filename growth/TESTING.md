# Growth 测试清单

使用 Godot 4.7.1，在项目根目录依次运行：

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path <project> --log-file .godot/growth-tests.log --script res://growth/tests/run_growth_tests.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path <project> --log-file .godot/growth-contract-edge-tests.log --script res://growth/tests/run_growth_contract_edge_tests.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path <project> --log-file .godot/growth-session-isolation-test.log --script res://growth/tests/run_growth_session_isolation_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path <project> --log-file .godot/reward-authority-tests.log --script res://growth/tests/run_reward_authority_tests.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path <project> --log-file .godot/growth-06-contract-tests.log --script res://growth/tests/run_growth_06_contract_tests.gd
```

当前证据：

- 行为与事务套件：25 tests / 155 assertions。
- 契约边界套件：4 tests / 10 assertions。
- 双 `RunSession` 静态 Resource 隔离：1 test / 5 assertions。
- 奖励路线权威与第一关绕过回归：3 tests / 15 assertions。
- 共享四槽与形态切换事件契约：10 tests / 84 assertions。
- 合计：43 tests / 269 assertions。

所有测试日志写入 `.godot/`。系统证书存储读取警告来自受限 headless 环境，不影响测试退出码。
