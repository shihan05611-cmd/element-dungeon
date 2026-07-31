# Elemental Fury generation record

## Final icon

Mode: built-in `image_gen`, `stylized-concept`.

```text
Use case: stylized-concept
Asset type: game UI skill icon source for a 2D side-scrolling dungeon game
Primary request: Elemental Fury icon — one brilliant neutral-white elemental core exploding outward inside a circular shock ring; the left half of the ring uses smooth rounded cyan water arcs while the right half uses sharp orange fire spikes, conveying one decisive all-energy burst rather than a lingering field
Style/medium: crisp low-resolution-friendly painted pixel-art icon, 3-to-5 value steps, controlled glow, strong silhouette, no frame or badge
Composition/framing: one centered circular symbol, square composition, generous padding, readable at 32x32 and 64x64
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal; uniform color only, no shadow, gradient, texture, reflection, floor, or lighting variation
Constraints: no text, numbers, UI keycaps, characters, enemies, logos, watermark, smoke cloud, multiple explosions, or background scene; do not use #00ff00 inside the symbol; crisp separated edges
```

Post-process: official chroma-key removal plus 256×256 finalization.

## VFX selection

The user selected the licensed eight-frame `burst_core_neutral_candidate.png`. Stage 2 promoted the pixels unchanged to `burst_core.png`; no generative edit or timing interpolation was applied.

