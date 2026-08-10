#!/usr/bin/env python3
"""Slice Dungeon_Tileset.png (160x160, 10x10 of 16x16) into named tiles."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = (
    ROOT
    / "assets/dungeon-assetpuck/2D Pixel Dungeon Asset Pack/character and tileset/Dungeon_Tileset.png"
)
OUT = ROOT / "assets/tiles/dungeon"
PREVIEW = ROOT / "assets/tiles/_preview"
TILE = 16

# (row, col) -> semantic name. Grounded by existing asset pixel matches + sheet layout.
NAMES: dict[tuple[int, int], str] = {
    # Row 0: outer wall top edge
    (0, 0): "wall_corner_outer_tl",
    (0, 1): "wall_top_a",
    (0, 2): "wall_top_b",
    (0, 3): "wall_top_c",
    (0, 4): "wall_top_d",
    (0, 5): "wall_corner_outer_tr",
    (0, 6): "floor_border_tl",
    (0, 7): "floor_border_t_a",
    (0, 8): "floor_border_t_b",
    (0, 9): "floor_border_tr",
    # Row 1
    (1, 0): "wall_side_l",
    (1, 1): "wall_face_a",
    (1, 2): "wall_face_b",
    (1, 3): "wall_face_c",
    (1, 4): "wall_face_d",
    (1, 5): "wall_side_r",
    (1, 6): "floor_border_l_a",
    (1, 7): "floor_a",
    (1, 8): "floor_b",
    (1, 9): "floor_border_r_a",
    # Row 2
    (2, 0): "wall_mid_l",
    (2, 1): "wall_inner_corner_tl",
    (2, 2): "floor_c",
    (2, 3): "floor_d",
    (2, 4): "wall_inner_corner_tr",
    (2, 5): "wall_mid_r",
    (2, 6): "floor_border_l_b",
    (2, 7): "floor_e",
    (2, 8): "floor_f",
    (2, 9): "floor_border_r_b",
    # Row 3
    (3, 0): "wall_side_l_b",
    (3, 1): "wall_inner_corner_bl",
    (3, 2): "wall_inner_bottom_a",
    (3, 3): "wall_inner_bottom_b",
    (3, 4): "wall_inner_corner_br",
    (3, 5): "wall_side_r_b",
    (3, 6): "door_closed_tl",
    (3, 7): "door_closed_tr",
    (3, 8): "floor_g",
    (3, 9): "ladder",
    # Row 4
    (4, 0): "wall_corner_outer_bl",
    (4, 1): "wall_bottom_a",
    (4, 2): "wall_bottom_b",
    (4, 3): "wall_bottom_c",
    (4, 4): "wall_bottom_d",
    (4, 5): "wall_corner_outer_br",
    (4, 6): "beam_vertical_a",
    (4, 7): "beam_vertical_b",
    (4, 8): "beam_vertical_c",
    (4, 9): "crate_stack",
    # Row 5
    (5, 0): "wall_ledge_l",
    (5, 1): "wall_ledge_a",
    (5, 2): "wall_ledge_b",
    (5, 3): "wall_ledge_r",
    (5, 4): "debris_a",
    (5, 5): "debris_b",
    (5, 6): "door_closed_bl",
    (5, 7): "door_closed_br",
    (5, 8): "beam_stump",
    (5, 9): "rubble_stones",
    # Row 6
    (6, 0): "floor_room_a",
    (6, 1): "floor_room_b",
    (6, 2): "floor_room_c",
    (6, 3): "floor_room_d",
    (6, 4): "debris_c",
    (6, 5): "debris_d",
    (6, 6): "door_open_l",
    (6, 7): "door_open_r",  # existing bone_a.png pixel-matches this (misnamed in root)
    (6, 8): "bone_shards",
    (6, 9): "rubble",
    # Row 7
    (7, 0): "floor_border_bl",
    (7, 1): "floor_border_b_a",
    (7, 2): "floor_border_b_b",
    (7, 3): "floor_border_br",
    (7, 4): "banner",
    (7, 5): "bone_b",
    (7, 6): "bone_c",
    (7, 7): "skull_and_bone",
    (7, 8): "void",
    (7, 9): "floor_h",
    # Row 8: chests & items
    (8, 0): "chest_wood_closed",
    (8, 1): "chest_wood_open",
    (8, 2): "chest_wood_looted",
    (8, 3): "chest_metal_closed",
    (8, 4): "chest_metal_open",
    (8, 5): "chest_metal_looted",
    (8, 6): "coin_gold",
    (8, 7): "potion_blue_a",
    (8, 8): "key_silver",
    (8, 9): "potion_red_a",
    # Row 9: lights & items
    (9, 0): "torch_wall_lit_a",
    (9, 1): "torch_wall_lit_b",
    (9, 2): "torch_wall_unlit",
    (9, 3): "candelabra_lit_tall",
    (9, 4): "candelabra_unlit_tall",
    (9, 5): "candelabra_lit_short",
    (9, 6): "candelabra_unlit_short",
    (9, 7): "potion_blue_b",
    (9, 8): "potion_red_b",
    (9, 9): "key_gold",
}

# Convenience copies into assets/tiles/ (skip if target already exists)
ROOT_COPIES = {
    "key_gold.png": "key_gold.png",
    "key_silver.png": "key_silver.png",
    "potion_red_a.png": "potion_red.png",
    "potion_blue_b.png": "potion_blue_b.png",
    "torch_wall_lit_a.png": "torch_wall.png",
    "torch_wall_unlit.png": "torch_wall_unlit.png",
    "ladder.png": "ladder.png",
    "banner.png": "banner.png",
    "door_closed_tl.png": "door_closed_tl.png",
    "door_closed_tr.png": "door_closed_tr.png",
    "door_closed_bl.png": "door_closed_bl.png",
    "door_closed_br.png": "door_closed_br.png",
    "chest_wood_open.png": "chest_open.png",
    "chest_metal_closed.png": "chest_metal.png",
    "skull_and_bone.png": "skull_and_bone.png",
    "door_open_l.png": "door_open_l.png",
    "door_open_r.png": "door_open_r.png",
}


def make_transparent(cell: Image.Image) -> Image.Image:
    pixels = []
    # Pillow 10+: get_flattened_data; fallback for older
    raw = getattr(cell, "get_flattened_data", None)
    data = raw() if raw else cell.getdata()
    for r, g, b, a in data:
        if r + g + b <= 8:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((r, g, b, a))
    out = Image.new("RGBA", cell.size)
    out.putdata(pixels)
    return out


def main() -> None:
    if not SRC.is_file():
        raise SystemExit(f"missing source: {SRC}")

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    if PREVIEW.exists():
        shutil.rmtree(PREVIEW)

    im = Image.open(SRC).convert("RGBA")
    if im.size != (160, 160):
        raise SystemExit(f"unexpected size {im.size}, expected 160x160")

    hashes: dict[str, str] = {}
    tiles: list[dict] = []

    for row in range(10):
        for col in range(10):
            name = NAMES[(row, col)]
            cell = make_transparent(
                im.crop((col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE))
            )
            digest = hashlib.md5(cell.tobytes()).hexdigest()
            cell.save(OUT / f"{name}.png", optimize=True)
            dup = hashes.get(digest)
            if dup is None:
                hashes[digest] = name
            tiles.append(
                {
                    "name": name,
                    "row": row,
                    "col": col,
                    "file": f"res://assets/tiles/dungeon/{name}.png",
                    "duplicate_of": dup if dup != name else None,
                }
            )

    manifest = {
        "source": str(SRC.relative_to(ROOT)).replace("\\", "/"),
        "tile_size": TILE,
        "cols": 10,
        "rows": 10,
        "count": len(tiles),
        "unique_visuals": len(hashes),
        "note": "Near-black background converted to alpha. Godot auto-generates .import on open.",
        "tiles": tiles,
        "aliases_existing": {
            "wall_top.png": "wall_top_a",
            "wall_side.png": "wall_side_l",
            "wall.png": "wall_face_a",
            "floor.png": "floor_a",
            "floor_c.png": "floor_a",
            "floor_a.png": "floor_e",
            "floor_b.png": "floor_g",
            "floor_d.png": "wall_inner_bottom_b",
            "debris_a.png": "debris_a",
            "debris_b.png": "debris_b",
            "debris_c.png": "debris_c",
            "skull_pile.png": "debris_c",
            "debris_d.png": "debris_d",
            "bone_a.png": "door_open_r",
            "bone_b.png": "bone_b",
            "bone_c.png": "bone_c",
            "rubble.png": "rubble",
            "chest.png": "chest_wood_closed",
            "gold.png": "coin_gold",
            "vision.png": "potion_blue_a",
            "quest.png": "key_silver",
            "deco_skull.png": "key_silver",
        },
    }
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    tiles_root = ROOT / "assets/tiles"
    for src_name, dst_name in ROOT_COPIES.items():
        src_path = OUT / src_name
        dst_path = tiles_root / dst_name
        if src_path.is_file() and not dst_path.exists():
            shutil.copy2(src_path, dst_path)
            print(f"copied: assets/tiles/{dst_name}")

    dups = [t for t in tiles if t["duplicate_of"]]
    print(f"wrote {len(tiles)} tiles -> {OUT.relative_to(ROOT)}")
    print(f"unique visuals: {len(hashes)}, duplicate slots: {len(dups)}")
    for t in dups:
        print(f"  ({t['row']},{t['col']}) {t['name']} == {t['duplicate_of']}")


if __name__ == "__main__":
    main()
