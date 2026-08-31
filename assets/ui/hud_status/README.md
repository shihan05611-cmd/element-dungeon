# Task 91 status HUD source trace

`status_hud_water.png` and `status_hud_fire.png` are direct integer-nearest 4:1
crops of these Task 79 approved source images:

- `docs/agent_tasks/evidence/task79/status_hud_water_scoped_concept.png`
- `docs/agent_tasks/evidence/task79/status_hud_fire_scoped_concept.png`

Each crop uses source rectangle `(328, 288, 1056, 348)` and is reduced to the
fixed runtime size `264 x 87`. The HP and SP bar interiors only—runtime
coordinates `(53,14,179,25)` and `(53,48,179,25)`—were cleared to alpha so the
existing `ProgressBar` fills and value labels remain live. The remaining pixels
(including the concept labels, double border, right-side element break, and dark
texture) are preserved from the source crop.
