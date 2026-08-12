# Run Route Portal generation record

Mode: built-in `image_gen`, `stylized-concept` followed by one `precise-object-edit` background correction. No CLI/API/model fallback was used. Task17/32 icons and Task31 dark rooms were inspected at original size as visual constraints.

```text
Use case: stylized-concept
Asset type: isolated world-object sprite source for a 2D side-scrolling dungeon game
Primary request: one route-choice elemental portal, a compact vertical oval gate made from six chunky dark indigo stone-metal segments around a bright violet-blue inner ring, with a clear dark center and cyan energy notches suggesting controlled rotation
Style/medium: crisp low-resolution-friendly painted pixel art, strong silhouette, 3-to-5 value steps, hard stair-step edges, limited violet/indigo/cyan palette
Composition/framing: single centered upright portal, front view with slight depth, square canvas, generous padding, designed for 96px and 128px
Constraints: no character, scenery, wall, floor, runes, text, arrows, badge, shadow, smoke, fog, watermark, or complete background; perfectly flat solid #00ff00 chroma-key field
```

The selected design was edited once to remove a rejected black background and external halo while preserving the portal geometry and colors. Selected source: `exec-163ecde1-cbb0-4ce0-888f-2dd4d8869d36.png`, SHA-256 `E5E8567EC4F56046B5B1D97DF4C959FAE11CAFD9EB4B950D48205923C6A568F3`.

Post-process: official `remove_chroma_key.py` with border auto-key, soft matte, thresholds 12/220, edge-contract 1 and despill; alpha subject centered at 220 px on a 256×256 canvas.
