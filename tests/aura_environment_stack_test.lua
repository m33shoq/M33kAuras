local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
local stubs = require("wow_stubs")
stubs.install()
M33kAuras = stubs.newM33kAuras()
local Private = stubs.newPrivate()
local data = {}
for _, id in ipairs({ "parent", "child", "no-uid", "group", "fresh-child" }) do
  data[id] = { id = id, uid = id .. "-uid", config = {}, information = {}, actions = {} }
end
data["no-uid"].uid = nil
data.group.controlledChildren = { "fresh-child" }
M33kAuras.GetData = function(id) return data[id] end
T.loadAddonFile("M33kAuras/AuraEnvironment.lua", "M33kAuras", Private)

local function context(id, message)
  local env = Private.GetSanitizedGlobal("aura_env")
  local uid
  Private.DebugLog.Print = function(value) uid = value end
  Private.GetSanitizedGlobal("DebugPrint")()
  T.expect((id == nil and env == nil or env and env.id == id)
           and uid == (id and data[id].uid), message)
  return env
end

T.section("nested activation preserves the environment and UID")
Private.ActivateAuraEnvironment()
context(nil, "popping an empty stack leaves no active context")
Private.ActivateAuraEnvironment("parent")
local parent = context("parent", "fresh parent is active")
Private.ActivateAuraEnvironment("no-uid", nil, nil, nil, true)
context("no-uid", "config-only activation accepts a nil UID")
Private.ActivateAuraEnvironment("child")
context("child", "a child can be nested above a nil UID")
Private.ActivateAuraEnvironment()
context("no-uid", "pop restores the environment with a nil UID")
Private.ActivateAuraEnvironment()
T.expect(context("parent", "pop restores the parent UID") == parent,
         "the original parent environment table is restored")
Private.ActivateAuraEnvironment("parent")
T.expect(context("parent", "recursive activation of the same aura is active") == parent,
         "recursive activation reuses the environment table")
Private.ActivateAuraEnvironment()
context("parent", "recursive pop retains the outer activation")
Private.ActivateAuraEnvironment("missing")
context(nil, "an unknown aura ID pops the active context")
Private.ActivateAuraEnvironment()
context(nil, "an additional empty pop is safe")

T.section("config-only and full initialization share the same stack")
Private.ActivateAuraEnvironment("parent")
local state, states = {}, {}
Private.ActivateAuraEnvironment("no-uid", "clone", state, states, true)
local configEnv = context("no-uid", "an existing config-only environment can be reactivated")
T.expect(configEnv.cloneId == "clone" and configEnv.state == state and configEnv.states == states,
         "clone and trigger state are forwarded")
Private.ActivateAuraEnvironment()
context("parent", "config-only pop restores the caller")
Private.ActivateAuraEnvironment("no-uid")
T.expect(context("no-uid", "config-only environment upgrades to full initialization") == configEnv,
         "full initialization preserves the config environment table")
Private.ActivateAuraEnvironment()
context("parent", "upgraded environment pops back to its caller")
Private.ActivateAuraEnvironment()

T.section("group initialization restores context after initializing children")
Private.ActivateAuraEnvironment("group")
local group = context("group", "group is current after config-only child initialization")
T.expect(group.child_envs[1].id == "fresh-child", "group retains its child environment")
Private.ActivateAuraEnvironment()
context(nil, "group initialization leaves a balanced stack")

T.section("init and lifecycle callbacks can nest aura activations")
data.lifecycle = { id = "lifecycle", uid = "lifecycle-uid", config = {}, information = {},
                   actions = { init = { do_custom = true, custom = "test" } } }
local initCalls, lifecycleCalls = 0, 0
Private.customActionsFunctions.lifecycle = {
  init = function()
    initCalls = initCalls + 1
    context("lifecycle", "init callback receives the initialized context")
    Private.ActivateAuraEnvironment("child")
    Private.ActivateAuraEnvironment()
    context("lifecycle", "init callback restores its context after nested activation")
  end,
}
Private.ActivateAuraEnvironmentLifecycle = function(id)
  if id == "lifecycle" then
    lifecycleCalls = lifecycleCalls + 1
    context(id, "lifecycle callback receives the initialized context")
    Private.ActivateAuraEnvironment(id)
    Private.ActivateAuraEnvironment()
    context(id, "recursive lifecycle activation restores its caller")
  end
end
Private.ActivateAuraEnvironment("parent")
Private.ActivateAuraEnvironment("lifecycle")
Private.ActivateAuraEnvironment()
context("parent", "initialization and lifecycle callbacks preserve the outer caller")
Private.ActivateAuraEnvironment("lifecycle")
Private.ActivateAuraEnvironment()
T.expect(initCalls == 1 and lifecycleCalls == 1, "reactivation does not repeat initialization callbacks")
Private.ActivateAuraEnvironment()
context(nil, "callbacks leave the stack balanced")
T.finish()
