# Keep env.nu minimal; shared interactive behavior belongs in config.nu.
if ($nu.os-info.name == "windows") {
  let home_bin = $"($nu.home-dir)\\bin"
  if $home_bin not-in $env.PATH {
    $env.PATH = ($env.PATH | append $home_bin)
  }
} else {
  let path_blacklist = ["node_modules", "starship"]
  
  # 1. Locate Zsh
  let zsh_cmd = (["/bin/zsh", "/usr/bin/zsh"] | where { |it| $it | path exists } | first | default "zsh")

  if ($zsh_cmd | path exists) or (which zsh | is-not-empty) {
    # 2. Get the Zsh path
    # We stringify $env.PATH here to ensure the subshell gets a clean string
    let current_path_str = ($env.PATH | flatten | str join (char esep))
    
    let zsh_raw = (with-env { PATH: $"/usr/bin:/bin:/opt/homebrew/bin:($current_path_str)" } {
      ^$zsh_cmd -ic 'echo "BEG_PATH"; echo $PATH; echo "END_PATH"' | complete
    }).stdout

    let zsh_path_str = ($zsh_raw 
      | lines 
      | skip until { |it| $it == "BEG_PATH" } 
      | skip 1 
      | take until { |it| $it == "END_PATH" }
      | first
      | default "")

    if ($zsh_path_str | is-not-empty) {
      # 3. ATOMIC RESET (The Book Method)
      # We combine the Zsh string and the current PATH into one giant string.
      # This forces any nested lists (like your Index 10) to be stringified and re-parsed.
      let combined_raw = ([$zsh_path_str, $current_path_str] | str join (char esep))
      
      $env.PATH = ($combined_raw 
        | split row (char esep)             # Split by ':'
        | where {|p| $p | is-not-empty}     # Remove empty artifacts
        | uniq                              # Remove duplicates
        | where {|path|                     # Apply blacklist
            $path_blacklist | all {|term| $path !~ $term}
          }
      )
    }
  }

  # 4. Final Overrides
  for dir in [ $"($nu.home-dir)/.local/bin" $"($nu.home-dir)/bin" ] {
    if ($dir | path exists) and ($dir not-in $env.PATH) {
       $env.PATH = ($env.PATH | append $dir)
    }
  }
}