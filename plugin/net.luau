local T = require("./lib/top.luau")
function update() T.draw("net") end
noctalia.state.watch("status", function(_) update() end)
noctalia.setUpdateInterval(60000)
update()
