from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "docs/agent_tasks/evidence/task94/task94_skill_hud_hierarchy_states_full_concept_1920x1080.png"
RUNTIME = ROOT / "docs/agent_tasks/evidence/task95/screenshots/01_normal_with_empty_1920x1080.png"
OUTPUT = Path(__file__).parent / "native_runtime"

ACTIVE_REFERENCE_BOX = (690, 918, 1230, 1060)
ACTIVE_RUNTIME_BOX = (690, 912, 1230, 1054)
PASSIVE_BOX = (1420, 934, 1835, 1050)


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in (Path(r"C:\Windows\Fonts\msyh.ttc"), Path(r"C:\Windows\Fonts\simhei.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def save_pair(name: str, image: Image.Image) -> None:
    image.save(OUTPUT / f"{name}_1x.png")
    image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST).save(
        OUTPUT / f"{name}_4x_nearest.png"
    )


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    runtime = Image.open(RUNTIME).convert("RGBA")
    if source.size != (1920, 1080) or runtime.size != (1920, 1080):
        raise RuntimeError(f"comparison requires two 1920x1080 images: source={source.size}, runtime={runtime.size}")
    OUTPUT.mkdir(parents=True, exist_ok=True)

    source_active = source.crop(ACTIVE_REFERENCE_BOX)
    runtime_active = runtime.crop(ACTIVE_RUNTIME_BOX)
    source_passive = source.crop(PASSIVE_BOX)
    runtime_passive = runtime.crop(PASSIVE_BOX)
    save_pair("task95_active_runtime_closeup", runtime_active)
    save_pair("task95_passive_runtime_closeup", runtime_passive)

    board = Image.new("RGBA", (1240, 620), (8, 12, 20, 255))
    draw = ImageDraw.Draw(board)
    title_font = font(26)
    label_font = font(18)
    draw.text((32, 18), "Task95 原生像素资源与 Task94 最终 PASS 图 1× 对照", font=title_font, fill=(224, 236, 248, 255))
    draw.text((32, 58), "Task94 主动参考（原图裁切 540×142）", font=label_font, fill=(109, 188, 232, 255))
    draw.text((650, 58), "Task95 Godot 实机（原图裁切 540×142）", font=label_font, fill=(109, 188, 232, 255))
    board.alpha_composite(source_active, (32, 88))
    board.alpha_composite(runtime_active, (650, 88))
    draw.text((32, 270), "Task94 被动参考（原图裁切 415×116）", font=label_font, fill=(142, 157, 181, 255))
    draw.text((650, 270), "Task95 Godot 实机（原图裁切 415×116）", font=label_font, fill=(142, 157, 181, 255))
    board.alpha_composite(source_passive, (32, 300))
    board.alpha_composite(runtime_passive, (650, 300))
    notes = [
        "对照重点：主动顶/底边贯通、仅两处分隔、角部阶梯与亮暗层；被动 4×1 更暗更细。",
        "Task95 动态键位、图标、SP、冷却和被动状态来自运行时，不属于静态框体资产。",
        "本图只并排展示 1×原始截图像素，不参与运行时资源生成。",
    ]
    for index, line in enumerate(notes):
        draw.text((32, 454 + index * 38), line, font=label_font, fill=(196, 207, 221, 255))
    board.save(OUTPUT / "task94_task95_native_runtime_comparison_1x.png")
    print("TASK95 NATIVE VISUAL COMPARISON COMPLETE")


if __name__ == "__main__":
    main()
