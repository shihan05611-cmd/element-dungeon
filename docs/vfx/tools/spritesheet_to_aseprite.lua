local input = app.params["input"]
local output = app.params["output"]
local duration_ms = tonumber(app.params["duration_ms"] or "80")

if not input or input == "" then
  error("Missing -script-param input=<path>")
end

if not output or output == "" then
  error("Missing -script-param output=<path>")
end

local sheet = Image { fromFile=input }

if not sheet then
  error("Unable to load input image: " .. input)
end

if sheet.height ~= 64 or sheet.width % 64 ~= 0 then
  error("Expected a horizontal 64x64 frame strip: " .. input)
end

local frame_count = sheet.width // 64
local sprite = Sprite(64, 64, ColorMode.RGB)
local layer = sprite.layers[1]
layer.name = "VFX"
sprite.gridBounds = Rectangle(0, 0, 64, 64)
sprite.data = "Source candidate: " .. input

for index = 1, frame_count do
  local frame
  if index == 1 then
    frame = sprite.frames[1]
  else
    frame = sprite:newEmptyFrame()
  end

  local source_rect = Rectangle((index - 1) * 64, 0, 64, 64)
  local frame_image = Image(sheet, source_rect)
  sprite:newCel(layer, frame, frame_image, Point(0, 0))
  frame.duration = duration_ms / 1000.0
end

local tag = sprite:newTag(1, frame_count)
tag.name = "preview_loop"
tag.aniDir = AniDir.FORWARD
tag.repeats = 0
tag.data = "Preview timing only; final timing depends on Task 15."

sprite:saveAs(output)
sprite:close()
