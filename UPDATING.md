# Updating RTSspoof

RTSspoof is under active development — new civilizations, buildings and AI
improvements get added over time. This guide covers how to pull those
updates into a copy of the game you already installed (see
[INSTALL.md](INSTALL.md) if you haven't installed it yet).

Which method you use depends on how you got the project originally.

## Quick version

- **Downloaded a ZIP?** Download a fresh ZIP and replace your old folder.
- **Cloned with Git?** Run `git pull` inside the project folder.
- Either way: reopen the project in Godot afterward — no reinstall of Godot
  itself is ever needed for a game update, only for a *Godot* update (see
  bottom of this page).

---

## If you downloaded a ZIP (no Git)

There's no "update" button for a ZIP download — you just get a fresh copy:

1. Close Godot if the project is currently open.
2. Go to the repository's GitHub page ([github.com/Golden-King05/RTSspoof](https://github.com/Golden-King05/RTSspoof))
   and download a new ZIP the same way you did the first time
   (**Code → Download ZIP**).
3. Extract it to a **new** folder (don't extract on top of your old one —
   safer to keep them separate in case you had local changes you want to
   compare).
4. If you had made any of your own edits to the old copy that you want to
   keep, copy just those specific files over manually — otherwise, you can
   delete the old folder once you've confirmed the new one opens correctly.
5. Open the new folder's `project.godot` in Godot as described in
   [INSTALL.md](INSTALL.md#step-3-open-the-project-in-godot).

If you plan to update often, switching to Git (Option B in INSTALL.md) will
save you from repeating this every time — see below.

## If you cloned with Git (recommended for frequent updates)

Open a terminal, navigate into your RTSspoof folder, and run:

```
cd RTSspoof
git pull
```

This downloads and applies any new commits since your last update. A
successful pull looks something like:

```
Updating ef75259..d833e94
Fast-forward
 Main.gd                  | 12 ++++++++++--
 ai/AIController.gd       | 45 +++++++++++++++++++++++++--------------
 ...
```

If it instead says `Already up to date.`, you already have the latest
version.

### If you've made your own local changes

If you've edited any files yourself (tweaking stats, adding a feature,
etc.), `git pull` may refuse to run, or may report a **merge conflict**, to
avoid overwriting your work. You have two common options:

- **Keep your changes and update anyway:**
  ```
  git stash        # temporarily sets your edits aside
  git pull         # get the latest version
  git stash pop    # re-apply your edits on top
  ```
  If `git stash pop` reports a conflict, it means your edit and an upstream
  change touched the same lines — you'll need to resolve that manually in
  the affected file(s) (Git marks the conflicting sections with `<<<<<<<`
  markers).
- **Discard your local changes and just take the update:**
  ```
  git reset --hard
  git pull
  ```
  ⚠️ This permanently deletes any uncommitted edits you made — only do this
  if you're sure you don't need them.

### Checking what version you're on

```
git log -1
```

This shows the commit hash and message you're currently on, so you can
compare it against the repository's commit history on GitHub to see if
you're behind.

## After updating (either method)

1. Reopen (or re-select, if it was already open) the project in Godot.
2. Godot may briefly re-scan/re-import the project the first time it opens
   after an update — this is automatic and normal, just wait for it to
   finish before pressing Play.
3. Press **F5** to run and confirm the update applied (check for new
   civilizations, buildings, or behavior mentioned in the update you pulled).

## Updating Godot itself

Updating *RTSspoof* is separate from updating the *Godot Engine* you use to
run it. You generally don't need to update Godot unless:

- This project starts requiring a newer minimum version (check the
  [README's Installing & updating section](README.md#installing--updating)), or
- You want editor features unrelated to this project.

To update Godot, just download the newer version from
[godotengine.org/download](https://godotengine.org/download) the same way
you did the first time (Step 1 in INSTALL.md) — it doesn't overwrite your
old version automatically, so you can keep both if you like, or delete the
old executable/app once you've confirmed the new one works.
