# Passive Energy final manifest

| File | Purpose | Blend | Display | Tintable | Runtime |
|---|---|---|---|---|---|
| `icon.png` | Formal passive icon for `passive_energy` / 元素储备 | alpha | 256×256 source; HUD 32×32 or 64×64 | no | static icon only |

- Final file: 62,876 bytes; SHA-256 `28D5B75EF96B80AAE5D9F0209B74AB186870774553F46706EB2C589830248441`.
- Alpha QA: RGBA, transparent four corners, nonzero-alpha coverage `0.452744`, visible magenta/green key pollution `0` pixels.
- Shape contract: reinforced capped reservoir plus side clamps and three capacity windows conveys maximum-SP storage; no recovery arrow, charging rays, potion cork or instant refill semantics.
- Visual QA: inspected at original 256×256 and on a dark background at 128×128, 64×64 and 32×32; the canister silhouette and three windows remain distinct.
- Source and exact prompt are recorded in `prompt.md`; the original generated output remains in Codex generated-images storage and was not deleted.
- Gameplay dependency is the read-only `res://resources/skills/passive_energy.tres` (`maximum_energy_bonus = 10`). No world VFX, presentation scene or runtime delivery is introduced.
