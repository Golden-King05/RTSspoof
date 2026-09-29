# RTSspoof

A small Age of Empires II–inspired real-time strategy prototype built in
Godot 4 (GDScript), featuring five playable civilizations: the
**Egyptians**, the **British**, the **Achaemenids** (Cyrus the Great's
Persian Empire), the **Vikings**, and the **Romans**.

## Play now (Windows, no Godot needed)

Don't want to install Godot or open an editor at all? Grab the standalone
build straight from the repo:
**[releases/latest/RTSspoof.exe](releases/latest/RTSspoof.exe)** — download
it and double-click it. No installer, no launcher, no Godot required.
(It's committed directly to the repo rather than published as a GitHub
Release — see the note in "Publishing a new Windows build" below.)

The game opens straight to a main menu (Play / Quit) and checks
`releases/latest/VERSION` in this repo for a newer build on startup. If
one's out, a **Download Update** button appears — clicking it downloads the
new exe and relaunches automatically, so you never have to manually
re-download it yourself.

## Installing & updating (from source, for development)

Want to look at or change the code? You'll need Godot itself.

New here? **[See INSTALL.md](INSTALL.md)** for a full step-by-step guide
(installing Godot itself, downloading the project, opening and running it —
written for people who haven't done this before).

Already have it and want the latest version? **[See UPDATING.md](UPDATING.md)**
for how to pull updates, whether you downloaded a ZIP or cloned with Git.

The short version, if you've done this kind of thing before:

1. Install [Godot Engine 4.3](https://godotengine.org/download) or later
   (Standard build, GL Compatibility renderer).
2. Download or clone this repository.
3. In Godot, choose **Import**, select `project.godot` from this folder,
   then **Import & Edit**.
4. Press **Run** (F5). The game opens on a main menu; click **Play** to
   reach the match setup lobby.
5. In the lobby, pick your civilization and team on the left (click a
   civilization's **i** button to see its bonus/unique unit), add up to 8
   total players with **+ Add AI Player**, then **Start Match**. Players on
   the same team are allies; the match ends when only one team has units or
   buildings left. Game rules and map selection on the right are
   placeholders for now -- there's only one map.

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
- Select villagers to reveal build buttons (House, Barracks, Stable, Farm,
  Lumberjack, Mine, Windmill) in the bottom panel; click one, then
  left-click on the map to place it (**Esc** or right-click cancels
  placement). Select a Town Center, Barracks or Stable to see its training
  options, a Farm to see its remaining food, or a Lumberjack/Mine/Windmill
  to see which resource(s) it accepts.
- Any build/train button you can't currently afford is tinted red; hover
  it to see the exact cost, with whichever resource(s) you're short on
  also shown in red.

## Civilizations

| Civ | Bonus | Unique Unit |
|---|---|---|
| Egyptians | Villagers gather Food 20% faster from farms/bushes built near water; start with +50 Gold | War Chariot (fast melee, Stable) |
| British | Houses support +5 extra population; archers fire 20% farther | Longbowman (long-range archer) |
| Achaemenids | All units move 15% faster; start with +100 Gold | Immortal (elite heavy infantry) |
| Vikings | Raiding: every 10 damage dealt to an enemy building loots 1 Wood or Stone (by building type) + 0.5 Gold; start with +40 Wood | Berserker (fast, hard-hitting melee) |
| Romans | Buildings are constructed 30% faster and have 20% more HP; start with +30 Stone | Legionary (high-armor balanced melee), Aquilifer (aura support, trained at the Town Center) |

Lakes are scattered around the map (one near each base, one contested in
the middle) — they're impassable, and any food source (a placed Farm or a
wild berry bush) within range of one counts as "near water" for the
Egyptian bonus. Select a Farm to see whether it's currently in range.

Vikings loot resources by attacking buildings: Town Centers pay out in
Stone, everything else (House, Barracks, Farm) pays out in Wood, always
alongside a little Gold. Damage carries over between hits, so it doesn't
need to land in neat multiples of 10 — a Berserker's fast attacks are the
best raiders since they cross that threshold quickest.

The **Aquilifer** (Romans' Town-Center-trained unit, carrying the legion's
eagle standard) is a support unit, not a fighter: select it to see its aura
radius drawn as a circle. Any non-villager ally inside that radius gets a
bonus to armor, attack and attack speed while the Aquilifer lives — a thin
gold ring on a unit shows it's currently buffed. If the Aquilifer dies,
everyone who was in range instead takes the same bonus in reverse (a
morale-break debuff, shown as a thin dark-red ring) for 10 minutes. Losing
your standard bearer mid-fight is a real setback, so it's worth keeping
one behind the front line rather than leading with it.

## Feature scope (core prototype)

- A tile-grid map (`core/MapGenerator.gd`): lakes are carved as blob-shaped
  groups of whole grid tiles rather than smooth circles, and every resource
  spawns as a grid-aligned clump grown outward from a seed tile -- trees
  grow into full forests, gold/stone/berries into smaller clumps. One clump
  of each resource type is guaranteed near every base; the rest, forests
  included, are scattered across the whole map.
- Villagers that gather resources and construct buildings; Town Center,
  House, Barracks, Stable and Farm, plus resource-specific depots --
  Lumberjack Camp (wood), Mine (stone + gold) and Windmill (food) -- that
  let villagers drop off close to a resource cluster instead of walking
  all the way back to the Town Center (which still accepts everything). A
  population cap economy ties it together.
- Every civ starts the match with a **Scout** already on the field (fast,
  wide vision, moderate damage but low HP -- built for early exploring and
  harassing enemy villagers, not standing toe-to-toe in a real fight), and
  can train more of them plus **Cavalry** (a tankier melee horseman) and
  **Horse Archer** (fast ranged cavalry) at the Stable once it's built. The
  Egyptian War Chariot unique unit trains at the Stable too, not the
  Barracks.
- NavigationAgent2D pathfinding with avoidance around units/buildings.
- Melee/ranged combat with HP, armor and attack cooldowns.
- Grid-based fog of war (unexplored / explored / visible) for the human
  player.
- A scripted AI opponent that gathers, expands, builds farms/houses/a
  barracks, trains an army and attack-moves once strong enough. It reads
  its own civ's bonuses to adapt: it builds Farms near a lake shore when
  playing Egyptians (to actually earn the water bonus), raids in smaller
  and more frequent parties when playing Vikings, and commits its army a
  bit sooner when playing a faster-moving civ like the Achaemenids. It
  also prioritizes economic buildings over discretionary army training --
  it won't blow its stockpile on a unit the moment it can afford one if a
  Farm or House is still unfunded, so it actually saves up for big-ticket
  items instead of spending everything as it comes in. It builds one
  Lumberjack/Mine/Windmill each next to whichever matching resource cluster
  sits closest to home once it can afford to, and trains one Town-Center
  unique unit (e.g. a Roman Aquilifer) alongside its villagers if its civ
  has one.

This is a vertical-slice prototype, not a full game: no tech tree, ages,
or campaign.

## Project layout

```
Main.gd / Main.tscn   -- wires the whole match together (no other scenes;
                          all units/buildings/UI are built procedurally)
autoload/              -- GameData (unit/building/civ stat tables), GameManager (match/player state)
core/                  -- camera, selection/input, fog of war, ground, map/resource generation, player economy, placement ghost
entities/               -- Unit, Building, ResourceNode (generic, data-driven by GameData)
ai/                     -- scripted AI opponent
ui/                     -- main menu (with self-updater), HUD and the match-setup lobby screen
```

## Publishing a new Windows build

Builds are published by committing them straight into the repo under
`releases/latest/`, **not** as a GitHub Release -- there's no CI/automation
with permission to create Releases or upload their assets here, so a plain
git commit is the reliable path. The main menu's self-updater
(`ui/MainMenu.gd`) checks two fixed raw-file URLs pointed at that folder:
`releases/latest/VERSION` (a one-line version string) and
`releases/latest/RTSspoof.exe`. To ship an update:

1. Bump `CURRENT_VERSION` in `ui/MainMenu.gd` (e.g. `"v1.0.1"`).
2. Export a release build: `godot --headless --path . --export-release
   "Windows Desktop" build/windows/RTSspoof.exe` (requires Godot's export
   templates for this exact editor version to be installed first, via the
   editor's **Editor → Manage Export Templates**, or downloaded from
   [the matching GitHub release](https://github.com/godotengine/godot/releases)).
3. Overwrite `releases/latest/RTSspoof.exe` with the new build and
   `releases/latest/VERSION` with the same string you set in step 1
   (no `v`-prefix mismatch -- it's a literal string compare).
4. Commit and push both files (plus the `CURRENT_VERSION` change) together.
   Any older copy of the game will now offer that update the next time it's
   opened.

Note this means `releases/latest/RTSspoof.exe` is a binary that gets
replaced (not diffed) on every update, so the repo's git history grows by
roughly one exe's size per release -- an accepted tradeoff here in exchange
for not needing Release-publishing permissions. If that ever becomes a
problem, `ui/MainMenu.gd`'s `VERSION_CHECK_URL`/`EXE_DOWNLOAD_URL` constants
are the only things that would need to change to point at a real GitHub
Release instead. `export_presets.cfg` is committed (it's just config);
`build/` output is not (see `.gitignore`) -- only `releases/latest/` is the
actual published artifact.

## Headless / automated testing

`Main.gd` accepts a few debug arguments (after `--` on the command line)
useful for smoke-testing without a human at the controls, e.g.:

```
godot --path . -- --autostart=egyptian --debuglog --quit-after-seconds=60
godot --path . -- --autostart=british --simulate --screenshot=out.png --quit-after-seconds=10
```

- `--autostart=<civ>` skips the civ-select screen and starts as that civ.
- `--ai-civ=<civ>` forces the AI opponent's civ instead of a random pick
  (handy for testing one civ's AI behavior deterministically).
- `--debuglog` prints both players' resources/population/buildings every 3s.
- `--simulate` exercises selection/orders/building placement automatically.
- `--screenshot=<path>` saves a PNG when the run ends.
- `--quit-after-seconds=<n>` ends the run after n seconds.
- `--camera=<x>,<y>` repositions the camera (useful with `--screenshot`).
- `--open-lobby` opens the match-setup lobby directly, skipping the main menu.
- `--multitest=<n>` (2-8) starts an n-player match (1 human + n-1 AI) split
  across two alternating teams, for exercising the multiplayer/team code
  path headlessly.
