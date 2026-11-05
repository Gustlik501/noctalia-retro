--!nonstrict
local R = require("./lib/retro.luau")
local W = require("./lib/workspaces.luau")
local colors = { "#4992A7", "#C6B2A8", "#BE9292", "#8998AA" }
-- State-watch callbacks in 5.4.1 carry no bar snapshot. Cache placement at load.
local outputName = barWidget.outputName() or ""
local function tile(content, click, tip)
  return R.bevel(content, 58, 66, "raised", nil, click, tip)
end
local function grip()
  local lines = {}
  for _ = 1, 15 do
    table.insert(lines, ui.box({ width = 8, height = 2, fill = R.surface }))
    table.insert(lines, ui.box({ width = 8, height = 1, fill = "#808080" }))
    table.insert(lines, ui.box({ width = 8, height = 1, fill = "#FFFFFF" }))
  end
  return R.bevel(ui.column({ gap = 0, width = 8, height = 60 }, lines), 12, 66, "raised")
end
local function launcher(name, title)
  local icon = noctalia.getConfig(name .. "_icon")
  local command = noctalia.getConfig(name .. "_command")
  local content = icon ~= "" and ui.image({ path = icon, width = 48, height = 48, fit = "contain", radius = 0 })
    or R.label(title, 10)
  return tile(content, function() R.command(command) end, title .. ": " .. command)
end
local function switcher()
  local output = outputName
  local ids, active = W.select(noctalia.state.get("workspaces"), output, noctalia.getConfig("workspace_ids"))
  local function cell(slot)
    local id = ids[slot]
    local click
    if id and string.match(output, "^[%w_%-]+$") then
      click = function()
        -- Focus the widget's monitor even if keyboard focus was on another output.
        local modern = 'dispatch hl.dsp.focus({monitor="' .. output .. '"}); dispatch hl.dsp.focus({workspace="' .. tostring(id) .. '"})'
        noctalia.runAsync({ "hyprctl", "--batch", modern }, function(result)
          local reply = string.lower(result.stdout or "")
          if result.exitCode ~= 0 or string.find(reply, "error", 1, true)
              or string.find(reply, "invalid", 1, true) or string.find(reply, "unknown", 1, true) then
            -- Legacy Hyprland (pre-0.57) dispatcher grammar.
            noctalia.runAsync({ "hyprctl", "--batch", "dispatch focusmonitor " .. output .. "; dispatch workspace " .. tostring(id) })
          end
        end)
      end
    end
    return R.bevel(R.label(id or "", 12, "bold", slot == 1 and id and "#FFFFFF" or "#000000"),
      90, 26, id and id == active and "sunken" or "raised", id and colors[slot] or R.surface, click)
  end
  local lock = R.bevel(ui.glyph({ name = "lock", size = 12, color = "#000000" }), 27, 26, "raised", nil,
    function() R.ipc("session", "lock") end, "Lock this session")
  local exit = R.bevel(R.label("EXIT", 8), 27, 26, "raised", nil, R.session, "Session menu (does not log out immediately)")
  return R.bevel(ui.column({ width = 213, height = 54, gap = 2 }, {
    ui.row({ gap = 3, height = 26 }, { cell(1), lock, cell(2) }),
    ui.row({ gap = 3, height = 26 }, { cell(3), exit, cell(4) }),
  }), 225, 66, "sunken")
end
local function render()
  local status = noctalia.state.get("status") or {}
  local clockIcon = noctalia.getConfig("clock_icon")
  local clock = clockIcon ~= "" and ui.column({ align = "center", gap = 1 }, {
    ui.image({ path = clockIcon, width = 48, height = 48, fit = "contain" }),
    R.label(noctalia.formatTime(noctalia.getConfig("clock_format")), 11),
  }) or ui.column({ align = "center", gap = 5 }, {
    R.label(noctalia.formatTime(noctalia.getConfig("clock_format")), 17), R.label("LOCAL", 9),
  })
  local days = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }
  local months = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
  local date = ui.column({ align = "center", gap = 0 }, {
    R.label(days[(tonumber(noctalia.formatTime("%w")) or 0) + 1], 10),
    R.label(noctalia.formatTime("%-d"), 22),
    R.label(months[tonumber(noctalia.formatTime("%m")) or 1], 10),
  })
  local meters = {}
  for _, metric in ipairs({ { "CPU", status.cpu }, { "MEM", status.mem } }) do
    table.insert(meters, ui.row({ gap = 4, align = "center" }, { R.label(metric[1], 9), R.meter(metric[2], 42) }))
  end
  barWidget.render(R.bevel(ui.row({ width = 836, height = 72, paddingH = 4, paddingV = 3,
    gap = 3, align = "center", fill = R.surface }, {
    grip(), tile(clock), tile(date), launcher("terminal", "Terminal"), launcher("files", "Files"),
    launcher("browser", "Browser"), switcher(), launcher("editor", "Editor"), launcher("settings", "Settings"),
    launcher("trash", "Trash"), R.bevel(ui.column({ align = "center", gap = 6 }, meters), 82, 66, "raised", nil, nil,
      status.cpu and string.format("CPU %.0f%% / MEM %.0f%%", status.cpu, status.mem or 0) or "System monitor unavailable"), grip(),
  }), 840, 76, "raised"))
end
noctalia.setUpdateInterval(1000)
R.watch("status", render)
R.watch("workspaces", render)
function update() render() end
function onIpc(event, _payload)
  if event == "diagnostics" then
    local ids, active = W.select(noctalia.state.get("workspaces"), barWidget.outputName() or "", noctalia.getConfig("workspace_ids"))
    noctalia.log("retro front diagnostics: " .. noctalia.json.encode({
      ids = ids, active = active,
      output = barWidget.outputName(), fixed = noctalia.getConfig("workspace_ids"),
      terminal = noctalia.getConfig("terminal_command"),
    }))
  end
end
update()
