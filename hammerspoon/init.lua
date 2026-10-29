-- Hammerspoon config.
--
-- Source of truth: dotfiles repo, hammerspoon/init.lua; ~/.hammerspoon/init.lua is a symlink to
-- it (see install.sh, macOS only).
--
-- The "needs you" popup for Claude Code is the NeedsYou Spoon from the needs-you plugin
-- (fjrevoredo/agent-skills). /needs-you:setup copies it to ~/.hammerspoon/Spoons/.

hs.autoLaunch(true)
require("hs.ipc") -- lets the `hs` CLI talk to Hammerspoon (`hs -c '…'`)

hs.loadSpoon("NeedsYou"):start()
