class_name TransientMeleeDelivery
extends MeleeDelivery


func close_hit_window() -> void:
	if is_finished:
		return
	super()
	finish(&"hit_window_closed")
