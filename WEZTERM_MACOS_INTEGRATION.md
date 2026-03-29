# WezTerm macOS Integration Summary

This document outlines the macOS-specific pieces for a shared WezTerm + Nushell setup.

## 1. Finder Context Menu (Quick Action)

Used to open any folder in a new WezTerm tab directly from the Finder right-click menu.

* App: Shortcuts.app
* Type: Quick Action (Receive Folders from Finder)
* Action: Run Shell Script
* Pass Input: as arguments
* Script Content:
/Applications/WezTerm.app/Contents/MacOS/wezterm cli spawn --cwd "$1" || /Applications/WezTerm.app/Contents/MacOS/wezterm start --cwd "$1"

## 2. Shared Shell

Nushell is the preferred shell inside WezTerm. Shared shell helpers now live in the repo-owned Nushell config instead of `~/.zshrc`.

* Preferred Shell: `nu`
* WezTerm Fallback: `zsh -l`
* Shared Helper: `weztab` tries `wezterm cli spawn --cwd <current dir>` and falls back to `wezterm start`
* Shared Helper: `wez` runs `wezterm start --cwd <current dir>`

## 3. IntelliJ IDEA Integration

Configured as an "External Tool" to allow opening the current project directory in a high-contrast Matrix terminal.

* Path: Settings > Tools > External Tools
* Name: Open WezTerm
* Program: /Applications/WezTerm.app/Contents/MacOS/wezterm
* Arguments: start --cwd "$ProjectFileDir$"
* Working Directory: $ProjectFileDir$
* Suggested Keymap: Cmd + Shift + T /  Cmd + T

## 4. File System Associations

Set as the default handler for shell executable files.

* File Types: .sh and .command
* Procedure: Finder > Get Info > Open With: WezTerm > Change All...

## 5. Dotfile Symlinking

The repo now owns both WezTerm and Nushell config files.

* Repository Path: ~/dotfiles/.wezterm.lua
* Nushell Repo Paths:
  * ~/dotfiles/nushell/config.nu
  * ~/dotfiles/nushell/env.nu
* System Links:
  * `ln -s "$HOME/dotfiles/.wezterm.lua" "$HOME/.wezterm.lua"`
  * `ln -s "$HOME/dotfiles/nushell/config.nu" "$HOME/Library/Application Support/nushell/config.nu"`
  * `ln -s "$HOME/dotfiles/nushell/env.nu" "$HOME/Library/Application Support/nushell/env.nu"`
* Installer: `~/dotfiles/install.sh`
