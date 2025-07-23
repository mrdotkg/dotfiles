local wezterm = require 'wezterm'
local act = wezterm.action
local keybinds = require 'keybinds'
local utils = require 'utils'

local config = wezterm.config_builder()

-- ============================================================================
-- APPEARANCE & THEME
-- ============================================================================

-- Font Configuration
config.font = wezterm.font_with_fallback {
  { family = "Consolas", weight = "Medium" },
}
config.font_size = 12.0
config.line_height = 1.1
config.freetype_load_target = "HorizontalLcd"
config.freetype_render_target = "HorizontalLcd"

-- Color Scheme (Custom Nord Theme)
config.color_scheme_dirs = { wezterm.config_dir .. '/colors' }
config.color_scheme = "nordfox"

-- Window Appearance
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
config.window_background_opacity = 0.95
config.text_background_opacity = 1.0
config.window_close_confirmation = "AlwaysPrompt"

-- Cursor
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 800
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- ============================================================================
-- TABS & PANES
-- ============================================================================

-- Tab Bar
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = true
config.tab_max_width = 32

-- Tab Bar Colors (Nord Theme)
config.colors = {
  tab_bar = {
    background = "#2e3440",
    active_tab = {
      bg_color = "#81a1c1",
      fg_color = "#2e3440",
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = "#3b4252",
      fg_color = "#b9bfca",
    },
    inactive_tab_hover = {
      bg_color = "#434c5e",
      fg_color = "#e5e9f0",
    },
    new_tab = {
      bg_color = "#2e3440",
      fg_color = "#81a1c1",
    },
    new_tab_hover = {
      bg_color = "#3b4252",
      fg_color = "#e5e9f0",
    },
  },
}

-- Pane Borders
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.6 }

-- ============================================================================
-- KEYBINDINGS (Using modular keybinds.lua)
-- ============================================================================

-- Use the sophisticated keybinding system from keybinds.lua
config.keys = keybinds.create_keybinds()
config.key_tables = keybinds.key_tables

-- Mouse bindings from keybinds.lua
config.mouse_bindings = keybinds.mouse_bindings

-- ============================================================================
-- LAUNCH MENU & PROFILES
-- ============================================================================

config.launch_menu = {
  {
    label = "PowerShell Core",
    args = { "pwsh.exe", "-NoLogo" },
  },
  {
    label = "Windows PowerShell",
    args = { "powershell.exe", "-NoLogo" },
  },
  {
    label = "Command Prompt",
    args = { "cmd.exe" },
  },
  {
    label = "Git Bash",
    args = { "C:\\Program Files\\Git\\bin\\bash.exe", "-i", "-l" },
  },
  {
    label = "WSL Ubuntu",
    args = { "wsl.exe", "~" },
  },
}

-- Default shell
config.default_prog = { "pwsh.exe", "-NoLogo" }

-- ============================================================================
-- PERFORMANCE & BEHAVIOR
-- ============================================================================

config.scrollback_lines = 10000
config.enable_scroll_bar = true
config.check_for_updates = false
config.automatically_reload_config = true
config.exit_behavior = "Close"
config.window_close_confirmation = "AlwaysPrompt"

-- GPU and Performance
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.animation_fps = 60
config.max_fps = 60

-- ============================================================================
-- HYPERLINKS
-- ============================================================================

config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Add custom hyperlink rules for common file paths and URLs
table.insert(config.hyperlink_rules, {
  regex = [[["]?([\w\d]{1}[-\w\d]+)(/){1}([-\w\d\.]+)["]?]],
  format = "https://www.github.com/$1/$3",
})

-- ============================================================================
-- STARTUP
-- ============================================================================

-- Set working directory
config.default_cwd = wezterm.home_dir

-- Window startup position and size
config.initial_cols = 120
config.initial_rows = 35

-- ============================================================================
-- CUSTOM TAB TITLE
-- ============================================================================

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local title = tab.tab_title
  if title and #title > 0 then
    return title
  end
  
  local pane = tab.active_pane
  local process = string.gsub(pane.foreground_process_name, "(.*[/\\])(.*)", "%2")
  
  if process == "pwsh.exe" or process == "powershell.exe" then
    process = "PS"
  elseif process == "cmd.exe" then
    process = "CMD"
  elseif process == "bash.exe" then
    process = "BASH"
  end
  
  return string.format(" %s ", process)
end)

-- ============================================================================
-- EVENT HANDLERS (Enhanced with modular approach)
-- ============================================================================

-- Toggle between tmux keybinds and default keybinds
wezterm.on("toggle-tmux-keybinds", function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if overrides.keys then
    -- Switch back to default keybinds
    overrides.keys = nil
    overrides.key_tables = nil
    overrides.mouse_bindings = nil
  else
    -- Switch to tmux-style keybinds only
    overrides.keys = keybinds.tmux_keybinds
    overrides.key_tables = keybinds.key_tables
    overrides.mouse_bindings = keybinds.mouse_bindings
  end
  window:set_config_overrides(overrides)
end)

-- Trigger nvim with scrollback (from your on.lua)
wezterm.on("trigger-nvim-with-scrollback", function(window, pane)
  local scrollback = pane:get_lines_as_text(pane:get_dimensions().scrollback_rows)
  local name = os.tmpname()
  local f = io.open(name, "w+")
  f:write(scrollback)
  f:flush()
  f:close()
  window:perform_action(
    act.SpawnCommandInNewTab({
      args = { "nvim", name },
    }),
    pane
  )
  wezterm.sleep_ms(1000)
  os.remove(name)
end)

-- ============================================================================
-- STATUS LINE (Nord Theme)
-- ============================================================================

wezterm.on("update-right-status", function(window, pane)
  local date = wezterm.strftime "%H:%M %d/%m "
  local hostname = " " .. wezterm.hostname() .. " "
  
  window:set_right_status(wezterm.format {
    { Background = { Color = "#3b4252" } },
    { Foreground = { Color = "#b9bfca" } },
    { Text = hostname },
    { Background = { Color = "#81a1c1" } },
    { Foreground = { Color = "#2e3440" } },
    { Text = date },
  })
end)

return config
