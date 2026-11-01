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
| `layouts/main-plain.json` | Herdr's `main` layout with a faint focus ring around the focused pane |

### The theme

`themes/matrix.json` sets the terminal palette (black background, `#00ff41`
text, 16 ANSI colors) and a `colors` block for the rest of the window.

Without the `colors` block, Herdr derives the panel colors from the terminal
colors. The result is gray text and unrelated teal and blue accents. The block
sets:

| Role | Color | Contrast |
| :--- | :--- | :--- |
| `foreground` | `#80ffa0` | 16.0:1 on the sidebar |
| `muted` | `#52f07d` | 15.4:1 |
| `dim` | `#3fbf63` | 8.4:1 |
| `accent` | `#00ff41` | 14.7:1 |
| `solid` (primary buttons) | `#00ff41` | 14.7:1 |
| `chrome`, `surface`, `popover` | `#030a04`, `#07130a`, `#0a1a0c` | backgrounds |
| `hover`, `selected` | `#13301a`, `#1d4a24` | states |
| `border`, `input` | `#356b45`, `#4f9a5f` | lines |

Terminal text keeps the pure Matrix green. Only the window chrome uses the
lighter greens.

The UI greens are full-saturation tints of the terminal green, not gray. That
keeps the phosphor look on the sidebar, the tabs and the bars.

### The focus ring

The pane `focus` border takes its color from `accent`, and there is no
separate theme color for it. A neon `#00ff41` ring around the terminal reads
as "this window is selected all the time".

`layouts/main-plain.json` is a copy of Herdr's `main` with one change:

```json
"focus": { "width": 1, "color": "#00ff414d" }
```

`4d` is the alpha channel: the same neon green at 30 percent. On the black
canvas it draws `#004d14`, a faint line. Every other use of `accent` stays
neon, because the theme is unchanged.

The copy is needed because `layouts/main.json` belongs to Herdr and is
replaced on every start. A copy does not get Herdr's future changes to `main`.
Switch with `ctrl-shift-l` or `layout.switch`; Herdr's `main` is still there.

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

On a new machine, switch to the layout one time: `ctrl-shift-l` until
`main-plain` shows, or `herdr-app do layout.switch --name main-plain`.

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
Copy-Item "$HOME\.config\herdr-app\layouts\main-plain.json" .\herdr-app\layouts\main-plain.json
```

```bash
cp ~/.config/herdr-app/settings.json ./herdr-app/settings.json
cp ~/.config/herdr-app/themes/matrix.json ./herdr-app/themes/matrix.json
cp ~/.config/herdr-app/layouts/main-plain.json ./herdr-app/layouts/main-plain.json
```
