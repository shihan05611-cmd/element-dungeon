# Burning generation record

## Final icon

Mode: built-in `image_gen`, `stylized-concept`.

```text
Use case: stylized-concept
Asset type: game UI passive-skill icon source for a 2D side-scrolling dungeon game
Primary request: Burning passive icon — one compact pointed orange-red flame layer marker with three small rising sparks and a subtle persistent ring at its base, conveying a fire status that remains while dealing periodic damage
Style/medium: crisp low-resolution-friendly painted pixel-art icon, 3-to-5 value steps, controlled glow, strong silhouette, no frame or badge
Composition/framing: centered compact flame symbol, square composition, generous padding, readable at 32x32 and 64x64
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal; uniform color only, no shadow, gradient, texture, reflection, floor, or lighting variation
Constraints: no text, numbers, UI keycaps, characters, enemies, extra attachment orb, consumed layers, smoke plume, ground fire patch, healing symbol, logos, watermark, or background scene; do not use #00ff00 inside the symbol; crisp separated edges
```

## VFX synthesis

Mode: deterministic Python 3 + Pillow.

```text
Create a sparse twelve-frame 64×64 enemy-attached fire loop with short tongues and rising sparks.
Create a separate eight-frame 64×64 outward spark accent for the confirmed one-second Burning tick.
Keep the enemy center readable; do not encode stack count or layer consumption.
```

