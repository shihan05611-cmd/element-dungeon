# Run Reward Chest generation record

Mode: built-in `image_gen`, `stylized-concept` followed by `precise-object-edit`. No CLI/API/model fallback was used. Task17/32 icons and Task31 combat screenshots were inspected at original size and used as visual constraints; no project image was passed as an input.

## Closed-state design prompt

```text
Use case: stylized-concept
Asset type: world object sprite source for a 2D side-scrolling dungeon game
Primary request: a closed ordinary end-of-combat reward chest, sturdy compact treasure coffer with a low arched lid, dark walnut planks, deep navy iron bands, warm gold latch and corner brackets; humble dungeon reward, not a royal legendary chest
Style/medium: crisp low-resolution-friendly painted pixel art, strong chunky silhouette, 3-to-5 value steps, hard pixel-like stair-step edges, restrained highlights
Composition/framing: single isolated chest, centered, slight front three-quarter view, square canvas, generous padding, designed for 96px and 128px
Constraints: lid fully closed; no contents, text, characters, particles, shadow, reflection, watermark, or scene background
```

The generated design was edited once to replace a rejected black halo background with a perfectly uniform `#00ff00` field while preserving the chest exactly.

## Open-state edit prompt

```text
Use case: precise-object-edit
Input image: the selected closed-state chroma-key source
Primary request: create the open state by changing only the lid and small visible interior
Constraints: preserve the exact body, panels, bands, latch, brackets, wood, angle, proportions, pixel geometry, palette, scale and baseline; hinge the existing lid upward about 75 degrees; show only a compact dark interior with contained warm gold-white light; no coins, loot, particles, external glow, shadow, redesign or camera change
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background
```

Selected built-in sources:

- closed: `exec-47b41862-7946-4a3a-9dcd-b00b7f3d5672.png`, SHA-256 `ED7714421C945B20FBC550DFE86AEA72BF03B1684D302715BB8197CCEB7EBC98`;
- open: `exec-5a48bfe9-b8c5-41ad-8616-bdbd6406772a.png`, SHA-256 `C8939526C9338016F70299AD23074373CA060298B145200A3F3AF8A6C3FEAB13`.

Both sources were processed with the official helper using `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --edge-contract 1 --despill`, then resized from the shared square canvas to 256×256 so the two states retain their common scale and baseline.
