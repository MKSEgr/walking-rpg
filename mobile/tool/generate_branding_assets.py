#!/usr/bin/env python3
"""Generate and validate native Walking RPG launcher and splash assets."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MOBILE_ROOT = REPOSITORY_ROOT / "mobile"
EMBLEM_PATH = MOBILE_ROOT / "assets" / "branding" / "expedition_emblem.webp"

ANDROID_RES = MOBILE_ROOT / "android" / "app" / "src" / "main" / "res"
IOS_ASSETS = MOBILE_ROOT / "ios" / "Runner" / "Assets.xcassets"

INK = "#07151D"
DEEP_WATER = "#102A33"
ADAPTIVE_LAYER_DP = 108
ADAPTIVE_SAFE_DIAMETER_DP = 66
# Keep one logical pixel inside the guaranteed circle so density rounding and
# antialiasing cannot place a partially opaque edge outside the safe zone.
ADAPTIVE_ART_DIAMETER_DP = 65

ANDROID_DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}

IOS_ICON_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def _load_emblem() -> Image.Image:
    emblem = Image.open(EMBLEM_PATH).convert("RGBA")
    alpha = emblem.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"{EMBLEM_PATH} has no visible pixels")
    return emblem.crop(bbox)


def _radial_background(size: int) -> Image.Image:
    gradient = Image.radial_gradient("L").resize(
        (size, size),
        Image.Resampling.LANCZOS,
    )
    return ImageOps.colorize(
        gradient,
        black=DEEP_WATER,
        white=INK,
    ).convert("RGBA")


def _centered_emblem(
    emblem: Image.Image,
    canvas_size: int,
    visible_fraction: float,
) -> Image.Image:
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    target = max(1, round(canvas_size * visible_fraction))
    mark = emblem.copy()
    mark.thumbnail((target, target), Image.Resampling.LANCZOS)
    canvas.alpha_composite(
        mark,
        ((canvas_size - mark.width) // 2, (canvas_size - mark.height) // 2),
    )
    return canvas


def _full_icon(emblem: Image.Image, size: int) -> Image.Image:
    icon = _radial_background(size)
    icon.alpha_composite(_centered_emblem(emblem, size, 0.82))
    return icon


def _write_png(image: Image.Image, path: Path, *, rgb: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    output = image.convert("RGB") if rgb else image
    output.save(path, "PNG", optimize=True)


def _round_icon(emblem: Image.Image, size: int) -> Image.Image:
    icon = _full_icon(emblem, size)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    icon.putalpha(mask)
    return icon


def generate() -> None:
    emblem = _load_emblem()

    for density, scale in ANDROID_DENSITIES.items():
        mipmap = ANDROID_RES / f"mipmap-{density}"
        launcher_size = round(48 * scale)
        adaptive_size = round(ADAPTIVE_LAYER_DP * scale)
        launch_size = round(128 * scale)

        _write_png(
            _full_icon(emblem, launcher_size),
            mipmap / "ic_launcher.png",
            rgb=True,
        )
        _write_png(
            _round_icon(emblem, launcher_size),
            mipmap / "ic_launcher_round.png",
        )
        _write_png(
            _centered_emblem(
                emblem,
                adaptive_size,
                ADAPTIVE_ART_DIAMETER_DP / ADAPTIVE_LAYER_DP,
            ),
            mipmap / "ic_launcher_foreground.png",
        )
        _write_png(
            _centered_emblem(emblem, launch_size, 0.86),
            ANDROID_RES / f"drawable-{density}" / "launch_mark.png",
        )

    ios_icons = IOS_ASSETS / "AppIcon.appiconset"
    for filename, size in IOS_ICON_SIZES.items():
        _write_png(
            _full_icon(emblem, size),
            ios_icons / filename,
            rgb=True,
        )

    launch_images = IOS_ASSETS / "LaunchImage.imageset"
    for filename, size in {
        "LaunchImage.png": 160,
        "LaunchImage@2x.png": 320,
        "LaunchImage@3x.png": 480,
    }.items():
        _write_png(
            _centered_emblem(emblem, size, 0.86),
            launch_images / filename,
        )


def _assert_image(path: Path, size: int, mode: str) -> None:
    with Image.open(path) as image:
        image.load()
        if image.size != (size, size):
            raise ValueError(f"{path} is {image.size}, expected {size} x {size}")
        if image.mode != mode:
            raise ValueError(f"{path} is {image.mode}, expected {mode}")


def _assert_transparent_corners(path: Path) -> None:
    with Image.open(path).convert("RGBA") as image:
        corners = (
            image.getpixel((0, 0))[3],
            image.getpixel((image.width - 1, 0))[3],
            image.getpixel((0, image.height - 1))[3],
            image.getpixel((image.width - 1, image.height - 1))[3],
        )
        if corners != (0, 0, 0, 0):
            raise ValueError(f"{path} must keep transparent corners, got {corners}")


def validate() -> None:
    emblem = _load_emblem()
    if max(emblem.size) < 1024:
        raise ValueError(f"{EMBLEM_PATH} must retain a 1024 px source edge")

    for density, scale in ANDROID_DENSITIES.items():
        mipmap = ANDROID_RES / f"mipmap-{density}"
        launcher_size = round(48 * scale)
        adaptive_size = round(ADAPTIVE_LAYER_DP * scale)
        launch_size = round(128 * scale)

        _assert_image(mipmap / "ic_launcher.png", launcher_size, "RGB")
        _assert_image(mipmap / "ic_launcher_round.png", launcher_size, "RGBA")
        _assert_image(
            mipmap / "ic_launcher_foreground.png",
            adaptive_size,
            "RGBA",
        )
        _assert_transparent_corners(mipmap / "ic_launcher_round.png")
        _assert_transparent_corners(mipmap / "ic_launcher_foreground.png")
        _assert_transparent_corners(
            ANDROID_RES / f"drawable-{density}" / "launch_mark.png"
        )
        _assert_image(
            ANDROID_RES / f"drawable-{density}" / "launch_mark.png",
            launch_size,
            "RGBA",
        )

        with Image.open(mipmap / "ic_launcher_foreground.png") as foreground:
            alpha = foreground.getchannel("A")
            outside_safe_zone = alpha.copy()
            pixels = outside_safe_zone.load()
            center = adaptive_size / 2
            safe_radius = (
                adaptive_size
                * ADAPTIVE_SAFE_DIAMETER_DP
                / ADAPTIVE_LAYER_DP
                / 2
            )
            safe_radius_squared = safe_radius * safe_radius
            for y in range(adaptive_size):
                for x in range(adaptive_size):
                    distance_squared = (x + 0.5 - center) ** 2 + (
                        y + 0.5 - center
                    ) ** 2
                    if distance_squared <= safe_radius_squared:
                        pixels[x, y] = 0
            if outside_safe_zone.getbbox() is not None:
                raise ValueError(
                    f"{mipmap / 'ic_launcher_foreground.png'} exceeds the circular "
                    f"{ADAPTIVE_SAFE_DIAMETER_DP} dp safe zone"
                )

    for filename, size in IOS_ICON_SIZES.items():
        _assert_image(IOS_ASSETS / "AppIcon.appiconset" / filename, size, "RGB")

    for filename, size in {
        "LaunchImage.png": 160,
        "LaunchImage@2x.png": 320,
        "LaunchImage@3x.png": 480,
    }.items():
        path = IOS_ASSETS / "LaunchImage.imageset" / filename
        _assert_image(path, size, "RGBA")
        _assert_transparent_corners(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate committed assets without regenerating them",
    )
    args = parser.parse_args()

    if args.check:
        validate()
        return

    generate()
    validate()


if __name__ == "__main__":
    main()
