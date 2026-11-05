--!nonstrict
local R = require("./retro.luau")
local T = {}
function T.draw(kind)
  local state = noctalia.state.get("status") or {}
  local content, width, mode, click = nil, 60, "sunken", nil
  if kind == "toolchest" then
    content, width, mode, click = R.label("Toolchest"), 86, "raised", R.session
  elseif kind == "clock" then
    content, width = R.label(noctalia.formatTime(noctalia.getConfig("clock_format"))), 62
  elseif kind == "net" then
    local interface = state.net or "--"
    content = ui.row({ gap = 6, align = "center" }, { R.label("NET", 10), R.label(interface, 12, "normal") })
    width, click = math.max(90, 46 + #interface * 7), function() R.tab("network") end
  elseif kind == "bt" then
    content = ui.row({ gap = 6, align = "center" }, { R.label("BT", 10), R.label(state.bt or "--", 12, "normal") })
    width, click = 64, function() R.tab("bluetooth") end
  elseif kind == "vol" then
    local text = state.volume ~= nil and (tostring(state.volume) .. "%") or "--"
    if state.muted then text = "mute" end
    content = ui.row({ gap = 6, align = "center" }, { R.label("VOL", 10),
      R.meter(state.muted and 0 or state.volume, 54), R.label(text, 12, "normal") })
    width, click = 144, function() R.tab("audio") end
  elseif kind == "bat" then
    barWidget.setVisible(state.battery ~= nil)
    if state.battery == nil then return end
    content, width = R.label("BAT " .. tostring(state.battery) .. "%", 12), 84
    click = function() R.tab("system") end
  end
  barWidget.render(R.bevel(content, width, 22, mode, R.surface, click))
end
return T
