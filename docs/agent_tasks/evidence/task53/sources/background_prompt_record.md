# Task53 background rework image-generation source record

The built-in ImageGen tool was used once to create a nine-panel auxiliary paint source for the L2 background-only rework. It is not a runtime atlas and is not an engineering-connected asset.

Prompt:

> Use case: stylized-concept. Asset type: auxiliary source sheet for 32px pixel-art dungeon background tiles. Input image: supplied tidal dungeon tile master strict style/palette. one square 3x3 exactly nine distinct swatches with black separators/no labels: 4 broad slab bases, 2 distinct crack walls, deep groove, dark sealed arch, low-frequency macro wall. preserve coarse pixel clusters, deep navy/teal stone, large slabs, wide shadow planes, left-top light, sparse cyan, restrained purple; actual geometry differences; avoid tiny repetitive brick grids, periodic spots, gradients, AA, text/UI/objects/floors/platforms/etc. Source only.

- Copied source: `docs/agent_tasks/evidence/task53/sources/background_9class_source.png`
- Formal target: atlas rows `0–3` in `assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png`
- Processing: nine panels were independently cropped to 32×32 nearest-neighbor, palette-matched to the frozen tidal master, edge-normalized for cyclic tiling, and expanded into four within-family interior-layout variants.
- Protection: atlas rows `4–15`, chest, portal and Tidal Sentry are hash-gated and were not redrawn by this rework path.
