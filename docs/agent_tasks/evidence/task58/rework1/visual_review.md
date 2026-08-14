# rework1 visual QA

七张正式文件均为 rework1 冷根新生成的 1920×1080 PNG。原始字节用于 SHA/尺寸证据；独立 profile 下生成 960×540 QA 副本仅供逐张查看，不纳入候选或 evidence manifest。

- 01：关闭宝箱、locked portal 与 HUD 同帧完整，宝箱落地。
- 02：Player 靠近 locked portal，灰紫锁定图、提示、宝箱和 HUD 清晰。
- 03：真实 open chest 与 active portal 同帧，奖励提示可读。
- 04：Player 靠近 active portal，亮紫激活图和提示清晰。
- 05：Battle02 平台 Tidal Sentry 与已移动的紫色 ProjectileDelivery 同帧可见，哨兵未水平漂移。
- 06：独立皇冠落在中央台座，Overlay 关闭，皇冠 F 与出口 F 均可读。
- 07：皇冠交互后的既有梦尘商店 Overlay 打开，余额/候选/七槽/关闭控件清晰。

两次早期 capture 均由 runner 报告 7 images / 0 failures；因高分辨率工具切片查看存在区域缺失歧义，保存于 `attempts/`，最终采用加入 portal-focused 稳定等待后的第三次全新字节。
