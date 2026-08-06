# Task32 执行侧证据：正式四被动内容缺口

状态：`ACCEPTED`（中枢 Review 5.0 已于 2026-08-06 独立验收通过）

## 结论

Task32 在严格 allowlist 内补齐 `passive_vitality` / 坚韧体魄与 `passive_energy` / 元素储备两项正式静态内容，并为二者生成独立透明图标。正式 catalog 现为一个固定普通攻击加八个可购买内容（四主动、四被动），历史五项 reward projection 未增加。现有 RunSession、商店 UI、七槽 Runtime 与被动控制器无需修改即可动态消费新内容。

真实非 headless `RunGame` 已只通过正式梦尘购买、正式拥有列表和即时槽位事务获得并装配：P1 `burning`、P2 `unending`、P3 `passive_vitality`、P4 `passive_energy`。离开第二商店进入战 4 后，四个不同被动各有一个 Runtime，跨房间只发生一次整批注销和一次整批重建；未使用 fixture、直接注入、钱包写入、owned/loadout/revision 写入或旧免费奖励。

## 正式内容合同

| 字段 | `passive_vitality` / 坚韧体魄 | `passive_energy` / 元素储备 |
| --- | --- | --- |
| gameplay | 只读 `resources/skills/passive_vitality.tres` | 只读 `resources/skills/passive_energy.tres` |
| 冻结效果 | `maximum_health_bonus = 20`，不治疗 | `maximum_energy_bonus = 10`，不立即回 SP |
| 类型 | PASSIVE，严格被动槽 | PASSIVE，严格被动槽 |
| 购买价 | 梦尘 75 | 梦尘 75 |
| forms | `[water, fire]` | `[water, fire]` |
| 获取/配装 | 可购买、可装配；非初始拥有；无默认槽 | 可购买、可装配；非初始拥有；无默认槽 |
| 成长/奖励 | 无 active progression；非 reward/initial reward | 无 active progression；非 reward/initial reward |
| 世界表现 | `presentation_scene = null`；`runtime_delivery_scene = null` | `presentation_scene = null`；`runtime_delivery_scene = null` |
| icon | 独立 heart-core / armor 轮廓 | 独立 reservoir / clamps / windows 轮廓 |

两份只读 gameplay 资源在执行前后保持：

- `passive_vitality.tres`：576 bytes，SHA-256 `DB5BCEEE0FE70A241B0D48546D2E677EC81F70C4387735A61FEF00F6C7F3BA6D`；
- `passive_energy.tres`：570 bytes，SHA-256 `EE40240B4A2E29F6215B6B9040EC78B3D125F366A838605E61A11C8C30C31296`。

`passive_focus`、`passive_balance`、`water_lance`、`fire_lance` 继续无法由正式 `content_for` 找到。

## Catalog 迁移

| 投影 | Task30 接受基线 | Task32 |
| --- | ---: | ---: |
| gameplay definitions | 7 | 9 |
| obtainable/shop contents | 6 | 8 |
| active shop contents | 4 | 4 |
| passive shop contents | 2 | 4 |
| initial owned/default mapping | `element_bolt` / A1 | 不变 |
| historical reward projections | 5 | 5（不变） |

正式 RunGame 的免费奖励、经验/属性点和遗物模式继续禁用；Task32 没有恢复任何旧奖励入口。

## 图标生成与 QA

先完整读取并遵循 `imagegen` skill；生成前以原尺寸查看 Task17 六枚已接受 icon。两图均由内置 `image_gen` 以平面 `#ff00ff` chroma key 生成，再用 skill 官方 `remove_chroma_key.py`（`--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --edge-contract 1 --despill`）去背，并复用 Task17 接受工具的 `finalize_icon` 将主体以 220px 居中到 256×256 透明画布。

| icon | Bytes | SHA-256 | alpha coverage | QA |
| --- | ---: | --- | ---: | --- |
| `assets/generated/vfx/passive_vitality/icon.png` | 54,942 | `C4F7494D701FB91F3FDD06B7F97BC71768284F6DE5FA4E7315E3D4DF068E495C` | 0.406128 | 256×256 RGBA；四角透明；key pollution 0；32/64px 仍可辨心形核心与护甲 |
| `assets/generated/vfx/passive_energy/icon.png` | 62,876 | `28D5B75EF96B80AAE5D9F0209B74AB186870774553F46706EB2C589830248441` | 0.452744 | 256×256 RGBA；四角透明；key pollution 0；32/64px 仍可辨储罐、夹具与三格容量窗 |

两图不仅用红/蓝区分：vitality 是宽心核加胸甲/肩甲，energy 是有密封帽与三容量窗的直立储罐。原图、128/64/32px 暗底组合均已实际查看；无文字、数字、键帽、水印、世界背景或投影污染。精确提示词、生成源 SHA、去背流程和用途边界见各目录 `prompt.md` / `manifest.md`。Task32 未新增世界 VFX、动画、粒子、presentation scene、delivery 或 runtime 脚本。

## Runner 门禁

Task30 接受基线 26 个 runner 全部复跑，再加入 Task32 新 runner：

- 正式合计：`27/27 runners / 287 tests / 3338 assertions`，全部 exit `0`；
- Task32 新 runner：`5 tests / 173 assertions`，覆盖 9/8 catalog、4主动+4被动、两项完整字段、非奖励/无等级、陈旧/重复/余额不足原子拒绝、正式四次购买/即时装配和真实跨房间 Runtime rebuild；
- Task16：仍为 `11 tests`，`209 -> 231 assertions`（`+22`）；只增加 9/8 数量、legacy 排除列表、两项新内容与无假 world presentation 的断言；
- Task27 economy：仍为 `11 tests`，`291 -> 307 assertions`（`+16`）；只增加 shop `6 -> 8` 与两项被动的购买/无等级/非奖励/图标字段断言；
- Task12 `13/113`、Task18 `9/124`、Task24 `10/237`、Task30 `9/172` 均与接受基线一致；
- Task20 单列：`7 tests / 68 assertions`、exit `0`，继续历史 `BLOCKED`，不计入 27-runner 门禁。

全部 runner 的逐文件输出位于 `logs/baseline26/`、`logs/02_task32_formal_four_passive_content_tests.log` 和 `logs/03_task30_run_ui_tests.log`。

## 冷副本、scan、smoke 与 capture

- HEAD/开工检查点：`5e1c436b97ff82a31cd9533eb435e6f151353432`；执行前后无 Git 写操作；
- 全新冷副本：`C:\tmp\element-dungeon-task32-exec-20260806-01\project`；独立 profile：同根 `profile\Roaming` / `profile\Local`；
- 复制排除 `.git/.godot/.workbuddy/cache`；第一条 Godot 前冷副本 `.godot` 不存在；逐文件核对 `1491/1491 files / 44,340,538 bytes / only-source 0 / only-cold 0 / mismatch 0`；
- 第一条 Godot 命令严格为 4.7.1 headless editor scan；版本 `4.7.1.stable.official.a13da4feb`，exit `0`；
- `RunGame` 与 `TestRoom` 各 180 帧 headless smoke，均 exit `0`；
- 非 headless capture：OpenGL 3.3 / NVIDIA RTX 2060，`381 assertions / 4 images`，exit `0`；
- capture 后 final headless editor rescan exit `0`；
- 33 份正式日志合计 212,778 bytes；aggregate SHA-256（相对日志路径、bytes、单文件 SHA，UTF-8/LF）为 `3EC679E57CDDE425BF39741A169708A7AFF8E02411F459F54E6D149EABEF93CD`；
- 全部日志大小写精确扫描：`SCRIPT ERROR` / `Parse Error` / `ERROR:` / `WARNING:` / `CrashHandlerException` 均为 `0`。

headless editor 在当前共享 Godot-AI 端口已占用时输出普通文本 `Failed to bind socket. Error: 3.`，与初始/final scan 均 exit 0、插件明确 headless disabled、上述五类正式错误标记 0 同时成立；不影响项目扫描、runner、smoke 或 capture。

## 实际 Viewport 与人工检查

每张保存前均断言：实际窗口/Viewport 尺寸、authority phase 与 revision；四个唯一正式 skill ID；权威 owned、梦尘收入 365、购买支出 300、余额 65 且守恒；七槽 mapping；P1–P4 顺序；四个 Runtime ID/slot 各一次；Runtime 与 authority mapping 相同；四项 icon 非空。战斗图额外断言跨房间只增加一次 registration/unregistration batch、四个 runtime 对象全部刷新且唯一、正式 HUD 三区在 bounds、P1–P4 icon/name 实际像素存在、无假 key/level/SP/cooldown，并断言玩家/敌人与 HUD 不相交。PNG 写回后重新解码并与 gated Viewport RGB8 逐字节一致。

| 文件 | 尺寸 | Bytes | SHA-256 | 原尺寸检查 |
| --- | ---: | ---: | --- | --- |
| `viewport/01_shop_four_passives_1920x1080.png` | 1920×1080 | 338,317 | `82A0073A5EA39FA9A3388AB7975D6A4ED9054C4B1C66D59E0A19482927484BF2` | 商店标题/钱包/购买支出/七槽与 P1–P4 名称完整，无裁切 |
| `viewport/02_shop_four_passives_2560x1440.png` | 2560×1440 | 497,539 | `3B133AE2EFB02D79F3E96F06A1E2DA31ECAAC45F204B03FD3F66889D8B7BF011` | 大屏配装区比例稳定，P1–P4 全部可读 |
| `viewport/03_combat_p1_p4_1920x1080.png` | 1920×1080 | 111,304 | `AEE8DC60B05E07DB94A3E2522D5527E1BD16117C6E2D28D73497C82BABFA2777` | 四枚图标/名称清楚；HP 120、SP 110 正确；玩家/两敌人/HUD 无关键遮挡 |
| `viewport/04_combat_p1_p4_2560x1440.png` | 2560×1440 | 154,150 | `E046B3C91902799AC6DDA665703D6B8D599157F95FA83BB7AB70560059F37AEE` | 大屏四被动轮廓与文字更清晰，世界关键几何和 HUD 均完整 |

PNG 合计 4 个 / 1,101,310 bytes；aggregate SHA-256（文件名、尺寸、bytes、单文件 SHA，UTF-8/LF）为 `C57836C44BCF934FF4330C73624CDB7A72C1E358BF39ABB0D8F4C82206075CFF`。

## 修改文件 SHA-256

| 文件 | Bytes | SHA-256 |
| --- | ---: | --- |
| `resources/content/run_content_catalog.tres` | 2,188 | `4B0A93C4957A7576D55B936AEF88F8E74F1D9635BF4827E061CEDF45A5C5606E` |
| `resources/content/skills/passive_vitality_content.tres` | 756 | `771FCC7208FE89DFD0D984B5864DC2E922A6D4C86C31B9D267C60B9437B392CD` |
| `resources/content/skills/passive_energy_content.tres` | 754 | `AFCC5ADC3AAFE797D7996AAD6C83FEA044A135B8B63FD046535C1B5DD3268824` |
| `assets/generated/vfx/passive_vitality/icon.png` | 54,942 | `C4F7494D701FB91F3FDD06B7F97BC71768284F6DE5FA4E7315E3D4DF068E495C` |
| `assets/generated/vfx/passive_vitality/prompt.md` | 2,526 | `29D3A73A833E289F9BB6C1542CE00DB5628319F3010B77E2F8210D6F0613ABBB` |
| `assets/generated/vfx/passive_vitality/manifest.md` | 1,135 | `B2D674A4BCA6D75E30093955A6CAE9B71169D5C825B7CCAA321A9E86108B6E66` |
| `assets/generated/vfx/passive_energy/icon.png` | 62,876 | `28D5B75EF96B80AAE5D9F0209B74AB186870774553F46706EB2C589830248441` |
| `assets/generated/vfx/passive_energy/prompt.md` | 2,665 | `752042577E2DFFC88015355650D8BE85E8D7BE177B0FD3385621112B3CFA086B` |
| `assets/generated/vfx/passive_energy/manifest.md` | 1,178 | `6E07CAADE2899AB9B01C0461087A3A138D9EF7764AAE827271A40373D3F9D1DF` |
| `docs/vfx/final_asset_manifest.md` | 3,312 | `398FA0F5081E67AFF6297D48F70BD796F6576B31717A2CFFD72B5DF580214663` |
| `docs/current_gameplay_design_handoff.md` | 17,031 | `E1281D1535586A3B759FDB3DA9654792B7CE26F385BEFA5355248671FB8B9C69` |
| `combat/tests/run_skill_content_catalog_tests.gd` | 28,673 | `99B9F449DB71DD638F26ABDE4324E941DD6575525E51C5720AF2B192255DFF3E` |
| `growth/tests/run_task27_run_economy_progression_tests.gd` | 28,759 | `7E7B3CE62F2F3999B0948AA67DEB3EF1FF2D05DD6E7EC0F0870CF70532C31F77` |
| `growth/tests/run_task32_formal_four_passive_content_tests.gd` | 22,360 | `6B0BE1AA16149EBE8277525F334D51D71BF737511BBCBC9C909EA81E51F0A9D3` |
| `combat/tests/capture_task32_formal_four_passive_visual.gd` | 25,278 | `955894FB2A5004B4B6A1AAD1B72387C21BD4BE256898DCE81EB4FCFD6408BF94` |

任务书最终 `REVIEW` 状态文件、README、本任务 logs/PNG 的逐文件 SHA 统一记录在 `SHA256SUMS.txt`。

## 共享保护、边界与风险

- 共享 Godot PID `43452` 自 `2026-08-06 20:46:17 +08:00` 持续存活且 responding；执行者未调用、控制、运行、reload、reimport、保存或关闭共享编辑器；
- 共享 `.godot` 在执行前后均为 `754 files / 37,416,266 bytes`，latest `2026-08-06T12:52:36.9297954Z`；同一聚合算法结果保持 `560E5A70AC192319D61312F901421F412E51F8264ACA97FEC09A705F73A80CB0`；
- 共享全部 `.gd.uid/.import` 在执行前后均为 `537 files / 198,428 bytes`，latest `2026-08-06T12:46:32.2117630Z`；聚合保持 `A79E02BA75B531154A612E3AA7CBC517F4E3FF890946AF2BA3B5F58594E2D7B4`；其中既有未跟踪 sidecar 仍为 `66 files / 28,555 bytes`，Task32 未在共享区生成新 sidecar；
- allowlist 外 tracked diff 为 0；两份 readonly gameplay、RunSession/Director/catalog schema、Runtime/passive controller、Player/Enemy、RunFlow、HUD/Overlay、场景/房间、VFX runtime、`project.godot`、Task31 与历史 evidence 均未修改；
- `passive_focus` / `passive_balance` / 两把 lance 未注册；没有第三个被动、等级、世界 VFX 或数值再平衡；
- Git 写操作为 0：未执行 add/commit/push/reset/restore/checkout/clean/stash；HEAD 保持开工检查点；
- 当前唯一残余风险是中枢仍需在另一全新冷副本独立重放四被动正式路径并人工查看原图；执行侧未发现功能、事务、内容或视觉阻塞。

任务书切换 `REVIEW` 前，最终保护清单（排除 `.git/.godot/.workbuddy/cache`、全部 sidecar，以及尚待最终状态写入的任务书/README/SHA 清单）在共享与冷副本均为 `990 files / 45,446,829 bytes`，only-shared / only-cold / content mismatch 均为 `0`。最终状态文件与 evidence 元数据随后以 `SHA256SUMS.txt` 再核对；完成后本职责对话冻结，等待中枢独立验收。

## 中枢 Review 5.0 独立验收（2026-08-06）

中枢没有复用执行者冷副本或截图。正式 Review 使用全新 `C:\tmp\element-dungeon-task32-review5-20260806-02\project` 与独立 profile；复制 `1526/1526 files / 45,624,222 bytes`，0 缺失、0 额外、0 mismatch，首条 Godot 前无 `.godot`。首条 scan、27 个正式 runner、Task20 单列、双 180 帧 smoke、实际图形 capture 与最终 rescan 共 33 份日志，五类错误/警告标记全 0。

独立结果为 `27/27 runners / 287 tests / 3338 assertions`；Task20 `7/68` 仅作非门禁并继续历史 `BLOCKED`。图形 RunGame capture 为 `381 assertions / 4 images`、exit 0；两张商店图与两张战斗图均从空的冷副本 viewport 目录重新生成。Review 逐张原尺寸检查通过，并另行检查两枚正式图标的 256/64/32px 版本。共享 `.godot`、537 项 sidecar、只读 gameplay 与 allowlist 外 tracked 文件在验收前后零漂移。结论：`PASS / ACCEPTED`。
