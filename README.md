```
=========================================
  12x12 TILE-BASED MAP GENERATOR
=========================================
      ___
     /__/\         _____          ___         ___
     \  \:\       /  /::\        /  /\       /__/|
      \  \:\     /  /:/\:\      /  /:/      |  |:|
  _____\__\:\   /  /:/~/::\    /  /:/       |  |:|
 /__/::::::::\ /__/:/ /:/\:|  /  /::\     __|__|:|
 \  \:\~~\~~\/ \  \:\/:/~/:/ /__/:/\:\   /__/::::\
  \  \:\  ~~~   \  \::/ /:/  \__\/  \:\     ~\~~\:\
   \  \:\        \  \:\/:/        \  \:\      \  \:\
    \  \:\        \  \::/          \__\/       \__\/
     \__\/         \__\/
```

# 12x12 Tile-Based Map Generator

A procedural dungeon map generator for **Roblox**, written in Lua. Generates a walkable maze-style dungeon path using depth-first expansion, then populates the surrounding exterior with structures, scenery, and filler tiles.

---

## Features

- Procedural maze generation via depth-first frontier expansion
- Weighted random tile selection for walkable path tiles
- Flood-fill reachability analysis to isolate walkable vs. exterior zones
- Multi-size structure placement (villages, houses, ponds) in non-walkable areas
- Weighted filler tile system for natural exterior scenery
- Rectangular boundary padding to ensure full map coverage
- Random 90° rotation on tiles and structures for visual variety
- Grid attribute tagging on all tiles for downstream gameplay logic

---

## Requirements

- **Roblox Studio**
- A `ServerStorage` folder named **`TileTemplatesMesh`** containing all tile and structure model templates, preferably as a single mesh (Using Blender to merge and reduce triangle count for optimisation)
- This script placed inside a `Script` object in `ServerScriptService`

---

## Configuration

| Parameter | Default | Description |
|---|---|---|
| `TILE_SIZE` | `12` | Size of each tile in Roblox studs |
| `MAX_TILES` | `96000` | Maximum number of walkable tiles to place |
| `MAX_ITERATIONS` | `6000` | Maximum loop iterations before generation halts |
| `PADDING` | `12` | Grid padding around the bounding box during gap-fill |
| `FINAL_PADDING` | `6` | Extra padding for the final rectangular fill boundary |

---

## How It Works

### 1. Seed Placement
Two fixed tiles are placed at the origin to start every map:
- A **Floor** tile at grid position `(0, 0)` — the player spawn point
- A **Chest** tile at `(0, 1)` — a guaranteed starting reward

### 2. Maze Generation
A depth-first frontier stack expands outward from the seed. At each step the generator picks a random unoccupied neighbour, places a weighted random tile, and pushes it onto the frontier. This continues until `MAX_TILES` walkable tiles are placed or `MAX_ITERATIONS` is reached.

### 3. Flood Fill
A breadth-first flood fill marks all grid cells reachable from the origin via walkable tiles. Any cell not reachable is treated as exterior and becomes eligible for structure or filler placement.

### 4. Structure Placement
Structures are placed across three passes — largest first to prevent overlap:

1. **SmallVillage** (10×11 tiles) — ~0.4% chance per eligible cell
2. **VillageHouse** (4×3 tiles) — ~0.2% chance per eligible cell
3. **SmallPond** (2×2 tiles) — ~0.1% chance per eligible cell

Each structure receives a random 90° rotation. If rotated by an odd number of steps, the X/Y footprint dimensions are swapped to match.

### 5. Rectangular Fill
The bounding box of all placed tiles is calculated, expanded by `FINAL_PADDING`, and every remaining empty cell is filled with a randomly weighted filler tile. Filler tiles also receive random rotations.

---

## Tile Types

### Walkable Path Tiles (With reagard to dungeon-crawler-esque tile-based games)
Randomly placed during maze generation.

| Tile | Weight | Walkable |
|---|---|---|
| `Floor` | 50 | ✅ |
| `Trap` | 10 | ❌ |
| `Chest` | 0 *(manual only)* | ✅ |

### Filler Tiles
Used to fill the exterior map boundary.

| Tile | Weight | Walkable |
|---|---|---|
| `Grass` | 50 | ❌ |
| `Tree` | 25 | ❌ |
| `Cluster` | 20 | ❌ |
| `Cluster3` | 15 | ❌ |
| `Cluster2` | 10 | ❌ |
| `Rock` | 5 | ❌ |
| `Boulder` | 3 | ❌ |

---

## Structures

Multi-tile models placed as a single cloned instance. Their full footprint is reserved in the tile grid to prevent overlap.

| Structure | Footprint | Template |
|---|---|---|
| `VillageHouse` | 4 × 3 tiles | `VillageHouse` |
| `SmallVillage` | 10 × 11 tiles | `SmallVillage` |
| `SmallPond` | 2 × 2 tiles | `PondTile` |

---

## Tile Attributes

Every placed tile has the following Roblox instance attributes set, readable by other scripts:

| Attribute | Type | Description |
|---|---|---|
| `GridX` | `integer` | Grid X coordinate of the tile |
| `GridY` | `integer` | Grid Y coordinate of the tile |
| `TileType` | `string` | Tile type name (e.g. `Floor`, `Trap`, `Chest`, `FinalFill`) |
| `Walkable` | `boolean` | Whether players or NPCs can traverse this tile |

---

## Extending the Generator

### Adding a New Tile Type
Add an entry to the `TILE_TYPES` table with a `template` reference, a `weight`, and a `walkable` flag. Set `weight = 0` if it should only be placed manually or as filler.

```lua
NewTile = {
    template = TileTemplates:WaitForChild("NewTile"),
    weight = 15,
    walkable = true,
},
```

### Adding a New Structure
Add an entry to the `STRUCTURES` table, then add a placement loop in the structure placement section modelled on the existing ones.

```lua
Windmill = {
    template = TileTemplates:WaitForChild("Windmill"),
    sizeX = 3,
    sizeY = 3,
    walkable = false,
    weight = 1,
},
```

### Adding a New Filler Tile
Add an entry to the `FILLERS` array with a reference to a `TILE_TYPES` entry and a `weight`.

```lua
{ data = TILE_TYPES.NewTile, weight = 10 },
```

### Adjusting Map Size
- Increase `MAX_TILES` and `MAX_ITERATIONS` for a larger dungeon
- Increase `TILE_SIZE` to space tiles further apart in world space
- Increase `FINAL_PADDING` to add a wider natural border around the map edge

---

## Known Limitations

- **Long corridors** — depth-first generation tends to produce winding corridors with few branches. Switching to a random-index frontier pick (instead of always using the top of the stack) would produce a more branching layout.
- **Adjacency helper bug** — `isAdjacentToWalkable` uses the `SmallVillage` footprint as its scan window during filler placement, which may incorrectly suppress filler tiles near other structure types.
- **Structure spawning is not guaranteed** — structures rely on per-cell random chance and may not appear on every generation.
- **No pathfinding validation** — if `MAX_ITERATIONS` is hit early, disconnected walkable regions can exist.

---

## Output

On completion, the script prints to the Roblox output console:

```
MAP GEN COMPLETE: <n> walkable tiles
```

All tiles and structures are parented directly to `workspace`.

---

*12x12 Tile-Based Map Generator — Roblox Lua*
