class_name FormChangeRelicDefinition
extends RelicDefinition

## Static form-change source filter without expanding RelicDefinition's base
## contract. Catalogs typed as RelicDefinition accept this specialized Resource.

@export var response_policy: FormChangeResponsePolicy.Value = FormChangeResponsePolicy.Value.ALL


func validation_error() -> StringName:
	var base_error := super()
	if not base_error.is_empty():
		return base_error
	if effect_kind != EffectKind.FORM_SWITCH_ENERGY_RESTORE:
		return &"form_change_filter_requires_form_switch_effect"
	if not FormChangeResponsePolicy.is_valid(response_policy):
		return &"invalid_form_change_response_policy"
	return &""
