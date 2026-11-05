--!nonstrict
local W = {}
function W.select(snapshot, output, fixed)
  local ids, active = {}, nil
  snapshot = snapshot or {}
  for _, monitor in ipairs(snapshot.monitors or {}) do
    if monitor.name == output then active = monitor.activeWorkspace and monitor.activeWorkspace.id end
  end
  local seen = {}
  local list = fixed and fixed[output]
  if list and list ~= "" then
    for token in string.gmatch(list, "[^,%s]+") do
      local id = tonumber(token)
      if id and id > 0 and id == math.floor(id) and not seen[id] and #ids < 4 then
        table.insert(ids, id); seen[id] = true
      end
    end
  else
    for _, workspace in ipairs(snapshot.workspaces or {}) do
      if workspace.monitor == output and workspace.id > 0 and not seen[workspace.id] then
        table.insert(ids, workspace.id); seen[workspace.id] = true
      end
    end
    table.sort(ids)
    while #ids > 4 do table.remove(ids) end
  end
  return ids, active
end
return W
