#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${HERDR_APP_HOME:-}" ]]; then
  dest_root="$HERDR_APP_HOME"
else
  dest_root="${XDG_CONFIG_HOME:-$HOME/.config}/herdr-app"
fi

copy_config_file() {
  local source_path="$1"
  local dest_path="$2"

  mkdir -p "$(dirname "$dest_path")"

  if [[ -f "$dest_path" ]]; then
    if cmp -s "$source_path" "$dest_path"; then
      printf '[SKIP] Up to date: %s\n' "$dest_path"
      return
    fi

    local backup_path
    backup_path="${dest_path}.pre-dotfiles-$(date +%Y%m%d%H%M%S).bak"
    cp "$dest_path" "$backup_path"
    printf '[BACKUP] Copied existing file to %s\n' "$backup_path"
  fi

  cp "$source_path" "$dest_path"
  printf '[OK] Copied: %s\n' "$dest_path"
}

copy_config_file "$repo_root/settings.json" "$dest_root/settings.json"
copy_config_file "$repo_root/themes/matrix.json" "$dest_root/themes/matrix.json"
copy_config_file "$repo_root/layouts/main-plain.json" "$dest_root/layouts/main-plain.json"

printf '\nHerdr app theme files are in place. Changes apply while the app runs.\n'
printf 'Start the Herdr app, or switch to it, to see the Matrix theme.\n'
