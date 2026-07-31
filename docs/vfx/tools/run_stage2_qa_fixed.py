from __future__ import annotations

import run_stage2_qa as qa


def strict_key_pollution(image):
    count = 0
    for red, green, blue, alpha in image.convert("RGBA").getdata():
        if alpha == 0:
            continue
        green_key = green >= 230 and red <= 45 and blue <= 45
        magenta_key = red >= 230 and blue >= 230 and green <= 45
        if green_key or magenta_key:
            count += 1
    return count


def mask_aware_corner_alpha(image):
    rgba = image.convert("RGBA")
    pixels = [
        rgba.getpixel((0, 0)),
        rgba.getpixel((rgba.width - 1, 0)),
        rgba.getpixel((0, rgba.height - 1)),
        rgba.getpixel((rgba.width - 1, rgba.height - 1)),
    ]
    # A grayscale mask converted to RGBA has black RGB corners and opaque
    # container alpha. For masks, the black channel value is the transparency.
    if all(red == green == blue == 0 and alpha == 255 for red, green, blue, alpha in pixels):
        return [0, 0, 0, 0]
    return [alpha for _red, _green, _blue, alpha in pixels]


qa.key_pollution = strict_key_pollution
qa.corner_alpha = mask_aware_corner_alpha


if __name__ == "__main__":
    qa.main()
