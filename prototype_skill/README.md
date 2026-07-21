# Prototype skill module

Temporary, dependency-light skill prototype.

- `skill_caster.tscn` is the only integration point and is instanced under the player.
- Player and enemy scripts do not reference this module.
- The projectile calls `receive_interaction(position)` only when the hit body optionally provides it.
- No damage, mana, skill data, animation state, or permanent combat-system dependency is introduced.

To remove the module later, delete the `PrototypeSkillCaster` child from `scenes/player.tscn`, then delete this folder.
