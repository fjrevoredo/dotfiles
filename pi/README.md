# Pi dotfiles workflow

This directory is the source of truth for the **shared** parts of my Pi setup.

The goal is simple:

- keep Pi's workflow, UX, prompts, skills, extensions, and shared guidance consistent across machines
- keep auth, model selection, sessions, and machine-specific overrides local to each machine
- make updates easy to remember after long gaps

## Important scope note

The bootstrap scripts in this directory **do not install Pi**.

They assume Pi is already installed.

Their job is to:

- verify that `pi` is available,
- detect the active Pi agent directory,
- generate or sync the managed shared config files,
- preserve local-only files and directories,
- report whether anything changed or the setup is already up to date.

## Agent directory

By default, Pi uses:

```text
~/.pi/agent/
```

On Windows this is typically:

```text
%USERPROFILE%\.pi\agent\
```

If `PI_CODING_AGENT_DIR` is set, the bootstrap scripts should honor it.

## Shared in this repo

These are safe to commit:

- `settings.base.json`
- `keybindings.base.json`
- `AGENTS.base.md`
- `APPEND_SYSTEM.base.md`
- `prompts/`
- `skills/`
- `extensions/`
- `themes/`

## Local on each machine

These stay out of git and remain machine-specific:

- `~/.pi/agent/settings.local.json`
- `~/.pi/agent/keybindings.local.json`
- `~/.pi/agent/AGENTS.local.md`
- `~/.pi/agent/APPEND_SYSTEM.local.md`
- `~/.pi/agent/auth.json`
- `~/.pi/agent/models.json`
- `~/.pi/agent/sessions/`
- optional machine-local `~/.pi/agent/prompts/`
- optional machine-local `~/.pi/agent/skills/`
- optional machine-local `~/.pi/agent/extensions/`
- optional machine-local `~/.pi/agent/themes/`

## Generated managed outputs

Bootstrap generates and manages these files in the active Pi agent directory:

- `settings.json`
- `keybindings.json`
- `AGENTS.md`
- `APPEND_SYSTEM.md`
- `dotfiles-pi-bootstrap.json`

Treat those generated files as outputs, not as the source of truth.

## Operating model

### Settings

Pi has one global settings file, so this setup uses:

- a shared base settings file in git,
- a local override file on each machine,
- a generated final settings file.

Files:

- shared: `pi/settings.base.json`
- local: `~/.pi/agent/settings.local.json`
- generated: `~/.pi/agent/settings.json`

### Keybindings

Files:

- shared: `pi/keybindings.base.json`
- local: `~/.pi/agent/keybindings.local.json`
- generated: `~/.pi/agent/keybindings.json`

### Shared AGENTS guidance

Files:

- shared: `pi/AGENTS.base.md`
- local: `~/.pi/agent/AGENTS.local.md`
- generated: `~/.pi/agent/AGENTS.md`

### Shared system prompt additions

This setup standardizes on append-by-default.

Files:

- shared: `pi/APPEND_SYSTEM.base.md`
- local: `~/.pi/agent/APPEND_SYSTEM.local.md`
- generated: `~/.pi/agent/APPEND_SYSTEM.md`

`SYSTEM.md` is intentionally not part of the normal shared workflow.

## Merge rules

### JSON files

For `settings.json` and `keybindings.json`:

- nested **objects** merge recursively,
- **arrays replace**, they do not concatenate,
- local values win on conflict.

This matters for keys like:

- `packages`
- `extensions`
- `skills`
- `prompts`
- `themes`
- `enabledModels`

### Markdown files

For generated `AGENTS.md` and `APPEND_SYSTEM.md`:

- if both shared and local files exist, generated output is:
  1. shared content
  2. local content
- if only one exists, generate from that one

## Shared resource directories

The shared repo directories are **not** symlinked into `~/.pi/agent/`.

Instead, bootstrap generates `settings.json` with absolute repo paths for:

- `prompts`
- `skills`
- `extensions`
- `themes`

This is intentional.

It keeps machine-local resource directories still usable under `~/.pi/agent/`.

## First-time setup on a machine

1. Clone the dotfiles repo.
2. Install Pi separately.
3. Optionally create any local override files.
4. Run the Pi bootstrap script from this repo.
5. Set up auth locally.
6. Pick a model locally if desired.
7. Open Pi and validate the setup.

### Windows

```powershell
Set-Location D:\Repos\dotfiles
.\pi\install.ps1
```

### macOS

```bash
cd ~/dotfiles
./pi/install.sh
```

## Suggested local override examples

### `settings.local.json`

```json
{
  "defaultProvider": "anthropic",
  "defaultModel": "claude-sonnet-4-20250514"
}
```

### `keybindings.local.json`

```json
{
  "tui.input.newLine": ["shift+enter", "ctrl+j"]
}
```

### `AGENTS.local.md`

```markdown
Prefer work-machine defaults when dealing with internal repositories.
```

### `APPEND_SYSTEM.local.md`

```markdown
When running on this machine, be conservative about destructive shell commands.
```

## Auth workflow

Auth is intentionally local.

Use one of these:

- `/login`
- environment variables
- local `auth.json`

Example `auth.json`:

```json
{
  "anthropic": { "type": "api_key", "key": "ANTHROPIC_API_KEY" },
  "openai": { "type": "api_key", "key": "OPENAI_API_KEY" }
}
```

Or use local secret-manager commands:

```json
{
  "anthropic": { "type": "api_key", "key": "!op read 'op://vault/anthropic/api-key'" }
}
```

Never commit `auth.json`.

## Day-to-day workflows

## Workflow 1: update shared Pi config

Use this when changing prompts, keybindings, AGENTS guidance, extensions, themes, or shared settings.

1. Edit files under `dotfiles/pi/`.
2. Commit and push.
3. On each machine:
   1. `git pull`
   2. rerun the bootstrap script
   3. run `/reload` in Pi, or restart Pi

### Use `/reload` for

- keybindings
- prompts
- skills
- extensions
- context files such as `AGENTS.md` and `APPEND_SYSTEM.md`

### Themes

Themes hot-reload automatically when the active custom theme changes, but rerunning bootstrap is still the right step after repo updates.

## Workflow 2: change a machine-local preference

Use this when one machine needs a different model, keybinding, session directory, or local guidance.

1. Edit local override files in the Pi agent directory
2. Rerun bootstrap
3. Reload or restart Pi

Examples of local-only settings:

- work laptop uses one provider by default
- personal desktop uses another model
- one machine has extra local prompt templates
- one machine needs different keybindings
- one machine wants extra AGENTS guidance

## Workflow 3: update after a long gap

When returning after a few months, use this checklist:

1. Pull the latest dotfiles repo.
2. Read this file.
3. Rerun the Pi bootstrap script.
4. Open Pi.
5. Run `/reload` if Pi was already open.
6. Verify auth still works.
7. Verify the expected model is selected or selectable.

## Existing file behavior

If bootstrap finds an unmanaged existing target file such as:

- `settings.json`
- `keybindings.json`
- `AGENTS.md`
- `APPEND_SYSTEM.md`

it should:

1. create a timestamped backup,
2. replace it with the managed generated file,
3. tell you what was backed up and where.

That makes it safe to merge any old customizations manually afterward if needed.

## Recommended file responsibilities

### `settings.base.json`

Use for shared settings such as:

- theme
- UI behavior
- compaction defaults
- retry behavior
- shared workflow preferences
- generated shared resource paths

### `settings.local.json`

Use for machine-specific settings such as:

- `defaultProvider`
- `defaultModel`
- `sessionDir`
- `enabledModels`
- local path tweaks

### `keybindings.base.json`

Use for the long-term keyboard layout you want on every machine.

### `keybindings.local.json`

Use for machine-specific keybinding overrides only.

### `AGENTS.base.md`

Use for durable, always-on shared instructions that should apply everywhere.

### `AGENTS.local.md`

Use for machine-specific instructions only.

### `APPEND_SYSTEM.base.md`

Use for shared system-level guidance that should augment Pi's default system prompt.

### `APPEND_SYSTEM.local.md`

Use for machine-specific appended system guidance.

### `prompts/`

Use for reusable prompt templates you want available everywhere.

### `skills/`

Use for repeatable workflows that Pi should load on demand.

### `extensions/`

Use for tools, UI changes, status widgets, provider integrations, and custom behavior.

### `themes/`

Use for custom visual themes.

## Packages

Shared Pi packages are intentionally **out of scope for v1** of this setup.

The first version is focused on deterministic shared config sync.

If package support is added later, versions should be pinned by default.

## Troubleshooting

### Pi is not installed

Install Pi first, then rerun the bootstrap script.

### Pi is not seeing new prompts, skills, or extensions

- rerun the bootstrap script
- run `/reload`
- restart Pi if needed

### A machine lost its auth

- check `auth.json`
- check environment variables
- rerun `/login`

### The wrong model is selected

- check `settings.local.json`
- regenerate `settings.json`
- use `/model` in Pi to confirm available models

### Settings or guidance changed unexpectedly

- remember that `settings.json`, `keybindings.json`, `AGENTS.md`, and `APPEND_SYSTEM.md` are generated
- check the corresponding `.base` and `.local` source files
- rerun bootstrap to return to the intended merged state

### The repo moved to a new path

Rerun bootstrap so the generated absolute repo paths in `settings.json` are updated.

## Implementation note

The next implementation step is to add bootstrap scripts that:

- verify Pi is already installed
- honor `PI_CODING_AGENT_DIR` when set
- create any needed directories
- generate managed singleton files from shared + local sources
- inject shared repo resource paths into generated settings
- leave `auth.json`, `models.json`, `sessions/`, and optional machine-local resource directories untouched
- maintain `dotfiles-pi-bootstrap.json`

See `pi/PLAN.md` for the implementation checklist.
