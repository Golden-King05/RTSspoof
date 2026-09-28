# Installing RTSspoof

RTSspoof is a Godot project, not a packaged executable — there's no
"setup.exe" to run. Installing it means: get the free Godot Engine, get a
copy of this project's files, and open it in Godot. That's it. This guide
walks through every step in detail, with a quick version up top for anyone
who's done this before.

## Quick version

1. Install **Godot Engine 4.3+** from [godotengine.org/download](https://godotengine.org/download) (pick the "Standard" build for your OS).
2. Download this repository: **Code → Download ZIP** on GitHub, then unzip it.
3. Open Godot, click **Import**, select the `project.godot` file inside the unzipped folder, then **Import & Edit**.
4. Press the **Play** button (▶, top-right) or hit **F5**.

If any of that isn't clear, or something goes wrong, the sections below walk through each step slowly.

---

## Step 1: Install Godot Engine

RTSspoof needs **Godot Engine version 4.3 or newer**. Godot is a free, open-source
game engine — installing it is just downloading one file and extracting it,
there's no installer wizard.

1. Go to [godotengine.org/download](https://godotengine.org/download).
2. Choose your operating system (Windows, macOS, or Linux).
3. Download the **Standard** version (not ".NET" / "Mono" — this project
   doesn't use C#, so you don't need that variant).
4. Once downloaded:
   - **Windows**: you'll get a single `Godot_v4.3-stable_win64.exe` file (or
     similar). There's nothing to install — just put it somewhere convenient
     (like `C:\Godot\`) and double-click it to run.
   - **macOS**: you'll get a `.zip` containing `Godot.app`. Unzip it and
     drag `Godot.app` into your `Applications` folder. The first time you
     open it, macOS may warn that it's from an unidentified developer —
     right-click the app and choose **Open** to bypass that once.
   - **Linux**: you'll get a `.zip` with a single executable inside (e.g.
     `Godot_v4.3-stable_linux.x86_64`). Extract it, then either double-click
     it or run `chmod +x Godot_v4.3-stable_linux.x86_64` in a terminal
     first if it won't execute.
5. Run it once to confirm it opens — you should see the **Project Manager**
   window (a list of projects, currently empty). Leave it open or close it;
   either is fine.

## Step 2: Get a copy of RTSspoof

You don't need to know Git for this — downloading a ZIP works fine and is
the simplest option. If you *do* use Git already, cloning gets you easy
updates later (see [UPDATING.md](UPDATING.md)).

### Option A — Download ZIP (no account or tools needed)

1. Go to the repository's GitHub page: [github.com/Golden-King05/RTSspoof](https://github.com/Golden-King05/RTSspoof).
2. Click the green **Code** button.
3. Click **Download ZIP**.
4. Once it's downloaded, extract/unzip it somewhere you'll remember (like
   your Desktop or Documents folder). You should end up with a folder
   containing a file named `project.godot` — that's how you know you
   extracted it correctly (not one folder-inside-a-folder too deep).

### Option B — Clone with Git (recommended if you plan to update often)

If you have [Git](https://git-scm.com/downloads) installed, open a terminal
and run:

```
git clone https://github.com/Golden-King05/RTSspoof.git
```

This creates an `RTSspoof` folder with the project inside it. See
[UPDATING.md](UPDATING.md) for how to pull new changes into this folder later.

## Step 3: Open the project in Godot

1. Launch Godot — you'll land on the **Project Manager**.
2. Click **Import** (top-left area of the window).
3. Click **Browse**, navigate into the RTSspoof folder you downloaded/cloned,
   and select the `project.godot` file specifically (not the folder itself).
4. Click **Import & Edit**.
5. The first time you open it, Godot needs a few seconds to scan and import
   the project's files — you'll briefly see a progress bar. This is normal
   and only happens once (or after certain updates).
6. The Godot editor opens with the project loaded. You don't need to touch
   anything in the editor unless you're modifying the game.

## Step 4: Run the game

- Press **F5**, or click the **Play** button (▶) in the top-right corner of
  the editor window.
- A game window opens showing the civilization-select screen. Pick a
  civilization to start a match.
- See the main [README](README.md#controls) for controls once you're in-game.

If Godot asks "No main scene has been defined, select one?" the first time
you press Play, click **Select** and choose `Main.tscn` — this shouldn't
normally happen since it's already configured, but it's an easy fix if it
does.

---

## Troubleshooting

**"This project uses a different engine version" / import fails oddly.**
Make sure you're running Godot **4.3 or later**, and that you picked the
Standard (not Mono/.NET) build. Check your Godot version via **Help → About**
in the editor, or by running `godot --version` from a terminal.

**Nothing happens when I press Play, or I get a black window.**
Your graphics drivers may not support Godot's default renderer. Try
switching the renderer in the Project Manager before opening the project:
select the RTSspoof project row, and in **Project Settings → Rendering →
Renderer**, try "Compatibility" mode. This project is already configured to
use GL Compatibility, so this is rarely needed, but it's the first thing to
check if the screen stays black.

**I get errors about missing classes/scripts on first open.**
This usually means the project's internal cache hasn't been built yet —
just let Godot finish importing (Step 3.5 above) before pressing Play. If
it persists, close and reopen the project once.

**I don't see `project.godot` after extracting the ZIP.**
GitHub ZIPs sometimes extract into a folder like `RTSspoof-main/`. Make
sure you're pointing Godot's Import dialog at the folder that directly
contains `project.godot`, not a parent folder above it.

**I want to run it from a terminal instead of the editor UI.**
`godot --path /path/to/RTSspoof` runs the project directly. See the
[README's automated-testing section](README.md#headless--automated-testing)
for additional command-line flags used for debugging/testing.

---

Once installed, see [UPDATING.md](UPDATING.md) for how to get new versions
of the game as they're released.
