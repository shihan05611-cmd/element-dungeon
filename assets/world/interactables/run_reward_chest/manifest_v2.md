# Run reward chest v2 manifest

状态：`TASK53 FORMAL STATIC SPRITES / REVIEW CANDIDATE`

- Canvas: `80×72 RGBA`, hard alpha, bottom-center anchor.
- Shared formal visible baseline: local `y=70`; canvas center `x=40`.
- Recommended integer world display: `1×`; Nearest; mipmaps off; lossless; repeat disabled. Same-screen QA against the current 2× player selected this factor.
- Closed SHA-256: `2714DAC5A5EC44B7C092A7D2F3574FB0E71A6529090138051DE1FA154C400D97`; bbox `(8, 16, 71, 71)`.
- Open SHA-256: `CBC4344454B8D0D969545046A53A1B037CDB354091A4D526B5009285E0F74D68`; bbox `(6, 3, 74, 71)`.
- State semantics are structural: closed lid versus raised lid and dark interior. Do not synthesize open state with modulate.
- Static sprites only. No open-transition animation frames are included.
- Common bottom-center and fixed source scaling preserve body width, latch center and floor contact; see `docs/agent_tasks/evidence/task53/qa/interactable_anchor_qa.png`.
