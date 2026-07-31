# Element Reclaim generation record

## Final icon

Mode: built-in `image_gen`, `stylized-concept`.

Final prompt:

```text
Use case: stylized-concept
Asset type: game UI skill icon source for a 2D side-scrolling dungeon game
Primary request: Element Reclaim icon — ONLY cyan water droplets and orange fire shards curve inward along clear arcing paths toward one bright neutral-white central energy core; all particles visibly travel inward, never outward
Style/medium: crisp low-resolution-friendly painted pixel-art icon, 3-to-5 value steps, controlled glow, strong silhouette, no frame or badge
Composition/framing: centered inward spiral/convergence symbol, square composition, generous padding, readable at 32x32 and 64x64
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal; uniform color only, no shadow, gradient, texture, reflection, floor, or lighting variation
Constraints: exactly two elemental shape families only — rounded blue/cyan water droplets and pointed orange fire shards; absolutely no rocks, earth, purple, gray, green, wind, lightning, third element, text, numbers, UI keycaps, character silhouette, enemy silhouette, healing cross, energy bar, logos, watermark, smoke, outward blast, or background scene; do not use #00ff00 inside the symbol; crisp separated edges
```

Iteration: the first icon draft added gray rock particles. It was rejected and retained under `discarded/icon_reclaim_third_element_rejected_v1.png`; the final prompt explicitly limits the icon to water and fire.

## VFX synthesis

Mode: deterministic Python 3 + Pillow.

```text
Generate separate eight-frame 32×32 water-droplet and fire-shard particles.
Generate tintable eight-frame 64×64 extraction and player-arrival sheets.
Do not bake a fixed trajectory: integration moves particles from each matched enemy to the player along a runtime curve.
No success VFX on a failed or empty reclaim transaction.
```

