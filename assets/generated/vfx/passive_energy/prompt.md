# Passive Energy generation record

## Final icon

Mode: built-in `image_gen`, `stylized-concept`.

Task17's six accepted `icon.png` files were inspected at original size before generation and used as visual constraints; no project image was edited or passed as an image input.

```text
Use case: stylized-concept. Asset type: game UI passive-skill icon source for a 2D side-scrolling dungeon game. Create the formal passive icon for 元素储备 / passive_energy: one unmistakable upright reinforced elemental reservoir canister, shaped like a squat hexagonal crystal tank with a wide sealed cap, two side clamps, and three clearly separated horizontal capacity windows glowing inside; a small neutral-white crystal core is stored at the bottom. It must communicate permanently increased maximum SP storage/capacity, NOT instant energy recovery, charging, mana regeneration, a consumable potion, or a castable spell. Match an accepted six-icon set: crisp low-resolution-friendly painted pixel-art, strong chunky silhouette, 3-to-5 value steps, hard pixel-like stair-step edges, controlled tiny inner glow, saturated deep sapphire/cyan reservoir glass, dark navy metal clamps, warm gold seams, pale neutral-white accents, no frame or badge. Centered square composition with generous transparent-safe padding, readable and recognizable at 32x32 and 64x64. Shape redundancy is mandatory: vessel silhouette plus cap/clamps plus three capacity windows; do not rely on blue color alone. Scene/backdrop: perfectly flat solid #ff00ff chroma-key background, uniform color only, no shadow, gradient, texture, reflection, floor, or lighting variation. Constraints: no text, numbers, UI keycaps, characters, faces, enemies, lightning bolt, battery icon, plug, arrow, outward rays, pouring liquid, bubbles escaping, potion cork, heart, medical cross, flame, shield, armor breastplate, sword, logos, watermark, background scene; do not use #ff00ff anywhere in the subject; crisp separated boundary with no semitransparent cast shadow.
```

Generated source: `C:\Users\heliashi\.codex\generated_images\019fd201-d2b5-7593-afbd-d73bd1908acf\exec-e47939ca-ce94-4cda-9229-31d1449a47ab.png`, SHA-256 `0030D3C46C9C5164561EF634E853FA912DD5C3AEE1670D13730562A9D3301F0A`.

Post-process: official imagegen `remove_chroma_key.py` with `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --edge-contract 1 --despill`; Task17 `finalize_icon` then centers the alpha subject at 220 px inside a 256×256 transparent canvas.

No world VFX was generated. This is a permanent stat-capacity passive with `presentation_scene = null` and `runtime_delivery_scene = null`.
