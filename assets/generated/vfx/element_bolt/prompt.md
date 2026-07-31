# Element Bolt generation record

## Final icon

Mode: built-in `image_gen`, `stylized-concept`.

Input images: none. Project TestRoom scale and the existing projectile were read as design constraints, not passed as image inputs.

```text
Use case: stylized-concept
Asset type: game UI skill icon source for a 2D side-scrolling dungeon game
Primary request: Element Bolt icon — a compact diagonal elemental projectile with a bright neutral white core, a smooth rounded cyan water crescent on one side, and a pointed orange fire-flame tail on the other, clearly readable as a fast projectile rather than a laser beam
Style/medium: crisp low-resolution-friendly painted pixel-art icon, 3-to-5 value steps, controlled glow, strong silhouette, no frame or badge
Composition/framing: one centered symbol, square composition, generous padding, designed to remain readable at 32x32 and 64x64
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal; uniform color only, no shadow, gradient, texture, reflection, floor, or lighting variation
Constraints: no text, numbers, UI keycaps, characters, enemies, logos, watermark, smoke cloud, long beam, or background scene; do not use #00ff00 anywhere in the symbol; crisp separated edges
```

Post-process: official `remove_chroma_key.py`, soft matte, despill, edge-contract 1, 256×256 finalization, strict residual-key cleanup.

## VFX

No new projectile VFX was generated in stage 2. The user approved reuse of the already-integrated water/fire sheets; their source and runtime paths are recorded in `manifest.md`.

