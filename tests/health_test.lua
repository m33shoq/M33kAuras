-- Health amounts are display values, even when old saved filters are present.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")

local function read(path)
  local file = assert(io.open(T.repoRoot .. "/" .. path))
  local source = file:read("*a"):gsub("\r\n", "\n")
  file:close()
  return source
end
local function section(source, first, last)
  local from = assert(source:find(first, 1, true))
  return source:sub(from, assert(source:find(last, from, true)) - 1)
end
local function load(source, env)
  return setfenv(assert(loadstring(source)), env)()
end
local function contains(list, value)
  for _, item in ipairs(list) do if item == value then return true end end
  return false
end

-- Hostile values detect secret arithmetic and comparisons, not WoW taint.
local secret = newproxy(true)
for _, operation in ipairs({"__add", "__sub", "__mul", "__div", "__lt", "__le", "__eq", "__unm", "__concat", "__tostring"}) do
  getmetatable(secret)[operation] = function() error("Computed with secret health") end
end
local function issecretvalue(value)
  return type(value) == "userdata" and getmetatable(value) == getmetatable(secret)
end
local amounts, exists, watched, calls = {}, true, {}, {}
local function reset()
  amounts = {health = 40, maxhealth = 100, percenthealth = 40, deficit = 60}
  exists, calls = true, {}
end
reset()
local function api(name, ...)
  calls[name] = {...}
  return amounts[name]
end
local env = setmetatable({
  L = setmetatable({}, {__index = function(_, key) return key end}),
  constants = {nameRealmFilterDesc = ""},
  tinsert = table.insert, tconcat = table.concat,
  CurveConstants = {ScaleTo100 = {}},
  M33kAuras = {
    newFeatureString = "",
    IsRetail = function() return true end,
    IsForever = function() return true end,
    IsCataClassic = function() return false end,
    IsMists = function() return false end,
    IsCataOrMists = function() return false end,
    IsCataOrMistsOrRetail = function() return true end,
    IsClassicOrCataOrMists = function() return false end,
    IsWrathOrCataOrMistsOrRetail = function() return true end,
    UnitExistsFixed = function() return exists end,
    UnitNameWithRealm = function() return "Target", "Realm" end,
    UnitIsPet = function(unit) return unit:find("pet", 1, true) ~= nil end,
    WatchUnitChange = function(unit) watched[unit] = true end,
    WatchForPetDeath = function() watched.pet = true end,
    GetPlayerReaction = function() return 1 end,
    SpecForUnit = function() return 71 end,
    UnitRaidRole = function() return "NONE" end,
  },
  Private = {
    multiUnitUnits = {group = {player = true, party1 = true, partypet1 = true}},
    ExecEnv = {
      ParseNameCheck = function() return {Check = function() return true end} end,
      ParseStringCheck = function() return {Check = function() return true end} end,
    },
  },
  UnitHealth = function(...) return api("health", ...) end,
  UnitHealthMax = function(...) return api("maxhealth", ...) end,
  UnitHealthPercent = function(...) return api("percenthealth", ...) end,
  UnitHealthMissing = function(...) return api("deficit", ...) end,
  UnitGetTotalAbsorbs = function(...) return api("absorb", ...) end,
  UnitGetTotalHealAbsorbs = function(...) return api("healabsorb", ...) end,
  UnitClass = function() return "Warrior", "WARRIOR" end,
  UnitGUID = function() return nil end,
  UnitIsUnit = function(first, second) return first == second end,
  UnitIsDeadOrGhost = function() return false end,
  UnitIsConnected = function() return true end,
  UnitGroupRolesAssigned = function() return "DAMAGER" end,
  strsplit = function() return "" end,
  issecretvalue = issecretvalue,
  hasanysecretvalues = function(...)
    for i = 1, select("#", ...) do if issecretvalue(select(i, ...)) then return true end end
    return false
  end,
  -- WoW's xpcall passes arguments to the callback, unlike stock Lua 5.1.
  xpcall = function(callback, handler, ...)
    local args = {...}
    return xpcall(function() return callback(unpack(args)) end, handler)
  end,
}, {__index = _G})
local prototypes = read("M33kAuras/Prototypes.lua")
local generic = read("M33kAuras/GenericTrigger.lua")
local selected = load(section(prototypes, "local function AddUnitChangeInternalEvents", "Private.event_categories = {")
  .. "\nreturn {" .. section(prototypes, '  ["Health"] = {', '  ["Alternate Power"] = {') .. "}", env)
local prototype = selected.Health
local construct = load(section(generic, "function TestForTriState", "function Private.EndEvent")
  .. "\nreturn ConstructFunction", env)
local runOverlays = load(section(generic, "local function RunOverlayFuncs", "local function callFunctionForActivateEvent")
  .. "\nreturn RunOverlayFuncs", env)
local function trigger(options)
  options = options or {}
  options.unit = options.unit or "target"
  local fn = load(construct(prototype, options), env)
  return function(state, event, unit)
    return fn(state or {}, event or "UNIT_HEALTH", unit or options.unit)
  end
end

T.section("Health display values")
local track, state = trigger(), {}
T.expect(track(state) and state.value == 40 and state.total == 100 and state.progressType == "static",
  "tracks health and maximum health as static progress")
T.expect(state.health == 40 and state.maxhealth == 100 and state.percenthealth == 40 and state.deficit == 60,
  "stores every health display property")
T.expect(calls.health[1] == "target" and calls.health[2] == false
  and calls.maxhealth[1] == "target" and calls.percenthealth[2] == false
  and calls.percenthealth[3] == env.CurveConstants.ScaleTo100 and calls.deficit[2] == false,
  "queries matching current, percent, and missing health directly from the APIs")
T.expect(not calls.absorb and not calls.healabsorb, "disabled absorb overlays do not query optional health amounts")
state.changed = false
T.expect(track(state) and not state.changed, "unchanged readable values do not force a refresh")
for name in pairs(amounts) do amounts[name] = newproxy(secret) end
T.expect(track(state) and state.changed and rawequal(state.value, amounts.health)
  and rawequal(state.total, amounts.maxhealth), "secret values replace readable progress without inspection")
for name, value in pairs(amounts) do
  T.expect(rawequal(state[name], value), name .. ": passes secret values through for display")
end
state.changed = false
T.expect(track(state) and state.changed, "secret values refresh even when their identity is unchanged")
for name in pairs(amounts) do amounts[name] = newproxy(secret) end
T.expect(track(state) and rawequal(state.health, amounts.health), "new secret values replace earlier secret values")
local oldOptions = {use_showAbsorb = true, use_showHealAbsorb = true, use_showIncomingHeal = true}
amounts.absorb, amounts.healabsorb = newproxy(secret), newproxy(secret)
for _, name in ipairs({"health", "maxhealth", "percenthealth", "deficit", "absorb", "healabsorb"}) do
  oldOptions["use_" .. name], oldOptions[name], oldOptions[name .. "_operator"] = true, {999}, {">"}
end
T.expect(trigger(oldOptions)({}), "saved health comparisons and overlay selections cannot block a secret display")
reset()
for name in pairs(amounts) do amounts[name] = 0 end
T.expect(track(state) and state.value == 0 and state.total == 0 and state.maxhealth == 0
  and state.percenthealth == 0 and state.deficit == 0, "preserves zero values without clamping or division")
amounts, exists = {}, false
T.expect(not track(state), "missing units do not activate a health display")
reset()
T.expect(track(state, "UNIT_MAXHEALTH", "TARGET") and state.unit == "target",
  "normalizes unit tokens on maximum-health updates")

T.section("Absorb overlays")
local overlayFields = {
  {name = "absorb", toggle = "use_showAbsorb", mode = "absorbMode", event = "UNIT_ABSORB_AMOUNT_CHANGED"},
  {name = "healabsorb", toggle = "use_showHealAbsorb", mode = "absorbHealMode", event = "UNIT_HEAL_ABSORB_AMOUNT_CHANGED"},
}
for _, field in ipairs(overlayFields) do
  reset()
  for name in pairs(amounts) do amounts[name] = newproxy(secret) end
  amounts[field.name] = newproxy(secret)
  local options = {unit = "target", [field.toggle] = true}
  local withOverlay, overlayState = trigger(options), {}
  T.expect(withOverlay(overlayState, field.event) and rawequal(overlayState[field.name], amounts[field.name])
    and calls[field.name][1] == "target", field.name .. ": stores the secret API value when enabled")
  T.expect(not calls[field.name == "absorb" and "healabsorb" or "absorb"],
    field.name .. ": leaves the other optional API disabled")
  local event = {trigger = options, overlayFuncs = {}}
  for _, overlay in ipairs(prototype.overlayFuncs) do
    if overlay.enable(options) then event.overlayFuncs[#event.overlayFuncs + 1] = overlay.func end
  end
  T.expect(#event.overlayFuncs == 1, field.name .. ": enables only its selected overlay")
  local errors = {}
  local function evaluate()
    runOverlays(event, overlayState, "health", function(err) errors[#errors + 1] = err end)
    return overlayState.additionalProgress[1]
  end
  local additional = evaluate()
  T.expect(#errors == 0 and additional.direction == "forward" and rawequal(additional.width, amounts[field.name]),
    field.name .. ": default additionalProgress forwards secret width without health arithmetic")
  options[field.mode] = "OVERLAY_FROM_START"
  additional = evaluate()
  T.expect(#errors == 0 and additional.min == 0 and rawequal(additional.max, amounts[field.name])
    and additional.direction == nil and additional.width == nil,
    field.name .. ": start attachment forwards secret bounds and clears directional progress")
  options[field.mode] = "OVERLAY_FROM_END"
  amounts[field.name] = newproxy(secret)
  withOverlay(overlayState, field.event)
  additional = evaluate()
  T.expect(#errors == 0 and additional.direction == "forward" and rawequal(additional.width, amounts[field.name])
    and additional.min == nil and additional.max == nil,
    field.name .. ": end attachment refreshes secret width and clears bounds")
  amounts[field.name] = 0
  withOverlay(overlayState, field.event)
  additional = evaluate()
  T.expect(#errors == 0 and additional.width == 0, field.name .. ": empty absorbs preserve zero overlay width")
end
reset()

T.section("Display metadata and conditions")
env.GenericTrigger = {GetPrototype = function(options) return selected[options.event] end}
load(section(generic, "local function ProgressType", "---@type fun(data: auraData, triggernum: integer, state: state, eventData: table)")
  .. section(generic, "function GenericTrigger.GetAdditionalProperties", "function GenericTrigger.CreateFallbackState"), env)
local data = {triggers = {{trigger = {type = "unit", event = "Health", unit = "target"}}}}
local conditions = env.GenericTrigger.GetTriggerConditions(data, 1)
local properties = env.GenericTrigger.GetAdditionalProperties(data, 1)
local sources, progress = {}, {}
env.GenericTrigger.GetProgressSources(data, 1, sources)
for _, source in ipairs(sources) do progress[source.property] = source end
for _, name in ipairs({"health", "maxhealth", "percenthealth", "deficit"}) do
  T.expect(properties[name] and progress[name], name .. ": is available to text and progress displays")
  T.expect(not conditions[name], name .. ": cannot be selected for a condition comparison")
end
T.expect(not conditions.value and not conditions.total, "generic progress conditions cannot bypass health restrictions")
T.expect(progress.value and progress.value.total == "total" and progress.total,
  "retains standard current and total progress sources")
T.expect(state[progress.health.total] == state.maxhealth and state[progress.deficit.total] == state.maxhealth,
  "current and missing health use maximum health as their progress total")
T.expect(progress.percenthealth.total and state[progress.percenthealth.total] == 100,
  "percentage progress has a fixed total of 100")
T.expect(conditions.class and conditions.nameplateType, "retains usable unit metadata conditions")
T.expect(progress.health.useAdditionalProgress, "the Health progress source retains its absorb overlays")
T.expect(not properties.absorb and not properties.healabsorb and not progress.absorb and not progress.healabsorb,
  "disabled absorb sources are absent from display choices")
data.triggers[1].trigger.use_showAbsorb, data.triggers[1].trigger.use_showHealAbsorb = true, true
conditions = env.GenericTrigger.GetTriggerConditions(data, 1)
properties = env.GenericTrigger.GetAdditionalProperties(data, 1)
sources, progress = {}, {}
env.GenericTrigger.GetProgressSources(data, 1, sources)
for _, source in ipairs(sources) do progress[source.property] = source end
for _, field in ipairs(overlayFields) do
  T.expect(properties[field.name] and progress[field.name] and progress[field.name].total == "total",
    field.name .. ": enabled amount is available for text and progress displays")
  T.expect(not conditions[field.name], field.name .. ": cannot be selected for a condition comparison")
end
for _, option in ipairs(prototype.args) do
  if option.name == "health" or option.name == "maxhealth" or option.name == "percenthealth" or option.name == "deficit"
    or option.name == "absorb" or option.name == "healabsorb" then
    T.expect(option.hidden, option.name .. ": does not expose an amount filter in trigger options")
  end
end
data.triggers[1].trigger.event = "Power"
conditions, sources = env.GenericTrigger.GetTriggerConditions(data, 1), {}
env.GenericTrigger.GetProgressSources(data, 1, sources)
T.expect(conditions.value and conditions.total and conditions.power and conditions.percentpower,
  "Power retains its existing numeric condition choices")
progress = {}
for _, source in ipairs(sources) do progress[source.property] = source end
T.expect(progress.power and progress.power.total == "total" and progress.value,
  "Power retains its existing progress choices")

T.section("Unit refresh events")
local options = {unit = "target"}
local events = prototype.events(options)
for _, event in ipairs({"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE"}) do
  T.expect(contains(events.unit_events.target, event), "listens for " .. event)
end
for _, field in ipairs(overlayFields) do
  T.expect(not contains(events.unit_events.target, field.event), field.name .. ": skips disabled overlay events")
  local selectedEvents = prototype.events({unit = "target", [field.toggle] = true})
  T.expect(contains(selectedEvents.unit_events.target, field.event), field.name .. ": listens for enabled overlay updates")
end
T.expect(contains(prototype.internal_events(options), "UNIT_CHANGED_target"), "refreshes when the target changes")
local forced = prototype.force_events(options)
T.expect(#forced == 1 and forced[1][2] == "target", "seeds a unit evaluation when loaded")
prototype.loadFunc(options)
T.expect(watched.target, "watches the selected unit for changes")
options, watched = {unit = "group", use_includePets = true, includePets = "PetsOnly"}, {}
prototype.loadFunc(options)
T.expect(watched.partypet1 and not watched.player and not watched.party1, "pet-only groups watch pet units")
forced = prototype.force_events(options)
T.expect(#forced == 1 and forced[1][2] == "partypet1", "pet-only groups seed only pet units")
T.finish()
