# My Dotfiles

A cross-platform dotfiles repository for keeping my macOS and Windows 11 terminal environments perfectly synced.

## What's Inside

Currently, this repository manages my **WezTerm** configuration:

* **Custom Matrix Theme:** High-contrast phosphor green on pure black.
* **Streamlined UI:** Borderless windows with a conditionally hidden, modern tab bar.
* **Centered Startup:** Auto-centers the terminal window on launch.
* **Font:** JetBrains Mono (Size 15.0) with ligatures.

### Custom Keybindings

I use a custom `tmux`-style workflow to prevent shortcut collisions between macOS and Windows.

* **Leader Key:** `Ctrl + A` (Timeout: 1000ms)

| Action | Shortcut |
| :--- | :--- |
| **Split Pane Right** | `Leader` + `d` |
| **Split Pane Top** | `Leader` + `w` |
| **Navigate Panes** | `Leader` + `Arrow Keys` |
| **Close Active Pane**| `Leader` + `x` |

## Installation

To use these dotfiles on a new machine, clone the repository to your home folder and create a symlink to the configuration files.

### macOS (zsh)

```bash
git clone [https://github.com/fjrevoredo/dotfiles.git](https://github.com/fjrevoredo/dotfiles.git) ~/dotfiles
ln -s ~/dotfiles/.wezterm.lua ~/.wezterm.lua
