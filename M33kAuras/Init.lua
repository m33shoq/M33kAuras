---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)
WASYNC_MAIN_PRIVATE = Private

---@class M33kAuras
M33kAuras = {}
---@type table<string, string>
M33kAuras.L = {}
Private.frames = {}

--- @alias uid string
--- @alias auraId string

--- @class state
--- @field id auraId
--- @field cloneId string?
--- @field show boolean?
--- @field changed boolean?
--- @field paused boolean?
--- @field remaining number?
--- @field autoHide boolean|string|nil
--- @field progressType "timed"|"static"|nil
--- @field expirationTime number?
--- @field duration number?
--- @field name any?
--- @field icon any?
--- @field value number?
--- @field total number?
--- @field inverse boolean?

--- @alias non_transmissable_field table<string, non_transmissable_field|boolean>

--- @class multiUnitUnits
--- @field nameplate table<string, boolean>
--- @field boss table<string, boolean>
--- @field arena table<string, boolean>
--- @field group table<string, boolean>
--- @field party table<string, boolean>
--- @field raid table<string, boolean>

--- @alias traverseFunction fun(): auraData

---@class WARegion : Frame
---@field state state
---@field states state[]
---@field regionType string
---@field FrameTick fun(self: WARegion)?
---@field UpdateValue fun(self: WARegion)?
---@field UpdateTime fun(self: WARegion)?
---@field Update fun(self: WARegion)?

--- @class Private
--- @field ActivateAuraEnvironment fun(id: auraId?, cloneId: string?, state: state?, states: state[]?, config: boolean?)
--- @field ActivateAuraEnvironmentForRegion fun(region: table, onlyConfig: boolean?)
--- @field AddToWatchedTriggerDelay fun(id: auraId, triggerNum: number)
--- @field anchor_frame_types table<anchorFrameTypes, string>
--- @field anchor_frame_types_group table<anchorFrameTypes, string>
--- @field anim_function_strings table<string, string>
--- @field anim_presets table<string, table>
--- @field AuraWarnings AuraWarnings
--- @field AuraEnvironmentWrappedSystem AuraEnvironmentWrappedSystem
--- @field callbacks callbacks
--- @field category_event_prototype table<string, table<string, string>>
--- @field CanHaveTooltip fun(data: auraData): boolean
--- @field CheckTalentsForLoad fun(event: string)
--- @field ContainsCustomPlaceHolder fun(input: string): boolean
--- @field ContainsAnyPlaceHolders fun(input: string): boolean
--- @field ContainsPlaceHolders fun(input: string, placeholders: string, checkDoublePercent?: boolean): boolean
--- @field CreateSubscribableObject fun(): SubscribableObject
--- @field clones table<auraId, table<string, table>>
--- @field customActionsFunctions table<auraId, table<string, function?>>
--- @field DebugLog debugLog
--- @field dynamic_texts table<string, table>
--- @field EndEvent fun(state: state): boolean?
--- @field EnsureRegion fun(id: auraId, cloneId: string?): WARegion
--- @field ExecEnv table
--- @field event_prototypes table<string, prototypeData>
--- @field event_categories table<string, {name: string, default: string }>
--- @field Features Features
--- @field FindUnusedId fun(prefix: string?): string
--- @field FixGroupChildrenOrderForGroup fun(data: auraData)
--- @field frames table<string, table>
--- @field function_strings table<string, string>
--- @field GetDataByUID fun(uid: uid): auraData
--- @field GetErrorHandlerId fun(id: auraId, context: string): function
--- @field GetErrorHandlerUid fun(uid: uid, context: string): function
--- @field GetRegionByUID fun(uid: uid, cloneId: string): Region
--- @field glow_types table<string, string>
--- @field inverse_point_types table<string, string>
--- @field IsCLEUSubevent fun(subevent: string): boolean
--- @field IsDragonriding fun(): boolean
--- @field IsGroupType fun(data: auraData): boolean
--- @field item_slot_types string[]
--- @field LibSpecWrapper LibSpecWrapper
--- @field linked table<auraId, number>
--- @field loaded table<auraId, boolean>
--- @field LoadFunction fun(input: string): function
--- @field LoadOptions fun(msg: string?): boolean
--- @field maxTimerDuration number
--- @field multiUnitUnits multiUnitUnits
--- @field non_transmissable_fields table<string, non_transmissable_field>
--- @field non_transmissable_fields_v2000 table<string, non_transmissable_field>
--- @field orientation_types table<string, string>
--- @field orientation_with_circle_types table<string, string>
--- @field ParseNumber fun (numString: string|number): number?, string?
--- @field PreShowModels fun()
--- @field PrintHelp fun()
--- @field QuotedString fun(input: string): string
--- @field regionOptions table<string, table>
--- @field regions table<auraId, table>
--- @field regionTypes table<string, table>
--- @field reset_ranged_swing_spells table<number, boolean>
--- @field reset_swing_spells table<number, boolean>
--- @field noreset_swing_spells table<number, boolean>
--- @field RunCustomTextFunc fun(region: table, f: function): string?
--- @field spark_rotation_types table<string, string>
--- @field spec_types string[]
--- @field spec_types_3 string[]
--- @field spec_types_2 string[]
--- @field StartProfileAura fun(id: auraId)
--- @field StartProfileSystem fun(system: string)
--- @field StopProfileAura fun(id: auraId)
--- @field StopProfileSystem fun(system: string)
--- @field subRegionOptions table<string, table>
--- @field subRegionTypes table<string, table>
--- @field tick_placement_modes table<string, string>
--- @field tinySecondFormat fun(value: string|number): string?
--- @field TraverseAll fun(data: auraData): traverseFunction, auraData
--- @field TraverseAllChildren fun(data: auraData): traverseFunction, auraData
--- @field TraverseGroups fun(data: auraData): traverseFunction, auraData
--- @field TraverseLeafs fun(data: auraData): traverseFunction, auraData
--- @field TraverseLeafsOrAura fun(data: auraData): traverseFunction, auraData
--- @field TraverseParents fun(data: auraData): traverseFunction, auraData
--- @field TraverseSubGroups fun(data: auraData): traverseFunction, auraData
--- @field triggerTypes table<string, table>
--- @field triggerTypesOptions table<string, any>
--- @field UIDtoID fun(uid: uid): auraId
--- @field UnitEventList table<string, boolean>
--- @field UnitPlayerControlledFixed fun(unit: string): boolean
--- @field UpdatedTriggerState fun(id: auraId)
--- @field validate fun(input: table, default:table)
--- @field watched_trigger_events table<auraId, table<integer, table<integer, boolean>>>
--- @field RegisterRegionType fun(regionType: string, createFunction: function, modifyFunction: function, defaults: table, properties: table|function|nil, validate: function?))

--- @alias triggerTypes
--- | "aura"
--- | "aura2"
--- | "custom"

--- @alias anchorFrameTypes
--- | "SCREEN"
--- | "PRD"
--- | "MOUSE"
--- | "SELECTFRAME"
--- | "NAMEPLATE"
--- | "UNITFRAME"
--- | "CUSTOM"

--- @class triggerData
--- @field buffShowOn string
--- @field debuffType string
--- @field essence number?
--- @field event string|nil
--- @field instance_size table|nil
--- @field itemName string?
--- @field itemSetName string?
--- @field itemTypeName table|nil
--- @field range number?l
--- @field realSpellName string?
--- @field rune number?
--- @field spellName string?
--- @field subeventPrefix string?
--- @field subeventSuffix string?
--- @field type triggerTypes
--- @field unit string?
--- @field use_alwaystrue boolean|nil
--- @field use_ignoreoverride boolean|nil
--- @field use_showOn boolean|nil

---@class prototypeDataArgs
---@field name string
---@field required boolean?
---@field display string
---@field type "unit"|nil
---@field init "string"|nil
---@field values any
---@field desc string?
---@field store boolean?
---@field test string?

---@class prototypeData
---@field durationFunc (fun(trigger: triggerData): number, number, boolean?)|nil
---@field init (fun(trigger: triggerData):string?)|nil
---@field useModRate boolean?
---@field timedrequired boolean?
---@field GetNameAndIcon (fun(trigger: triggerData): string?, string?)|nil
---@field iconFunc (fun(trigger: triggerData): string?)|nil
---@field loadFunc (fun(trigger: triggerData): nil)|nil
---@field nameFunc (fun(trigger: triggerData): string?)|nil
---@field events (fun(trigger: triggerData): table)|nil
---@field internal_events (fun(trigger: triggerData): table)|nil
---@field name string
---@field statesParameter "unit"|"one"|"all"|nil
---@field progressType "timed"|"static"|"none"

--- @class triggerUntriggerData
--- @field trigger triggerData
--- @field untrigger triggerData

--- @class conditionCheck
--- @field variable string
--- @field trigger number
--- @field checks conditionCheck[]|nil

--- @class conditionChanges
--- @field property string

--- @class conditionData
--- @field check conditionCheck
--- @field changes conditionChanges

--- @class subRegionData

--- @class actionData
--- @field do_glow boolean
--- @field do_message boolean
--- @field do_sound boolean
--- @field message string
--- @field message_type string


--- @class actions
--- @field start actionData
--- @field finish actionData

--- @class load
--- @field use_realm boolean
--- @field itemtypeequipped table
--- @field size table

--- @alias regionTypes
--- | "aurabar"
--- | "dynamicgroup"
--- | "fallback"
--- | "group"
--- | "icon"
--- | "model"
--- | "progresstexture"
--- | "stopmotion"
--- | "text"
--- | "texture"

--- @class information
--- @field forceEvents boolean|nil
--- @field ignoreOptionsEventErrors boolean|nil
--- @field groupOffset boolean|nil

--- @alias dynamicGroupCenterType
--- | "LR"
--- | "RL"
--- | "CLR"
--- | "CRL"

--- @alias dynamicGroupGridType
--- | "RU"
--- | "UR"
--- | "LU"
--- | "UL"
--- | "RD"
--- | "DR"
--- | "LD"
--- | "DL"
--- | "HD"
--- | "HU"
--- | "VR"
--- | "VL"
--- | "DH"
--- | "UH"
--- | "LV"
--- | "RV"
--- | "HV"
--- | "VH"

--- @alias dynamicGroupCircularTypes
--- | "RADIUS"
--- | "SPACING"

--- @alias ColorArray {[1]: number, [2]: number, [3]: number, [4]: number }

--- @class auraData
--- @field anchorFrameType anchorFrameTypes?
--- @field animate boolean?
--- @field arcLength number?
--- @field actions actions?
--- @field border boolean?
--- @field borderBackdrop string?
--- @field borderColor ColorArray?
--- @field borderEdge string?
--- @field borderOffset number?
--- @field borderInset number?
--- @field borderSize number?
--- @field centerType dynamicGroupCenterType?
--- @field conditions conditionData[]?
--- @field constantFactor dynamicGroupCircularTypes
--- @field controlledChildren auraId[]?
--- @field displayText string?
--- @field frameStrata number?
--- @field fullCircle boolean?
--- @field gridType dynamicGroupGridType?
--- @field gridWidth number?
--- @field rowSpace number?
--- @field columnSpace number?
--- @field grow string?
--- @field id auraId
--- @field internalVersion number
--- @field information information
--- @field load load
--- @field limit number?
--- @field orientation string?
--- @field parent auraId?
--- @field radius number?
--- @field rotation number?
--- @field regionType regionTypes
--- @field scale number?
--- @field selfPoint AnchorPoint
--- @field subRegions subRegionData?
--- @field triggers triggerUntriggerData[]
--- @field url string?
--- @field useLimit boolean?
--- @field xOffset number?
--- @field yOffset number?

--- @class LibCustomGlow-1.0
--- @field ButtonGlow_Start fun(frame: Frame)
--- @field ButtonGlow_Stop fun(frame: Frame)
--- @field AutoCastGlow_Start fun(frame: Frame)
--- @field AutoCastGlow_Stop fun(frame: Frame)
--- @field PixelGlow_Start fun(frame: Frame)
--- @field PixelGlow_Stop fun(frame: Frame)

--- @class LibGetFrame-1.0
--- @field GetUnitFrame fun(unit: string)
--- @field GetUnitNameplate fun(unit: string)
--- @field StartProfile fun()
--- @field StopProfile fun()
--- @field GetProfileData fun(): table

--- @class LibSerialize
--- @field SerializeEx fun(self: LibSerialize,options: table, input: any)
--- @field Deserialize fun(self: LibSerialize, input: string): table

--- @class LibDeflate
--- @field CompressDeflate fun(self: LibDeflate, input: string, options: table): string
--- @field EncodeForPrint fun(self: LibDeflate, input: string): string)
--- @field EncodeForWoWAddonChannel fun(self: LibDeflate, input: string): string
--- @field DecodeForPrint fun(self: LibDeflate, input: string): string
--- @field DecodeForWoWAddonChannel fun(self: LibDeflate, input: string): string
--- @field DecompressDeflate fun(self: LibDeflate, input: string): string

--- @class LibDBIcon-1.0
--- @field Hide fun(self: LibDBIcon-1.0, name: string)
--- @field Register fun(self: LibDBIcon-1.0, name: string, broker: table, options: table)
--- @field Show fun(self: LibDBIcon-1.0, name: string)

--- @class LibSharedMedia-3.0
--- @field Fetch fun(self: LibSharedMedia-3.0, mediaType: string, name: string)
--- @field HashTable fun(self: LibSharedMedia-3.0, mediaType: string): table<string, string>
--- @field Register fun(self: LibSharedMedia-3.0, mediaType: string, name: string, path: string|number, flags: number?)
--- @field RegisterCallback fun(self: LibSharedMedia-3.0, callbackType: string, callback: fun(_: any, mediaType: string, key: string))
--- @field LOCALE_BIT_western number
--- @field LOCALE_BIT_ruRU number

--- @class LibCompress
--- @field Decompress fun(self: LibCompress, input: string): string

--- @class AceTimer-3.0
--- @field Embed fun(self: AceTimer-3.0, t: table)

M33kAuras.normalWidth = 1.3
M33kAuras.halfWidth = M33kAuras.normalWidth / 2
M33kAuras.doubleWidth = M33kAuras.normalWidth * 2
local versionStringFromToc = C_AddOns.GetAddOnMetadata("M33kAuras", "Version")
local versionString = "@project-version@"
local buildTime = "@build-time@"

local flavorFromToc = C_AddOns.GetAddOnMetadata("M33kAuras", "X-Flavor")
local flavorFromTocToNumber = {
  Vanilla = 1,
  TBC = 2,
  Wrath = 3,
  Cata = 4,
  Mists = 5,
  Mainline = 10
}
local flavor = flavorFromTocToNumber[flavorFromToc]

if not versionString:find("beta", 1, true) then
  M33kAuras.buildType = "release"
else
  M33kAuras.buildType = "beta"
end

--@alpha@
M33kAuras.buildType = "alpha"
--@end-alpha@

--@experimental@
M33kAuras.buildType = "pr"
--@end-experimental@

--@debug@
if versionStringFromToc == "@project-version@" then
  versionStringFromToc = "Dev"
  buildTime = "Dev"
  M33kAuras.buildType = "dev"
end
--@end-debug@

M33kAuras.versionString = versionStringFromToc
M33kAuras.buildTime = buildTime
M33kAuras.newFeatureString = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0|t"
M33kAuras.BuildInfo = select(4, GetBuildInfo())

---@return boolean result
function M33kAuras.IsClassicEra()
  return flavor == 1
end
-- save compatibility with old auras
M33kAuras.IsClassic = M33kAuras.IsClassicEra

---@return boolean result
function M33kAuras.IsWrathClassic()
  return flavor == 3
end

---@return boolean result
function M33kAuras.IsCataClassic()
  return flavor == 4
end

---@return boolean result
function M33kAuras.IsMists()
  return flavor == 5
end

---@return boolean result
function M33kAuras.IsRetail()
  return flavor == 10
end

---@return boolean result
function M33kAuras.IsClassicOrCata()
  return M33kAuras.IsClassicEra() or M33kAuras.IsCataClassic()
end

---@return boolean result
function M33kAuras.IsClassicOrCataOrMists()
  return M33kAuras.IsClassicOrCata() or M33kAuras.IsMists()
end

---@return boolean result
function M33kAuras.IsCataOrMists()
  return M33kAuras.IsCataClassic() or M33kAuras.IsMists()
end

function M33kAuras.IsCataOrMistsOrRetail()
  return M33kAuras.IsCataClassic() or M33kAuras.IsMists() or M33kAuras.IsRetail()
end

---@return boolean result
function M33kAuras.IsMistsOrRetail()
  return M33kAuras.IsMists() or M33kAuras.IsRetail()
end

---@return boolean result
function M33kAuras.IsCataOrRetail()
  return M33kAuras.IsCataClassic() or M33kAuras.IsRetail()
end

---@return boolean result
function M33kAuras.IsClassicOrWrath()
  return M33kAuras.IsClassicEra() or M33kAuras.IsWrathClassic()
end

---@return boolean result
function M33kAuras.IsWrathOrCata()
  return M33kAuras.IsWrathClassic() or M33kAuras.IsCataClassic()
end

---@return boolean result
function M33kAuras.IsWrathOrCataOrMists()
  return M33kAuras.IsWrathClassic() or M33kAuras.IsCataClassic() or M33kAuras.IsMists()
end

---@return boolean result
function M33kAuras.IsWrathOrCataOrMistsOrRetail()
  return M33kAuras.IsWrathClassic() or M33kAuras.IsCataClassic() or M33kAuras.IsMists() or M33kAuras.IsRetail()
end

---@return boolean result
function M33kAuras.IsClassicOrWrathOrCata()
  return M33kAuras.IsClassicEra() or M33kAuras.IsWrathClassic() or M33kAuras.IsCataClassic()
end

---@return boolean result
function M33kAuras.IsClassicOrWrathOrCataOrMists()
  return M33kAuras.IsClassicEra() or M33kAuras.IsWrathClassic() or M33kAuras.IsCataClassic() or M33kAuras.IsMists()
end

---@return boolean result
function M33kAuras.IsWrathOrMistsOrRetail()
  return M33kAuras.IsWrathClassic() or M33kAuras.IsMists() or M33kAuras.IsRetail()
end

---@return boolean result
function M33kAuras.IsWrathOrMists()
  return M33kAuras.IsWrathClassic() or M33kAuras.IsMists()
end

---@return boolean result
function M33kAuras.IsWrathOrRetail()
  return M33kAuras.IsWrathClassic() or M33kAuras.IsRetail()
end

---@return boolean result
function M33kAuras.IsTWW()
  return M33kAuras.BuildInfo >= 110000
end

---@param ... string
M33kAuras.prettyPrint = function(...)
  print("|cff9900ffM33kAuras:|r ", ...)
end

-- Force enable M33kAurasCompanion and Archive because some addon managers interfere with it
C_AddOns.EnableAddOn("M33kAurasCompanion")
C_AddOns.EnableAddOn("M33kAurasArchive")

local libsAreOk = true
do
  local StandAloneLibs = {
    "Archivist",
    "LibStub"
  }
  local LibStubLibs = {
    "CallbackHandler-1.0",
    "AceTimer-3.0",
    "AceSerializer-3.0",
    "AceComm-3.0",
    "LibSharedMedia-3.0",
    "LibDataBroker-1.1",
    "LibCompress",
    "SpellRange-1.0",
    "LibCustomGlow-1.0-m33kauras",
    "LibDBIcon-1.0",
    "LibGetFrame-1.0",
    "LibSerialize",
  }
  if M33kAuras.IsRetail() then
    tinsert(LibStubLibs, "LibSpecialization")
    AddonCompartmentFrame:RegisterAddon({
      text = AddonName,
      icon = "Interface\\AddOns\\M33kAuras\\Media\\Textures\\icon.blp",
      registerForAnyClick = true,
      notCheckable = true,
      func = function(button, menuInputData, menu)
        local mouseButton = menuInputData.buttonName
        if mouseButton == "LeftButton" then
          if IsShiftKeyDown() then
            if not (M33kAuras.IsOptionsOpen()) then
              M33kAuras.Toggle()
            end
          else
            M33kAuras.OpenOptions()
          end
        elseif mouseButton == "MiddleButton" then
          M33kAuras.ToggleMinimap()
        else
          M33kAurasProfilingFrame:Toggle()
        end
      end,
      funcOnEnter = function(button)
        MenuUtil.ShowTooltip(button, function(tooltip)
          M33kAuras.GenerateTooltip(true, tooltip)
        end)
      end,
      funcOnLeave = function(button)
        MenuUtil.HideTooltip(button)
      end,
    })
  end
  for _, lib in ipairs(StandAloneLibs) do
    if not lib then
        libsAreOk = false
        M33kAuras.prettyPrint("Missing library:", lib)
    end
  end
  if LibStub then
    for _, lib in ipairs(LibStubLibs) do
        if not LibStub:GetLibrary(lib, true) then
          libsAreOk = false
          M33kAuras.prettyPrint("Missing library:", lib)
        end
    end
  else
    libsAreOk = false
  end
end

function M33kAuras.IsLibsOK()
  return libsAreOk
end

if M33kAuras.BuildInfo < 120000 then
  libsAreOk = false
  StaticPopupDialogs["M33kAuras_OUTDATED_CLIENT_MIDNIGHT"] = {
    text = "This version of M33kAuras won't load on pre Midnight clients.",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    preferredIndex = 5,
  }
  StaticPopup_Show("M33kAuras_OUTDATED_CLIENT_MIDNIGHT")
  return
end

---@type M33kAurasSaved
M33kAurasSaved = M33kAurasSaved or {};
if (not next(M33kAurasSaved) or not (M33kAurasSaved and M33kAurasSaved.displays and next(M33kAurasSaved.displays))) and not M33kAurasSaved.migrationDisabled then
  C_AddOns.EnableAddOn("M33Auras")
  C_AddOns.LoadAddOn("M33Auras")
  if M33AurasSaved then
    M33kAurasSaved = CopyTable(M33AurasSaved)
    M33kAurasSaved.m33kMigrated = true
    C_AddOns.DisableAddOn("M33Auras")
    C_AddOns.DisableAddOn("WeakAuras")
  else
    C_AddOns.EnableAddOn("WeakAuras")
    C_AddOns.LoadAddOn("WeakAuras")
    if WeakAurasSaved then
      M33kAurasSaved = CopyTable(WeakAurasSaved)
      M33kAurasSaved.m33kMigrated = true
      C_AddOns.DisableAddOn("M33Auras")
      C_AddOns.DisableAddOn("WeakAuras")
    end
  end
end
if not M33kAurasSaved.m33kMigrated then
  if not M33kAurasSaved.migrationPromptCanceled then
    C_AddOns.EnableAddOn("M33Auras")
    C_AddOns.LoadAddOn("M33Auras")
  end
  local foundM33kAuras = false
  if type(M33AurasSaved) == "table" and type(M33AurasSaved.displays) == "table" and next(M33AurasSaved.displays) then
    libsAreOk = false
    StaticPopupDialogs["M33kAuras_MIGRATION_PROMPT"] = {
      text = "M33kAuras detected data from M33Auras. Do you want to migrate your settings from M33Auras to M33kAuras? This will delete existing settings for M33kAuras and cannot be undone.\n\nIf you will change your mind enable \"M33kAuras Settings Migration 2\" in addons list to see this prompt again.",
      button1 = YES or "Yes",
      button2 = NO or "No",
      showAlert = true,
      OnAccept = function()
        M33kAurasSaved = CopyTable(M33AurasSaved)
        M33kAurasSaved.m33kMigrated = true
        C_AddOns.DisableAddOn("M33Auras")
        C_AddOns.DisableAddOn("WeakAuras")
        C_UI.Reload()
      end,
      OnCancel = function()
        M33kAurasSaved.migrationPromptCanceled = true
        C_AddOns.DisableAddOn("M33Auras")
        C_AddOns.DisableAddOn("WeakAuras")
        C_UI.Reload()
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = false,
      preferredIndex = 5,
    }
    StaticPopup_Show("M33kAuras_MIGRATION_PROMPT")
    foundM33kAuras = true
  elseif not M33AurasSaved then
    C_AddOns.DisableAddOn("M33Auras")
  end

  if not foundM33kAuras then
    if not M33kAurasSaved.migrationPromptCanceled then
      C_AddOns.EnableAddOn("WeakAuras")
      C_AddOns.LoadAddOn("WeakAuras")
    end
    if type(WeakAurasSaved) == "table" and type(WeakAurasSaved.displays) == "table" and next(WeakAurasSaved.displays) then
      libsAreOk = false
      StaticPopupDialogs["M33kAuras_MIGRATION_PROMPT"] = {
        text = "M33kAuras detected data from WeakAuras. Do you want to migrate your settings from WeakAuras to M33kAuras? This will delete existing settings for M33kAuras and cannot be undone.\n\nIf you will change your mind enable \"M33kAuras Settings Migration\" in addons list to see this prompt again.",
        button1 = YES or "Yes",
        button2 = NO or "No",
        showAlert = true,
        OnAccept = function()
          M33kAurasSaved = CopyTable(WeakAurasSaved)
          M33kAurasSaved.m33Migrated = true
          C_AddOns.DisableAddOn("M33Auras")
          C_AddOns.DisableAddOn("WeakAuras")
          C_UI.Reload()
        end,
        OnCancel = function()
          M33kAurasSaved.migrationPromptCanceled = true
          C_AddOns.DisableAddOn("M33Auras")
          C_AddOns.DisableAddOn("WeakAuras")
          C_UI.Reload()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 5,
      }
      StaticPopup_Show("M33kAuras_MIGRATION_PROMPT")
    elseif not WeakAurasSaved then
      C_AddOns.DisableAddOn("WeakAuras")
    end
  end
end

if not libsAreOk then
  C_Timer.After(1, function()
    M33kAuras.prettyPrint("M33kAuras is missing necessary libraries. Please reinstall a proper package.")
  end)
end

-- These function stubs are defined here to reduce the number of errors that occur if M33kAuras.lua fails to compile
--- @type fun(regionType: string, createFunction: function, modifyFunction: function, defaults: table, properties: table|function|nil, validate: function?))
function Private.RegisterRegionType(_, _, _ ,_)
end

---@type fun(regionType: string, createOptions: function, icon: string|function, displayName: string, createThumbnail: function?, modifyThumbnail: function?, description: string?, templates: table?, getAnchors: function?)
---@diagnostic disable-next-line: duplicate-set-field
function Private.RegisterRegionOptions(_, _ , _ ,_ )
end

function Private.StartProfileSystem(_)
end

function Private.StartProfileAura(_)
end

function Private.StopProfileSystem(_)
end

function Private.StopProfileAura(_)
end

---@type fun()
function Private.StartProfileUID()
end

---@type fun()
function Private.StopProfileUID()
end

Private.ExecEnv = {}

-- If M33kAuras shuts down due to being installed on the wrong target, keep the bindings from erroring
--- @type fun(type: string)
---@diagnostic disable-next-line: duplicate-set-field
function M33kAuras.StartProfile(_)
end

---@diagnostic disable-next-line: duplicate-set-field
function M33kAuras.StopProfile()
end

---@diagnostic disable-next-line: duplicate-set-field
function M33kAuras.PrintProfile()
end

function M33kAuras.CountWagoUpdates()
  -- XXX this is to work around the Companion app trying to use our stuff!
  return 0
end

function M33kAuras.PurgeSecrets(tbl)
  for k, v in pairs(tbl) do
    if issecretvalue(v) then
      tbl[k] = nil
    end
  end
end

function M33kAuras.IsDurationObject(duration)
  local t = type(duration)
  if t == "userdata" and duration.GetRemainingDuration then
    return true
  end
  return false
end

function M33KAURAS_WIPE_ALL_SETTINGS()
  StaticPopupDialogs["M33KAURAS_WIPE_ALL_SETTINGS"] = {
      text = "Are you sure you want to wipe all settings for M33kAuras and disable settings migration from WeakAuras and M33Auras?\n\nThis action cannot be undone.",
      button1 = ACCEPT or "Yes",
      button2 = NO or "No",
      showAlert = true,
      OnAccept = function()
        C_AddOns.LoadAddOn("M33kAurasArchive")
        M33kAurasArchive = nil
        M33kAurasSaved = {
          migrationDisabled = true,
          migrationPromptCanceled = true,
          m33kMigrated = true,
        }

        C_UI.Reload()
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = false,
      preferredIndex = 5,
    }
  StaticPopup_Show("M33KAURAS_WIPE_ALL_SETTINGS")
end
