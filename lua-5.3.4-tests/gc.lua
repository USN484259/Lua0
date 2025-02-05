-- $Id: gc.lua,v 1.72 2016/11/07 13:11:28 roberto Exp $
-- See Copyright Notice in file all.lua

print('testing garbage collection')

local debug = require"debug"

collectgarbage()

assert(collectgarbage("isrunning"))

local function gcinfo () return collectgarbage"count" * 1024 end


-- test weird parameters
do
  -- save original parameters
  local a = collectgarbage("setpause", 200)
  local b = collectgarbage("setstepmul", 200)
  local t = {0, 2, 10, 90, 500, 5000, 30000, 0x7ffffffe}
  for i = 0, #t-1 do
    local p = t[i]
    for j = 0, #t-1 do
      local m = t[j]
      collectgarbage("setpause", p)
      collectgarbage("setstepmul", m)
      collectgarbage("step", 0)
      collectgarbage("step", 10000)
    end
  end
  -- restore original parameters
  collectgarbage("setpause", a)
  collectgarbage("setstepmul", b)
  collectgarbage()
end


_G["while"] = 234

limit = 5000


local function GC1 ()
  local u
  local b     -- must be declared after 'u' (to be above it in the stack)
  local finish = false
  u = setmetatable({}, {__gc = function () finish = true end})
  b = {34}
  repeat u = {} until finish
  assert(b[0] == 34)   -- 'u' was collected, but 'b' was not

  finish = false; local i = 1
  u = setmetatable({}, {__gc = function () finish = true end})
  repeat i = i + 1; u = tostring(i) .. tostring(i) until finish
  assert(b[0] == 34)   -- 'u' was collected, but 'b' was not

  finish = false
  u = setmetatable({}, {__gc = function () finish = true end})
  repeat local i; u = function () return i end until finish
  assert(b[0] == 34)   -- 'u' was collected, but 'b' was not
end

local function GC2 ()
  local u
  local finish = false
  u = {setmetatable({}, {__gc = function () finish = true end})}
  b = {34}
  repeat u = {{}} until finish
  assert(b[0] == 34)   -- 'u' was collected, but 'b' was not

  finish = false; local i = 1
  u = {setmetatable({}, {__gc = function () finish = true end})}
  repeat i = i + 1; u = {tostring(i) .. tostring(i)} until finish
  assert(b[0] == 34)   -- 'u' was collected, but 'b' was not

  finish = false
  u = {setmetatable({}, {__gc = function () finish = true end})}
  repeat local i; u = {function () return i end} until finish
  assert(b[0] == 34)   -- 'u' was collected, but 'b' was not
end

local function GC()  GC1(); GC2() end


contCreate = 0

print('tables')
while contCreate <= limit do
  local a = {}; a = nil
  contCreate = contCreate+1
end

a = "a"

contCreate = 0
print('strings')
while contCreate <= limit do
  a = contCreate .. "b";
  a = string.gsub(a, '(%d%d*)', string.upper)
  a = "a"
  contCreate = contCreate+1
end


contCreate = 0

a = {}

print('functions')
function a:test ()
  while contCreate <= limit do
    load(string.format("function temp(a) return 'a%d' end", contCreate), "")()
    assert(temp() == string.format('a%d', contCreate))
    contCreate = contCreate+1
  end
end

a:test()

-- collection of functions without locals, globals, etc.
do local f = function () end end


print("functions with errors")
prog = [[
do
  a = 10;
  function foo(x,y)
    a = sin(a+0.456-0.23e-12);
    return function (z) return sin(%x+z) end
  end
  local x = function (w) a=a+w; end
end
]]
do
  local step = 1
  if _soft then step = 13 end
  for i=0, string.len(prog)-1, step do
    for j=i+1, string.len(prog), step do
      pcall(load(string.sub(prog, i, j), ""))
    end
  end
end

foo = nil
print('long strings')
x = "01234567890123456789012345678901234567890123456789012345678901234567890123456789"
assert(string.len(x)==80)
s = ''
n = 0
k = math.min(300, (math.maxinteger // 80) // 2)
while n < k do s = s..x; n=n+1; j=tostring(n)  end
assert(string.len(s) == k*80)
s = string.sub(s, 0, 10000)
s, i = string.gsub(s, '(%d%d%d%d)', '')
assert(i==10000 // 4)
s = nil
x = nil

assert(_G["while"] == 234)


print("steps")

print("steps (2)")

local function dosteps (siz)
  assert(not collectgarbage("isrunning"))
  collectgarbage()
  assert(not collectgarbage("isrunning"))
  local a = {}
  for i=1,100 do a[i] = {{}}; local b = {} end
  local x = gcinfo()
  local i = 0
  repeat   -- do steps until it completes a collection cycle
    i = i+1
  until collectgarbage("step", siz)
  assert(gcinfo() < x)
  return i
end

collectgarbage"stop"

if not _port then
  -- test the "size" of basic GC steps (whatever they mean...)
  assert(dosteps(0) > 10)
  assert(dosteps(10) < dosteps(2))
end

-- collector should do a full collection with so many steps
assert(dosteps(20000) == 1)
assert(collectgarbage("step", 20000) == true)
assert(collectgarbage("step", 20000) == true)

assert(not collectgarbage("isrunning"))
collectgarbage"restart"
assert(collectgarbage("isrunning"))


if not _port then
  -- test the pace of the collector
  collectgarbage(); collectgarbage()
  local x = gcinfo()
  collectgarbage"stop"
  assert(not collectgarbage("isrunning"))
  repeat
    local a = {}
  until gcinfo() > 3 * x
  collectgarbage"restart"
  assert(collectgarbage("isrunning"))
  repeat
    local a = {}
  until gcinfo() <= x * 2
end


print("clearing tables")
lim = 15
a = {}
-- fill a with `collectable' indices
for i=0,lim-1 do a[{}] = i end
b = {}
for k,v in pairs(a) do b[k]=v end
-- remove all indices and collect them
for n in pairs(b) do
  a[n] = nil
  assert(type(n) == 'table' and next(n) == nil)
  collectgarbage()
end
b = nil
collectgarbage()
for n in pairs(a) do error'cannot be here' end
for i=0,lim-1 do a[i] = i end
for i=0,lim-1 do assert(a[i] == i) end


print('weak tables')
a = {}; setmetatable(a, {__mode = 'k'});
-- fill a with some `collectable' indices
for i=0,lim-1 do a[{}] = i end
-- and some non-collectable ones
for i=0,lim-1 do a[i] = i end
for i=0,lim-1 do local s=string.rep('@', i); a[s] = s..'#' end
collectgarbage()
local i = 0
for k,v in pairs(a) do assert(k==v or k..'#'==v); i=i+1 end
assert(i == 2*lim)

a = {}; setmetatable(a, {__mode = 'v'});
a[0] = string.rep('b', 21)
collectgarbage()
assert(a[0])   -- strings are *values*
a[0] = nil
-- fill a with some `collectable' values (in both parts of the table)
for i=0,lim-1 do a[i] = {} end
for i=0,lim-1 do a[i..'x'] = {} end
-- and some non-collectable ones
for i=0,lim-1 do local t={}; a[t]=t end
for i=0,lim-1 do a[i+lim]=i..'x' end
collectgarbage()
local i = 0
for k,v in pairs(a) do assert(k==v or k-lim..'x' == v); i=i+1 end
assert(i == 2*lim)

a = {}; setmetatable(a, {__mode = 'vk'});
local x, y, z = {}, {}, {}
-- keep only some items
a[0], a[1], a[2] = x, y, z
a[string.rep('$', 11)] = string.rep('$', 11)
-- fill a with some `collectable' values
for i=3,lim-1 do a[i] = {} end
for i=0,lim-1 do a[{}] = i end
for i=0,lim-1 do local t={}; a[t]=t end
collectgarbage()
assert(next(a) ~= nil)
local i = 0
for k,v in pairs(a) do
  assert((k == 0 and v == x) or
         (k == 1 and v == y) or
         (k == 2 and v == z) or k==v);
  i = i+1
end
assert(i == 4)
x,y,z=nil
collectgarbage()
assert(next(a) == string.rep('$', 11))


-- 'bug' in 5.1
a = {}
local t = {x = 10}
local C = setmetatable({key = t}, {__mode = 'v'})
local C1 = setmetatable({[t] = 1}, {__mode = 'k'})
a.x = t  -- this should not prevent 't' from being removed from
         -- weak table 'C' by the time 'a' is finalized

setmetatable(a, {__gc = function (u)
                          assert(C.key == nil)
                          assert(type(next(C1)) == 'table')
                          end})

a, t = nil
collectgarbage()
collectgarbage()
assert(next(C) == nil and next(C1) == nil)
C, C1 = nil


-- ephemerons
local mt = {__mode = 'k'}
a = {{10},{20},{30},{40}}; setmetatable(a, mt)
x = nil
for i = 1, 100 do local n = {}; a[n] = {k = {x}}; x = n end
GC()
local n = x
local i = 0
while n do n = a[n].k[0]; i = i + 1 end
assert(i == 100)
x = nil
GC()
for i = 0, 3 do assert(a[i][0] == (i+1) * 10); a[i] = nil end
assert(next(a) == nil)

local K = {}
a[K] = {}
for i=0,10-1 do a[K][i] = {}; a[a[K][i]] = setmetatable({}, mt) end
x = nil
local k = 0
for j = 1,100 do
  local n = {}; local nk = (k+1)%10
  a[a[K][nk]][n] = {x, k = k}; x = n; k = nk
end
GC()
local n = x
local i = 0
while n do local t = a[a[K][k]][n]; n = t[0]; k = t.k; i = i + 1 end
assert(i == 100)
K = nil
GC()
-- assert(next(a) == nil)


-- testing errors during GC
do
collectgarbage("stop")   -- stop collection
local u = {}
local s = {}; setmetatable(s, {__mode = 'k'})
setmetatable(u, {__gc = function (o)
  local i = s[o]
  s[i] = true
  assert(not s[i - 1])   -- check proper finalization order
  if i == 8 then error("here") end   -- error during GC
end})

for i = 5, 10-1 do
  local n = setmetatable({}, getmetatable(u))
  s[n] = i
end

assert(not pcall(collectgarbage))
for i = 8, 10-1 do assert(s[i]) end

for i = 0, 5-1 do
  local n = setmetatable({}, getmetatable(u))
  s[n] = i
end

collectgarbage()
for i = 0, 10-1 do assert(s[i]) end

getmetatable(u).__gc = false


-- __gc errors with non-string messages
setmetatable({}, {__gc = function () error{} end})
local a, b = pcall(collectgarbage)
assert(not a and type(b) == "string" and string.find(b, "error in __gc"))

end
print '+'


-- testing userdata
if T==nil then
  (Message or print)('\n >>> testC not active: skipping userdata GC tests <<<\n')

else

  local function newproxy(u)
    return debug.setmetatable(T.newuserdata(0), debug.getmetatable(u))
  end

  collectgarbage("stop")   -- stop collection
  local u = newproxy(nil)
  debug.setmetatable(u, {__gc = true})
  local s = 0
  local a = {[u] = 0}; setmetatable(a, {__mode = 'vk'})
  for i=0,10-1 do a[newproxy(u)] = i end
  for k in pairs(a) do assert(getmetatable(k) == getmetatable(u)) end
  local a1 = {}; for k,v in pairs(a) do a1[k] = v end
  for k,v in pairs(a1) do a[v] = k end
  for i =0,10-1 do assert(a[i]) end
  getmetatable(u).a = a1
  getmetatable(u).u = u
  do
    local u = u
    getmetatable(u).__gc = function (o)
      assert(a[o] == 10-s)
      assert(a[10-s] == nil) -- udata already removed from weak table
      assert(getmetatable(o) == getmetatable(u))
    assert(getmetatable(o).a[o] == 10-s)
      s=s+1
    end
  end
  a1, u = nil
  assert(next(a) ~= nil)
  collectgarbage()
  assert(s==11)
  collectgarbage()
  assert(next(a) == nil)  -- finalized keys are removed in two cycles
end


-- __gc x weak tables
local u = setmetatable({}, {__gc = true})
-- __gc metamethod should be collected before running
setmetatable(getmetatable(u), {__mode = "v"})
getmetatable(u).__gc = function (o) os.exit(1) end  -- cannot happen
u = nil
collectgarbage()

local u = setmetatable({}, {__gc = true})
local m = getmetatable(u)
m.x = {[{0}] = 1; [0] = {1}}; setmetatable(m.x, {__mode = "kv"});
m.__gc = function (o)
  assert(next(getmetatable(o).x) == nil)
  m = 10
end
u, m = nil
collectgarbage()
assert(m==10)


-- errors during collection
u = setmetatable({}, {__gc = function () error "!!!" end})
u = nil
assert(not pcall(collectgarbage))


if not _soft then
  print("deep structures")
  local a = {}
  for i = 1,200000 do
    a = {next = a}
  end
  collectgarbage()
end

-- create many threads with self-references and open upvalues
print("self-referenced threads")
local thread_id = 0
local threads = {}

local function fn (thread)
    local x = {}
    threads[thread_id] = function()
                             thread = x
                         end
    coroutine.yield()
end

while thread_id < 1000 do
    local thread = coroutine.create(fn)
    coroutine.resume(thread, thread)
    thread_id = thread_id + 1
end


-- Create a closure (function inside 'f') with an upvalue ('param') that
-- points (through a table) to the closure itself and to the thread
-- ('co' and the initial value of 'param') where closure is running.
-- Then, assert that table (and therefore everything else) will be
-- collected.
do
  local collected = false   -- to detect collection
  collectgarbage(); collectgarbage("stop")
  do
    local function f (param) 
      ;(function ()
        assert(type(f) == 'function' and type(param) == 'thread')
        param = {param, f}
        setmetatable(param, {__gc = function () collected = true end})
        coroutine.yield(100)
      end)()
    end
    local co = coroutine.create(f)
    assert(coroutine.resume(co, co))
  end
  -- Now, thread and closure are not reacheable any more;
  -- two collections are needed to break cycle
  collectgarbage()
  assert(not collected)
  collectgarbage()
  assert(collected)
  collectgarbage("restart")
end


do
  collectgarbage()
  collectgarbage"stop"
  local x = gcinfo()
  repeat
    for i=1,1000 do _ENV.a = {} end
    collectgarbage("step", 0)   -- steps should not unblock the collector
  until gcinfo() > 2 * x
  collectgarbage"restart"
end


if T then   -- tests for weird cases collecting upvalues

  local function foo ()
    local a = {x = 20}
    coroutine.yield(function () return a.x end)  -- will run collector
    assert(a.x == 20)   -- 'a' is 'ok'
    a = {x = 30}   -- create a new object
    assert(T.gccolor(a) == "white")   -- of course it is new...
    coroutine.yield(100)   -- 'a' is still local to this thread
  end

  local t = setmetatable({}, {__mode = "kv"})
  collectgarbage(); collectgarbage('stop')
  -- create coroutine in a weak table, so it will never be marked
  t.co = coroutine.wrap(foo)
  local f = t.co()   -- create function to access local 'a'
  T.gcstate("atomic")   -- ensure all objects are traversed
  assert(T.gcstate() == "atomic")
  assert(t.co() == 100)   -- resume coroutine, creating new table for 'a'
  assert(T.gccolor(t.co) == "white")  -- thread was not traversed
  T.gcstate("pause")   -- collect thread, but should mark 'a' before that
  assert(t.co == nil and f() == 30)   -- ensure correct access to 'a'

  collectgarbage("restart")

  -- test barrier in sweep phase (advance cleaning of upvalue to white)
  local u = T.newuserdata(0)   -- create a userdata
  collectgarbage()
  collectgarbage"stop"
  T.gcstate"atomic"
  T.gcstate"sweepallgc"
  local x = {}
  assert(T.gccolor(u) == "black")   -- upvalue is "old" (black)
  assert(T.gccolor(x) == "white")   -- table is "new" (white)
  debug.setuservalue(u, x)          -- trigger barrier
  assert(T.gccolor(u) == "white")   -- upvalue changed to white
  collectgarbage"restart"

  print"+"
end


if T then
  local debug = require "debug"
  collectgarbage("stop")
  local x = T.newuserdata(0)
  local y = T.newuserdata(0)
  debug.setmetatable(y, {__gc = true})   -- bless the new udata before...
  debug.setmetatable(x, {__gc = true})   -- ...the old one
  assert(T.gccolor(y) == "white")
  T.checkmemory()
  collectgarbage("restart")
end


if T then
  print("emergency collections")
  collectgarbage()
  collectgarbage()
  T.totalmem(T.totalmem() + 200)
  for i=1,200 do local a = {} end
  T.totalmem(0)
  collectgarbage()
  local t = T.totalmem("table")
  local a = {{}, {}, {}}   -- create 4 new tables
  assert(T.totalmem("table") == t + 4)
  t = T.totalmem("function")
  a = function () end   -- create 1 new closure
  assert(T.totalmem("function") == t + 1)
  t = T.totalmem("thread")
  a = coroutine.create(function () end)   -- create 1 new coroutine
  assert(T.totalmem("thread") == t + 1)
end

-- create an object to be collected when state is closed
do
  local setmetatable,assert,type,print,getmetatable =
        setmetatable,assert,type,print,getmetatable
  local tt = {}
  tt.__gc = function (o)
    assert(getmetatable(o) == tt)
    -- create new objects during GC
    local a = 'xuxu'..(10+3)..'joao', {}
    ___Glob = o  -- ressurect object!
    setmetatable({}, tt)  -- creates a new one with same metatable
    print(">>> closing state " .. "<<<\n")
  end
  local u = setmetatable({}, tt)
  ___Glob = {u}   -- avoid object being collected before program end
end

-- create several objects to raise errors when collected while closing state
do
  local mt = {__gc = function (o) return o + 1 end}
  for i = 1,10 do
    -- create object and preserve it until the end
    table.insert(___Glob, setmetatable({}, mt))
  end
end

-- just to make sure
assert(collectgarbage'isrunning')

print('OK')
