if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

local knownEvents = {
  PLAYER_ENTERING_WORLD = true,
  ADDON_RESTRICTION_STATE_CHANGED = true,
  PLAYER_IN_COMBAT_CHANGED = true,
  ENCOUNTER_STATE_CHANGED = true,
  CHALLENGE_MODE_START = true,
  -- i have no idea about pvp but lest pray this works
  PVP_MATCH_ACTIVE = true,
  PVP_MATCH_COMPLETE = true,
  PVP_MATCH_INACTIVE = true,
  PVP_MATCH_STATE_CHANGED = true,
}

local secretState = nil
local function HandleEvent(_, event, ...)
  local newSecretState = C_Secrets.ShouldAurasBeSecret() or C_Secrets.ShouldCooldownsBeSecret()
  if secretState ~= newSecretState then
    -- if not knownEvents[event] and event ~= "ADDON_LOADED" then
    --   geterrorhandler()("secret state changed: " .. tostring(newSecretState) .. ", on event: " .. event)
    --   WeakAuras.prettyPrint("secret state changed:", newSecretState, "on event:", event)
    -- end
    secretState = newSecretState
    Private.callbacks:Fire("WA_SECRET_STATE_UPDATE") -- for load
    Private.ScanEvents("WA_SECRET_STATE_UPDATE") -- for triggers
  end
  if event == "ADDON_RESTRICTION_STATE_CHANGED" then
    local restrictionType, state = ...
    if state == Enum.AddOnRestrictionState.Activating then
      -- in case we missed an event we can ensure if applied
      -- type affects us by rechecking on next frame
      C_Timer.After(0, HandleEvent)
    end
  end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", HandleEvent)
for event in pairs(knownEvents) do
  frame:RegisterEvent(event)
end

-- frame:RegisterAllEvents()

function WeakAuras.IsSecretStateActive()
  return secretState
end

-- local DoesAddonRestrictionsActive
-- do
--   local importantRestrictionTypes = {
--     Enum.AddOnRestrictionType.Combat,
--     Enum.AddOnRestrictionType.Encounter,
--     Enum.AddOnRestrictionType.ChallangeMode,
--     Enum.AddOnRestrictionType.PvPMatch,
--   }
--   local STATE_INACTIVE = Enum.AddOnRestrictionState.Inactive
--   function DoesAddonRestrictionsActive()
--     for _, restrictionType in ipairs(importantRestrictionTypes) do
--       local state = C_RestrictedActions.GetAddOnRestrictionState(restrictionType)
--       if state ~= STATE_INACTIVE then
--         return true, restrictionType
--       end
--     end
--     return false
--   end
--   WeakAuras.DoesAddonRestrictionsActive = DoesAddonRestrictionsActive
-- end
