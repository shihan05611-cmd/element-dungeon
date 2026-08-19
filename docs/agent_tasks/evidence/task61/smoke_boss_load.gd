extends SceneTree

const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")


func _initialize() -> void:
	var boss := BOSS_SCENE.instantiate() as BossTideEmber
	if boss == null:
		print("FAIL: could not instantiate boss scene")
		quit(1)
		return
	root.add_child(boss)
	call_deferred(&"_after_ready", boss)


func _after_ready(boss: BossTideEmber) -> void:
	print("form=%s element=%s water=%d fire=%d ranged_profile_valid=%s" % [
		String(boss.current_form_id),
		String(boss.current_form.element_id),
		boss.element_carrier.get_amount(&"water"),
		boss.element_carrier.get_amount(&"fire"),
		boss.ranged_projectile_profile != null and boss.ranged_projectile_profile.validation_error().is_empty(),
	])
	print("tuning_valid=%s ember_valid=%s tide_valid=%s plain_valid=%s" % [
		boss.tuning.validation_error(),
		boss.ember_form.validation_error(),
		boss.tide_form.validation_error(),
		boss.plain_form.validation_error(),
	])
	print("PASS")
	quit(0)
