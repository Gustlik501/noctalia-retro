local W = require("../plugin/lib/workspaces")
local snapshot = {
  monitors = { { name = "A", activeWorkspace = { id = 3 } }, { name = "B", activeWorkspace = { id = 6 } } },
  workspaces = {
    { id = 4, monitor = "A" }, { id = 1, monitor = "A" }, { id = 3, monitor = "A" },
    { id = 2, monitor = "A" }, { id = 5, monitor = "A" }, { id = -99, monitor = "A" },
    { id = 6, monitor = "B" },
  },
}
local ids, active = W.select(snapshot, "A", {})
assert(table.concat(ids, ",") == "1,2,3,4" and active == 3)
ids, active = W.select(snapshot, "B", {})
assert(#ids == 1 and ids[1] == 6 and active == 6)
ids, active = W.select(snapshot, "A", { A = "7, 3, nope, -1, 2.5, 7, 9, 8, 10" })
assert(table.concat(ids, ",") == "7,3,9,8" and active == 3)
ids = W.select(nil, "gone", {})
assert(#ids == 0)
print("monitor filtering, ordering, fixed IDs, missing and special workspaces: OK")
