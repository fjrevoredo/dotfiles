#!/usr/bin/env bash

set -euo pipefail

case "$(uname -s)" in
  Darwin|Linux)
    ;;
  *)
    printf '[ERROR] Unsupported OS for pi/install.sh\n' >&2
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pi_repo_dir="$repo_root/pi"

if ! command -v pi >/dev/null 2>&1; then
  printf '[ERROR] `pi` was not found on PATH. Install Pi first, then rerun this script.\n' >&2
  exit 1
fi

python_bin=''
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then
    python_bin="$candidate"
    break
  fi
done

if [[ -z "$python_bin" ]]; then
  printf '[ERROR] Python 3 was not found on PATH. Install python3, then rerun this script.\n' >&2
  exit 1
fi

export DOTFILES_REPO_ROOT="$repo_root"
export DOTFILES_PI_DIR="$pi_repo_dir"

"$python_bin" - <<'PY'
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

repo_root = Path(os.environ["DOTFILES_REPO_ROOT"]).resolve()
pi_repo_dir = Path(os.environ["DOTFILES_PI_DIR"]).resolve()
env_agent_dir = os.environ.get("PI_CODING_AGENT_DIR")
if env_agent_dir:
    agent_dir = Path(os.path.expanduser(env_agent_dir)).resolve()
else:
    agent_dir = (Path.home() / ".pi" / "agent").resolve()

print(f"[INFO] Repo root: {repo_root}")
print(f"[INFO] Pi agent dir: {agent_dir}")

resource_dirs = {
    "prompts": pi_repo_dir / "prompts",
    "skills": pi_repo_dir / "skills",
    "extensions": pi_repo_dir / "extensions",
    "themes": pi_repo_dir / "themes",
}

managed_targets = {
    "settings.json": {
        "kind": "json",
        "path": agent_dir / "settings.json",
        "sources": [
            str((pi_repo_dir / "settings.base.json").resolve()),
            str((agent_dir / "settings.local.json").resolve()),
            *(str(path.resolve()) for path in resource_dirs.values()),
        ],
    },
    "keybindings.json": {
        "kind": "json",
        "path": agent_dir / "keybindings.json",
        "sources": [
            str((pi_repo_dir / "keybindings.base.json").resolve()),
            str((agent_dir / "keybindings.local.json").resolve()),
        ],
    },
    "AGENTS.md": {
        "kind": "markdown",
        "path": agent_dir / "AGENTS.md",
        "sources": [
            str((pi_repo_dir / "AGENTS.base.md").resolve()),
            str((agent_dir / "AGENTS.local.md").resolve()),
        ],
    },
    "APPEND_SYSTEM.md": {
        "kind": "markdown",
        "path": agent_dir / "APPEND_SYSTEM.md",
        "sources": [
            str((pi_repo_dir / "APPEND_SYSTEM.base.md").resolve()),
            str((agent_dir / "APPEND_SYSTEM.local.md").resolve()),
        ],
    },
}

manifest_path = agent_dir / "dotfiles-pi-bootstrap.json"
seed_files = {
    agent_dir / "settings.local.json": "{}\n",
    agent_dir / "keybindings.local.json": "{}\n",
    agent_dir / "AGENTS.local.md": "\n",
    agent_dir / "APPEND_SYSTEM.local.md": "\n",
}

changes = 0
backup_count = 0


def read_json_file(path: Path) -> dict:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"[ERROR] Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"[ERROR] Expected a JSON object in {path}")
    return data


def deep_merge(base, override):
    result = dict(base)
    for key, value in override.items():
        base_value = result.get(key)
        if isinstance(base_value, dict) and isinstance(value, dict):
            result[key] = deep_merge(base_value, value)
        else:
            result[key] = value
    return result


def normalize_json_text(value: dict) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def load_markdown_content(path: Path):
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return None
    return text.rstrip() + "\n"


def render_markdown(target_name: str, shared_path: Path, local_path: Path) -> str:
    shared_text = load_markdown_content(shared_path)
    local_text = load_markdown_content(local_path)
    parts = []
    if shared_text or local_text:
        parts.append(
            f"<!-- Managed by dotfiles pi bootstrap. Edit {shared_path.name} and {local_path.name}, then rerun bootstrap. -->"
        )
    if shared_text:
        parts.append(shared_text.rstrip())
    if local_text:
        parts.append(local_text.rstrip())
    if not parts:
        return ""
    return "\n\n".join(parts) + "\n"


def make_backup_path(path: Path) -> Path:
    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    candidate = path.with_name(f"{path.name}.pre-dotfiles-pi-{stamp}.bak")
    index = 1
    while candidate.exists():
        candidate = path.with_name(f"{path.name}.pre-dotfiles-pi-{stamp}-{index}.bak")
        index += 1
    return candidate


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, text: str) -> None:
    ensure_parent(path)
    path.write_text(text, encoding="utf-8")


def load_manifest(path: Path):
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict):
        return None
    return data


agent_dir.mkdir(parents=True, exist_ok=True)
for resource_dir in resource_dirs.values():
    resource_dir.mkdir(parents=True, exist_ok=True)
for subdir in ("prompts", "skills", "extensions", "themes", "sessions"):
    (agent_dir / subdir).mkdir(parents=True, exist_ok=True)

for seed_path, seed_content in seed_files.items():
    if seed_path.exists():
        continue
    write_text(seed_path, seed_content)
    changes += 1
    print(f"[CREATE] {seed_path}")

settings_value = deep_merge(
    read_json_file(pi_repo_dir / "settings.base.json"),
    read_json_file(agent_dir / "settings.local.json"),
)
for key, path in resource_dirs.items():
    settings_value[key] = [str(path.resolve())]
keybindings_value = deep_merge(
    read_json_file(pi_repo_dir / "keybindings.base.json"),
    read_json_file(agent_dir / "keybindings.local.json"),
)

expected_content = {
    "settings.json": normalize_json_text(settings_value),
    "keybindings.json": normalize_json_text(keybindings_value),
    "AGENTS.md": render_markdown(
        "AGENTS.md",
        pi_repo_dir / "AGENTS.base.md",
        agent_dir / "AGENTS.local.md",
    ),
    "APPEND_SYSTEM.md": render_markdown(
        "APPEND_SYSTEM.md",
        pi_repo_dir / "APPEND_SYSTEM.base.md",
        agent_dir / "APPEND_SYSTEM.local.md",
    ),
}

manifest_data = load_manifest(manifest_path)
managed_names = set()
if isinstance(manifest_data, dict):
    generated_files = manifest_data.get("generatedFiles")
    if isinstance(generated_files, dict):
        managed_names = set(generated_files.keys())

for name, details in managed_targets.items():
    target_path = details["path"]
    target_exists = target_path.exists() or target_path.is_symlink()
    is_managed = name in managed_names
    needs_backup = False
    if target_exists and not is_managed:
        needs_backup = True
    if target_exists and is_managed and (target_path.is_dir() or target_path.is_symlink()):
        needs_backup = True
    if needs_backup:
        backup_path = make_backup_path(target_path)
        shutil.move(str(target_path), str(backup_path))
        backup_count += 1
        changes += 1
        target_exists = False
        print(f"[BACKUP] {target_path} -> {backup_path}")
    current_text = None
    if target_exists:
        current_text = target_path.read_text(encoding="utf-8")
    desired_text = expected_content[name]
    if current_text == desired_text:
        print(f"[SKIP] {target_path} is up to date")
        continue
    write_text(target_path, desired_text)
    changes += 1
    print(f"[WRITE] {target_path}")

expected_manifest = {
    "schemaVersion": 1,
    "tool": "dotfiles-pi-bootstrap",
    "repoRoot": str(repo_root),
    "agentDir": str(agent_dir),
    "generatedFiles": {
        name: {
            "kind": details["kind"],
            "path": str(details["path"]),
            "sources": details["sources"],
        }
        for name, details in managed_targets.items()
    },
    "updatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
}

manifest_needs_write = True
if isinstance(manifest_data, dict):
    comparable_current = dict(manifest_data)
    comparable_expected = dict(expected_manifest)
    comparable_current.pop("updatedAt", None)
    comparable_expected.pop("updatedAt", None)
    manifest_needs_write = comparable_current != comparable_expected

if manifest_needs_write or changes > 0:
    write_text(manifest_path, normalize_json_text(expected_manifest))
    changes += 1
    print(f"[WRITE] {manifest_path}")
else:
    print(f"[SKIP] {manifest_path} is up to date")

if changes == 0:
    print("\nPi bootstrap is already up to date.")
else:
    print(f"\nPi bootstrap applied {changes} change(s).")
    if backup_count:
        print(f"Backups created: {backup_count}")

print("Run /reload in Pi or restart Pi to pick up changes.")
PY
