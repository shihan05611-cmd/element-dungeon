# Task53 deterministic art QA summary

- Formal PNG count: 6.
- Atlas manifest cells: 256; explicit blank reservations: 74.
- Legal 8-neighbor Terrain masks: 47/47.
- Atlas geometry: 512×512 RGBA, 16×16 cells, 32×32 px, margin 0, separation 0.
- Alpha policy: all formal sprites and atlas use RGBA; sprite alpha is hard 0/255 after target-size cleanup.
- Runtime reference scan: 0 hits in permitted runtime text scope; protected project.godot excluded.
- Task53 output `.import` sidecars: 0 (expected 0).
- QA images are composed from the formal PNGs at 100%, 2× or 3× nearest-neighbor only.
- Automated art gates: 23/23 PASS; see `automated_gate_results.csv`.
- Background atlas uniqueness: 64/64; required key classes: 9/9; largest duplicate group: 1.
- Preview exact-tile usage: 64/64 unique, maximum 10/288; exact-tile adjacency H=0, V=0.
- Hand-authored macro rhythm: broad-base adjacency score 313; equal-family adjacency H=173, V=165.
- Frozen source hashes are unchanged; see `frozen_master_hashes.csv`.
- Old chest/portal candidates still exist and were only fingerprinted; deletion remains a later engineering responsibility.
- No Godot/editor execution and no Git write operation are part of this build.
- Current/future builder runs exclude `global_instakill` files and `project.godot` from reads and scans.
- Known process deviation: the first four build iterations included a read-only new-path text scan of `project.godot` before the stricter protection conflict was identified. It reported 0 Task53 references and made no write or execution; this task does not claim literal no-read compliance for that file.
