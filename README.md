# RTSspoof

A small Age of Empires II–inspired real-time strategy prototype built in
Godot 4 (GDScript), featuring three playable civilizations: the
**Egyptians**, the **British**, and the **Achaemenids** (Cyrus the Great's
Persian Empire).

## Requirements

- [Godot Engine 4.3](https://godotengine.org/download) or later (standard/GL
  Compatibility renderer).

## Running the game

1. Open Godot, choose "Import", and select `project.godot` in this folder.
2. Press **Run** (F5). The game opens on a civilization-select screen.
3. Pick a civilization to start a 1v1 match against a scripted AI opponent
   randomly playing one of the other two.

## Controls

- **Left-click** a unit/building to select it, or **drag** a box to select
  multiple units.
- **Right-click** to issue a context command to the current selection:
  - on empty ground → move
  - on an enemy unit/building → attack
  - on a resource (tree, gold/stone mine, berry bush) or a finished farm → gather
  - on your own unfinished building → help construct
- **WASD / arrow keys** or moving the mouse to the screen edge → pan the
  camera. **Mouse wheel** → zoom.
- Select villagers to reveal build buttons (House, Barracks, Farm) in the
  bottom panel; click one, then left-click on the map to place it (**Esc**
  or right-click cancels placement). Select a Town Center or Barracks to
  see its training options, or a Farm to see its remaining food.

## Civilizations

| Civ | Bonus | Unique Unit |
|---|---|---|
| Egyptians | Villagers gather Food 20% faster from farms/bushes built near water; start with +50 Gold | War Chariot (fast melee) |
| British | Houses support +5 extra population; archers fire 20% farther | Longbowman (long-range archer) |
| Achaemenids | All units move 15% faster; start with +100 Gold | Immortal (elite heavy infantry) |

Lakes are scattered around the map (one near each base, one contested in
the middle) — they're impassable, and any food source (a placed Farm or a
wild berry bush) within range of one counts as "near water" for the
Egyptian bonus. Select a Farm to see whether it's currently in range.

## Feature scope (core prototype)

- Procedurally drawn top-down map with scattered resources (wood, food,
  gold, stone), impassable lakes, and contested resources in the middle.
- Villagers that gather resources and construct buildings; Town Center,
  House, Barracks and buildable Farm buildings; a population cap economy.
- NavigationAgent2D pathfinding with avoidance around units/buildings.
- Melee/ranged combat with HP, armor and attack cooldowns.
- Grid-based fog of war (unexplored / explored / visible) for the human
  player.
- A basic scripted AI opponent that gathers, expands, builds a barracks,
  trains an army and attack-moves once strong enough.

This is a vertical-slice prototype, not a full game: no tech tree, ages,
or campaign.

## Project layout

```
Main.gd / Main.tscn   -- wires the whole match together (no other scenes;
                          all units/buildings/UI are built procedurally)
autoload/              -- GameData (unit/building/civ stat tables), GameManager (match/player state)
core/                  -- camera, selection/input, fog of war, ground, player economy, placement ghost
entities/               -- Unit, Building, ResourceNode (generic, data-driven by GameData)
ai/                     -- scripted AI opponent
ui/                     -- HUD and civ-select screen
```

## Headless / automated testing

`Main.gd` accepts a few debug arguments (after `--` on the command line)
useful for smoke-testing without a human at the controls, e.g.:

```
godot --path . -- --autostart=egyptian --debuglog --quit-after-seconds=60
godot --path . -- --autostart=british --simulate --screenshot=out.png --quit-after-seconds=10
```

- `--autostart=<egyptian|british>` skips the civ-select screen.
- `--debuglog` prints both players' resources/population/army every 3s.
- `--simulate` exercises selection/orders/building placement automatically.
- `--screenshot=<path>` saves a PNG when the run ends.
- `--quit-after-seconds=<n>` ends the run after n seconds.
- `--camera=<x>,<y>` repositions the camera (useful with `--screenshot`).
