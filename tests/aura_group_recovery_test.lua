-- Exercise group rebuff reminders through the real scanner and event handlers.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
local function noop() end
local function yes() return true end
local function no() return false end
local file = assert(io.open(T.repoRoot .. "/M33kAuras/Prototypes.lua"))
local prototypes = file:read("*a")
file:close()
local strings = assert(prototypes:match("Private.function_strings = (%b{})"))
local functionStrings = assert(loadstring("return " .. strings))()

local function newFixture(raid)
  local units, states, scans, data = {}, {}, {}, {}
  local first, second = raid and "raid1" or "player", raid and "raid2" or "party1"
  units[first] = { visible = true, spec = 71 }
  units[second] = { visible = true, spec = 72 }
  local private = {
    frames = {}, watched_trigger_events = {}, player_target_events = {},
    StartProfileSystem = noop, StopProfileSystem = noop,
    StartProfileAura = noop, StopProfileAura = noop, UpdatedTriggerState = noop,
    AuraWarnings = { UpdateWarning = noop },
    multiUnitUnits = { group = {}, party = {}, raid = {}, boss = {}, arena = {} },
    ExecEnv = {
      UnitName = function(unit) return unit end,
      UnitIsUnit = function(a, b) return a == b or (raid and a == "raid1" and b == "player") end,
      GetSpellName = function() return "Battle Shout" end,
      GetSpellInfo = function() return "Battle Shout", nil, 132333 end,
    },
    LibSpecWrapper = {
      Register = noop,
      -- Keep communicated specializations available for the entire wipe.
      SpecForUnit = function(unit) return units[unit] and units[unit].spec end,
    },
    ParseNumber = function(value) return tonumber(value:match("^(%d+)%%$")) / 100, "fraction" end,
    LoadFunction = function(source) return assert(loadstring(source))() end,
    function_strings = functionStrings,
  }
  local addon = {
    IsLibsOK = yes, IsRetail = yes, IsCataOrMistsOrRetail = yes,
    IsWrathOrCataOrMistsOrRetail = yes, IsClassicOrWrathOrCataOrMists = no,
    IsForever = no, IsPaused = no, IsUntrackableSoftTarget = no,
    L = setmetatable({}, { __index = function(_, key) return key end }),
    EJIcons = {}, timer = {},
    UnitIsPet = function(unit) return unit == "pet" or unit:find("pet") ~= nil end,
    raidUnits = {}, raidpetUnits = {}, partyUnits = {}, partypetUnits = {},
    unitToPetUnit = { player = "pet" }, petUnitToUnit = { pet = "player" },
    GetTriggerStateForTrigger = function(id)
      states[id] = states[id] or {}
      return states[id]
    end,
    GetData = function(id) return data[id] end,
  }
  private.multiUnitUnits.group.player, private.multiUnitUnits.group.pet = true, true
  private.multiUnitUnits.party.player, private.multiUnitUnits.party.pet = true, true
  for _, kind in ipairs({ "raid", "party" }) do
    for i = 1, kind == "raid" and 40 or 4 do
      local unit, pet = kind .. i, kind .. "pet" .. i
      addon[kind .. "Units"][i], addon[kind .. "petUnits"][i] = unit, pet
      addon.unitToPetUnit[unit], addon.petUnitToUnit[pet] = pet, unit
      private.multiUnitUnits[kind][unit], private.multiUnitUnits[kind][pet] = true, true
      private.multiUnitUnits.group[unit], private.multiUnitUnits.group[pet] = true, true
    end
  end
  local env = setmetatable({
    M33kAuras = addon,
    GetTime = function() return 100 end,
    IsInRaid = function() return raid end,
    GetNumGroupMembers = function() return 2 end,
    GetNumSubgroupMembers = function() return 1 end,
    UnitExists = function(unit) return units[unit] ~= nil end,
    UnitGUID = function(unit) return units[unit] and unit end,
    UnitIsVisible = function(unit) return units[unit] and units[unit].visible or false end,
    UnitIsDeadOrGhost = function(unit) return units[unit] and units[unit].dead or false end,
    UnitIsConnected = function(unit) return units[unit] and not units[unit].disconnected end,
    issecretvalue = no, hasanysecretvalues = no,
    wipe = function(t)
      for key in pairs(t) do t[key] = nil end
      return t
    end,
    tinsert = table.insert, tremove = table.remove,
    tContains = function(t, value) for _, v in ipairs(t) do if v == value then return true end end end,
    GetTexCoordsByGrid = noop, CreateTextureMarkup = noop,
    C_Secrets = { ShouldAurasBeSecret = no },
    Enum = { AddOnRestrictionState = { Inactive = 0 } },
    AuraUtil = {
      ForEachAura = function(unit, filter, _, callback)
        scans[unit] = (scans[unit] or 0) + 1
        if filter == "HELPFUL" and units[unit] and units[unit].buff then
          callback({ name = "Battle Shout", spellId = 6673, auraInstanceID = 1,
            icon = 132333, applications = 0, duration = 0, expirationTime = 0, timeMod = 1 })
        end
      end,
    },
    CreateFrame = function()
      return {
        events = {}, scripts = {},
        RegisterEvent = function(self, event) self.events[event] = true end,
        UnregisterEvent = noop,
        SetScript = function(self, event, handler) self.scripts[event] = handler end,
      }
    end,
  }, { __index = _G })
  local triggerSystem
  addon.RegisterTriggerSystem = function(_, system) triggerSystem = system end
  local chunk = assert(loadfile(T.repoRoot .. "/M33kAuras/BuffTrigger2.lua"))
  setfenv(chunk, env)("M33kAuras", private)
  local frame = private.frames["M33kAuras Buff2 Frame"]
  local function update() frame.scripts.OnUpdate() end
  local function event(name, ...)
    if frame.events[name] then frame.scripts.OnEvent(frame, name, ...) end
    update()
  end
  local function load()
    triggerSystem.LoadDisplays({ Rebuff = true })
    update()
  end
  data.Rebuff = { id = "Rebuff", uid = "Rebuff", triggers = {{ trigger = {
    type = "aura2", unit = "group", debuffType = "HELPFUL",
    useExactSpellId = true, auraspellids = { "6673" },
    useGroup_count = true, group_countOperator = "<", group_count = "100%",
    ignoreDead = true, ignoreDisconnected = true, ignoreInvisible = true,
    useActualSpec = true, actualSpec = { [71] = true, [72] = true },
  } }} }
  triggerSystem.Add(data.Rebuff)
  return {
    units = units, first = first, second = second, event = event, load = load, scans = scans,
    unload = function() triggerSystem.UnloadDisplays({ Rebuff = true }) end,
    state = function(id)
      id = id or "Rebuff"
      return states[id] and states[id][""]
    end,
    loadTarget = function()
      data.Target = { id = "Target", uid = "Target", triggers = {{ trigger = {
        type = "aura2", unit = "target", debuffType = "HELPFUL",
        useExactSpellId = true, auraspellids = { "6673" },
      } }} }
      triggerSystem.Add(data.Target)
      triggerSystem.LoadDisplays({ Target = true })
      update()
    end,
  }
end

for _, raid in ipairs({ false, true }) do
  local mode = raid and "Raid" or "Party"
  T.section(mode .. ": release and return with unchanged specializations")
  local f = newFixture(raid)
  f.units[f.first].buff, f.units[f.second].buff = true, true
  f.load()
  T.expect(not f.state() or not f.state().show, "fully buffed group hides the reminder")
  -- Alive-only loading unloads the aura when the player dies.
  f.unload()
  for _, unit in pairs(f.units) do unit.dead, unit.buff, unit.visible = true, false, false end
  f.event("PARTY_MEMBER_DISABLE", f.first)
  f.event("PARTY_MEMBER_DISABLE", f.second)
  f.event("UNIT_AURA", f.first)
  f.event("UNIT_AURA", f.second)
  -- On returning through the instance portal, the aura can load before Buff2's event.
  for _, unit in pairs(f.units) do unit.dead, unit.visible = false, true end
  f.load()
  f.event("PLAYER_ENTERING_WORLD")
  local state = f.state()
  T.expect(state and state.show and state.unitCount == 0 and state.maxUnitCount == 2,
    "returning after release shows 0 / 2 without a roster or enable event")
  f.units[f.first].buff = true
  f.event("UNIT_AURA", f.first)
  state = f.state()
  T.expect(state and state.show and state.unitCount == 1 and state.maxUnitCount == 2,
    "rebuffing one returned member updates the count to 1 / 2")
  f.units[f.second].buff = true
  f.event("UNIT_AURA", f.second)
  T.expect(f.state() and not f.state().show, "rebuffing everyone hides the reminder")

  f = newFixture(raid)
  f.units[f.first].visible, f.units[f.second].visible = false, false
  f.load()
  f.unload()
  f.units[f.first].visible, f.units[f.second].visible = true, true
  f.event("PLAYER_ENTERING_WORLD")
  f.load()
  T.expect(f.state() and f.state().show and f.state().maxUnitCount == 2,
    "visibility also recovers when Buff2 handles world entry before the aura loads")

  f = newFixture(raid)
  f.units[f.first].buff, f.units[f.second].visible = true, false
  f.load()
  f.units[f.second].visible = true
  f.event("READY_CHECK", "Leader", 35)
  T.expect(f.state() and f.state().show and f.state().unitCount == 1 and f.state().maxUnitCount == 2,
    "a ready check clears stale visibility and restores the rebuff reminder")

  T.section(mode .. ": UNIT_FLAGS already handles alive changes")
  f = newFixture(raid)
  f.units[f.first].buff, f.units[f.second].dead = true, true
  f.load()
  f.units[f.second].dead = false
  f.event("UNIT_FLAGS", f.second)
  T.expect(f.state() and f.state().show and f.state().maxUnitCount == 2,
    "UNIT_FLAGS includes a member who becomes alive without a local player event")
  f.units[f.second].visible = false
  f.event("PARTY_MEMBER_DISABLE", f.second)
  f.units[f.second].visible = true
  f.event("UNIT_FLAGS", f.second)
  T.expect(not f.state().show, "UNIT_FLAGS alone does not invalidate cached invisibility")
  f.event("READY_CHECK", "Leader", 35)
  T.expect(f.state().show and f.state().unitCount == 1 and f.state().maxUnitCount == 2,
    "ready check restores the member excluded by stale visibility despite UNIT_FLAGS")

  T.section(mode .. ": local recovery events, ready checks, and stale buff data")
  for _, event in ipairs({ "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD", "READY_CHECK" }) do
    f = newFixture(raid)
    f.units[f.first].buff, f.units[f.second].buff = true, true
    f.load()
    f.units[f.second].buff = false
    f.event(event)
    state = f.state()
    T.expect(state and state.show and state.unitCount == 1 and state.maxUnitCount == 2,
      event .. " refreshes buff data even without UNIT_AURA")

    f = newFixture(raid)
    f.units[f.first].buff, f.units[f.second].dead = true, true
    f.load()
    f.units[f.second].dead = false
    f.event(event)
    state = f.state()
    T.expect(state and state.show and state.unitCount == 1 and state.maxUnitCount == 2,
      event .. " rebuilds the group count including members who are alive again")
    f.event(event)
    T.expect(f.state() and f.state().maxUnitCount == 2,
      "repeated " .. event .. " does not double count members")
  end

  T.section(mode .. ": recovery preserves filters and individual unit scans")
  for _, excluded in ipairs({ "dead", "invisible", "disconnected", "wrong spec", "absent" }) do
    f = newFixture(raid)
    f.load()
    if excluded == "dead" then f.units[f.second].dead = true
    elseif excluded == "invisible" then f.units[f.second].visible = false
    elseif excluded == "disconnected" then f.units[f.second].disconnected = true
    elseif excluded == "wrong spec" then f.units[f.second].spec = 65
    else f.units[f.second] = nil end
    f.event("PLAYER_ENTERING_WORLD")
    state = f.state()
    T.expect(state and state.show and state.unitCount == 0 and state.maxUnitCount == 1,
      "returning still excludes a member who is " .. excluded)
  end

  f = newFixture(raid)
  f.units.target = { visible = true, buff = true }
  f.load()
  f.loadTarget()
  T.expect(f.state("Target") and f.state("Target").show, "individual target aura initially matches")
  local scansBefore = f.scans[f.first]
  f.units.target.buff = false
  f.event("PLAYER_ENTERING_WORLD")
  T.expect(not f.state("Target").show, "world entry still refreshes individual target buffs")
  T.expect(f.scans[f.first] - scansBefore == 1, "world entry scans each tracked group member only once")
  f.units.target.buff = true
  f.event("UNIT_AURA", "target")
  f.units.target = nil
  f.event("PLAYER_ENTERING_WORLD")
  T.expect(not f.state("Target").show, "world entry still cleans up a vanished target")
end

T.finish()
