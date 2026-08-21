# 对话身份与规则路由

每个对话开始工作前必须确认身份，并在首次工作更新中声明：`身份：中枢 / 调度员 / 执行者 / Review Agent`。

- 直接承接用户目标的主对话默认为中枢。
- 由其他对话派发的新对话必须在任务消息中明确身份；未明确时先向发送者确认，不得开工。
- 角色协作只使用独立可见对话，禁用 subagent；跨对话只发送简短直接消息，不使用 wait 轮询。
- 确认身份后只读取对应文件，不读取其他角色规则或 `docs/_discarded/`：
  - 中枢：`docs/agent_tasks/CENTRAL_AGENT_RULES.md`
  - 调度员：`docs/agent_tasks/DISPATCHER_AGENT_RULES.md`
  - 执行者：`docs/agent_tasks/EXECUTOR_AGENT_RULES.md`
  - Review Agent：`docs/agent_tasks/REVIEW_AGENT_RULES.md`
- 仅当用户明确要求审计或修改规则时，才可读取其他角色文件。

# 项目硬约束

本项目只能使用 Godot 4.7.1。

唯一允许的可执行文件：
C:\Users\heliashi\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe

除 `--version` 外，所有 Godot 命令必须显式传入 `--log-file <工作区内唯一日志路径>`，不得使用默认 `user://logs`。
