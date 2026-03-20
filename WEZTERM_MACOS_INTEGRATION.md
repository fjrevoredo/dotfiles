# WezTerm macOS Integration Summary

This document outlines the specific steps taken to integrate WezTerm as the primary terminal emulator on macOS, ensuring it works as a seamless replacement for the default Terminal.app.

## 1. Finder Context Menu (Quick Action)

Used to open any folder in a new WezTerm tab directly from the Finder right-click menu.

* App: Shortcuts.app
* Type: Quick Action (Receive Folders from Finder)
* Action: Run Shell Script
* Pass Input: as arguments
* Script Content:
/Applications/WezTerm.app/Contents/MacOS/wezterm cli spawn --cwd "$1" || /Applications/WezTerm.app/Contents/MacOS/wezterm start --cwd "$1"

## 2. Command Line Alias

Added to the shell configuration to allow spawning new WezTerm tabs from an existing terminal session.

* File: ~/.zshrc
* Command: alias wez="wezterm cli spawn --cwd . || wezterm start --cwd ."

## 3. IntelliJ IDEA Integration

Configured as an "External Tool" to allow opening the current project directory in a high-contrast Matrix terminal.

* Path: Settings > Tools > External Tools
* Name: Open WezTerm
* Program: /bin/zsh
* Arguments: -c "/Applications/WezTerm.app/Contents/MacOS/wezterm cli spawn --cwd \"$ProjectFileDir$\" || /Applications/WezTerm.app/Contents/MacOS/wezterm start --cwd \"$ProjectFileDir$\""
* Working Directory: $ProjectFileDir$
* Suggested Keymap: Cmd + Shift + T /  Cmd + T

## 4. File System Associations

Set as the default handler for shell executable files.

* File Types: .sh and .command
* Procedure: Finder > Get Info > Open With: WezTerm > Change All...

## 5. Dotfile Symlinking

To maintain a single source of truth for the configuration across multiple machines, the file is stored in a dedicated repository and symlinked.

* Repository Path: ~/dotfiles/.wezterm.lua
* System Link: ln -s "$HOME/dotfiles/.wezterm.lua" "$HOME/.wezterm.lua"

* [Create an install.sh script for the repo](gemini://submit_prompt?text=Create+a+bash+script+named+install.sh+that+automates+the+symlinking+and+zsh+alias+setup+for+macOS)
* [Create an install.ps1 script for Windows](gemini://submit_prompt?text=Create+a+PowerShell+script+named+install.ps1+to+automate+the+symlink+creation+on+Windows)
* [Add a section for SSH Agent setup](gemini://submit_prompt?text=Add+a+section+to+the+summary+about+configuring+the+1Password+SSH+Agent)
