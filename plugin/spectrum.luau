--!nonstrict
local R = require("./lib/retro.luau")
local levels, lastFrame = {}, 0
local enabled = noctalia.getConfig("audio_spectrum")
noctalia.setUpdateInterval(250)
local function render()
  local bars = {}
  for i = 1, 16 do
    local h = math.clamp(math.floor((levels[i] or 0) * 14), 1, 14)
    table.insert(bars, ui.column({ width = 6, height = 14, justify = "end" }, {
      ui.box({ width = 6, height = h, fill = R.green }),
    }))
  end
  barWidget.render(R.bevel(ui.row({ gap = 1, align = "end", width = 111, height = 14 }, bars),
    118, 22, "sunken", "#000000"))
end
function onAudioSpectrum(valuesCsv, stateCsv)
  if not enabled then return end
  if string.sub(stateCsv or "", 1, 1) == "0" then
    levels, lastFrame = {}, noctalia.nowMs()
    render()
    return
  end
  -- Host sends normalized 0..1 CSV; reduce contiguous bins to sixteen peaks.
  local bins = {}
  for v in string.gmatch(valuesCsv, "[^,]+") do table.insert(bins, tonumber(v) or 0) end
  for i = 1, 16 do
    local peak = 0
    local first = math.floor((i - 1) * #bins / 16) + 1
    local last = math.max(first, math.floor(i * #bins / 16))
    for j = first, last do peak = math.max(peak, bins[j] or 0) end
    levels[i] = math.clamp(peak, 0, 1)
  end
  lastFrame = noctalia.nowMs()
  render()
end
function update()
  if noctalia.nowMs() - lastFrame > 1000 then levels = {} end
  render()
end
update()
