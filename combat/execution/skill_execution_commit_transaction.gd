class_name SkillExecutionCommitTransaction
extends RefCounted

## Prepared external mutation. validation_error must be pure; after it returns
## empty, commit_silent is an infallible synchronous commit and publish_committed
## is the only observer-facing phase.

func validation_error() -> StringName:
	return &""


func commit_silent() -> void:
	pass


func publish_committed() -> void:
	pass


func owns_prepared_delivery() -> bool:
	return false


func requires_immediate_activation() -> bool:
	return false


func activate_prepared_delivery() -> bool:
	return true
