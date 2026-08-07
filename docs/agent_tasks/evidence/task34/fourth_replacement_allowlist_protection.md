# Task34 第四次接替 allowlist 与保护对账

相对第三次接替 REVIEW 冻结的 37 项实现/测试 SHA 清单，本轮只有 3 项变化，其余 34 项逐字节不变：

- `combat/targeting/physics_projectile_sweep_query_2d.gd`：`5046ADBB6FD0F26CC4C5712E3F546B8E1DBBD96C2F5F7B3A07C4246DEF246C27`
- `combat/delivery/projectile_delivery.gd`：`5F189F18C3ADF560609EF257BB7705B15BD1760D1B022971A521B3FF539337E4`
- `combat/tests/run_task34_projectile_cast_transaction_tests.gd`：`23C2B45BD0DEC424E959C6321B79C45BAEFB2D29BD3977C3A379DFC360E59C77`

三项均位于任务书第 16.2 节最小 allowlist。runner 未修改，SHA-256 为 `83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`。immutable Result 未修改，SHA-256 为 `B4C680EE83C240DE4D01D7BA4642417EA44D7BBC906B3A71F716C24691BDF943`。其他写入仅为 Task34 任务书和 `docs/agent_tasks/evidence/task34/**`。

最终共享保护聚合：

- HEAD：`102720086c53a84901b788726ad609d15263d64a`
- `.godot`：754 files / 37416266 bytes / latest `2026-08-06T12:52:36.9297954Z`，与接替前一致
- `.gd.uid + .import` sidecar：548 files / 198646 bytes / latest `2026-08-07T05:23:15.4138835Z`，与接替前一致
- 共享 Godot PID `43452`、godot-ai PID `21632`：均为原进程、仍在运行，本接替未使用、控制或关闭
- CENTRAL SHA-256：`178D3816D0B0D2C233B419D0FA088C8AFD98AE0BE6A6952FE10A89F6891A714D`
- 架构建议 SHA-256：`07450B76F22E6FC4BB90E6BDF6C72A120FBD5A8B01C0A75D2BCD317F45CEC247`
- `.workbuddy`、VFX `__pycache__` 与其他历史保护内容未由本接替修改
- Task35～37：未修改、未启动
- Git 写操作：0；未执行 add/commit/push/reset/restore/checkout/clean/stash/apply

当前 37 项完整 SHA 见 `fourth_replacement_modified_files_sha256.txt`；共享与正式 after 冷副本逐项 `37/37` 存在、`0 mismatch`。
