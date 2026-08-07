class_name ProjectileSweepQueryPort2D
extends RefCounted


func query_first_contact(_request: ProjectileSweepRequest2D) -> ProjectileSweepResult2D:
	return ProjectileSweepResult2D.query_failed(&"abstract_projectile_sweep_query_port")
