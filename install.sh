#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link_file() {
  local source_path="$1"
  local target_path="$2"
  local target_dir

  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir"

  if [[ -L "$target_path" ]]; then
    local current_target
    current_target="$(readlink "$target_path")"

    if [[ "$current_target" == "$source_path" ]]; then
      printf '[SKIP] %s already points to %s\n' "$target_path" "$source_path"
      return
    fi

    rm "$target_path"
  elif [[ -e "$target_path" ]]; then
    local backup_path
    backup_path="${target_path}.pre-dotfiles-$(date +%Y%m%d%H%M%S).bak"
    mv "$target_path" "$backup_path"
    printf '[BACKUP] Moved existing file to %s\n' "$backup_path"
  fi

  ln -s "$source_path" "$target_path"
  printf '[OK] %s -> %s\n' "$target_path" "$source_path"
}

case "$(uname -s)" in
  Darwin)
    nushell_dir="$HOME/Library/Application Support/nushell"
    ;;
  Linux)
    nushell_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nushell"
    ;;
  *)
    printf '[ERROR] Unsupported OS for install.sh\n' >&2
    exit 1
    ;;
esac

link_file "$repo_root/.wezterm.lua" "$HOME/.wezterm.lua"
link_file "$repo_root/nushell/config.nu" "$nushell_dir/config.nu"
link_file "$repo_root/nushell/env.nu" "$nushell_dir/env.nu"

printf '\nWezTerm and Nushell links are in place.\n'
printf 'Install Nushell separately if `nu` is not already available on PATH.\n'
