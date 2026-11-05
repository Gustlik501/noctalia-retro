local T = require("./lib/top.luau")
function update() T.draw("clock") end
noctalia.setUpdateInterval(1000)
update()
