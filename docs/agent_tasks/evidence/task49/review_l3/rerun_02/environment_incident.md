# Task49 L3 rerun_02 基础设施事件

Task40 首次非 headless 启动在当前工具沙箱内无法向 `C:\tmp\element-dungeon-task49-review-profile-20260813-02` 创建请求的日志，也无法推进脚本。180 秒和 600 秒外层超时强制终止时，Godot crash handler 在工具 stdout 报 signal 11。一次 headless 诊断与一次 Task41 启动出现同一“日志创建前停滞”。这些尝试均未产生正式 `--log-file`，也未生成本轮截图。

随后将 APPDATA/LOCALAPPDATA 临时指向工具可写目录执行 editor/import，Godot 立即启动并明确报告无法写冷根 `.godot` 的权限错误，从而确认阻塞发生在沙箱写权限层，而非候选脚本断言或生产运行期。

对用户已授权的 Task49 冷根与独立 profile 做受控放行后：

- Task40 capture 在 9.5 秒内 exit 0，报告 `1 tests / 140 assertions / 7 screenshots`；
- Task41 capture 在 12.4 秒内 exit 0，报告 `10 authority-checked screenshots`；
- 主场景 smoke 与 final editor/import scan 均 exit 0；
- 所有正式日志五类标记为 0。

因此 signal 11 仅发生在外层终止被权限阻塞的进程时，不作为候选运行期 crash 归因；异常过程仍在此如实保留，不用旧图或旧日志替代本轮证据。
