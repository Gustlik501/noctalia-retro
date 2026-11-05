--!nonstrict
-- Original Workstation '95 primitives. Containers, never ui.box, own children.
local R = { surface = "#C0C0C0", green = "#20C040", blue = "#2040C0" }

function R.label(text, size, weight, color)
  return ui.label({ text = tostring(text), fontFamily = noctalia.getConfig("font_family"),
    fontSize = size or 12, fontWeight = weight or "bold", color = color or "#000000",
    baseline = "inkCentered", textAlign = "center" })
end

-- Exact 1px outer and inner bevels, including their corner intersections.
function R.bevel(content, width, height, mode, fill, click, tooltip)
  local tl, br = { "#FFFFFF", "#DFDFDF" }, { "#000000", "#808080" }
  if mode == "sunken" or mode == "well" then
    tl, br = { "#808080", "#000000" }, { "#FFFFFF", "#DFDFDF" }
  end
  local count = mode == "well" and 1 or 2
  local node = ui.column({ width = width - count * 2, height = height - count * 2,
    fill = fill or R.surface, align = "center", justify = "center", radius = 0 }, { content })
  for i = count, 1, -1 do
    local inset = (i - 1) * 2
    local w, h = width - inset, height - inset
    node = ui.column({ width = w, height = h, gap = 0 }, {
      ui.box({ width = w, height = 1, fill = tl[i] }),
      ui.row({ width = w, height = h - 2, gap = 0 }, {
        ui.box({ width = 1, height = h - 2, fill = tl[i] }), node,
        ui.box({ width = 1, height = h - 2, fill = br[i] }),
      }),
      ui.box({ width = w, height = 1, fill = br[i] }),
    })
  end
  return ui.column({ width = width, height = height, gap = 0, radius = 0,
    onClick = click, tooltip = tooltip }, { node })
end

function R.meter(value, width)
  return R.bevel(ui.progress({ progress = math.clamp((value or 0) / 100, 0, 1),
    fill = R.blue, track = R.green, radius = 0, width = width - 2, height = 8 }), width, 10, "well")
end

function R.ipc(...)
  local args = { "noctalia", "msg" }
  for _, arg in ipairs({ ... }) do table.insert(args, arg) end
  noctalia.runAsync(args, function(result)
    if result.exitCode ~= 0 then noctalia.log("IPC failed: " .. result.stderr) end
  end)
end

function R.command(command)
  -- Launcher commands are deliberately trusted shell commands, not interpolated data.
  if command ~= "" then noctalia.runAsync({ "sh", "-c", command }) end
end

function R.session() R.ipc("panel-toggle", "session") end
function R.tab(name) R.ipc("panel-toggle", "control-center", name) end

function R.watch(key, render)
  noctalia.state.watch(key, function(_) render() end)
end

return R
