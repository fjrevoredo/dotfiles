# My Dotfiles

A cross-platform dotfiles repository for keeping the terminal experience aligned across Windows, macOS, and Linux.

## What's Inside

This repository manages a shared terminal stack:

* **WezTerm:** A shared `.wezterm.lua` with the existing Matrix theme, centered startup, and tmux-style pane bindings.
* **Nushell:** Shared `config.nu` and `env.nu` so the default shell experience is consistent across platforms.
* **Safe Fallbacks:** WezTerm prefers `nu` when it exists and falls back to the native platform shell when it does not.

### Custom Keybindings

* **Leader Key:** `Ctrl + A` (Timeout: 1000ms)

| Action | Shortcut |
| :--- | :--- |
| **Split Pane Right** | `Leader` + `d` |
| **Split Pane Top** | `Leader` + `w` |
| **Navigate Panes** | `Leader` + `Arrow Keys` |
| **Close Active Pane** | `Leader` + `x` |

## Installation

Clone the repo into your home directory and run the platform installer. Both installers create symlinks, keep correct existing symlinks in place, and back up existing non-symlink config files before replacing them.

Platform references:

* [WEZTERM_MACOS_INTEGRATION.md](/Users/francisco.revoredo/Documents/private/dotfiles/WEZTERM_MACOS_INTEGRATION.md)
* [WEZTERM_LINUX_INTEGRATION.md](/Users/francisco.revoredo/Documents/private/dotfiles/WEZTERM_LINUX_INTEGRATION.md)
* [WEZTERM_W11_INTEGRATION.md](/Users/francisco.revoredo/Documents/private/dotfiles/WEZTERM_W11_INTEGRATION.md)

### macOS / Linux

```bash
git clone https://github.com/fjrevoredo/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

### Windows

```powershell
git clone https://github.com/fjrevoredo/dotfiles.git $HOME\dotfiles
Set-Location $HOME\dotfiles
.\install.ps1
```

## Nushell Layout

The shared Nushell files live in `nushell/` inside this repo.

* `config.nu`: interactive shell behavior, aliases, and WezTerm helpers.
* `env.nu`: minimal environment setup.

Shared helpers:

* `wez`: starts WezTerm in the current directory.
* `weztab`: tries `wezterm cli spawn` first and falls back to `wezterm start`.

Install targets:

* **Windows:** `%AppData%\nushell\`
* **macOS:** `~/Library/Application Support/nushell/`
* **Linux:** `${XDG_CONFIG_HOME}/nushell/` when `XDG_CONFIG_HOME` is set to an absolute path, otherwise `~/.config/nushell/`

Shell fallback behavior:

* **Windows:** falls back to `pwsh.exe -NoLogo` when `nu` is unavailable.
* **macOS:** falls back to `zsh -l` when `nu` is unavailable.
* **Linux:** falls back to WezTerm's native login-shell resolution when `nu` is unavailable.

## Windows Note

On Windows, the shared Nushell config disables the `osc133` and `osc633` shell-integration markers. In WezTerm this avoided a rendering bug where the visible terminal content shifted upward on every keypress while typing at the prompt.

## Notes

* Install Nushell separately if `nu` is not already on your `PATH`.
* On macOS, GUI apps may not inherit Homebrew paths, so `.wezterm.lua` also checks common absolute Nushell locations.
* Existing shell-specific aliases in PowerShell or zsh can be removed after you are fully on Nushell.
