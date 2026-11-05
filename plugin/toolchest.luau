local T = require("./lib/top.luau")
function update() T.draw("toolchest") end
noctalia.setUpdateInterval(60000)
update()
