# Task34 第三次接替 Viewport 复核

capture 使用实际 `Windows` DisplayServer，非 headless。六张 PNG 的物理尺寸分别精确为 1920×1080 或 2560×1440，save_error 全部为 0。

| 场景 | accepted | reason | SP | impact |
|---|---|---|---:|---|
| enemy_contact | true | none | 0 | (760, 684) |
| wall_first | false | no_legal_target | 20 | none |
| empty_range | false | no_legal_target | 20 | none |

每个场景均覆盖两种分辨率。逐图人工检查确认 capture 验收叠层、战斗区域和底部技能信息可读；enemy 图显示成功状态与锁定 impact，wall/empty 图只有失败反馈且没有成功爆发残影。原图和 JSON：`third_replacement_final_artifacts/viewport/`。
