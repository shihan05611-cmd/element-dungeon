extends SceneTree

const HUD_SCRIPT: Script = preload("res://scripts/combat_hud.gd")


func _initialize() -> void:
	var hud := CanvasLayer.new()
	hud.name = "CombatHUD"
	hud.set_script(HUD_SCRIPT)
	root.add_child(hud)
	call_deferred(&"_after_ready", hud)


func _after_ready(hud: Node) -> void:
	print("boss_panel=%s" % [hud.get("boss_panel") != null])
	print("PASS")
	quit(0)
