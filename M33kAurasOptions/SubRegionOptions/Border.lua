if not M33kAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

local L = M33kAuras.L;

local function createOptions(parentData, data, index, subIndex)
  local areaAnchors = {}
  for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
    Mixin(areaAnchors, OptionsPrivate.Private.GetAnchorsForData(child, "area"))
  end

  local options = {
    __title = L["Border %s"]:format(subIndex),
    __order = 1,
    border_visible = {
      type = "toggle",
      width = M33kAuras.doubleWidth,
      name = L["Show Border"],
      order = 2,
    },
    border_edge = {
      type = "select",
      width = M33kAuras.normalWidth,
      dialogControl = "LSM30_Border",
      name = L["Border Style"],
      order = 3,
      values = AceGUIWidgetLSMlists.border,
    },
    border_color = {
      type = "color",
      width = M33kAuras.normalWidth,
      name = L["Border Color"],
      hasAlpha = true,
      order = 4,
    },
    border_offset = {
      type = "range",
      control = "M33kAurasSpinBox",
      width = M33kAuras.normalWidth,
      name = L["Border Offset"],
      order = 5,
      softMin = 0,
      softMax = 32,
      bigStep = 1,
    },
    border_size = {
      type = "range",
      control = "M33kAurasSpinBox",
      width = M33kAuras.normalWidth,
      name = L["Border Size"],
      order = 6,
      min = 1,
      softMax = 64,
      bigStep = 1,
    },
    anchor_area = {
      type = "select",
      width = M33kAuras.normalWidth,
      control = "M33kAurasTwoColumnDropdown",
      name = L["Border Anchor"],
      order = 7,
      values = areaAnchors,
      hidden = function() return parentData.regionType ~= "aurabar" end
    },
    border_ppscale = {
      type = "toggle",
      width = M33kAuras.doubleWidth,
      name = L["Force pixel perfect scale"],
      order = 8,
    }
  }

  OptionsPrivate.AddUpDownDeleteDuplicate(options, parentData, index, "subborder")

  return options
end

M33kAuras.RegisterSubRegionOptions("subborder", createOptions, L["Shows a border"]);
