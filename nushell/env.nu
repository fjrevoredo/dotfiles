# Keep env.nu minimal; shared interactive behavior belongs in config.nu.
def get_zsh_path_with_nvm [zsh_cmd: string, current_path_str: string] {
  # Ask Zsh to load nvm, activate the default alias, and print its PATH.
  let nvm_setup = 'export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"; for nvm_sh in "$NVM_DIR/nvm.sh" "/opt/homebrew/opt/nvm/nvm.sh" "/usr/local/opt/nvm/nvm.sh" "$HOME/.linuxbrew/opt/nvm/nvm.sh" "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh"; do if [ -s "$nvm_sh" ]; then . "$nvm_sh"; nvm use --silent default >/dev/null 2>&1; break; fi; done'

  (with-env { PATH: $"/usr/bin:/bin:/opt/homebrew/bin:($current_path_str)" } {
    ^$zsh_cmd -ic $"($nvm_setup); echo \"BEG_PATH\"; echo $PATH; echo \"END_PATH\"" | complete
  }).stdout
}

if ($nu.os-info.name == "windows") {
  let home_bin = $"($nu.home-dir)\\bin"
  if $home_bin not-in $env.PATH {
    $env.PATH = ($env.PATH | append $home_bin)
  }
} else {
  let path_blacklist = ["node_modules", "starship"]
  
  # Find a usable Zsh so we can reuse its PATH and shell startup behavior.
  let zsh_cmd = (["/bin/zsh", "/usr/bin/zsh"] | where { |it| $it | path exists } | first | default "zsh")

  if ($zsh_cmd | path exists) or (which zsh | is-not-empty) {
    # Serialize Nushell's PATH so the shell subprocess gets one clean string.
    let current_path_str = ($env.PATH | flatten | str join (char esep))

    # Extract only the PATH payload from the sentinel-wrapped Zsh output.
    let zsh_path_str = (get_zsh_path_with_nvm $zsh_cmd $current_path_str
      | lines 
      | skip until { |it| $it == "BEG_PATH" } 
      | skip 1 
      | take until { |it| $it == "END_PATH" }
      | first
      | default "")

    if ($zsh_path_str | is-not-empty) {
      # Merge the Zsh snapshot with Nushell's current PATH, then normalize it.
      let combined_raw = ([$zsh_path_str, $current_path_str] | str join (char esep))
      
      $env.PATH = ($combined_raw 
        | split row (char esep)
        | where {|p| $p | is-not-empty}
        | uniq
        | where {|path|
            $path_blacklist | all {|term| $path !~ $term}
          }
      )
    }
  }

  # Keep user-local bin directories available even after the PATH merge.
  for dir in [ $"($nu.home-dir)/.local/bin" $"($nu.home-dir)/bin" ] {
    if ($dir | path exists) and ($dir not-in $env.PATH) {
       $env.PATH = ($env.PATH | append $dir)
    }
  }
}