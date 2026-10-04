-- Exercise the real cooldown tracker and event handler with readable/secret data.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
local file = assert(io.open(T.repoRoot .. "/M33kAuras/GenericTrigger.lua"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local first = assert(source:find("-- CD/Rune/GCD support code", 1, true))
local last = assert(source:find("-- Swing timer support code", first, true))
local trackerSource = source:sub(first, last - 1)
local function noop() end
local secret = newproxy(true)
local function forbidden() error("Arithmetic or comparison on secret cooldown") end
for _, key in ipairs({"__add", "__sub", "__mul", "__div", "__lt", "__le", "__eq"}) do
  getmetatable(secret)[key] = forbidden
end
local function issecret(value) return rawequal(value, secret) end
local function hassecret(...)
  for i = 1, select("#", ...) do if issecret(select(i, ...)) then return true end end
  return false
end

local function fixture()
  local f = {now = 100, spells = {}, overrides = {}, events = {}, timers = {}, reads = {}, items = 0}
  local function info(id)
    f.reads[id] = (f.reads[id] or 0) + 1
    local spell = f.spells[id]
    return spell and spell.info
  end
  local function frame()
    return {RegisterEvent = noop, RegisterUnitEvent = noop,
      SetScript = function(self, name, fn) self[name] = fn end,
      Show = function(self) self.shown = true end,
      Hide = function(self) self.shown = false end}
  end
  local wa = {IsRetail = function() return true end, IsForever = function() return false end,
    IsTWW = function() return true end, IsWrathOrCata = function() return false end,
    IsClassicOrWrath = function() return false end,
    IsWrathOrCataOrMistsOrRetail = function() return true end,
    IsPaused = function() return f.paused end, IsSpellKnownIncludingPet = function() return true end}
  local private = {frames = {}, callbacks = {RegisterCallback = noop}, ExecEnv = {},
    StartProfileSystem = noop, StopProfileSystem = noop, ScanEvents = noop}
  private.ExecEnv.GetSpellInfo = function(id) return id, nil, id, nil, nil, nil, id end
  private.ExecEnv.GetSpellName = function(id) return id end
  private.ScanEventsByID = function(event, id, ...)
    local charges = wa.GetSpellCharges(id, true)
    table.insert(f.events, {event = event, id = id, charges = charges, ready = wa.IsSpellReady(id)})
  end
  local env = setmetatable({M33kAuras = wa, Private = private, CreateFrame = frame,
    GetTime = function() return f.now end, issecretvalue = issecret, hasanysecretvalues = hassecret,
    Constants = {SpellCooldownConsts = {GLOBAL_RECOVERY_CATEGORY = 133}},
    abs = math.abs, C_Secrets = {ShouldSpellCooldownBeSecret = function(id)
      return id == 61304 or id == 29515 or (f.spells[id] and f.spells[id].secret) or false
    end},
    C_Spell = {GetSpellCooldown = info,
      GetSpellCharges = function(id) return f.spells[id] and f.spells[id].charges end,
      GetSpellCastCount = function(id) return f.spells[id] and f.spells[id].count or 0 end,
      GetOverrideSpell = function(id) return f.overrides[id] or id end},
    C_Container = {GetItemCooldown = function() f.items = f.items + 1; return 0, 0, true end},
    timer = {ScheduleTimerFixed = function(_, fn, delay, ...)
      local task = {fn = fn, args = {...}, delay = delay}
      table.insert(f.timers, task)
      return task
    end, CancelTimer = function(_, task) task.cancelled = true end},
  }, {__index = _G})
  setfenv(assert(loadstring(trackerSource)), env)()
  f.wa, f.private, f.env = wa, private, env
  function f:add(id, restricted, active)
    self.spells[id] = {secret = restricted, info = {
      isActive = active, isEnabled = true, isOnGCD = false,
      startTime = restricted and secret or (active and self.now or 0),
      duration = restricted and secret or (active and 10 or 0), modRate = restricted and secret or 1,
    }}
  end
  function f:watch(id, follow, exact)
    self.wa.WatchSpellCooldown(id, false, exact ~= false, follow)
    self.frame = self.private.frames["Cooldown Trigger Handler"]
  end
  function f:send(event, ...)
    self.frame:HandleEvent(event, ...)
  end
  function f:count(event, id)
    local count = 0
    for _, entry in ipairs(self.events) do
      if entry.event == event and (not id or entry.id == id) then count = count + 1 end
    end
    return count
  end
  function f:reset() self.events, self.reads = {}, {} end
  return f
end

T.section("Subscriptions and event routing")
local f = fixture()
f:add(10, true, true)
f.spells[10].charges = {currentCharges = 1, maxCharges = 2, cooldownStartTime = secret,
  cooldownDuration = secret, chargeModRate = secret}
f:watch(10)
T.expect(f.wa.GetSpellCharges(10) == 1, "registers and initializes a spell while its cooldown is secret")
f:reset()
f:send("SPELL_UPDATE_COOLDOWN", 10)
T.expect(f:count("SPELL_COOLDOWN_CHANGED", 10) == 1, "secret spell gets one post-refresh notification")
f:send("SPELL_UPDATE_COOLDOWN")
T.expect(f:count("SPELL_COOLDOWN_CHANGED", 10) == 2, "full refresh includes secret subscriptions")
f:add(10, false, false)
f:send("WA_SECRET_STATE_UPDATE")
T.expect(f.wa.GetSpellCooldown(10) == 0, "subscription survives restrictions ending")
f:watch(10)
f:reset()
f:send("SPELL_UPDATE_COOLDOWN", 10)
T.expect(f:count("SPELL_COOLDOWN_CHANGED", 10) == 0, "repeat watch does not force unchanged numeric updates")

for _, restricted in ipairs({false, true}) do
  f = fixture()
  f:add(20, restricted, true)
  f:add(21, restricted, true)
  f.overrides[20] = 21
  f:watch(20, true)
  f:watch(21, false)
  f:reset()
  if not restricted then f.spells[21].info.duration = 12 end
  f:send("SPELL_UPDATE_COOLDOWN", 20)
  T.expect(f:count("SPELL_COOLDOWN_CHANGED", 20) == 1 and f:count("SPELL_COOLDOWN_CHANGED", 21) == 1,
    "base event reaches effective spell and subscribers, restricted=" .. tostring(restricted))
  f:reset()
  if not restricted then f.spells[21].info.duration = 15 end
  f:send("SPELL_UPDATE_COOLDOWN", 99, 20)
  T.expect(f:count("SPELL_COOLDOWN_CHANGED", 20) == 1 and f:count("SPELL_COOLDOWN_CHANGED", 21) == 1,
    "previous override event reaches current subscription through base ID")
  f:add(22, restricted, true)
  f.overrides[20] = 22
  f:send("SPELLS_CHANGED")
  T.expect(f:count("SPELL_CHARGES_CHANGED", 20) == 0, "remapping without a readable charge delta emits no charge event")
  f:reset()
  if not restricted then f.spells[22].info.duration = 20 end
  f:send("SPELL_UPDATE_COOLDOWN", 22, 20)
  T.expect(f:count("SPELL_COOLDOWN_CHANGED", 20) == 1, "remapped subscriber receives new override event")
end

T.section("Refresh ordering and broad updates")
f = fixture()
f:add(30, true, true)
f:add(31, true, true)
f:watch(30)
f:watch(31)
f.wa.WatchItemCooldown(1000)
f.spells[30].charges = {currentCharges = 2, maxCharges = 3, cooldownStartTime = secret,
  cooldownDuration = secret, chargeModRate = secret}
f:reset()
f:send("SPELL_UPDATE_COOLDOWN", 30)
T.expect(f:count("SPELL_COOLDOWN_CHANGED", 30) == 1, "charge and timing refreshes coalesce")
for _, event in ipairs(f.events) do
  if event.event == "SPELL_COOLDOWN_CHANGED" then
    T.expect(event.charges == 2, "notification observes refreshed charges")
  end
end
f:reset()
local items = f.items
f:send("ACTIONBAR_UPDATE_COOLDOWN")
f:send("SPELL_UPDATE_COOLDOWN", 30)
T.expect(f.frame.shown, "targeted update preserves pending broad refresh")
f.frame:OnUpdate(0.016)
T.expect(f:count("SPELL_COOLDOWN_CHANGED", 31) == 1 and f.items > items,
  "pending broad refresh still updates other spells and items")
T.expect(not f.frame.shown, "completed broad refresh stops OnUpdate")
f:send("ACTIONBAR_UPDATE_COOLDOWN")
f:send("SPELL_UPDATE_COOLDOWN")
T.expect(not f.frame.shown, "full spell update satisfies pending broad refresh")
f:reset()
f.paused = true
f:send("SPELL_UPDATE_COOLDOWN", 30)
T.expect(#f.events == 0, "secret refresh respects addon pause")

T.section("Readiness and transitions")
f = fixture()
f:add(40, true, true)
f:watch(40)
T.expect(f.wa.IsSpellReady(40) == nil, "initial active secret cooldown has unknown readiness")
f:send("SPELL_UPDATE_COOLDOWN", 40)
T.expect(f.wa.IsSpellReady(40) == false, "active non-GCD cooldown is not ready")
T.expect(f:count("SPELL_COOLDOWN_READY", 40) == 0, "initial not-ready observation is not a ready event")
f.spells[40].info.isOnGCD = true
f:send("SPELL_UPDATE_USABLE")
T.expect(f.wa.IsSpellReady(40) == false, "unrelated event does not trust isOnGCD")
f:send("SPELL_UPDATE_COOLDOWN", 40)
T.expect(f.wa.IsSpellReady(40) == true and f:count("SPELL_COOLDOWN_READY", 40) == 1,
  "GCD-only event transitions from not ready to ready once")
f:send("SPELL_UPDATE_COOLDOWN", 40)
f:send("SPELL_UPDATE_USABLE")
T.expect(f:count("SPELL_COOLDOWN_READY", 40) == 1, "repeated ready observations do not emit ready again")
T.expect(f.wa.IsSpellReady(40) == true, "unrelated refresh preserves authoritative event classification")
f.spells[40].info.isOnGCD = nil
f:send("SPELL_UPDATE_COOLDOWN", 40)
T.expect(f.wa.IsSpellReady(40) == true, "absent GCD classification and recovery retain the pre-m90 ready fallback")
f.spells[40].info = nil
f:send("SPELL_UPDATE_COOLDOWN", 40)
f:add(40, true, false)
f.spells[40].info.isActive = false
f.spells[40].info.isOnGCD = false
f:send("SPELL_UPDATE_COOLDOWN", 40)
T.expect(f.wa.IsSpellReady(40) == true, "inactive cooldown is ready even with isOnGCD=false")
T.expect(f:count("SPELL_COOLDOWN_READY", 40) == 1, "unknown-to-ready does not invent a completed cooldown")
f.spells[40].info.isEnabled = false
f:send("SPELL_UPDATE_COOLDOWN", 40)
T.expect(f.wa.IsSpellReady(40) == false, "held cooldown is not ready despite isActive=false")
f.spells[40].info = nil
f:send("SPELL_UPDATE_COOLDOWN", 40)
T.expect(f.wa.IsSpellReady(40) == nil, "missing API data clears readiness")

T.section("Generated trigger visibility")
local protoFile = assert(io.open(T.repoRoot .. "/M33kAuras/Prototypes.lua"))
local prototypes = protoFile:read("*a"):gsub("\r\n", "\n")
protoFile:close()
local protoStart = assert(prototypes:find('  ["Cooldown Progress (Spell)"]', 1, true))
local initStart = assert(prototypes:find("    init = function(trigger)", protoStart, true))
local initEnd = assert(prototypes:find("    GetNameAndIcon =", initStart, true))
f = fixture()
f:add(45, true, true)
f:watch(45)
f.private.ExecEnv.GetSpellIcon = function(id) return id end
f.env.C_StringUtil = {TruncateWhenZero = function() return nil end}
f.env.C_Spell.GetSpellDisplayCount = function() return nil end
f.wa.GetSpellCooldownDuration = function() return {} end
f.wa.GetSpellCooldownDurationNoGCD = function() return {} end
local init = setfenv(assert(loadstring("return {" .. prototypes:sub(initStart, initEnd - 1) .. "}")), f.env)().init
local function visible(mode)
  local generated = init({spellName = 45, genericShowOn = mode, use_exact_spellName = true})
  local fn = setfenv(assert(loadstring("return function(state) " .. generated .. "\nreturn genericShowOn end")), f.env)()
  return not not fn({})
end
T.expect(not visible("showOnReady") and visible("showOnCooldown"), "unknown readiness defaults to On Cooldown, not Ready")
T.expect(visible("showAlways"), "unknown readiness still allows unconditional duration display")
f:send("SPELL_UPDATE_COOLDOWN", 45)
T.expect(not visible("showOnReady") and visible("showOnCooldown"), "known cooldown matches only On Cooldown")
f.spells[45].info.isActive = false
f:send("SPELL_UPDATE_COOLDOWN", 45)
T.expect(visible("showOnReady") and not visible("showOnCooldown"), "known ready matches only Ready")

T.section("Issue 13: shared GCD and recovery transitions")
f.wa.WatchItemCooldown(1000)
for _, eventSpellId in ipairs({999, 61304}) do
  f.spells[45].info.isActive = true
  f.spells[45].info.isOnGCD = true
  f:reset()
  local oldItems = f.items
  f:send("ACTIONBAR_UPDATE_COOLDOWN")
  f:send("SPELL_UPDATE_COOLDOWN", eventSpellId, nil, nil, eventSpellId == 999 and 133 or nil)
  T.expect(f:count("SPELL_COOLDOWN_CHANGED", 45) == 1 and f.wa.IsSpellReady(45) == true,
    "GCD event from another spell refreshes the watched spell synchronously: " .. eventSpellId)
  T.expect(not f.frame.shown and f.items > oldItems, "GCD refresh also satisfies pending action-bar work")
  T.expect(visible("showOnReady") and not visible("showOnCooldown"), "GCD alone does not show a cooldown-only aura")
  f.spells[45].info.isOnGCD = false
  f:send("ACTIONBAR_UPDATE_COOLDOWN")
  f.frame:OnUpdate(0.016)
  T.expect(visible("showOnReady") and not visible("showOnCooldown"),
    "deferred refresh does not turn a classified GCD into a spell cooldown")
  f.spells[45].info.isActive = false
  f:send("SPELL_UPDATE_COOLDOWN", 61304)
  T.expect(f.wa.IsSpellReady(45) == true and not visible("showOnCooldown"), "GCD end leaves the unused spell ready")
  T.expect(f:count("SPELL_COOLDOWN_READY", 45) == 0, "GCD start and end do not report a completed spell cooldown")
end

f.spells[45].info.isActive = true
f.spells[45].info.isOnGCD = nil
f:send("SPELL_UPDATE_COOLDOWN", 45)
T.expect(visible("showOnReady") and not visible("showOnCooldown"),
  "missing GCD classification with no recovery does not invent a cooldown")
for _, recovery in ipairs({secret, 0, 10}) do
  f.spells[45].info.isOnGCD = true
  f.spells[45].info.timeUntilEndOfStartRecovery = nil
  f:send("SPELL_UPDATE_COOLDOWN", 45)
  f:reset()
  f.spells[45].info.isOnGCD = nil
  f.spells[45].info.timeUntilEndOfStartRecovery = recovery
  f:send("ACTIONBAR_UPDATE_COOLDOWN")
  f.frame:OnUpdate(0.016)
  T.expect(f.wa.IsSpellReady(45) == false and not visible("showOnReady") and visible("showOnCooldown"),
    "recovery presence replaces cached GCD readiness without reading its value")
  f:send("SPELL_UPDATE_COOLDOWN", 45)
  T.expect(f:count("SPELL_COOLDOWN_READY", 45) == 0, "entering recovery never emits a ready event")
  f.spells[45].info.timeUntilEndOfStartRecovery = nil
  f:send("SPELL_UPDATE_COOLDOWN", 45)
  f:send("SPELL_UPDATE_COOLDOWN", 45)
  T.expect(f:count("SPELL_COOLDOWN_READY", 45) == 1 and not visible("showOnCooldown"),
    "recovery completion restores ready and emits one completion event")
end

f.spells[45].info.isOnGCD = true
f:send("SPELL_UPDATE_COOLDOWN", 45)
f.spells[45].info.timeUntilEndOfStartRecovery = secret
f:send("SPELL_UPDATE_USABLE")
T.expect(f.wa.IsSpellReady(45) ~= true and not visible("showOnReady"),
  "changed recovery invalidates cached ready even with an untrustworthy non-nil GCD flag")
f.spells[45].info.isOnGCD = false
f:send("SPELL_UPDATE_COOLDOWN", 45)
f:reset()
f:send("SPELL_UPDATE_COOLDOWN", 999, nil, nil, 133)
T.expect(f.wa.IsSpellReady(45) == false and visible("showOnCooldown") and f:count("SPELL_COOLDOWN_READY", 45) == 0,
  "another spell's GCD does not mark a real cooldown ready")

for _, ready in ipairs({false, true}) do
  for _, inRecovery in ipairs({false, true}) do
    f.spells[45].info.isOnGCD = ready
    f.spells[45].info.timeUntilEndOfStartRecovery = inRecovery and secret or nil
    f:send("SPELL_UPDATE_COOLDOWN", 45)
    f:reset()
    f.spells[45].info.isOnGCD = nil
    f:send("ACTIONBAR_UPDATE_COOLDOWN")
    f.frame:OnUpdate(0.016)
    T.expect(f.wa.IsSpellReady(45) == ready and visible("showOnReady") == ready
      and visible("showOnCooldown") ~= ready and f:count("SPELL_COOLDOWN_READY", 45) == 0,
      "missing classification outside the event preserves unchanged cooldown evidence: ready="
      .. tostring(ready) .. ", recovery=" .. tostring(inRecovery))
  end
end

f:add(46, true, true)
f:watch(46)
f.spells[46].info.isOnGCD = nil
f:send("SPELL_UPDATE_USABLE")
T.expect(f.wa.IsSpellReady(46) == true, "an unknown initial snapshot does not suppress the recovery fallback")

T.section("Readable timing and restriction transitions")
f = fixture()
f:add(50, false, true)
f:watch(50)
local start, duration = f.wa.GetSpellCooldown(50)
T.expect(start == 100 and duration == 10, "normal cooldown remains numerically tracked")
local task = f.timers[#f.timers]
f:add(50, true, true)
f:send("WA_SECRET_STATE_UPDATE")
T.expect(task.cancelled and f.wa.GetSpellCooldown(50) == nil,
  "restriction transition cancels numeric expiration and hides old timing")
T.expect(f.wa.IsSpellReady(50) == nil, "secrecy transition invalidates old readiness evidence")
f:add(50, false, false)
f:send("WA_SECRET_STATE_UPDATE")
T.expect(f.wa.GetSpellCooldown(50) == 0 and f.wa.IsSpellReady(50) == true,
  "readable timing resumes when restrictions end")
f:add(50, false, true)
f:send("SPELL_UPDATE_COOLDOWN", 50)
f:reset()
f.now = 111
task = f.timers[#f.timers]
task.fn(unpack(task.args))
T.expect(f:count("SPELL_COOLDOWN_READY", 50) == 1, "numeric timer still reports cooldown completion")
f = fixture()
f:add(51, false, true)
f:watch(51)
f:add(51, true, false)
f:send("SPELL_UPDATE_COOLDOWN", 51)
T.expect(f:count("SPELL_COOLDOWN_READY", 51) == 1, "known completion across secrecy transition is reported once")

T.section("Secret charges and broad readiness refresh")
f = fixture()
f:add(60, true, true)
f.spells[60].charges = {currentCharges = secret, maxCharges = 2, cooldownStartTime = secret,
  cooldownDuration = secret, chargeModRate = secret}
f.spells[60].count = secret
f:watch(60)
f:send("SPELL_UPDATE_COOLDOWN")
T.expect(f.wa.IsSpellReady(60) == false, "nil-ID cooldown event supplies authoritative classification")
T.expect(f:count("SPELL_COOLDOWN_CHANGED", 60) == 1 and f:count("SPELL_CHARGES_CHANGED", 60) == 0,
  "secret charges update display without calculating a delta")
T.expect(issecret(f.wa.GetSpellCharges(60)), "secret charges are retained for display")
f.spells[60].info.isActive = false
f:send("SPELL_UPDATE_COOLDOWN")
f:send("SPELL_UPDATE_COOLDOWN")
T.expect(f:count("SPELL_COOLDOWN_READY", 60) == 1, "full refresh also emits ready only on transition")
f:add(61, false, false)
T.expect(f.wa.IsSpellReady(61) == true, "readiness helper supports an unwatched spell")
f:add(61, false, true)
T.expect(f.wa.IsSpellReady(61) == false, "unwatched readiness is not cached indefinitely")

T.section("Targeted update cost")
local function visitsForTargetedUpdate(unrelated)
  local sample = fixture()
  sample:add(70, true, true)
  sample:watch(70)
  for id = 100, 99 + unrelated do
    sample:add(id, true, true)
    sample:watch(id)
  end
  local visits = 0
  local tables, newTables, resolutions = {}, 0, 0
  local resolve = sample.private.ExecEnv.GetEffectiveSpellId
  sample.private.ExecEnv.GetEffectiveSpellId = function(...)
    resolutions = resolutions + 1
    return resolve(...)
  end
  sample.env.pairs = function(values)
    if not tables[values] then tables[values] = true; newTables = newTables + 1 end
    local iterator, state, key = pairs(values)
    return function(t, previous)
      local nextKey, value = iterator(t, previous)
      if nextKey ~= nil then visits = visits + 1 end
      return nextKey, value
    end, state, key
  end
  sample:reset()
  sample:send("SPELL_UPDATE_COOLDOWN", 70)
  local firstVisits = visits
  T.expect(sample:count("SPELL_COOLDOWN_CHANGED") == 1,
    "targeted update notifies only its subscriber with " .. unrelated .. " unrelated spells")
  newTables = 0
  sample:send("SPELL_UPDATE_COOLDOWN", 70)
  T.expect(newTables == 0, "repeated events iterate cached tables without constructing a target set")
  T.expect(resolutions == 0, "indexed spell events do not resolve spell IDs again")
  return firstVisits
end
T.expect(visitsForTargetedUpdate(0) == visitsForTargetedUpdate(250),
  "targeted routing does not iterate unrelated subscriptions")

T.section("Routing index lifetime and deduplication")
f = fixture()
for id = 80, 82 do f:add(id, true, true) end
f.overrides[80] = 81
f:watch(80, true)
f:watch(80, true, false)
f:watch(80, false)
f:watch(81, false)
f:reset()
f:send("SPELL_UPDATE_COOLDOWN", 81, 80)
T.expect(f.reads[80] == 2 and f.reads[81] == 2,
  "overlapping spell/base routes refresh each effective spell once across watch modes")
f.overrides[80] = 82
f:send("SPELLS_CHANGED")
f:reset()
f:send("SPELL_UPDATE_COOLDOWN", 80)
T.expect(f.reads[80] == 2 and f.reads[82] == 2 and not f.reads[81],
  "remapping removes old target from base route while retaining exact watcher")
f:reset()
f:send("SPELL_UPDATE_COOLDOWN", 81)
T.expect(f:count("SPELL_COOLDOWN_CHANGED", 81) == 1 and f:count("SPELL_COOLDOWN_CHANGED", 80) == 0,
  "old effective spell keeps its independent subscriber after remapping")
f = fixture()
for id = 90, 92 do f:add(id, true, true) end
f.overrides[90] = 91
f:watch(90, true)
f:watch(90, true, false)
f.overrides[90] = 92
f:send("SPELLS_CHANGED")
f:reset()
f:send("SPELL_UPDATE_COOLDOWN", 91)
T.expect(#f.events == 0 and not f.reads[91], "last subscription removes obsolete event route")
local resolve = f.private.ExecEnv.GetEffectiveSpellId
f.private.ExecEnv.GetEffectiveSpellId = function(id, ...)
  if id == 999 then return 92 end
  return resolve(id, ...)
end
f:send("SPELL_UPDATE_COOLDOWN", 999)
T.expect(f:count("SPELL_COOLDOWN_CHANGED", 90) == 1,
  "unindexed rank can still resolve to a watched effective spell")

T.section("Specific charges with restricted data")
f = fixture()
f:add(900, true, true)
f.spells[900].charges = {currentCharges = secret, maxCharges = 2, cooldownStartTime = secret,
  cooldownDuration = secret, chargeModRate = secret}
f:watch(900)
f.env.C_StringUtil = {TruncateWhenZero = function() return nil end}
f.env.C_Spell.GetSpellDisplayCount = function() return nil end
f.wa.GetSpellCooldownDuration = function() return {} end
f.wa.GetSpellCooldownDurationNoGCD = function() return {} end
setfenv(init, f.env)
local generated = init({spellName = 900, genericShowOn = "showAlways", use_exact_spellName = true,
  use_trackcharge = true, trackcharge = "2"})
local specificCharge = setfenv(assert(loadstring("return function(state) " .. generated .. "\nreturn genericShowOn end")), f.env)()
local ok, visible = pcall(specificCharge, {})
T.expect(ok and visible == false, "secret charge count fails specific-charge trigger without comparison")
f.spells[900].charges.currentCharges = 1
f:send("SPELL_UPDATE_COOLDOWN", 900)
ok, visible = pcall(specificCharge, {})
T.expect(ok and visible == false, "unavailable charge timing is not reported as a timed charge")
f.spells[900].charges.currentCharges = 2
f:send("SPELL_UPDATE_COOLDOWN", 900)
local chargeState = {}
ok, visible = pcall(specificCharge, chargeState)
T.expect(ok and visible and chargeState.duration == 0 and chargeState.expirationTime == 0,
  "readable available charge can still be displayed while timing is restricted")
f:add(900, false, false)
f.spells[900].charges = {currentCharges = 1, maxCharges = 2, cooldownStartTime = 100,
  cooldownDuration = 10, chargeModRate = 1}
f:send("WA_SECRET_STATE_UPDATE")
ok, visible = pcall(specificCharge, chargeState)
T.expect(ok and visible and chargeState.duration == 10 and chargeState.expirationTime == 110,
  "specific-charge timing resumes when data becomes readable")

T.section("Ready events when restrictions end")
for _, before in ipairs({"ready", "cooldown", "unknown"}) do
  for _, after in ipairs({"ready", "cooldown"}) do
    f = fixture()
    f:add(910, false, before ~= "ready")
    f:watch(910)
    f:add(910, true, before ~= "ready")
    if before == "unknown" then
      f:send("WA_SECRET_STATE_UPDATE")
    else
      f:send("SPELL_UPDATE_COOLDOWN", 910)
    end
    f:reset()
    f:add(910, false, after ~= "ready")
    f:send("WA_SECRET_STATE_UPDATE")
    f:send("SPELL_UPDATE_COOLDOWN", 910)
    local expected = before == "cooldown" and after == "ready" and 1 or 0
    T.expect(f:count("SPELL_COOLDOWN_READY", 910) == expected,
      "restriction exit " .. before .. " -> " .. after .. " reports only a known completion")
  end
end

T.section("Raw and normalized routes together")
for _, rawFirst in ipairs({true, false}) do
  f = fixture()
  for id = 920, 922 do f:add(id, true, true) end
  local canonicalId = 921
  local originalResolve = f.private.ExecEnv.GetEffectiveSpellId
  f.private.ExecEnv.GetEffectiveSpellId = function(id, exact, ...)
    if id == 920 and not exact then return canonicalId end
    return originalResolve(id, exact, ...)
  end
  if rawFirst then f:watch(920); f:watch(921) else f:watch(921); f:watch(920) end
  f:reset()
  f:send("SPELL_UPDATE_COOLDOWN", 920)
  T.expect(f:count("SPELL_COOLDOWN_CHANGED", 920) == 1 and f:count("SPELL_COOLDOWN_CHANGED", 921) == 1
    and f.reads[920] == 2 and f.reads[921] == 2,
    "raw and normalized subscriptions refresh once in either registration order")
  f:reset()
  f:send("SPELL_UPDATE_COOLDOWN", 920, 921)
  T.expect(f.reads[920] == 2 and f.reads[921] == 2,
    "base ID does not duplicate a target already included through normalization")
  f:watch(922)
  canonicalId = 922
  f:send("SPELLS_CHANGED")
  f:reset()
  f:send("SPELL_UPDATE_COOLDOWN", 920)
  T.expect(f:count("SPELL_COOLDOWN_CHANGED", 920) == 1 and f:count("SPELL_COOLDOWN_CHANGED", 922) == 1
    and f:count("SPELL_COOLDOWN_CHANGED", 921) == 0,
    "SPELLS_CHANGED refreshes normalization even when exact-ID watches do not move")
  local resolutions = 0
  local resolve = f.private.ExecEnv.GetEffectiveSpellId
  f.private.ExecEnv.GetEffectiveSpellId = function(...)
    resolutions = resolutions + 1
    return resolve(...)
  end
  f:send("SPELL_UPDATE_COOLDOWN", 920)
  T.expect(resolutions == 0, "merged rank route still avoids resolution on the event path")
end
T.section("Recorded SPELL_UPDATE_COOLDOWN payloads")
f = fixture()
for _, id in ipairs({119381, 1464, 1269383, 1306635, 1295582}) do f:add(id, true, true) end
f.overrides[1464] = 1269383
f:watch(1464, true)
for _, id in ipairs({119381, 1269383, 1306635, 1295582}) do f:watch(id) end
for _, payload in ipairs({
  {spell = 1269383, base = 1464, category = 0, recovery = 133, broad = true},
  {spell = 1464, category = 0, recovery = 133, broad = true},
  {spell = 1306635, category = 0, recovery = 0},
  {spell = 1295582},
  {broad = true},
}) do
  f:reset()
  f:send("SPELL_UPDATE_COOLDOWN", payload.spell, payload.base, payload.category, payload.recovery, nil)
  local description = tostring(payload.spell) .. ", " .. tostring(payload.base) .. ", "
    .. tostring(payload.category) .. ", " .. tostring(payload.recovery) .. ", nil"
  if payload.broad then
    T.expect(f.reads[119381] == 2 and f.reads[1269383] == 2
      and f:count("SPELL_COOLDOWN_CHANGED", 119381) == 1
      and f:count("SPELL_COOLDOWN_CHANGED", 1464) == 1
      and f:count("SPELL_COOLDOWN_CHANGED", 1269383) == 1,
      "recorded GCD/full payload refreshes other spells and override subscribers once: " .. description)
  else
    T.expect(f.reads[119381] == nil and f.reads[1269383] == nil
      and f:count("SPELL_COOLDOWN_CHANGED", payload.spell) == 1
      and f:count("SPELL_COOLDOWN_CHANGED") == 1,
      "recorded zero/nil recovery payload remains targeted: " .. description)
  end
end
T.finish()
