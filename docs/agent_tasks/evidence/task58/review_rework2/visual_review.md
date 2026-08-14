# Task58 rework2 fresh capture 原尺寸视觉 QA

Reviewer 使用本轮全新冷根/profile 重新生成七张 `1920×1080` 原图，并逐张以 original detail 检查。`visual_manifest.csv` 证明七图 SHA 均不同于 capture 前文件；以下判断不复用执行、首轮或 rework1 截图。

1. `task58_01_closed_chest_1920x1080.png`：关闭宝箱与 locked portal 同屏可辨；玩家、地面、HUD、脚底锚点完整，无遮挡或悬浮。
2. `task58_02_locked_portal_1920x1080.png`：玩家靠近 locked portal；关闭宝箱、门体、地面和 HUD 均保留，尺度正常。
3. `task58_03_open_chest_1920x1080.png`：宝箱为真实 open 纹理，portal 为 active 纹理；奖励文字、HUD、地面锚点清晰。
4. `task58_04_active_portal_1920x1080.png`：玩家靠近 active portal；open chest 与 active portal 双状态同时成立，无颜色调制冒充迹象。
5. `task58_05_battle02_tidal_sentry_live_projectile_1920x1080.png`：右侧平台上的青蓝色静态 Sentry 与已离开发射点的紫色 live projectile 同屏；玩家、其余敌人、平台、地面和 HUD 均可见。
6. `task58_06_shop_crown_ui_closed_1920x1080.png`：皇冠作为独立对象居中落在基座，merchant overlay 关闭；皇冠 F 与出口 F 世界提示、HUD、地面锚点均保留。
7. `task58_07_shop_crown_ui_open_1920x1080.png`：既有 merchant UI 打开；标题、余额、购买/升级、七槽位与关闭控件可读，未出现新页面或伪造商店。

结论：七图全部通过本轮原尺寸视觉 QA；capture 的两次尝试、稳定等待和 Player 位移没有移除 HUD/地面/锚点证明，也没有伪造双纹理状态或掩盖产品问题。
