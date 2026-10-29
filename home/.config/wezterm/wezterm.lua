local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 13.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
		opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)


-- Route inner-terminal navigation only when Herdr owns this local PTY.
-- Plain shells keep WezTerm's native tab, pane, search, and copy actions.
local act = wezterm.action
local function route_herdr(sequence, fallback)
	return wezterm.action_callback(function(window, pane)
		local process = pane:get_foreground_process_name() or ""
		local name = process:match("([^/\\]+)$") or process
		if name == "herdr" then
			window:perform_action(act.SendString("\x02" .. sequence), pane)
		else
			window:perform_action(fallback, pane)
		end
	end)
end

config.keys = {
	{ key = "Tab", mods = "CTRL", action = route_herdr("n", act.ActivateTabRelative(1)) },
	{ key = "Tab", mods = "CTRL|SHIFT", action = route_herdr("p", act.ActivateTabRelative(-1)) },
	{ key = "[", mods = "CMD|SHIFT", action = route_herdr("p", act.ActivateTabRelative(-1)) },
	{ key = "]", mods = "CMD|SHIFT", action = route_herdr("n", act.ActivateTabRelative(1)) },
	{ key = "LeftArrow", mods = "CMD|ALT", action = route_herdr("p", act.ActivateTabRelative(-1)) },
	{ key = "RightArrow", mods = "CMD|ALT", action = route_herdr("n", act.ActivateTabRelative(1)) },
	{ key = "LeftArrow", mods = "CTRL|SHIFT", action = route_herdr("h", act.ActivatePaneDirection("Left")) },
	{ key = "DownArrow", mods = "CTRL|SHIFT", action = route_herdr("j", act.ActivatePaneDirection("Down")) },
	{ key = "UpArrow", mods = "CTRL|SHIFT", action = route_herdr("k", act.ActivatePaneDirection("Up")) },
	{ key = "RightArrow", mods = "CTRL|SHIFT", action = route_herdr("l", act.ActivatePaneDirection("Right")) },
	{ key = "z", mods = "CTRL|SHIFT", action = route_herdr("z", act.TogglePaneZoomState) },
	{ key = "x", mods = "CTRL|SHIFT", action = route_herdr("y", act.ActivateCopyMode) },
	{ key = "f", mods = "CMD", action = route_herdr("y/", act.Search("CurrentSelectionOrEmptyString")) },
	{ key = "f", mods = "CTRL|SHIFT", action = route_herdr("y/", act.Search("CurrentSelectionOrEmptyString")) },
	{ key = "p", mods = "CTRL|SHIFT", action = route_herdr("g", act.ActivateCommandPalette) },
	-- HyperWhisper uses this globally to change mode while recording.
	-- Cmd+K remains available to clear WezTerm's scrollback deliberately.
	{ key = "k", mods = "CTRL|SHIFT", action = act.Nop },
}
for index = 1, 9 do
	table.insert(config.keys, {
		key = tostring(index),
		mods = "CMD",
		action = route_herdr(tostring(index), act.ActivateTab(index == 9 and -1 or index - 1)),
	})
end

return config
