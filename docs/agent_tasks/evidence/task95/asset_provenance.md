# Task95 native-pixel HUD asset provenance

- sole visual reference: `docs/agent_tasks/evidence/task94/task94_skill_hud_hierarchy_states_full_concept_1920x1080.png`
- source RGBA SHA-256: `b33092d351bbca4066e1a82dee92369b20690a4b094494ab4099fac0d256c021`
- Task94 reference boxes inspected: active `(690, 918, 1230, 1060)`; passive `(1420, 934, 1835, 1050)`
- native authoring: every 1x opaque run is hand-authored directly at 324x85 / 249x70 (and state-resource native sizes); no Task94 crop was resized into a runtime asset.
- palette: every opaque RGB tuple occurs verbatim in the corresponding Task94 final PASS crop.
- active structure: one stepped outer contour, continuous y=4/5 and y=80/81 edges, exactly two layered separator bands centered at x=108 and x=216, plus three empty key-tab contours.
- passive structure: lower-weight group contour and four repeated quiet native slot contours; empty dash, lock and pulse remain separate state resources.
- dynamic exclusion: shared frames contain no icon, key digit, SP value, cooldown shade/countdown, passive icon, lock, empty dash or pulse.
- evidence scaling: only `native_assets/*_4x_nearest.png` uses resize, strictly 4x nearest-neighbor for inspection; runtime assets are the authored 1x images.
- runtime interior samples remain source-exact: active `(1170, 980)` = `(13, 17, 23, 255)`; passive `(1800, 1018)` = `(16, 20, 28, 255)`.

## Runtime outputs

- `assets/ui/hud_skill/active_frame.png`: size `(324, 85)`, alpha `(0, 255)`, RGBA SHA-256 `77435e0337146ffcebc81fb38fa5a496b27e68d330cb658e25966aa6a77f9b91`
- `assets/ui/hud_skill/passive_frame.png`: size `(249, 70)`, alpha `(0, 255)`, RGBA SHA-256 `e09904423accb9de4a72fed827240892b4cb537533ab561ffe373aa1cff0155a`
- `assets/ui/hud_skill/passive_empty_inset.png`: size `(42, 44)`, alpha `(0, 255)`, RGBA SHA-256 `c8360b4131fdebe1822f00226869f02720f980e5d6a92dbaaa395b157a1a3b8e`
- `assets/ui/hud_skill/passive_lock.png`: size `(24, 30)`, alpha `(0, 255)`, RGBA SHA-256 `381871587aa7e21d34ee46eecd9aa4e8887b07ce5f0d51659071f0f88321fae9`
- `assets/ui/hud_skill/passive_pulse_border.png`: size `(57, 58)`, alpha `(0, 255)`, RGBA SHA-256 `5597e8735e64fead44899e2ccd2a2075f1aa3782fff7a767944dfff0d3cb8d1c`

## Inspection outputs

- `native_assets/active_frame_1x.png`: exact runtime pixels
- `native_assets/active_frame_4x_nearest.png`: `1296x340`, nearest-neighbor
- `native_assets/passive_frame_1x.png`: exact runtime pixels
- `native_assets/passive_frame_4x_nearest.png`: `996x280`, nearest-neighbor
- `native_assets/passive_empty_inset_1x.png`: exact runtime pixels
- `native_assets/passive_empty_inset_4x_nearest.png`: `168x176`, nearest-neighbor
- `native_assets/passive_lock_1x.png`: exact runtime pixels
- `native_assets/passive_lock_4x_nearest.png`: `96x120`, nearest-neighbor
- `native_assets/passive_pulse_border_1x.png`: exact runtime pixels
- `native_assets/passive_pulse_border_4x_nearest.png`: `228x232`, nearest-neighbor
