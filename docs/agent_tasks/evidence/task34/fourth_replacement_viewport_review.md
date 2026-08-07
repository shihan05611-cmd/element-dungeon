# Task34 第四次接替 Viewport 复核

正式 after 冷副本使用 Windows/OpenGL 非 headless capture，脚本和 gameplay 未为本轮修改。六张 PNG 均已按原始分辨率逐张人工查看：布局可读，关键 HUD 与结果信息无遮挡；拒绝画面只显示失败状态、没有成功残影。

| 场景 | 1920×1080 | 2560×1440 | 事务结果 |
| --- | --- | --- | --- |
| enemy contact | 正确物理尺寸 | 正确物理尺寸 | accepted=true，SP=0，impact=(760,684) |
| wall first | 正确物理尺寸 | 正确物理尺寸 | accepted=false，no_legal_target，SP=20，impact=none |
| empty range | 正确物理尺寸 | 正确物理尺寸 | accepted=false，no_legal_target，SP=20，impact=none |

六次 `save_error=0`。原图在 `fourth_replacement_final_artifacts/viewport/`，结构化 capture 记录在 `fourth_replacement_final_artifacts/16_task34_viewport_capture.log`。
