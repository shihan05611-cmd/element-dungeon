from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SHEETS = (
    (ROOT / "assets/characters/cat/cat_attack.png", "cat_attack"),
    (ROOT / "assets/characters/cat/cat_water_attack.png", "cat_water_attack"),
    (ROOT / "assets/characters/cat/cat_fire_attack.png", "cat_fire_attack"),
)
CELL_WIDTH = 80
CELL_HEIGHT = 64
AIRFLOW_LEFT_EDGE_BY_FRAME = (0, 0, 19, 19, 19, 19, 20, 20)


def connected_components(image: Image.Image) -> list[tuple[int, tuple[int, int, int, int]]]:
    alpha = image.getchannel("A")
    occupied = {(x, y) for y in range(image.height) for x in range(image.width) if alpha.getpixel((x, y))}
    result: list[tuple[int, tuple[int, int, int, int]]] = []
    while occupied:
        start = occupied.pop()
        queue = deque([start])
        points = [start]
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in occupied:
                    occupied.remove(neighbor)
                    points.append(neighbor)
                    queue.append(neighbor)
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        result.append((len(points), (min(xs), min(ys), max(xs) + 1, max(ys) + 1)))
    return sorted(result, reverse=True)


def component_points(image: Image.Image) -> list[set[tuple[int, int]]]:
    alpha = image.getchannel("A")
    occupied = {(x, y) for y in range(image.height) for x in range(image.width) if alpha.getpixel((x, y))}
    result: list[set[tuple[int, int]]] = []
    while occupied:
        start = occupied.pop()
        queue = deque([start])
        points = {start}
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in occupied:
                    occupied.remove(neighbor)
                    points.add(neighbor)
                    queue.append(neighbor)
        result.append(points)
    return result


def split_cell(cell: Image.Image, frame: int) -> tuple[Image.Image, Image.Image]:
    body = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    airflow = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    cutoff = AIRFLOW_LEFT_EDGE_BY_FRAME[frame]
    components = component_points(cell)
    main = max(components, key=len)
    for component in components:
        detached_effect = component is not main and any(x < cutoff or y < 20 for x, y in component)
        for x, y in component:
            is_airflow = (cutoff > 0 and x < cutoff) or detached_effect
            (airflow if is_airflow else body).putpixel((x, y), cell.getpixel((x, y)))
    return body, airflow


def composite_exact(body: Image.Image, airflow: Image.Image, source: Image.Image) -> bool:
    for y in range(source.height):
        for x in range(source.width):
            body_pixel = body.getpixel((x, y))
            airflow_pixel = airflow.getpixel((x, y))
            if body_pixel[3] > 0 and airflow_pixel[3] > 0:
                return False
            reconstructed = body_pixel if body_pixel[3] > 0 else airflow_pixel
            source_pixel = source.getpixel((x, y))
            if source_pixel[3] > 0 and reconstructed != source_pixel:
                return False
            if source_pixel[3] == 0 and reconstructed[3] != 0:
                return False
    return True


def main() -> None:
    for sheet_path, stem in SHEETS:
        sheet = Image.open(sheet_path).convert("RGBA")
        if sheet.size != (CELL_WIDTH * 8, CELL_HEIGHT):
            raise ValueError(f"{sheet_path}: expected 640x64, got {sheet.size}")
        body_sheet = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
        airflow_sheet = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
        for frame in range(sheet.width // CELL_WIDTH):
            cell = sheet.crop((frame * CELL_WIDTH, 0, (frame + 1) * CELL_WIDTH, CELL_HEIGHT))
            body, airflow = split_cell(cell, frame)
            if not composite_exact(body, airflow, cell):
                raise AssertionError(f"{sheet_path.name} frame {frame}: split does not recompose exactly")
            body_sheet.alpha_composite(body, (frame * CELL_WIDTH, 0))
            airflow_sheet.alpha_composite(airflow, (frame * CELL_WIDTH, 0))
        body_path = sheet_path.with_name(f"{stem}_body.png")
        airflow_path = sheet_path.with_name(f"{stem}_airflow.png")
        body_sheet.save(body_path)
        airflow_sheet.save(airflow_path)
        if not composite_exact(body_sheet, airflow_sheet, sheet):
            raise AssertionError(f"{sheet_path.name}: sheet split does not recompose exactly")
        print(f"{sheet_path.name} -> {body_path.name} + {airflow_path.name}: exact")


if __name__ == "__main__":
    main()
