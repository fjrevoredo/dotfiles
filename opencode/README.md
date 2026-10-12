# OpenCode Plugins

TUI plugins for OpenCode. OpenCode discovers each directory under the global
plugin directory (`<config>/plugins/<name>/tui.tsx`) and hot-reloads it. No
`cli.json` change is necessary for discovery.

The global config directory is:

* **Windows:** `%USERPROFILE%\.config\opencode`
* **macOS / Linux:** `${XDG_CONFIG_HOME}/opencode` when `XDG_CONFIG_HOME` is
  set, otherwise `~/.config/opencode`

## herdr-pane-id

Shows the Herdr pane and tab id in the OpenCode footer, for example
`wK:p2 + wK:t2`.

* Slots: `prompt.footer.status` (session) and `home.footer.status` (home screen).
* Plugin id: `herdr.pane-id`.
* Hidden when OpenCode runs outside Herdr.
* Verified with OpenCode 2.0.27.

### Install (copy)

Windows (PowerShell):

```powershell
$dest = "$HOME\.config\opencode\plugins\herdr-pane-id"
New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
Copy-Item -Recurse ".\opencode\plugins\herdr-pane-id" $dest
```

macOS / Linux:

```bash
config="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
mkdir -p "$config/plugins"
rm -rf "$config/plugins/herdr-pane-id"
cp -R ./opencode/plugins/herdr-pane-id "$config/plugins/herdr-pane-id"
```

### Install (symlink)

Use this form to keep the dotfiles clone as the source of truth. OpenCode
accepts a symlinked plugin directory and follows the real files for hot reload.

Windows (PowerShell; needs Developer Mode or an admin shell):

```powershell
$dest = "$HOME\.config\opencode\plugins\herdr-pane-id"
New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Path $dest -Target "$(Resolve-Path .\opencode\plugins\herdr-pane-id)"
```

macOS / Linux:

```bash
config="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
mkdir -p "$config/plugins"
ln -sfn "$(pwd)/opencode/plugins/herdr-pane-id" "$config/plugins/herdr-pane-id"
```

### Verify

1. Start or restart OpenCode inside a Herdr pane.
2. The badge shows in the session footer, next to the working directory.
3. When the badge does not show, run `/plugins` in OpenCode and read the error.

### Settings

The default text shows the pane and the tab. To show one id only, add this
entry to `cli.json` under `plugins`:

```json
{ "package": "./plugins/herdr-pane-id", "options": { "show": "pane" } }
```

`show` accepts `pane`, `tab`, or `both` (default).

### Disable or remove

* Disable: add `"-herdr.pane-id"` to the `plugins` array in `cli.json`.
* Remove: delete the `herdr-pane-id` directory from the OpenCode config.

## File Layout

* `plugins/herdr-pane-id/tui.tsx`: the plugin source. The file is a verbatim
  copy of the live plugin at
  `%USERPROFILE%\.config\opencode\plugins\herdr-pane-id\tui.tsx` on Windows.
