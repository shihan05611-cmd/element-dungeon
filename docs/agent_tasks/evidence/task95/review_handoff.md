# Task95 independent Review handoff

Status: native-pixel resource rework returned to Central for comparison; **do not send to Review yet and not self-accepted**.

## Task95-owned changes

- `assets/ui/hud_skill/`: five extracted/imported PNG resources.
- `scripts/combat_hud.gd`: Task95 constants, active/passive layout, static frame projection, dynamic active/passive state projection and lock-only fixture API.
- `combat/tests/run_task95_skill_hud_tests.gd`: focused 3+4 layout/state/compatibility coverage.
- `combat/tests/capture_task95_skill_hud_visuals.gd`: seven true-window captures.
- Exact intentional expectation migrations in Task72/73/74 and HUD loadout feedback tests.
- `docs/agent_tasks/evidence/task95/`: provenance, logs, screenshots and audit notes.

## Dirty-worktree isolation

The pre-existing Task91 status HUD and element-skill-icon changes in `scripts/combat_hud.gd`, `combat/tests/run_hud_loadout_feedback_tests.gd`, `assets/ui/hud_status/`, `scripts/ui/element_skill_icon_renderer.gd` and their tests/evidence were retained. No checkout, reset, whole-file replacement, commit or push was used.

Preservation gates pass in the final code state:

- Task91 status HUD: 2 tests / 14 assertions.
- Element skill icon renderer: 4 tests / 1246 assertions.
- HUD loadout feedback including the pre-existing palette swap checks: 13 tests / 143 assertions.

## Central recheck entry points

1. `asset_provenance.md`, `native_assets/` and `extract_task95_skill_hud_assets.py` for native 1×/4×, source palette, pixel-run and alpha traceability.
2. `test_results.md` and `final_*.log` for current-code regression evidence.
3. `visual_evidence_audit.md`, `native_runtime/task94_task95_native_runtime_comparison_1x.png` and `screenshots/` for Task94 side-by-side and same-camera states.
4. Inspect the 1920×1080 images at original size for continuous active top/bottom edges, exactly two separators, key/SP/readout legibility and passive visual subordination.
5. Confirm the lock exists only via the focused fixture API/test and is absent from normal runtime screenshots.
