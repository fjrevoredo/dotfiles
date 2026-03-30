# WezTerm Linux Integration Summary

This document outlines the Linux-specific pieces for a shared WezTerm + Nushell setup.

## 1. Shared Shell

Nushell is the preferred shell inside WezTerm. Shared shell helpers live in the repo-owned Nushell config.

* Preferred Shell: `nu`
* Detection: `.wezterm.lua` first checks `PATH` for `nu`
* WezTerm Fallback: the user's native login shell as resolved by WezTerm when `nu` is unavailable
* Shared Helper: `weztab` tries `wezterm cli spawn --cwd <current dir>` and falls back to `wezterm start`
* Shared Helper: `wez` runs `wezterm start --cwd <current dir>`

## 2. Window Decorations

The shared WezTerm config uses `RESIZE` on Linux.

* Linux Behavior: `.wezterm.lua` does not enable macOS-only integrated title buttons on Linux
* Window Manager Note: on X11 and Wayland, the desktop environment may still influence how decorations appear

## 3. Dotfile Symlinking

The repo owns both WezTerm and Nushell config files.

The installer is the safer option because it backs up existing non-symlink files before replacing them.

* Repository Path: `~/dotfiles/.wezterm.lua`
* Nushell Repo Paths:
  * `~/dotfiles/nushell/config.nu`
  * `~/dotfiles/nushell/env.nu`
* Install Target:
  * `${XDG_CONFIG_HOME}/nushell/` when `XDG_CONFIG_HOME` is set to an absolute path
  * `~/.config/nushell/` otherwise
* Installer: `~/dotfiles/install.sh`

## 4. Launching WezTerm in the Current Directory

Desktop integration varies by distribution and desktop environment, so the repo only standardizes the command pattern.

* Generic Command: `wezterm start --cwd <directory>`
* Shared Helper in Nushell: `wez` starts WezTerm in the current directory
* Shared Helper in Nushell: `weztab` prefers `wezterm cli spawn --cwd <current dir>` when an instance is already running

## 5. Notes

* Install Nushell separately if `nu` is not already available on `PATH`
* If `XDG_CONFIG_HOME` is set, it should be an absolute path
* If `nu` is not installed, WezTerm will use the login shell configured for the current user
