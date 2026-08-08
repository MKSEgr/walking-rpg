#!/usr/bin/env python3
"""Validate committed companion motion atlases and their game manifests."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
CHARACTER_ASSETS = REPOSITORY_ROOT / "mobile" / "assets" / "characters"
SPARK_MANIFEST = CHARACTER_ASSETS / "companion_spark_motion_v1.json"

REQUIRED_CLIPS = {
    "idle",
    "runRight",
    "runLeft",
    "greet",
    "jump",
    "tired",
    "waiting",
    "sensing",
    "inspect",
}


def _as_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{label} must be an integer")
    return value


def _load_manifest(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return payload


def _asset_path(manifest: dict[str, Any]) -> Path:
    relative = manifest.get("asset")
    if not isinstance(relative, str) or not relative.startswith("assets/"):
        raise ValueError("asset must be a Flutter assets/ path")
    return REPOSITORY_ROOT / "mobile" / relative


def _validate_hash(path: Path, expected: Any) -> None:
    if not isinstance(expected, str) or len(expected) != 64:
        raise ValueError("sha256 must be a lowercase 64-character digest")
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise ValueError(f"{path} sha256 is {actual}, expected {expected}")


def _validate_manifest(manifest: dict[str, Any]) -> None:
    if manifest.get("schemaVersion") != 1:
        raise ValueError("schemaVersion must be 1")
    if manifest.get("petId") != "spark-v1":
        raise ValueError("the Искра atlas must keep the stable petId spark-v1")

    clips = manifest.get("clips")
    if not isinstance(clips, dict) or set(clips) != REQUIRED_CLIPS:
        raise ValueError(f"clips must be exactly {sorted(REQUIRED_CLIPS)}")

    directions = manifest.get("lookDirections")
    if not isinstance(directions, list) or len(directions) != 16:
        raise ValueError("lookDirections must contain all 16 directions")
    indexes = [
        _as_int(direction.get("index"), "look direction index")
        for direction in directions
    ]
    if indexes != list(range(16)):
        raise ValueError("lookDirections must be ordered from index 0 through 15")


def _expected_cells(
    manifest: dict[str, Any],
    *,
    columns: int,
    rows: int,
) -> set[tuple[int, int]]:
    occupied: set[tuple[int, int]] = set()
    clips = manifest["clips"]
    for name, clip in clips.items():
        row = _as_int(clip.get("row"), f"clips.{name}.row")
        frames = _as_int(clip.get("frames"), f"clips.{name}.frames")
        fps = _as_int(clip.get("fps"), f"clips.{name}.fps")
        if row < 0 or row >= rows:
            raise ValueError(f"clips.{name}.row is outside the atlas")
        if frames <= 0 or frames > columns:
            raise ValueError(f"clips.{name}.frames must be between 1 and {columns}")
        if fps <= 0:
            raise ValueError(f"clips.{name}.fps must be positive")
        if not isinstance(clip.get("loop"), bool):
            raise ValueError(f"clips.{name}.loop must be a boolean")
        occupied.update((row, column) for column in range(frames))

    for direction in manifest["lookDirections"]:
        row = _as_int(direction.get("row"), "look direction row")
        column = _as_int(direction.get("column"), "look direction column")
        if row < 0 or row >= rows or column < 0 or column >= columns:
            raise ValueError("a look direction is outside the atlas")
        occupied.add((row, column))
    return occupied


def validate(path: Path = SPARK_MANIFEST) -> None:
    manifest = _load_manifest(path)
    _validate_manifest(manifest)
    asset_path = _asset_path(manifest)
    _validate_hash(asset_path, manifest.get("sha256"))

    atlas = manifest.get("atlas")
    if not isinstance(atlas, dict):
        raise ValueError("atlas must be a JSON object")
    width = _as_int(atlas.get("width"), "atlas.width")
    height = _as_int(atlas.get("height"), "atlas.height")
    columns = _as_int(atlas.get("columns"), "atlas.columns")
    rows = _as_int(atlas.get("rows"), "atlas.rows")
    cell_width = _as_int(atlas.get("cellWidth"), "atlas.cellWidth")
    cell_height = _as_int(atlas.get("cellHeight"), "atlas.cellHeight")
    if width != columns * cell_width or height != rows * cell_height:
        raise ValueError("atlas dimensions do not match its grid")

    expected = _expected_cells(manifest, columns=columns, rows=rows)
    with Image.open(asset_path) as image:
        image.load()
        if image.mode != "RGBA":
            raise ValueError(f"{asset_path} is {image.mode}, expected RGBA")
        if image.size != (width, height):
            raise ValueError(
                f"{asset_path} is {image.size}, expected {(width, height)}"
            )
        alpha = image.getchannel("A")
        for row in range(rows):
            for column in range(columns):
                bounds = (
                    column * cell_width,
                    row * cell_height,
                    (column + 1) * cell_width,
                    (row + 1) * cell_height,
                )
                visible = alpha.crop(bounds).getbbox() is not None
                should_be_visible = (row, column) in expected
                if visible != should_be_visible:
                    state = "visible" if visible else "empty"
                    wanted = "occupied" if should_be_visible else "unused"
                    raise ValueError(
                        f"cell ({row}, {column}) is {state}, expected {wanted}"
                    )

    print(
        f"Validated {manifest['petId']}: {len(expected)} frames, "
        f"{columns} x {rows} atlas, sha256 {manifest['sha256']}"
    )


if __name__ == "__main__":
    validate()
