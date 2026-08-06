# Passive Vitality generation record

## Final icon

Mode: built-in `image_gen`, `stylized-concept`.

Task17's six accepted `icon.png` files were inspected at original size before generation and used as visual constraints; no project image was edited or passed as an image input.

```text
Use case: stylized-concept. Asset type: game UI passive-skill icon source for a 2D side-scrolling dungeon game. Create the formal passive icon for 坚韧体魄 / passive_vitality: one unmistakable broad heart-shaped life core locked inside a thick angular chest-armor breastplate, with two short symmetric shoulder plates and a small golden reinforcement seam. It must communicate permanently increased maximum health and durable capacity, NOT healing, regeneration, resurrection, damage reduction, or an activated shield. Match an accepted six-icon set: crisp low-resolution-friendly painted pixel-art, strong chunky silhouette, 3-to-5 value steps, hard pixel-like stair-step edges, controlled tiny inner glow, saturated crimson/coral heart core, dark burgundy steel, warm gold highlight, pale neutral-white specular accents, no frame or badge. Centered square composition with generous transparent-safe padding, readable and recognizable at 32x32 and 64x64. Shape redundancy is mandatory: heart silhouette plus armored breastplate geometry; do not rely on red color alone. Scene/backdrop: perfectly flat solid #ff00ff chroma-key background, uniform color only, no shadow, gradient, texture, reflection, floor, or lighting variation. Constraints: no text, numbers, UI keycaps, characters, faces, enemies, medical cross, potion, bandage, plus sign, floating healing sparkles, wings, active shield bubble, sword, flame, water droplet, energy container, logos, watermark, background scene; do not use #ff00ff anywhere in the subject; crisp separated boundary with no semitransparent cast shadow.
```

Generated source: `C:\Users\heliashi\.codex\generated_images\019fd201-d2b5-7593-afbd-d73bd1908acf\exec-bd71a0d7-5578-48e7-9139-94cde2de71b7.png`, SHA-256 `CD3E1B839DD8493A2A1B8CD6B30DFD80CD756A261E48A637047D6900B980DB14`.

Post-process: official imagegen `remove_chroma_key.py` with `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --edge-contract 1 --despill`; Task17 `finalize_icon` then centers the alpha subject at 220 px inside a 256×256 transparent canvas.

No world VFX was generated. This is a permanent stat-capacity passive with `presentation_scene = null` and `runtime_delivery_scene = null`.
