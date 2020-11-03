luax = require('luax')
luax.run_luax()
--[==[luax

---[[
luax.text\{
  \luax.math{C_{a_i}^j = 8}
}
--]]

--[[
context.starttext()
context.startimath()
context("C_")
context("{a_i}")
context("^")
context("j=5")
context.stopimath()
context.stoptext()
--]]

]==]
