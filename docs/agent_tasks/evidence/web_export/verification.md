# Godot Web 导出验证

- 验证日期：2026-09-01
- 引擎：Godot 4.7.1 stable
- 导出预设：`Web`，单线程，无 GDExtension
- 输出入口：`build/web/index.html`
- 浏览器：Chromium WebGL 2
- 浏览器结果：游戏正常进入战斗场景；控制台无 error；中文战斗标签正常显示
- HTTP：`index.html`、`index.wasm`、`index.pck` 均返回 200
- MIME：WASM 为 `application/wasm`，PCK 为 `application/octet-stream`

## 自动化检查

- HUD/loadout/feedback：13 tests，143 assertions
- Task87 元素反应视觉：7 tests，38 assertions
- Task58 场景交互：3 tests，91 assertions
- Task61 Boss 三形态：18 tests，110 assertions
- 合计：41 tests，382 assertions，全部通过
- 场景资源扫描：通过

## 保留日志

- `web_export_20260901_final_03.log`
- `web_font_hud_feedback.log`
- `web_font_task87.log`
- `web_font_task58.log`
- `web_font_task61.log`
- `web_font_scene_scan.log`

导出日志中的根证书存储读取警告来自受限执行环境，不影响本次导出退出码与浏览器运行结果。
