# Elemental Laser generation record

## Final icon

Mode: built-in `image_gen`, `stylized-concept`.

```text
Use case: stylized-concept
Asset type: game UI skill icon source for a 2D side-scrolling dungeon game
Primary request: Elemental Laser icon — a clean horizontal piercing beam crossing two small target rings, with a bright white core; the upper edge is a smooth cyan water wave and the lower edge is a sharp orange fire serration, clearly a sustained laser rather than a projectile
Style/medium: crisp low-resolution-friendly painted pixel-art icon, 3-to-5 value steps, controlled glow, strong compact silhouette, no frame or badge
Composition/framing: centered horizontal symbol inside a square, generous padding on all sides, readable at 32x32 and 64x64
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal; uniform color only, no shadow, gradient, texture, reflection, floor, or lighting variation
Constraints: no text, numbers, UI keycaps, characters, enemies, logos, watermark, lightning zigzag, smoke, lens flare, or background scene; do not use #00ff00 inside the symbol; crisp separated edges
```

## VFX synthesis

Mode: deterministic Python 3 + Pillow 12.2.0, script `docs/vfx/tools/synthesize_skill_vfx.py`.

```text
Create a minimal 320×24 penetrating beam from five repeatable 64×24 segments.
Water uses smooth wave edges and rounded pulse droplets.
Fire uses jagged serrated edges and pointed pulse shards.
Generate an eight-frame 64×64 target pulse for each element.
Keep all output RGBA transparent; generate grayscale masks from exact alpha.
```

