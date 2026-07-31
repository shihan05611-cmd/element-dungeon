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
