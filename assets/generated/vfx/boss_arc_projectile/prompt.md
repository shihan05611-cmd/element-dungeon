# Boss Arc Projectile generation record

Mode: built-in `image_gen`, `stylized-concept` followed by one `precise-object-edit` background cleanup. No CLI/API/model fallback was used. Task31 Boss-room screenshots were inspected at original size as the dark-world reference.

```text
Use case: stylized-concept
Asset type: isolated enemy projectile sprite source for a 2D side-scrolling dungeon game
Primary request: one low-flying boss projectile traveling horizontally left, shaped as a broad violet crescent arc with two forward horn tips, a thick lavender cutting edge, a compact dark-purple rear core and three short backward speed fins; read as a jump-over hazard, not a weapon pickup
Style/medium: crisp low-resolution-friendly painted pixel art, strong 2:1 horizontal silhouette, 3-to-5 value steps, hard stair-step edges, purple/violet/lavender palette with a tiny cyan highlight, mostly opaque
Composition/framing: centered in a square canvas with generous padding, designed around 96×48 display
Constraints: no character, hand, weapon handle, face, eye, emblem, pickup sparkle, text, badge, watermark, shadow, smoke, long soft trail, aura, scenery or background; flat #00ff00 chroma-key field
```

The selected projectile was edited once to remove a rejected black background/fringe while preserving orientation and geometry. Selected source: `exec-4b7dc196-cb01-4993-80f4-9637c2287053.png`, SHA-256 `6DE50A20F7546A2511C7B04CAF5C642400199CF57A446E31B866A1357BEF4F95`.

Post-process: official helper with border auto-key, soft matte, thresholds 12/220, edge-contract 1 and despill; 220 px subject on a 256×256 alpha canvas; final strict cleanup removed 2 pure green edge pixels.
