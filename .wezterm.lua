-- Pull in the WezTerm API
local wezterm = require 'wezterm'
local act = wezterm.action

local target = wezterm.target_triple
local is_windows = target:find('windows') ~= nil
local is_macos = target:find('apple%-darwin') ~= nil

local function executable_exists(path)
  local check_command

  if is_windows then
    check_command = { 'cmd.exe', '/c', 'if exist "' .. path .. '" echo 1' }
  else
    check_command = { 'sh', '-lc', 'if [ -x "' .. path .. '" ]; then printf 1; fi' }
  end

  local success, stdout, _ = wezterm.run_child_process(check_command)
  return success and stdout:gsub('%s+', '') == '1'
end

local function command_exists(command)
  local check_command

  if is_windows then
    check_command = { 'cmd.exe', '/c', 'where ' .. command .. ' >nul 2>nul && echo 1' }
  else
    check_command = { 'sh', '-lc', 'if command -v ' .. command .. ' >/dev/null 2>&1; then printf 1; fi' }
  end

  local success, stdout, _ = wezterm.run_child_process(check_command)
  return success and stdout:gsub('%s+', '') == '1'
end

local function find_nu()
  if command_exists('nu') then
    return 'nu'
  end

  if is_macos then
    local macos_candidates = {
      '/opt/homebrew/bin/nu',
      '/usr/local/bin/nu',
    }

    for _, path in ipairs(macos_candidates) do
      if executable_exists(path) then
        return path
      end
    end
  end

  return nil
end

local function default_shell()
  local nu_path = find_nu()

  if nu_path ~= nil then
    return { nu_path }
  end

  if is_windows then
    return { 'pwsh.exe', '-NoLogo' }
  end

  if is_macos then
    return { 'zsh', '-l' }
  end

  return nil
end

-- ============================================================================
-- WINDOW POSITIONING (Center on startup)
-- ============================================================================
wezterm.on('gui-startup', function(cmd)
  -- Spawn the main window
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  local gui_window = window:gui_window()
  
  -- Grab the active screen's dimensions and the window's pixel dimensions
  local screen = wezterm.gui.screens().active
  local dimensions = gui_window:get_dimensions()

  -- Calculate the exact center coordinates
  local center_x = (screen.width - dimensions.pixel_width) / 2
  local center_y = (screen.height - dimensions.pixel_height) / 2

  -- Move the window to the center
  gui_window:set_position(center_x, center_y)
end)

-- ============================================================================
-- STATUS BAR INDICATOR
-- ============================================================================
wezterm.on('update-right-status', function(window, pane)
  local leader = ""
  
  -- If the leader key is active, change the string
  if window:leader_is_active() then
    leader = " [LEADER] "
  end

  -- Format the text and display it on the right side of the tab bar
  window:set_right_status(wezterm.format({
    { Attribute = { Intensity = "Bold" } },
    { Foreground = { Color = "#00FF41" } }, -- Vibrant Matrix green
    { Text = leader },
  }))
end)

-- This table holds the configuration
local config = wezterm.config_builder()

-- ============================================================================
-- 1. OS & Environment
-- ============================================================================
local shell = default_shell()

if shell ~= nil then
  config.default_prog = shell
end

-- ============================================================================
-- 2. Look & Feel
-- ============================================================================
-- Custom High-Contrast Matrix Theme
config.colors = {
  foreground = '#00ff41', -- Vibrant glowing Matrix green
  background = '#000000', -- Pure pitch black
  
  -- Make the cursor pop
  cursor_bg = '#00ff41',
  cursor_fg = '#000000',
  cursor_border = '#00ff41',

  -- Highlighted text settings
  selection_fg = '#000000',
  selection_bg = '#00ff41',
}

-- Increased font size for better readability
config.font = wezterm.font('JetBrains Mono')
config.font_size = 15.0

-- Medium-Large initial window size
config.initial_cols = 120
config.initial_rows = 35

-- ============================================================================
-- 3. UI Elements
-- ============================================================================
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false 

-- Borderless/integrated title bar look
if is_windows then
  config.window_decorations = "RESIZE"
elseif is_macos then
  config.window_decorations = "RESIZE|INTEGRATED_BUTTONS"
else
  config.window_decorations = "RESIZE"
end

-- ============================================================================
-- 4. Multiplexing & Keybindings
-- ============================================================================
-- Set a "Leader" key (like tmux). We'll use Ctrl+A. 
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {
  -- PANE NAVIGATION (Arrow Keys)
  { key = 'UpArrow', mods = 'LEADER', action = act.ActivatePaneDirection('Up') },
  { key = 'DownArrow', mods = 'LEADER', action = act.ActivatePaneDirection('Down') },
  { key = 'LeftArrow', mods = 'LEADER', action = act.ActivatePaneDirection('Left') },
  { key = 'RightArrow', mods = 'LEADER', action = act.ActivatePaneDirection('Right') },

  -- PANE SPLITTING (Simple keys, no Shift required)
  -- Split Top: Leader, then 'w'
  {
    key = 'w',
    mods = 'LEADER',
    action = act.SplitPane {
      direction = 'Up',
      size = { Percent = 50 },
    },
  },
  -- Split Right: Leader, then 'd'
  {
    key = 'd',
    mods = 'LEADER',
    action = act.SplitPane {
      direction = 'Right',
      size = { Percent = 50 },
    },
  },

  -- CLOSE PANE
  -- Close current pane: Leader, then 'x'
  {
    key = 'x',
    mods = 'LEADER',
    action = act.CloseCurrentPane { confirm = true },
  },
}

return config
