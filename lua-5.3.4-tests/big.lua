-- $Id: big.lua,v 1.32 2016/11/07 13:11:28 roberto Exp $
-- See Copyright Notice in file all.lua

if _soft then
  return 'a'
end

print "testing large tables"

local debug = require"debug" 

local lim = 2^18 + 1000
local prog = { "local y = {0" }
for i = 0, lim-1 do prog[#prog] = i  end
prog[#prog] = "}\n"
prog[#prog] = "X = y\n"
prog[#prog] = ("assert(X[%d] == %d)"):format(lim - 1, lim - 2)
prog[#prog] = "return 0"
prog = table.concat(prog, ";")

local env = {string = string, assert = assert}
local f = assert(load(prog, nil, nil, env))

f()
assert(env.X[lim - 1] == lim - 2 and env.X[lim] == lim - 1)
for k in pairs(env) do env[k] = nil end

-- yields during accesses larger than K (in RK)
setmetatable(env, {
  __index = function (t, n) coroutine.yield('g'); return _G[n] end,
  __newindex = function (t, n, v) coroutine.yield('s'); _G[n] = v end,
})

X = nil
co = coroutine.wrap(f)
assert(co() == 's')
assert(co() == 'g')
assert(co() == 'g')
assert(co() == 0)

assert(X[lim - 1] == lim - 2 and X[lim] == lim - 1)

-- errors in accesses larger than K (in RK)
getmetatable(env).__index = function () end
getmetatable(env).__newindex = function () end
local e, m = pcall(f)
assert(not e and m:find("global 'X'"))

-- errors in metamethods 
getmetatable(env).__newindex = function () error("hi") end
local e, m = xpcall(f, debug.traceback)
assert(not e and m:find("'__newindex'"))

f, X = nil

coroutine.yield'b'

if 2^32 == 0 then   -- (small integers) {   

print "testing string length overflow"

local repstrings = 192          -- number of strings to be concatenated
local ssize = math.ceil(2.0^32 / repstrings) + 1   -- size of each string

assert(repstrings * ssize > 2.0^32)  -- it should be larger than maximum size

local longs = string.rep("\0", ssize)   -- create one long string

-- create function to concatentate 'repstrings' copies of its argument
local rep = assert(load(
  "local a = ...; return " .. string.rep("a", repstrings, "..")))

local a, b = pcall(rep, longs)   -- call that function

-- it should fail without creating string (result would be too large)
assert(not a and string.find(b, "overflow"))

end   -- }

print'OK'

return 'a'
