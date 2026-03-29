# Repository Guidelines

## Project Structure & Module Organization

This repository manages a shared terminal setup across Windows, macOS, and Linux.

- `.wezterm.lua`: shared WezTerm configuration and shell selection.
- `nushell/config.nu`: interactive Nushell behavior, aliases, and WezTerm helpers.
- `nushell/env.nu`: minimal environment setup.
- `install.sh`: macOS/Linux installer.
- `install.ps1`: Windows installer.
- `README.md` and `WEZTERM_*_INTEGRATION.md`: user-facing setup and platform notes.

There is no `src/` or test suite; changes are made directly in config and installer files.

## Build, Test, and Development Commands

Use lightweight validation before committing:

- `bash -n install.sh`: syntax-check the Unix installer.
- `git diff --check`: catch trailing whitespace and patch formatting issues.
- `pwsh -NoLogo -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path './install.ps1'), [ref]$null, [ref]$null)"`: parse-check the PowerShell installer when `pwsh` is available.
- Open WezTerm and Nushell manually after config changes to confirm startup behavior.

## Coding Style & Naming Conventions

- Use ASCII unless a file already contains Unicode.
- Keep Lua, Nushell, Bash, and PowerShell changes small and explicit.
- Preserve existing style: two-space indentation in Lua/Nushell/Bash, four spaces in PowerShell.
- Prefer descriptive helper names such as `default_shell`, `Set-SymbolicLink`, and `weztab`.
- Do not silently overwrite user files; installers should back up or skip existing config safely.

## Testing Guidelines

There is no automated test framework in this repository. Validation is syntax checks plus manual platform checks:

- Launch WezTerm with and without `nu` on `PATH`.
- Verify shared aliases such as `ll` and `dc`.
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
