class_name ElementDefinition
extends Resource

## Static presentation/catalog data only. Runtime element amounts never live in
## this Resource, so sharing one `.tres` cannot share combat state.

@export var id: StringName = ElementIds.NONE
@export var display_name: String = ""
@export var presentation_color: Color = Color.WHITE
@export var presentation_tags: PackedStringArray = PackedStringArray()


func validation_error() -> StringName:
	if not ElementIds.is_combat_element(id):
		return &"unknown_element_id"
	if display_name.is_empty():
		return &"missing_display_name"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()
