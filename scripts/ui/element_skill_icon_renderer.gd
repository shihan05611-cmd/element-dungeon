class_name ElementSkillIconRenderer
extends RefCounted

## Programmatic 16-bit icon source for skills whose element follows the
## player's current form. Each glyph is authored once as five grayscale bands;
## the runtime maps those bands to a water or fire palette and caches the final
## texture. CombatHUD then swaps the cached texture on element_changed.

const BASE_SIZE := 16

const GRAYSCALE_PALETTE: Array[Color] = [
	Color(0.0, 0.0, 0.0, 1.0),
	Color(0.25, 0.25, 0.25, 1.0),
	Color(0.5, 0.5, 0.5, 1.0),
	Color(0.75, 0.75, 0.75, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
]

const WATER_PALETTE: Array[Color] = [
	Color("06151f"),
	Color("0b3959"),
	Color("0e78a8"),
	Color("4bd5ee"),
	Color("e7ffff"),
]

const FIRE_PALETTE: Array[Color] = [
	Color("240905"),
	Color("6e160b"),
	Color("cf3c12"),
	Color("ff9a24"),
	Color("fff0c2"),
]

const ELEMENT_BOLT_PATTERN: Array[String] = [
	"................",
	".............1..",
	"............231.",
	"..........1231..",
	".........2341...",
	"........2341....",
	"....1112341.....",
	"...12334431.....",
	"..123455431.....",
	".1234555431.....",
	".1345555431.....",
	".1344555431.....",
	".123444431......",
	"..1233331.......",
	"...11111........",
	"................",
]

const ELEMENTAL_LASER_PATTERN: Array[String] = [
	"................",
	"................",
	"................",
	"..11........11..",
	".1231......1321.",
	"12331......13321",
	"1343211111123431",
	"1455555555555541",
	"1455555555555541",
	"1343211111123431",
	"12331......13321",
	".1231......1321.",
	"..11........11..",
	"................",
	"................",
	"................",
]

var _grayscale_images: Dictionary[StringName, Image] = {}
var _tinted_textures: Dictionary[String, Texture2D] = {}


func supports(skill_id: StringName) -> bool:
	return skill_id == &"element_bolt" or skill_id == &"elemental_laser"


func grayscale_image(skill_id: StringName) -> Image:
	if not supports(skill_id):
		return null
	if not _grayscale_images.has(skill_id):
		_grayscale_images[skill_id] = _build_grayscale_image(_pattern_for(skill_id))
	return (_grayscale_images[skill_id] as Image).duplicate()


func texture_for(skill_id: StringName, element_id: StringName) -> Texture2D:
	if not supports(skill_id):
		return null
	var palette := _palette_for(element_id)
	if palette.is_empty():
		return null
	var cache_key := "%s:%s" % [String(skill_id), String(element_id)]
	if not _tinted_textures.has(cache_key):
		var tinted := _tint_image(grayscale_image(skill_id), palette)
		_tinted_textures[cache_key] = ImageTexture.create_from_image(tinted)
	return _tinted_textures[cache_key]


func _pattern_for(skill_id: StringName) -> Array[String]:
	if skill_id == &"element_bolt":
		return ELEMENT_BOLT_PATTERN
	if skill_id == &"elemental_laser":
		return ELEMENTAL_LASER_PATTERN
	return []


func _palette_for(element_id: StringName) -> Array[Color]:
	if element_id == ElementIds.WATER:
		return WATER_PALETTE
	if element_id == ElementIds.FIRE:
		return FIRE_PALETTE
	return []


func _build_grayscale_image(pattern: Array[String]) -> Image:
	assert(pattern.size() == BASE_SIZE)
	var image := Image.create(BASE_SIZE, BASE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y: int in BASE_SIZE:
		assert(pattern[y].length() == BASE_SIZE)
		for x: int in BASE_SIZE:
			var symbol := pattern[y].substr(x, 1)
			if symbol == ".":
				continue
			var palette_index := symbol.to_int() - 1
			assert(palette_index >= 0 and palette_index < GRAYSCALE_PALETTE.size())
			image.set_pixel(x, y, GRAYSCALE_PALETTE[palette_index])
	return image


func _tint_image(source: Image, palette: Array[Color]) -> Image:
	var tinted := Image.create(BASE_SIZE, BASE_SIZE, false, Image.FORMAT_RGBA8)
	tinted.fill(Color.TRANSPARENT)
	for y: int in BASE_SIZE:
		for x: int in BASE_SIZE:
			var sampled := source.get_pixel(x, y)
			if sampled.a <= 0.0:
				continue
			var palette_index := clampi(roundi(sampled.r * 4.0), 0, palette.size() - 1)
			var color := palette[palette_index]
			color.a = sampled.a
			tinted.set_pixel(x, y, color)
	return tinted
