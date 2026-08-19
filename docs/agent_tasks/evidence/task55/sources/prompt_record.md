# Task55 built-in ImageGen source record

Mode：built-in `image_gen`（项目位图资产，未使用 CLI/API fallback）  
Use case：`stylized-concept`  
Shared references：

- `assets/art_preview/scene_preview/tidal_dungeon_room_v1.png`：目标构图、宏观石墙比例与氛围参考；
- `assets/art_preview/tiles/dungeon_tileset_v1.png`：潮汐石材、深蓝/青紫配色与粗像素参考。

## Prompt set and copied sources

1. `background_wall_source.png`
   - Prompt：wide 24:13 empty tidal dungeon wall only; large horizontal stone courses, broad dark masonry planes and quiet gameplay band; uniformly dim unlit material values; no arches, pillars, chains, cracks as focal objects, floor, platform, lamp, crystal, character, chest, portal, light pool, glow, vignette, repeated tiles or tiny brick grid.
2. `back_decor_chromakey.png`
   - Prompt：transparent-source overlay on flat `#FF00FF`; one large recessed dark arch, two partial heavy pilasters, two short chains, two restrained cracks and two rubble groups; sparse isolated objects; no wall plane, floor, platform, fixture, lighting, shadow, glow or gameplay object.
3. `front_decor_chromakey.png`
   - Prompt：transparent-source overlay on flat `#FF00FF`; low broken stone shelf at bottom-left, smaller bottom-right outcrop and minimal upper-corner fragments; central 75% gameplay band nearly empty; no wall, floor, playable platform, light or gameplay object.
4. `ground_floor_chromakey.png`
   - Prompt：one individually authored full-width floor strip on flat `#FF00FF`; continuous playable top, large uneven stone blocks, sparse seams, consistent thickness; no repeated modules, baked lighting or other objects.
5. `platform_short_chromakey.png`
   - Prompt：one independently drawn short platform on flat `#FF00FF`; continuous top, heavy caps, broad center slab and restrained violet under-edge; unlit, no supports or other objects.
6. `platform_medium_chromakey.png`
   - Prompt：one independently drawn medium platform on flat `#FF00FF`; same family thickness/caps, two unequal center slabs and one restrained seam; explicitly not a stretched short platform.
7. `platform_long_chromakey.png`
   - Prompt：one independently drawn long platform on flat `#FF00FF`; same family thickness/caps, three unequal slabs and non-equal seams; explicitly no repeated center module or stretched texture.

The six chroma-key sources were processed with the installed imagegen `remove_chroma_key.py` helper. Formal files were then cropped to the declared canvas, reduced with nearest-neighbor, constrained to the accepted tidal palette, hard-alpha cleaned and checked at original size. The generated source images are provenance only; the seven files under `assets/world/rooms/tidal_dungeon/platform_room_v1/` are the runtime candidates.
