--!nonstrict
-- One VM owns all polling and the event stream, independent of bar placements.
local status = {}
local busy = {}
local workspaces, monitors = {}, {}
local dirtyAt, nextWorkspace, nextStatus, nextBattery = 0, 0, 0, 0
local hyprland = noctalia.getenv("HYPRLAND_INSTANCE_SIGNATURE")
local runtime = noctalia.getenv("XDG_RUNTIME_DIR")
local function publish() noctalia.state.set("status", status) end
local function publishWorkspaces()
  noctalia.state.set("workspaces", { workspaces = workspaces, monitors = monitors })
end
local function query(key, argv, callback)
  if busy[key] then return end
  busy[key] = true
  local accepted = noctalia.runAsync(argv, function(result)
    busy[key] = nil
    callback(result.exitCode == 0 and result.stdout or nil)
  end)
  if not accepted then busy[key] = nil end
end
local function json(raw) return raw and noctalia.json.decode(raw) or nil end
local function refreshWorkspaces()
  if not hyprland or hyprland == "" then return end
  query("workspaces", { "hyprctl", "-j", "workspaces" }, function(raw)
    local data = json(raw)
    if type(data) == "table" then workspaces = data; publishWorkspaces() end
  end)
  query("monitors", { "hyprctl", "-j", "monitors" }, function(raw)
    local data = json(raw)
    if type(data) == "table" then monitors = data; publishWorkspaces() end
  end)
end
local function refreshStatus()
  local forced = noctalia.getConfig("network_interface")
  if forced ~= "" then status.net = forced end
  query("network", { "ip", "-j", "route", "show", "default" }, function(raw)
    local routes = json(raw)
    if forced == "" then
      local best
      for _, route in ipairs(type(routes) == "table" and routes or {}) do
        if route.dev and (not best or (route.metric or 0) < (best.metric or 0)) then best = route end
      end
      status.net = best and best.dev or "offline"
    end
    publish()
  end)
  query("bluetooth", { "bluetoothctl", "show" }, function(raw)
    status.bt = raw and (string.find(raw, "Powered: yes", 1, true) and "on" or "off") or "--"
    publish()
  end)
  query("volume", { "wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@" }, function(raw)
    local volume = raw and tonumber(string.match(raw, "Volume:%s*([%d%.]+)"))
    status.volume = volume and math.floor(volume * 100 + 0.5) or nil
    status.muted = raw ~= nil and string.find(raw, "[MUTED]", 1, true) ~= nil
    publish()
  end)
end
local function refreshBattery()
  -- Ignore mains adapters and peripheral batteries; present only system batteries.
  local names = noctalia.listDir("/sys/class/power_supply") or {}
  local paths = {}
  for _, name in ipairs(names) do
    local base = "/sys/class/power_supply/" .. name
    local kind = noctalia.readFile(base .. "/type")
    local scope = noctalia.readFile(base .. "/scope")
    if kind and string.match(kind, "^Battery") and not (scope and string.match(scope, "^Device")) then
      table.insert(paths, base)
    end
  end
  table.sort(paths)
  if #paths == 0 then status.battery = nil; publish(); return end
  -- First system battery; capacity is kernel-provided percentage, not energy units.
  noctalia.readFileAsync(paths[1] .. "/capacity", function(raw)
    status.battery = raw and tonumber(raw) or nil
    publish()
  end)
end

-- The shell expands only inherited compositor coordinates. No live socket fallback.
-- runStream is terminated by Noctalia on unload, including its process group.
if hyprland and hyprland ~= "" and runtime and runtime ~= "" and noctalia.commandExists("socat") then
  noctalia.runStream([[
while :; do
  socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null
  sleep 2
done
]], function(line)
    local event = string.match(line, "^([^>]+)>>") or ""
    if string.find(event, "workspace", 1, true) or string.find(event, "monitor", 1, true)
        or event == "focusedmon" then
      if dirtyAt == 0 then dirtyAt = noctalia.nowMs() end
    end
  end)
end
noctalia.setUpdateInterval(250)
function update()
  local now = noctalia.nowMs()
  if now >= nextWorkspace or (dirtyAt > 0 and now - dirtyAt >= 150) then
    nextWorkspace, dirtyAt = now + 5000, 0
    refreshWorkspaces()
  end
  if now >= nextStatus then
    nextStatus = now + noctalia.getConfig("status_poll_ms")
    refreshStatus()
  end
  if now >= nextBattery then nextBattery = now + 30000; refreshBattery() end
  local stats = noctalia.systemStats()
  if stats and stats.sampledAtMs ~= status.sampledAtMs then
    status.cpu = stats.cpu and stats.cpu.usagePercent
    status.mem = stats.ram and stats.ram.usagePercent
    status.sampledAtMs = stats.sampledAtMs
    publish()
  end
end
function onIpc(event, _payload)
  if event == "diagnostics" then
    noctalia.log("retro diagnostics: " .. noctalia.json.encode({
      status = status, workspaces = workspaces, monitors = monitors,
    }))
  end
end
update()
