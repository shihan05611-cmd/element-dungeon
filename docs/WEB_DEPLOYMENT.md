# Web 打包与 GitHub Pages 部署

## 本地导出

本项目只使用 Godot 4.7.1。确认已经安装 `4.7.1.stable` Web 导出模板后，在项目根目录执行：

```powershell
& 'C:\Users\heliashi\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --export-release Web 'build/web/index.html' `
  --log-file 'docs/agent_tasks/evidence/web_export/web_export.log'
```

导出结果必须包含 `build/web/index.html`、WebAssembly 和 PCK 文件。不要直接双击 HTML；应通过 HTTP 服务测试。

```powershell
python -m http.server 18080 --bind 127.0.0.1 --directory build/web
```

访问 `http://127.0.0.1:18080/`。

## GitHub Pages

`.github/workflows/deploy-pages.yml` 会在 `main` 分支中的 `build/web` 或工作流发生变化时部署静态文件，也可在 Actions 页面手动运行。

首次启用时，在 GitHub 仓库中打开 `Settings → Pages`，将 `Build and deployment → Source` 设为 `GitHub Actions`。本仓库的预期地址为：

`https://shihan05611-cmd.github.io/element-dungeon/`

## 发布边界

- Web 导出使用单线程模式，避免 GitHub Pages 缺少跨源隔离响应头时无法启动。
- `addons`、`build`、`combat/tests`、`growth/tests`、`docs` 和 `tmp` 不进入发布包。
- 本地导出和提交不等于上线；只有 push 到 GitHub 后才会触发 Pages 部署。
