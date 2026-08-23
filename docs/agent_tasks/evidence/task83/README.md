# Task 83: HP/SP-only StatusPanel

Windowed OpenGL captures use the same 1920x1080 camera and real test-room HUD:

- `screenshots/01_water_hp_sp.png` — water state.
- `screenshots/02_fire_hp_sp.png` — fire state; StatusPanel geometry is unchanged.
- `screenshots/03_fire_low_hp.png` — fire state at 20/100 HP with the retained low-health alert.

The capture script asserts that `TitleRow` and `CurrentElement` are absent, while
both HP/SP value paths remain.
