# Task95 true-window evidence audit

This is executor evidence, not final acceptance. Independent Review Agent visual inspection is still required.

## Capture environment

- Godot: `4.7.1.stable.official.a13da4feb`
- Renderer: OpenGL 3.3 Compatibility
- Device: NVIDIA GeForce RTX 2060
- Scene/camera: `scenes/test_room.tscn`, unchanged across the 1920×1080 sequence
- Capture point: `RenderingServer.frame_post_draw`
- Native-asset import log: `task95_native_asset_import.log`
- Capture log: `task95_native_asset_capture.log`

## Files

| File | Intended evidence | SHA-256 |
| --- | --- | --- |
| `screenshots/01_normal_with_empty_1920x1080.png` | normal active/passive HUD; A3 empty with key only | `0231f4587720e4647e9d10b3954df42db5298e2082500cd780712482557e3996` |
| `screenshots/02_cooldown_3s_and_empty_1920x1080.png` | bottom-anchored active cooldown and centered `3.0`; A3 remains empty | `8e074117e6a204ebf655fb64a697176f46b32fea1e0ccb690f13393f0faf49fc` |
| `screenshots/03_passive_trigger_1920x1080.png` | P1 thin bright-edge trigger pulse; active cooldown cleared | `f5f6d10826d17207824536c30cba59a3c2fbc8afe599977f60cbc8827e8113b1` |
| `screenshots/04_h_hidden_1920x1080.png` | both active and passive regions hidden | `d446ffbe1baa871ca11fc4cd5b0364706b8051a72339927d10db177bf7af1182` |
| `screenshots/05_h_restored_1920x1080.png` | physical-H path restores both regions | `aefedada22ccc963ec02c9ff9296d638e0e5a00c4671a1cae10c6067ad7d900a` |
| `screenshots/06_layout_1152x648.png` | minimum canvas layout | `775555d7505ad59625954e6367e042d38ba6c7526b6bf43c60d95f630bea5562` |
| `screenshots/07_layout_2560x1440.png` | large canvas layout | `3d551e17ef23b98d56db93df2f61ae169c071395e2fdf25d0ff733f43e0027c5` |

The capture script rejects any file whose pixel dimensions differ from its requested filename dimensions.

## Executor inspection notes

- Runtime PNGs are hand-authored at their final Godot dimensions; no `540→324` or `415→249` runtime-asset resize remains. `native_assets/` contains exact 1× copies and inspection-only 4× nearest-neighbor copies.
- `native_runtime/task94_task95_native_runtime_comparison_1x.png` places the untouched Task94 crops and the new Godot capture side-by-side without resizing either crop.
- Active HUD is bottom-centered and has one continuous outer contour with exactly two internal separators. Active slot controls use `StyleBoxEmpty`, so they cannot add three independent closed frames.
- Passive HUD is a lower-right `4×1` strip. Programmatic matrix checks retain a 51 logical-pixel right margin and 18 logical-pixel bottom margin at 1152×648, 1920×1080 and 2560×1440.
- Active A3 keeps its dynamic key `3` but has no icon, SP value or cooldown copy.
- The cooldown comparison changes only local active-slot-1 pixels: local RGB diff bbox `(50, 44, 130, 116)` inside the active evidence box `(690, 912, 1230, 1054)`.
- The passive-trigger comparison changes only P1: local RGB diff bbox `(12, 9, 107, 106)` inside the passive evidence box `(1420, 934, 1835, 1050)`.
- Hidden versus restored comparisons cover both complete HUD evidence boxes (active local bbox `(0, 0, 540, 141)`, passive `(0, 0, 415, 116)`), confirming H controls both separated regions.
- No lock screenshot is presented as gameplay evidence. The lock is exercised only by the focused fixture test; normal capture/runtime state has no fabricated locked slot.
- At all three displayed resolutions, the active and passive regions are separated, remain inside safe bounds, and show no crop at the window edge.
