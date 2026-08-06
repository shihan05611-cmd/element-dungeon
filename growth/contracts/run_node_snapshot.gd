class_name RunNodeSnapshot
extends RefCounted

var node_id: StringName
var kind: int
var display_name: String
var scene_path: String
var final_boss: bool


func _init(
		p_node_id: StringName = &"",
		p_kind: int = RunNodeKind.ENTRY,
		p_display_name: String = "",
		p_scene_path: String = "",
		p_final_boss: bool = false
) -> void:
	node_id = p_node_id
	kind = p_kind
	display_name = p_display_name
	scene_path = p_scene_path
	final_boss = p_final_boss


static func from_definition(definition: RunNodeDefinition) -> RunNodeSnapshot:
	if definition == null:
		return null
	var room := definition.combat_room
	return RunNodeSnapshot.new(
		definition.node_id,
		definition.kind,
		room.display_name if room != null else String(definition.node_id),
		room.room_scene.resource_path if room != null and room.room_scene != null else "",
		room.final_boss if room != null else false
	)
