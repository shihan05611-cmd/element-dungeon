# Passive Vitality final manifest

| File | Purpose | Blend | Display | Tintable | Runtime |
|---|---|---|---|---|---|
| `icon.png` | Formal passive icon for `passive_vitality` / 坚韧体魄 | alpha | 256×256 source; HUD 32×32 or 64×64 | no | static icon only |

- Final file: 54,942 bytes; SHA-256 `C4F7494D701FB91F3FDD06B7F97BC71768284F6DE5FA4E7315E3D4DF068E495C`.
- Alpha QA: RGBA, transparent four corners, nonzero-alpha coverage `0.406128`, visible magenta/green key pollution `0` pixels.
- Shape contract: heart core plus armored breastplate/shoulders conveys maximum-health capacity; no healing cross, potion, recovery burst or active shield semantics.
- Visual QA: inspected at original 256×256 and on a dark background at 128×128, 64×64 and 32×32; the heart and armor remain distinct.
- Source and exact prompt are recorded in `prompt.md`; the original generated output remains in Codex generated-images storage and was not deleted.
- Gameplay dependency is the read-only `res://resources/skills/passive_vitality.tres` (`maximum_health_bonus = 20`). No world VFX, presentation scene or runtime delivery is introduced.
