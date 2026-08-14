# Task58 L3 evidence

状态：首轮独立 Review `FAIL / FROZEN`；rework1 候选 `REVIEW / FROZEN`

首轮执行证据保留在本目录原有文件中；独立 Review 在 SHOP snapshot 同信号栈发现 Overlay 一帧可见，并发现任务书 baseline 状态误记为 `M`。rework1 已在原 allowlist 内修复并完整重跑 L3，独立证据入口为 `rework1/README.md`。本状态不代表 `ACCEPTED`。

固定基线为 `51b8ffde0894fd430517225e693b7c44008038aa`。所有 Godot 正式命令均在 `task58-exec-20260814-01` 冷根和 `task58-exec-profile-20260814-01` 独立 profile 中执行；共享工作树从未作为 Godot `--path`。

## 结论

- 正式宝箱/传送门均以真实双 texture 切换，不使用 modulate 冒充状态。
- 皇冠是独立世界交互，F 只显示既有商店 overlay；专项断言确认重复打开不提交购买、升级、配装、离店或经济变更。
- Battle02 SpawnA 使用专用静态 Tidal Sentry；水平位移门禁、平台落地、确定性 Player、连续三发、ProjectileDelivery 生命周期、命中/清理、元素/死亡/奖励/清房全部通过。
- 旧资产运行引用归零后，严格删除任务书十项；未宽泛清理父目录或历史证据。
- 正式测试总计 23 tests / 977 assertions；fresh capture 1 test / 7 images；180 帧 smoke 与三次正式 editor scan 全部退出 0。
- 12 份正式日志五类标记均为 0；七张截图已经 1920×1080 原尺寸人工核验。

## 文件索引

- `formal_asset_freeze.csv`：六张正式 PNG 的 SHA、尺寸、alpha/bbox 冻结。
- `old_asset_freeze.csv`：删除前十项旧资产字节与 SHA。
- `runtime_reference_migration.csv`：旧运行引用由 3 迁移为 0。
- `runner_summary.csv`、`log_marker_summary.csv`：专项、回归、capture、smoke、scan 结果。
- `visual_manifest.csv`、`screenshots/`：七张正式截图及 SHA。
- `sidecar_reconciliation.csv`、`logs/sidecar_*_final_scan.csv`：final scan 前后 sidecar 对账。
- `overlay_manifest.csv`：evidence glob 之外的精确 allowlist 变更。
- `protection_reconciliation.csv`：正式 PNG、受保护文件、共享进程与工作区保护结果。
- `attempt_register.csv`、`attempts/`：被正式结果取代但仍保留的环境/测试/视觉迭代记录。
- `evidence_manifest.csv`：除自身外全部 evidence 文件的 bytes/SHA256。

## 正式与排除记录

`logs/` 仅包含用于门禁的正式成功日志；`attempts/` 保留早期尝试，不能计入正式五类标记统计。首次 sandbox scan 的根证书错误属于隔离环境，正式非 sandbox 冷根 scan 已通过；Task58 首次专项暴露测试夹具禁用 Player 后 hurtbox 不可见，修正测试夹具后通过；Task43 首轮只暴露旧图像底边公式未计 Sprite 偏移/半开像素边界，按任务书许可迁移断言后通过；首次 capture 通过程序门禁但因构图重叠被正式重拍替代。
