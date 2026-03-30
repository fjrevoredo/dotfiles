# WezTerm Windows 11 Integration Summary

This document outlines the Windows-specific pieces for a shared WezTerm + Nushell setup.

## 1. Explorer Context Menu (Right-Click "Open Here")

To add WezTerm to the Windows 11 context menu for directories, a registry entry is used. This allows right-clicking in any folder background to open a WezTerm instance there.

* Method: Windows Registry (HKCU)
* Menu Name: Open in WezTerm
* Command: wezterm-gui.exe start --cwd "%V"
* PowerShell Command to Apply:
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\WezTerm" -Value "Open in WezTerm" -Force
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\WezTerm\command" -Value "wezterm-gui.exe start --cwd \"%V\"" -Force

## 2. Shared Shell

Nushell is the preferred shell inside WezTerm. Shared shell helpers now live in the repo-owned Nushell config instead of the PowerShell profile.

* Preferred Shell: `nu`
* WezTerm Fallback: `pwsh.exe -NoLogo`
* Shared Helper: `weztab` tries `wezterm cli spawn --cwd <current dir>` and falls back to `wezterm start`
* Shared Helper: `wez` runs `wezterm start --cwd <current dir>`
* Windows-Specific Workaround: `osc133` and `osc633` are disabled in `nushell/config.nu` because they caused WezTerm to visually scroll the screen upward on each keypress while typing.

## 3. IntelliJ IDEA Integration

Configured as an "External Tool" to launch the Matrix terminal directly from the IDE.

* Path: Settings > Tools > External Tools
* Name: Open WezTerm
* Program: wezterm-gui.exe
* Arguments: start --cwd $ProjectFileDir$
* Working Directory: $ProjectFileDir$
* Suggested Keymap: Ctrl + Shift + T / Ctrl + T

## 4. 1Password SSH Agent Integration

Configured the Windows OpenSSH client to communicate with the 1Password SSH agent pipe.

* File: %USERPROFILE%\.ssh\config
* Content:
Host *
  IdentityAgent "\\.\pipe\openssh-ssh-agent"

## 5. Dotfile Symlinking

Ensures both WezTerm and Nushell configs are synced from the GitHub repository to the Windows user profile.

The installer is the safer option because it backs up existing non-symlink files before replacing them.

* Requirement: Windows Developer Mode must be ON (Settings > System > For Developers)
* Repository Path: $HOME\dotfiles\.wezterm.lua
* Nushell Repo Paths:
  * $HOME\dotfiles\nushell\config.nu
  * $HOME\dotfiles\nushell\env.nu
* System Link Commands (PowerShell):
  * `New-Item -ItemType SymbolicLink -Path "$HOME\.wezterm.lua" -Target "$HOME\dotfiles\.wezterm.lua"`
  * `New-Item -ItemType SymbolicLink -Path "$env:APPDATA\nushell\config.nu" -Target "$HOME\dotfiles\nushell\config.nu"`
  * `New-Item -ItemType SymbolicLink -Path "$env:APPDATA\nushell\env.nu" -Target "$HOME\dotfiles\nushell\env.nu"`
* Installer: `$HOME\dotfiles\install.ps1`
