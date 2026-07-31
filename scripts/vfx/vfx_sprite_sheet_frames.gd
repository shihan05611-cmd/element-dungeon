class_name VfxSpriteSheetFrames
extends SpriteFrames

@export var animation_name: StringName = &"default":
	set(value):
		animation_name = value
		_rebuild()
@export var frame_size: Vector2i = Vector2i(64, 64):
	set(value):
		frame_size = value
		_rebuild()
@export_range(1, 64, 1) var frame_count: int = 1:
	set(value):
		frame_count = value
		_rebuild()
@export_range(0.001, 1000.0, 0.001) var frames_per_second: float = 12.5:
	set(value):
		frames_per_second = value
		_rebuild()
@export var loops: bool = false:
	set(value):
		loops = value
		_rebuild()
@export var sheet: Texture2D:
	set(value):
		sheet = value
		_rebuild()


func _rebuild() -> void:
	if (
		sheet == null
		or animation_name.is_empty()
		or frame_size.x <= 0
		or frame_size.y <= 0
		or frame_count <= 0
		or not is_finite(frames_per_second)
		or frames_per_second <= 0.0
	):
		return
	clear_all()
	add_animation(animation_name)
	set_animation_loop(animation_name, loops)
	set_animation_speed(animation_name, frames_per_second)
	for frame_index in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(
			frame_index * frame_size.x,
			0,
			frame_size.x,
			frame_size.y
		)
		add_frame(animation_name, frame)

