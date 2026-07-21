class_name RelicEffectRegistry
extends RefCounted


static func create_effect(effect_kind: RelicDefinition.EffectKind) -> RelicEffect:
	match effect_kind:
		RelicDefinition.EffectKind.FORM_SWITCH_ENERGY_RESTORE:
			return FormSwitchEnergyEffect.new()
		RelicDefinition.EffectKind.REACTION_ENERGY_RESTORE:
			return ReactionEnergyEffect.new()
		RelicDefinition.EffectKind.ROOM_COMPLETE_HEAL:
			return RoomCompleteHealEffect.new()
		RelicDefinition.EffectKind.REACTION_TEMPORARY_ATTACK:
			return ReactionTemporaryAttackEffect.new()
		RelicDefinition.EffectKind.ACQUIRE_MAXIMUM_HEALTH, RelicDefinition.EffectKind.ACQUIRE_MAXIMUM_ENERGY:
			return AcquireMaximumStatEffect.new()
		_:
			return null
