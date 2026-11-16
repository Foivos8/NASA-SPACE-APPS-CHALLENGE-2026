# Apollo 13 - Level 1: Launch Sequence (Godot 4 starter)

Open `project.godot` in Godot 4.4 or newer and press F5.

- Move: arrow keys or WASD (four directions, one tile per step)
- Interact / advance text: E, Enter or Space
- Choices: Up / Down, then E

## Layout

| Path | What it is |
| --- | --- |
| `main.tscn`, `scripts/level.gd` | The level. Builds two TileMapLayers, the player, NPCs and UI from the JSON at runtime. |
| `data/level1.json` | Tiles, zones, interactables (with all text), objectives, launch events. |
| `data/level1_ground.txt`, `data/level1_objects.txt` | The two tile layers as comma-separated tile ids (.txt so Godot does not import them as translations), for painting the map in the TileMap editor instead. |
| `assets/tileset.png` | 32x32 atlas, 8 columns. Tile id = column + 8 * row. Names and solid ids are in the JSON. |
| `assets/*.png` | Player (4 frames: down, up, left, right), pad leader, seated astronaut, objective marker. |
| `docs/` | Rendered map and labelled map. |
| `tools/gen_level.py` | Regenerates art + data: `python3 tools/gen_level.py` (needs Pillow). |
| `tools/smoke_test.gd` | Headless walkthrough: `godot --headless --path . --script tools/smoke_test.gd` |

All art is procedural placeholder pixel art. Replace `assets/tileset.png` with hand-drawn
tiles in the same grid positions and nothing else needs to change.
