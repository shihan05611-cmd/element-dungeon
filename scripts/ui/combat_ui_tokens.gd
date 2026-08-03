class_name CombatUiTokens
extends RefCounted

## Semantic presentation tokens for the combat HUD and run overlays.
## This file contains no combat, loadout, reward, or growth decisions.

const SURFACE := Color("0d1422")
const SURFACE_RAISED := Color("151f31")
const SURFACE_SOFT := Color("1b2940")
const SURFACE_OVERLAY := Color("101a2a")
const SCRIM := Color(0.015, 0.02, 0.035, 0.88)
const BORDER := Color("52647f")
const BORDER_FOCUS := Color("f4d37a")
const BORDER_PASSIVE := Color("9d83d8")
const TEXT := Color("f4f7fc")
const TEXT_MUTED := Color("aebbd0")
const TEXT_DIM := Color("8290a8")
const WATER := Color("54d6f4")
const WATER_COLORBLIND := Color("75d5ff")
const FIRE := Color("ff7557")
const FIRE_COLORBLIND := Color("ffb347")
const NEUTRAL := Color("ddd6c5")
const SUCCESS := Color("78dfa0")
const WARNING := Color("ffd166")
const ERROR := Color("ff7a86")
const BUSY := Color("b99cff")
const COOLDOWN := Color("79a9ff")
const COOLDOWN_SHADE := Color(0.015, 0.025, 0.05, 0.78)

const GAP_XS := 4
const GAP_SM := 8
const GAP_MD := 12
const TOUCH_MINIMUM := 44


static func panel(
	background: Color = SURFACE,
	border: Color = BORDER,
	radius: int = 8,
	border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 5
	return style


static func flat_panel(
	background: Color = SURFACE_RAISED,
	border: Color = BORDER,
	radius: int = 6,
	border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


static func button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := flat_panel(background, border, 6, 1)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func focus_style(border: Color = BORDER_FOCUS, radius: int = 7) -> StyleBoxFlat:
	var style := flat_panel(Color(0.0, 0.0, 0.0, 0.0), border, radius, 3)
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style
