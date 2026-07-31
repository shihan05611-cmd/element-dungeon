# Unending generation record

## Final icon

Mode: built-in `image_gen`, `stylized-concept`.

```text
Use case: stylized-concept
Asset type: game UI passive-skill icon source for a 2D side-scrolling dungeon game
Primary request: Unending passive icon — one rounded cyan-blue water droplet rising from two clean concentric ripples, with two small bubbles, conveying persistent water attachment and a brief recovery trigger without using medical symbolism
Style/medium: crisp low-resolution-friendly painted pixel-art icon, 3-to-5 value steps, controlled glow, strong rounded silhouette, no frame or badge
Composition/framing: centered droplet-and-ripple symbol, square composition, generous padding, readable at 32x32 and 64x64
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background for background removal; uniform color only, no shadow, gradient, texture, reflection, floor, or lighting variation
Constraints: no text, numbers, UI keycaps, characters, enemies, heart, medical cross, flame, consumed layers, large wave, logos, watermark, or background scene; do not use #ff00ff inside the symbol; crisp separated edges
```

## VFX synthesis

Mode: deterministic Python 3 + Pillow.

```text
Create a rounded twelve-frame 64×64 enemy-attached loop of bubbles and orbiting droplets.
Create a separate eight-frame 64×64 ripple/rising-drop accent for a successful Unending heal trigger.
Keep the effect on the enemy and do not imply stack consumption or the player's current element.
```
