# Pi shared configuration plan

## Goal

Create a low-maintenance Pi setup that keeps the important workflow and UX pieces shared in this dotfiles repo while keeping credentials, model choices, and session state local to each machine.

## Scope

This plan is for **Pi configuration bootstrap and sync only**.

It does **not** install Pi itself.

The bootstrap command should:

1. verify that `pi` is already installed,
2. determine the active Pi agent directory,
3. generate or sync the managed shared config files,
4. preserve local-only files and directories,
5. report whether changes were applied or the setup is already up to date.

## Desired outcome

After this is finished, a new machine should only require:

1. cloning `dotfiles`,
2. installing Pi separately,
3. running one Pi bootstrap command from this repo,
4. setting local auth and model preferences,
5. starting Pi.

The shared experience should include:

- prompts
- skills
- extensions
- themes
- keybindings
- global AGENTS/system guidance
- baseline Pi settings

The local-only experience should include:

- `auth.json`
- local model defaults
- machine-specific `models.json`
- sessions
- local-only prompts/skills/extensions/themes if needed
- any machine-specific overrides

## Design principles

- **Public repo safe**: no secrets, tokens, or session history in git.
- **Fast to remember**: future maintenance should be obvious after months away.
- **Source of truth is declarative**: shared config lives in the repo, not in ad-hoc machine state.
- **Local state stays local**: Pi runtime files remain under the normal Pi home directory.
- **Installers are idempotent**: rerunning setup should be safe.
- **Prefer generation over linking**: generated files and explicit settings paths are lower-maintenance than symlinks/junctions over time.

## Agreed architecture

### Shared files in the repo

Planned layout under `pi/`:

```text
pi/
  README.md
  PLAN.md
  settings.base.json
  keybindings.base.json
  AGENTS.base.md
  APPEND_SYSTEM.base.md
  prompts/
  skills/
  extensions/
  themes/
  install.ps1
  install.sh
```

### Local files on each machine

Pi continues to use its normal runtime directory, honoring `PI_CODING_AGENT_DIR` when set.

Default location:

```text
~/.pi/agent/
```

On Windows this is typically:

```text
%USERPROFILE%\.pi\agent\
```

Inside that directory, local-only inputs are:

```text
settings.local.json
keybindings.local.json
AGENTS.local.md
APPEND_SYSTEM.local.md
auth.json
models.json
sessions/
prompts/              # optional machine-local prompts
skills/               # optional machine-local skills
extensions/           # optional machine-local extensions
themes/               # optional machine-local themes
```

### Generated managed outputs

The bootstrap script manages these generated files in the active Pi agent directory:

```text
settings.json
keybindings.json
AGENTS.md
APPEND_SYSTEM.md
dotfiles-pi-bootstrap.json
```

## Why this architecture

We are **not** pointing `PI_CODING_AGENT_DIR` at the public dotfiles repo.

That would make it too easy to mix in:

- `auth.json`
- sessions
- package state
- other machine-local files

We are also **not** symlinking shared resource directories into `~/.pi/agent/`.

Instead, the bootstrap script will:

- generate the fixed singleton files Pi expects in the agent directory, and
- generate `settings.json` so it includes absolute repo paths for shared `prompts/`, `skills/`, `extensions/`, and `themes/`.

That keeps local-only resource directories usable on each machine without editing the repo.

## Shared vs local split

### Shared in git

- `settings.base.json`
- `keybindings.base.json`
- `AGENTS.base.md`
- `APPEND_SYSTEM.base.md`
- `prompts/`
- `skills/`
- `extensions/`
- `themes/`

### Local only

- `auth.json`
- `models.json`
- `sessions/`
- `settings.local.json`
- `keybindings.local.json`
- `AGENTS.local.md`
- `APPEND_SYSTEM.local.md`
- optional machine-local `prompts/`, `skills/`, `extensions/`, `themes/`

## File generation model

### Settings

Pi has one global settings file, so we will use a generated file strategy:

- shared: `pi/settings.base.json`
- local input: `~/.pi/agent/settings.local.json`
- generated: `~/.pi/agent/settings.json`

The bootstrap script should also inject absolute repo paths for:

- `prompts`
- `skills`
- `extensions`
- `themes`

That makes the repo resources active without replacing the machine-local directories under `~/.pi/agent/`.

### Keybindings

- shared: `pi/keybindings.base.json`
- local input: `~/.pi/agent/keybindings.local.json`
- generated: `~/.pi/agent/keybindings.json`

### AGENTS guidance

- shared: `pi/AGENTS.base.md`
- local input: `~/.pi/agent/AGENTS.local.md`
- generated: `~/.pi/agent/AGENTS.md`

### System prompt append

Use append-by-default, not full replacement.

- shared: `pi/APPEND_SYSTEM.base.md`
- local input: `~/.pi/agent/APPEND_SYSTEM.local.md`
- generated: `~/.pi/agent/APPEND_SYSTEM.md`

`SYSTEM.md` is intentionally **not** part of the default v1 design. If a full system prompt replacement is ever needed later, support can be added explicitly.

## Merge and generation rules

### JSON merge rules

For `settings.json` and `keybindings.json` generation:

1. read the shared base file,
2. read the local file if present,
3. merge them,
4. let local values win on conflict,
5. write the generated file.

### Object and array behavior

This must match Pi semantics closely:

- nested **objects** merge recursively,
- **arrays replace**, they do not concatenate,
- primitives are overwritten by local values.

This matters especially for:

- `packages`
- `extensions`
- `skills`
- `prompts`
- `themes`
- `enabledModels`

### Settings generation details

The generated `settings.json` must include absolute repo paths for shared resource directories.

Those generated path arrays should be treated as managed output from bootstrap, not hand-edited state.

Local machine-specific settings still belong in `settings.local.json`.

### AGENTS and APPEND_SYSTEM generation details

For generated Markdown files:

- if only the shared file exists, write the shared content,
- if only the local file exists, write the local content,
- if both exist, concatenate them in this order:
  1. shared content
  2. local content

The generated file should contain a short header comment noting that it is managed by the dotfiles Pi bootstrap and pointing to the base/local source files.

### Keybindings generation details

`keybindings.json` should be generated from base + local using the JSON rules above.

If the same keybinding id exists in both files, the local value wins.

## Bootstrap responsibilities

The bootstrap command should:

1. verify `pi` is installed and callable,
2. resolve the active Pi agent directory,
   - use `PI_CODING_AGENT_DIR` when set,
   - otherwise use Pi's default agent directory,
3. create missing directories as needed,
4. create example local input files only when missing,
5. back up and replace existing unmanaged target files,
6. generate managed outputs,
7. write a manifest/state file,
8. detect and report whether anything changed.

## Manifest / state file

Bootstrap should maintain:

```text
~/.pi/agent/dotfiles-pi-bootstrap.json
```

Purpose:

- mark which files are managed,
- record the source repo path used to generate them,
- make reruns and up-to-date checks explicit,
- help distinguish managed files from unmanaged user files.

Suggested contents:

- bootstrap version or schema version,
- repo root path,
- generated file list,
- last successful bootstrap timestamp.

## Existing file policy

If a target managed output already exists and is not known to be managed by the bootstrap:

1. create a timestamped backup,
2. replace it with the generated managed file,
3. print a summary showing:
   - what was backed up,
   - where the backup went,
   - which files are now managed.

This applies to:

- `settings.json`
- `keybindings.json`
- `AGENTS.md`
- `APPEND_SYSTEM.md`

Bootstrap should be non-interactive by default.

## Up-to-date detection

On rerun, bootstrap should compare the intended generated outputs against the current managed files.

If nothing changed, it should say the Pi setup is already up to date.

If anything changed, it should report what was regenerated.

If the repo moved on disk, rerunning bootstrap should update absolute repo paths in `settings.json` and the manifest.

## What belongs in each file

### `settings.base.json`

Use for shared settings such as:

- theme
- quiet startup and UI choices
- compaction defaults
- retry settings
- shared workflow preferences
- generated shared resource paths

### `settings.local.json`

Use for machine-specific settings such as:

- `defaultProvider`
- `defaultModel`
- `sessionDir`
- `enabledModels`
- machine-specific path tweaks
- anything tied to one computer or one environment

### `keybindings.base.json`

Use for the long-term shared keybinding layout.

### `keybindings.local.json`

Use for machine-specific keybinding overrides only.

### `AGENTS.base.md`

Use for durable, always-on shared guidance.

### `AGENTS.local.md`

Use for machine-specific guidance that should only apply on one machine.

### `APPEND_SYSTEM.base.md`

Use for shared system-prompt additions that should apply everywhere.

### `APPEND_SYSTEM.local.md`

Use for machine-specific appended system guidance.

## Planned workflows

### First-time setup on a machine

1. Clone dotfiles.
2. Install Pi separately.
3. Create any desired local override files under the Pi agent directory.
4. Run `pi/install.ps1` or `pi/install.sh` from the repo.
5. Authenticate locally via `/login`, environment variables, or `auth.json`.
6. Start Pi and validate.

### Shared config update

1. Edit files under `dotfiles/pi/`.
2. Commit and push.
3. Pull changes on each machine.
4. Rerun the Pi bootstrap script.
5. Use `/reload` in Pi or restart Pi.

### Local-only update

1. Edit local override files in the Pi agent directory.
2. Rerun bootstrap to regenerate managed outputs.
3. Reload or restart Pi.

### Returning after a long gap

1. Pull the latest dotfiles repo.
2. Read `pi/README.md`.
3. Rerun bootstrap.
4. Start Pi.
5. Run `/reload` if Pi was already open.

## Package decision for v1

Shared Pi packages are **out of scope for v1**.

Reason:

- they add extra lifecycle and versioning complexity,
- they are not required for the core shared/local split,
- deferring them keeps the first implementation smaller and safer.

If package support is added later, versions should be **pinned by default**.

## Implementation phases

## Phase 1 - Documentation and structure

- [x] Add `pi/PLAN.md`
- [x] Add `pi/README.md`
- [x] Link root `README.md` to Pi docs
- [x] Update Pi docs to match the agreed generated-file architecture
- [x] Create starter base files and placeholder directories under `pi/`

## Phase 2 - Bootstrap tooling

- [x] Add `pi/install.ps1`
- [x] Add `pi/install.sh`
- [x] Verify `pi` is installed before doing any work
- [x] Honor `PI_CODING_AGENT_DIR` when set
- [x] Generate `settings.json` from base + local + managed shared resource paths
- [x] Generate `keybindings.json` from base + local
- [x] Generate `AGENTS.md` from base + local
- [x] Generate `APPEND_SYSTEM.md` from base + local
- [x] Create example local override files only if missing
- [x] Back up and replace existing unmanaged files safely
- [x] Write and maintain `dotfiles-pi-bootstrap.json`
- [x] Detect no-op reruns and report already up to date

## Phase 3 - Shared config content

- [x] Create initial `settings.base.json`
- [x] Create initial `keybindings.base.json`
- [x] Create initial `AGENTS.base.md`
- [x] Create initial `APPEND_SYSTEM.base.md`
- [x] Add initial shared prompts/skills/extensions/themes as needed

## Phase 4 - Validation

- [ ] Validate on Windows
- [ ] Validate on macOS
- [ ] Confirm `/reload` behavior for keybindings, prompts, skills, extensions, and context files
- [ ] Confirm themes hot-reload correctly
- [ ] Confirm auth remains local
- [ ] Confirm model defaults remain local
- [ ] Confirm local-only prompts/skills/extensions/themes still work alongside repo-shared resources
- [ ] Confirm repo move/path change is fixed by rerunning bootstrap

## Acceptance criteria

The setup is complete when all of the following are true:

- shared Pi config is stored under `dotfiles/pi/`
- running one bootstrap command syncs a machine correctly after Pi is already installed
- bootstrap honors `PI_CODING_AGENT_DIR` when set
- auth never needs to be committed to the repo
- model defaults can differ per machine without editing shared files
- local-only prompts/skills/extensions/themes remain possible on each machine
- unmanaged existing singleton files are backed up and replaced safely
- rerunning bootstrap is safe and can detect the already up-to-date case
- future shared updates only require `git pull` + bootstrap + `/reload`
- documentation is clear enough to follow after months away

## Operational rules

To keep this maintainable:

- Treat generated `settings.json`, `keybindings.json`, `AGENTS.md`, and `APPEND_SYSTEM.md` as output files.
- Treat `settings.local.json`, `keybindings.local.json`, `AGENTS.local.md`, and `APPEND_SYSTEM.local.md` as the place for machine-specific overrides.
- Keep shared resource directories in the repo and load them via generated settings paths.
- Do not add shared package management to v1.
- Keep bootstrap non-interactive and idempotent.

## Future enhancements

Possible later additions:

- shared package support with pinned versions,
- profile-aware local overrides such as work vs personal,
- optional support for managed `SYSTEM.md` in workflows that truly need full replacement,
- Linux validation if it becomes a regular target.
