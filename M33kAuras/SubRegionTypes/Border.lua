if not M33kAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

local SharedMedia = LibStub("LibSharedMedia-3.0");
local L = M33kAuras.L;

local default = function(parentType)
  local options = {
    border_visible = true,
    border_color = {1, 1, 1, 1},
    border_edge = "Square Full White",
    border_offset = 0,
    border_size = 2,
  }
  if parentType == "aurabar" then
    options["anchor_area"] = "bar"
  end
  Private.subRegionPrototype.AddAlphaToDefault(options, "border")
  return options
end

local properties = {
  border_visible = {
    display = L["Visibility"],
    setter = "SetVisible",
    type = "bool",
    defaultProperty = true
  },
  border_color = {
    display = L["Color"],
    setter = "SetBorderColor",
    type = "color"
  },
}

Private.subRegionPrototype.AddAlphaProperties(properties, "border")
Private.subRegionPrototype.AddColorFromBooleanProperty(properties, "border", "border_color")


local function create()
  local region = CreateFrame("Frame", nil, UIParent, "BackdropTemplateM33kAuras")
  return region
end

local function onAcquire(subRegion)
  subRegion:Show()
end

local function onRelease(subRegion)
  subRegion:Hide()
end

local function modify(parent, region, parentData, data, first)
  region:SetParent(parent)


  if data.border_ppscale then -- hides/shows are required here to force a refresh of the region
    local pixelPerfectScale = PixelUtil.GetPixelToUIUnitFactor()
    region:ForEachPiece(function(pieceName, piece)
      piece:SetSnapToPixelGrid(false)
      if piece:GetTexelSnappingBias() ~= 0 then
        piece.originalSnappingBias = piece:GetTexelSnappingBias()
        piece:SetTexelSnappingBias(0)
      end

      piece:SetIgnoreParentScale(true)
      piece:SetScale(pixelPerfectScale)
      piece:Hide()
      piece:Show()
    end)

    region:SetIgnoreParentScale(true)
    region:SetScale(pixelPerfectScale)
    region:Hide()
    region:Show()
  else

    region:ForEachPiece(function(pieceName, piece)
      piece:SetSnapToPixelGrid(true)
      if piece.originalSnappingBias then
        piece:SetTexelSnappingBias(piece.originalSnappingBias)
        piece.originalSnappingBias = nil
      end

      piece:SetIgnoreParentScale(false)
      piece:SetScale(1)
      piece:Hide()
      piece:Show()
    end)

    region:SetIgnoreParentScale(false)
    region:SetScale(1)
    region:Hide()
    region:Show()
  end



  local edgeFile = SharedMedia:Fetch("border", data.border_edge)
  if edgeFile and edgeFile ~= "" then
    region:SetBackdrop({
      edgeFile = edgeFile,
      edgeSize = data.border_size,
      bgFile = nil,
    })
    region:SetBackdropBorderColor(data.border_color[1], data.border_color[2],
                                  data.border_color[3], data.border_color[4])
    region:SetBackdropColor(0, 0, 0, 0)
  end

  function region:SetBorderColor(r, g, b, a)
    self:SetBackdropBorderColor(r, g, b, a or 1)
  end

  region:SetBorderColor(data.border_color[1], data.border_color[2], data.border_color[3], data.border_color[4]);

  function region:SetVisible(visible)
    if visible then
      self:Show()
    else
      self:Hide()
    end
  end

  region:SetAlpha(1)
  region:SetVisible(data.border_visible)

  region.Anchor = function()
    parent:AnchorSubRegion(region, "area", parentData.regionType == "aurabar" and data.anchor_area or nil,
                           nil, data.border_offset, data.border_offset)
  end
end

local function supports(regionType)
  return regionType == "texture"
         or regionType == "progresstexture"
         or regionType == "icon"
         or regionType == "aurabar"
         or regionType == "empty"
end

M33kAuras.RegisterSubRegionType("subborder", L["Border"], supports, create, modify, onAcquire, onRelease,
                                default, nil, properties)
