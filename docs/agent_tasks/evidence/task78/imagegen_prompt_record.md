# Task 78 image-generation prompt record

- Mode: built-in `image_gen` (default mode).
- Role: concept-direction references only. Final game spritesheets are rebuilt
  deterministically from the shipped neutral Boss sheets so frame counts,
  anchors, baselines, and action semantics remain exact.
- Water concept prompt: preserve the neutral Boss structure, use the player
  water form only as a flow-method reference, build connected wave crests and
  ribbons, keep a stable six-frame baseline, and avoid detached droplets,
  isolated bright pixels, blur, gradients, or copied player effects.
- Fire concept prompt: preserve the neutral Boss structure, use the player fire
  form only as a flow-method reference, build a more forceful connected flame
  contour with coherent tongues, keep a stable six-frame baseline, and avoid
  campfire shapes, random detached specks, isolated bright pixels, blur,
  gradients, or copied player effects.
- Saved concepts:
  - `concepts/boss_tide_flow_reference_imagegen.png`
  - `concepts/boss_ember_flow_reference_imagegen.png`
