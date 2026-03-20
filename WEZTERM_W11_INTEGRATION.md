# WezTerm Windows 11 Integration Summary

## 1. Explorer Context Menu (Right-Click "Open Here")

To add WezTerm to the Windows 11 context menu for directories, a registry entry is used. This allows right-clicking in any folder background to open a WezTerm instance there.

* Method: Windows Registry (HKCU)
* Menu Name: Open in WezTerm
* Command: wezterm-gui.exe start --cwd "%V"
* PowerShell Command to Apply:
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\WezTerm" -Value "Open in WezTerm" -Force
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\WezTerm\command" -Value "wezterm-gui.exe start --cwd \"%V\"" -Force

## 2. PowerShell Profile Alias

Added an alias to PowerShell 7 to allow spawning new tabs or windows from the command line quickly.

* File: $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
* Command: Set-Alias -Name wez -Value wezterm-gui.exe
* Function for Tabs: function wez-tab { wezterm cli spawn --cwd . }

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

Ensures the configuration is synced from the GitHub repository to the Windows User Profile.

* Requirement: Windows Developer Mode must be ON (Settings > System > For Developers)
* Repository Path: $HOME\dotfiles\.wezterm.lua
* System Link Command (PowerShell): 
New-Item -ItemType SymbolicLink -Path "$HOME\.wezterm.lua" -Target "$HOME\dotfiles\.wezterm.lua"

* [Create install.ps1 for Windows](gemini://submit_prompt?text=Create+a+PowerShell+script+named+install.ps1+to+automate+the+symlink+creation+on+Windows)
* [Create install.sh for macOS](gemini://submit_prompt?text=Create+a+bash+script+named+install.sh+to+automate+the+symlink+creation+on+macOS)
* [Add a README.md to the repo](gemini://submit_prompt?text=Draft+a+comprehensive+README.md+for+the+dotfiles+repository)