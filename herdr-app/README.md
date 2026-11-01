# Herdr app

Herdr app config for the Matrix look: a green-on-black terminal palette plus
readable green UI colors.

The app stores its config in `~/.config/herdr-app` on every platform.
`HERDR_APP_HOME` overrides that folder.

## Files

| File | What it sets |
| :--- | :--- |
| `settings.json` | zoom (1.15), theme (`matrix`), dark appearance, sounds, terminal contrast, telemetry off |
| `themes/matrix.json` | the Matrix theme: terminal colors and the UI colors |

### The theme

`themes/matrix.json` sets the terminal palette (black background, `#00ff41`
text, 16 ANSI colors) and a `colors` block for the rest of the window.

Without the `colors` block, Herdr derives the panel colors from the terminal
colors. The result is gray text and unrelated teal and blue accents. The block
sets:

| Role | Color | Contrast |
| :--- | :--- | :--- |
| `foreground` | `#d8ffd8` | 18.4:1 on the sidebar |
| `muted` | `#a7d6a7` | 12.3:1 |
| `dim` | `#7cb87c` | 8.6:1 |
| `accent` | `#00ff41` | 14.7:1 |
| `chrome`, `surface`, `popover` | `#050805`, `#0a0f0a`, `#0d140d` | backgrounds |
| `hover`, `selected` | `#162316`, `#1c3a1e` | states |
| `border`, `input` | `#2b4a29`, `#46703f` | lines |

Terminal text keeps the pure Matrix green. Only the window chrome uses the
lighter greens.

### The size

`zoom` is the only setting that makes the UI larger. It scales the mods, the
terminals and the layout sizes together. `font_size` and `ui_font` change the
font, not the UI text size. `ui_font_size` is not a valid key.

## Install (copy)

Windows (PowerShell):

```powershell
.\herdr-app\install.ps1
```

macOS / Linux:

```bash
./herdr-app/install.sh
```

Both scripts copy the files into `~/.config/herdr-app`, create the folder when
it is missing, skip files that are already equal, and back up a different file
as `<name>.pre-dotfiles-<timestamp>.bak`.

Install after the Herdr app has started at least once. The files apply while
the app runs.

### Why copy, not symlink

Symlinks work here: Developer Mode is on, so `pwsh` creates them without
admin. They are still wrong for this folder. Herdr writes `settings.json`
itself when a setting changes, and it keeps only the values that differ from
its defaults. Through a symlink, that smaller file replaces the shared copy
and the `theme` key goes away. Copy keeps the full file in the repo.

Windows PowerShell 5.1 cannot create symlinks at all, even with Developer
Mode. Use `pwsh` 7 for a manual link.

## Verify

1. The sidebar text is green, not gray.
2. Settings > Look shows `matrix` as the theme.
3. `herdr-app status` reports `"errors": []`.

## Write back

Herdr rewrites `settings.json` when you change a setting from the app, for
example with the zoom keys. It writes only the values that differ from its
defaults, so `theme`, `appearance` and `telemetry` can leave the file. The
theme pick is then kept per layout in `layouts/.state/`.

After a change in the app, copy the live files back into this folder:

```powershell
Copy-Item "$HOME\.config\herdr-app\settings.json" .\herdr-app\settings.json
Copy-Item "$HOME\.config\herdr-app\themes\matrix.json" .\herdr-app\themes\matrix.json
```

```bash
cp ~/.config/herdr-app/settings.json ./herdr-app/settings.json
cp ~/.config/herdr-app/themes/matrix.json ./herdr-app/themes/matrix.json
```
