class_name RuntimeLoadoutPort
extends RefCounted

## Agent B implements this port. validate_snapshot must be side-effect free;
## try_replace_snapshot must atomically replace all slots or change nothing.

func snapshot() -> RuntimeLoadoutSnapshot:
	return RuntimeLoadoutSnapshot.new()


func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
	return RuntimeLoadoutChangeResult.rejected(&"runtime_loadout_port_not_configured", snapshot())


func try_replace_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
	return RuntimeLoadoutChangeResult.rejected(&"runtime_loadout_port_not_configured", snapshot())
