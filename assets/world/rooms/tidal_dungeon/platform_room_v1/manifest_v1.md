# Tidal dungeon platform room layered art v1

状态：`TASK55 FORMAL ART / REVIEW CANDIDATE`

## Room-layer contract

| file | source canvas | runtime display | origin | alpha role | SHA-256 |
|---|---:|---:|---|---|---|
| `background_wall_v1.png` | 768×416 RGBA | 1536×832, 2× Nearest | (0,0) | opaque wall plane | `E4EF73A15F3EFB39D8FC88CCC01081F56C331BD185D489332ACA007AD38A48E4` |
| `back_decor_v1.png` | 768×416 RGBA | 1536×832, 2× Nearest | (0,0) | transparent back decoration | `0E75805A1C959889A0F07C8F879D20EBFA65903176F67D3E4CE114749291C449` |
| `front_decor_v1.png` | 768×416 RGBA | 1536×832, 2× Nearest | (0,0) | sparse transparent foreground | `F79B5C1A679CAD7209036328D6AB7A969146785F6D6CDEF16E484AB959130F45` |

- The three room layers share the exact canvas, top-left origin and pixel alignment. Do not scale or offset them independently.
- Recommended draw order: `background_wall` → `back_decor` → gameplay/platforms/interactables → `front_decor`.
- These three layers contain no lamp, light fixture, luminous core, baked light pool, bloom, vignette or local halo. Any future lighting must be a separate runtime light/VFX responsibility.
- `back_decor` alpha coverage is `0.139817`; `front_decor` is `0.088232`. Neither is a renamed wall copy.
- Task53 atlas is provenance/palette reference only. No TileSet, TileMapLayer or enlarged atlas tile is used by this room contract.

## Independent ground and platforms

| file | source canvas | runtime display | visible top | anchor references | SHA-256 |
|---|---:|---:|---:|---|---|
| `ground_floor_v1.png` | 768×64 RGBA | 1536×128, 2× Nearest | local y=0 | top-center (384,0), bottom-center (384,64) | `20BC95128605EDFF3EA93F02481A43E9842D0FE91922FDD17C401B71A4EE42F9` |
| `platform_short_v1.png` | 160×32 RGBA | 320×64, 2× Nearest | local y=0 | top-center (80,0), bottom-center (80,32) | `DC74F20CBA4EE8DD7509185D4D19C96E6AB9AB070CBCECC74331954A50564B68` |
| `platform_medium_v1.png` | 224×32 RGBA | 448×64, 2× Nearest | local y=0 | top-center (112,0), bottom-center (112,32) | `FF7A05672F186FDF67DA4CC3B8BB1732A6550A7382C2E4E0844E7427ABEA8583` |
| `platform_long_v1.png` | 320×32 RGBA | 640×64, 2× Nearest | local y=0 | top-center (160,0), bottom-center (160,32) | `3AC1C0EED33D069E6E7271344D4A77150B1293DD073DAB630EE96B7DED047716` |

- Ground, short, medium and long are four independently generated and target-cleaned images; the longer pieces are not stretched copies of the short piece.
- All four use the same material planes and thickness language. Their declared standable top is continuous across the full width at source `y=0`; measured top-line difference is `0` pixels.
- Collision recommendation: one simple horizontal/top-aligned rectangle or StaticBody shape spanning the declared sprite width; visual/collision top deviation must remain ≤1 source pixel. Engineering owns the actual collision nodes.
- Filtering: Nearest; mipmaps off; lossless; repeat disabled. Runtime display is exactly 2×.

## Scope boundary

Static art only. No `.import`, `.tscn`, `.tres`, `.gd`, Godot connection, collision node, room layout implementation, TileSet, TileMapLayer or baked-light layer is included.
