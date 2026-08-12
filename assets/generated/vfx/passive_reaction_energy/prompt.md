# Passive Reaction Energy generation record

Mode: built-in `image_gen`, `stylized-concept` followed by one `precise-object-edit` background cleanup. No CLI/API/model fallback was used. All eight accepted Task17/32 icons were inspected at original size; `passive_energy` and `element_reclaim` were explicit negative references, not edit inputs.

```text
Use case: stylized-concept
Asset type: game UI passive-skill icon source for a 2D side-scrolling dungeon game
Primary request: Elemental Reaction Energy / 元素回响 — one jagged reaction burst colliding with a rounded elemental spark, with three bold curved return channels sweeping downward and inward into a faceted neutral-white diamond core; communicate energy produced by a reaction and flowing back to the player
Style/medium: crisp low-resolution-friendly painted pixel art matching the accepted icon set, strong silhouette, 3-to-5 value steps, hard stair-step edges, violet/cyan/warm amber with a white core, no frame or badge
Composition/framing: compact centered emblem with clear gaps, generous padding, readable at 32×32 and 64×64
Constraints: no battery, canister, reservoir, tank, capacity windows, heart, healing cross, shield, storage gauge, lightning-only symbol, or water/fire spiral matching Reclaim; no text, character, watermark, shadow, halo or background; flat #00ff00 chroma-key field
```

The selected emblem was edited once to remove a rejected black/color-wash background and external bloom while preserving the burst, return channels and receiving core. Selected source: `exec-58a9c7bc-8924-4bed-8ba8-020e5d02a7d4.png`, SHA-256 `B0154087824FCD71B534775979F3D24B0923BFFDCE406999937004C6D2B5A17F`.

Post-process: official helper with border auto-key, soft matte, thresholds 12/220, edge-contract 1 and despill; 220 px subject on 256×256 alpha canvas; final strict cleanup removed 12 pure green edge pixels.
