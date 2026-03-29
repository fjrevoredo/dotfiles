# Keep env.nu minimal; shared interactive behavior belongs in config.nu.
if ($nu.os-info.name == "windows") {
  let home_bin = $"($nu.home-dir)\\bin"
  if $home_bin not-in $env.PATH {
    $env.PATH = ($env.PATH | append $home_bin)
  }
} else {
  for dir in [ $"($nu.home-dir)/.local/bin" $"($nu.home-dir)/bin" ] {
    if $dir not-in $env.PATH {
      $env.PATH = ($env.PATH | append $dir)
    }
  }
}
