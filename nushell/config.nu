$env.config = ($env.config
  | upsert shell_integration {
      osc2: true
      osc7: true
      osc8: true
      osc9_9: false
      osc133: ($nu.os-info.name != "windows")
      osc633: ($nu.os-info.name != "windows")
      reset_application_mode: true
    }
)

$env.config = ($env.config
  | upsert show_banner false
  | upsert edit_mode "emacs"
  | upsert history {
      max_size: 100_000
      sync_on_enter: true
      file_format: "sqlite"
      isolation: false
    }
  | upsert completions {
      case_sensitive: false
      quick: true
      partial: true
      algorithm: "fuzzy"
      external: {
        enable: true
        max_results: 50
      }
    }
)

def current-working-directory [] {
  $env.PWD | path expand | into string
}

def --wrapped wez [...args] {
  ^wezterm start --cwd (current-working-directory) ...$args
}

def --wrapped weztab [...args] {
  try {
    ^wezterm cli spawn --cwd (current-working-directory) ...$args
  } catch {
    ^wezterm start --cwd (current-working-directory) ...$args
  }
}

def --env mkcd [directory: string] {
  mkdir $directory
  cd $directory
}

alias l = ls
alias la = ls -a
alias ll = ls -la
alias dc = docker compose
