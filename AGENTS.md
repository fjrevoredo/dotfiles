# Repository Guidelines

## Project Overview

Cross-platform dotfiles repository managing a shared WezTerm + Nushell terminal setup across Windows, macOS, and Linux.

## Project Structure

- `.wezterm.lua`: WezTerm configuration — shell detection, window management, theme, keybindings.
- `nushell/config.nu`: interactive Nushell behavior, aliases, and WezTerm helpers (`wez`, `weztab`).
- `nushell/env.nu`: minimal Nushell environment setup (PATH additions).
- `install.sh`: macOS/Linux installer (creates symlinks, backs up existing files).
- `install.ps1`: Windows installer (creates symlinks, registers Explorer context menu).
- `README.md`: user-facing setup instructions.
- `WEZTERM_MACOS_INTEGRATION.md`, `WEZTERM_LINUX_INTEGRATION.md`, `WEZTERM_W11_INTEGRATION.md`: platform-specific integration notes.

There is no `src/` or test suite; changes are made directly in config and installer files.

## Architecture

### `.wezterm.lua` Evaluation Order

The file is evaluated top-to-bottom in a specific order that must be preserved:

1. **Helper functions** (`executable_exists`, `command_exists`, `find_nu`, `default_shell`) — defined first so they are available for step 2.
2. **Module-level state** (`nu_found`) — set by `default_shell()`, read later by the `gui-startup` event handler.
3. **Event handlers** (`gui-startup`, `update-right-status`) — registered via `wezterm.on()`, fire later at runtime.
4. **Config object** — `wezterm.config_builder()` created last, populated with settings, then returned.

Do not reorder these sections. The `default_shell()` call on the config object (line ~127) must happen before the config is finalized, and the `gui-startup` handler relies on the `nu_found` flag set during that call.

### Shell Detection & Fallback

Detection follows a strict order:

1. `command_exists('nu')` — checks if `nu` is on WezTerm's inherited PATH via `sh -c 'command -v nu'`.
2. Candidate absolute paths — checked via `executable_exists()` using `sh -c 'if [ -x path ]'`. Covers Homebrew (`/opt/homebrew/bin`), Linuxbrew (`~/.linuxbrew/bin`, `/home/linuxbrew/.linuxbrew/bin`), cargo (`~/.cargo/bin`), system (`/usr/bin`, `/usr/local/bin`), snap, and `~/.local/bin`.

When `nu` is found, it becomes `config.default_prog`. When not found:
- The fallback shell is `zsh -l` (macOS/Linux) or `pwsh.exe -NoLogo` (Windows).
- `wezterm.log_warn()` fires at config evaluation time (visible in terminal stdout and the debug overlay).
- `gui_window:toast_notification()` fires in the `gui-startup` handler (desktop notification, 7-second timeout).

The `nu_found` boolean bridges these two moments: it is set during config evaluation and read when the GUI starts.

### Installer Pattern

Both installers follow the same pattern:
- Symlink repo files to platform-specific locations.
- If target is already a correct symlink → skip.
- If target is an existing file → back up with timestamp suffix (`.pre-dotfiles-<timestamp>.bak`), then symlink.
- Never silently overwrite user files.

Symlink targets:
- `.wezterm.lua` → `~/.wezterm.lua` (all platforms)
- `nushell/config.nu`, `nushell/env.nu` → platform nushell dir:
  - macOS: `~/Library/Application Support/nushell/`
  - Linux: `${XDG_CONFIG_HOME}/nushell/` or `~/.config/nushell/`
  - Windows: `%AppData%\nushell\`

## Important Constraints

- **Never use `sh -lc` for child process checks.** The `-l` flag sources login profile scripts that may output text to stdout, polluting the captured output and causing detection to fail silently. Always use `sh -c`.
- **Never fail silently on shell detection.** If `nu` is not found, both `wezterm.log_warn()` and `toast_notification()` must fire. Removing either breaks the user-visible fallback signal.
- **Never overwrite user files without backup.** Installers must back up or skip existing non-symlink files.
- **Consider all three platforms** (`is_windows`, `is_macos`, Linux fallback) when editing any platform-conditional logic in `.wezterm.lua`.
- **Use the WezTerm docs at `https://wezterm.org/config/lua/general.html`** as the authoritative API reference. Do not guess at WezTerm API signatures.

## Build & Validation Commands

Automated checks to run before committing:

- `bash -n install.sh` — syntax-check the Unix installer.
- `git diff --check` — catch trailing whitespace and patch formatting issues.
- `pwsh -NoLogo -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path './install.ps1'), [ref]$null, [ref]$null)"` — parse-check the PowerShell installer (when `pwsh` is available).
- There is no automated Lua linter in this project. Validate `.wezterm.lua` by relaunching WezTerm and checking the debug overlay (`Ctrl+Shift+L`) for errors.

## Coding Style & Naming Conventions

- Use ASCII unless a file already contains Unicode.
- Keep changes small and explicit.
- **No comments** in code unless explicitly requested.
- **Indentation:** two spaces in Lua, Nushell, and Bash; four spaces in PowerShell.
- **Naming conventions by language:**
  - Lua: `snake_case` for local functions and variables.
  - Nushell: `snake_case` for `def` names, `kebab-case` for flags.
  - Bash: `snake_case` for functions.
  - PowerShell: `PascalCase` verb-noun for functions (e.g., `Set-SymbolicLink`).

## Testing

There is no automated test framework. Validation is syntax checks plus manual verification.

### Automated (agent runs these)

- `bash -n install.sh`
- `git diff --check`
- PowerShell parse check (when `pwsh` available)

### Manual (ask the user to verify)

- Launch WezTerm and confirm `nu` starts as the default shell.
- Temporarily rename `nu` (or remove it from PATH) and relaunch WezTerm to verify the fallback notification appears (toast + log_warn).
- Verify shared aliases such as `ll` and `dc` work in Nushell.
- Confirm installers create symlinks and preserve existing files with backups.

## Commit & Pull Request Guidelines

Recent history uses short, imperative commit messages, for example:

- `Unify WezTerm shell setup around Nushell`
- `update docs`
- `add initial setup`

Keep commits focused on one change set. In pull requests, include:

- a short summary of user-visible behavior,
- affected platforms (`Windows`, `macOS`, `Linux`),
- any manual validation performed,
- screenshots only when documenting terminal rendering issues.

## Reference

- WezTerm Lua API: `https://wezterm.org/config/lua/general.html`
