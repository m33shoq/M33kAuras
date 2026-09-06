-- Run from the repository root with Lua 5.1 or LuaJIT.
local function noop() end
M33kAuras = { IsLibsOK = function() return true end, L = {}, GetDataByUID = noop }
issecretvalue = function() return false end
local now = 0
GetTime = function() return now end
CreateFrame = function()
  return { SetScript = function(self, name, handler) self[name] = handler end }
end
local Private = {
  frames = {}, anim_function_strings = {},
  anim_ease_functions = { none = function(value) return value end },
  ParseNumber = tonumber, GetDataByUID = noop,
  StartProfileSystem = noop, StopProfileSystem = noop,
  StartProfileUID = noop, StopProfileUID = noop,
  ActivateAuraEnvironmentForRegion = noop, ActivateAuraEnvironment = noop,
}
assert(loadfile("M33kAuras/Animations.lua"))("M33kAuras", Private)
local frame = Private.frames["M33kAuras Animation Frame"]
local function tick(elapsed)
  now = now + elapsed
  assert(frame.OnUpdate, "updates must be active")
  frame.OnUpdate(frame, elapsed)
end
local function region()
  return {
    GetAlpha = function() return 1 end,
    GetWidth = function() return 100 end, GetHeight = function() return 100 end,
    SetOffsetAnim = noop, SetAnimAlpha = noop, SetWidth = noop, SetHeight = noop,
  }
end
local function animate(target, callback, loop)
  return Private.Animate("display", "uid", "main",
    { type = "custom", use_alpha = true, duration = 1 }, target, false, callback, loop)
end

assert(frame.OnUpdate == nil, "no handler before work is queued")
local positioned = 0
local group = { DoPositionChildren = function() positioned = positioned + 1 end }
Private.RegisterGroupForPositioning("group", group)
tick(0.1)
assert(positioned == 1 and frame.OnUpdate == nil, "group-only work stops when drained")

local target = region()
local finished = 0
now = 1000
assert(animate(target, function() finished = finished + 1 end))
tick(0.5)
assert(finished == 0 and frame.OnUpdate, "idle time does not advance a new animation")
tick(0.5)
assert(finished == 1 and frame.OnUpdate == nil, "completion stops idle updates")

assert(animate(target, function() Private.RegisterGroupForPositioning("group", group) end))
tick(1)
assert(frame.OnUpdate, "completion callback can queue group work")
tick(0.1)
assert(positioned == 2 and frame.OnUpdate == nil)

assert(animate(target, function() animate(target) end))
tick(1)
if frame.OnUpdate then tick(1) end
assert(frame.OnUpdate == nil, "callback animation completes and releases updates")

assert(animate(target, nil, true))
tick(1)
assert(frame.OnUpdate, "loop restart keeps updates active")
Private.CancelAnimation(target)
tick(0.1)
assert(frame.OnUpdate == nil, "cancellation stops updates on the next frame")

assert(animate(target))
Private.RegisterGroupForPositioning("cancel", {
  DoPositionChildren = function() Private.CancelAnimation(target) end,
})
tick(0.1)
assert(frame.OnUpdate == nil, "cancellation inside OnUpdate drains safely")
print("Animation lifecycle checks passed")
