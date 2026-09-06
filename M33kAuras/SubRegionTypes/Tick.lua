if not M33kAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

local L = M33kAuras.L;

local default = function()
  local d = {
    tick_visible = true,
    tick_color = {1, 1, 1, 1},
    tick_placement_mode = "AtValue",
    tick_placements = {"50"},
    progressSources = {{-2, ""}},
    automatic_length = true,
    tick_thickness = 2,
    tick_length = 30,
    use_texture = false,
    tick_texture = [[Interface\CastingBar\UI-CastingBar-Spark]],
    tick_blend_mode = "ADD",
    tick_desaturate = false,
    tick_rotation = 0,
    tick_xOffset = 0,
    tick_yOffset = 0,
    tick_mirror = false,
  }
  Private.subRegionPrototype.AddAlphaToDefault(d, "tick")
  return d
end

local properties = {
  tick_visible = {
    display = L["Visibility"],
    setter = "SetVisible",
    type = "bool",
    defaultProperty = true,
  },
  tick_color = {
    display = L["Color"],
    setter = "SetTickColor",
    type = "color",
  },
  tick_placement_mode = {
    display = L["Placement Mode"],
    setter = "SetTickPlacementMode",
    type = "list",
    values = Private.tick_placement_modes,
  },
  automatic_length = {
    display = L["Automatic Length"],
    setter = "SetAutomaticLength",
    type = "bool",
    defaultProperty = true,
  },
  tick_thickness = {
    display = L["Thickness"],
    setter = "SetTickThickness",
    type = "number",
    min = 0,
    bigStep = 1,
    default = 2,
  },
  tick_length = {
    display = L["Length"],
    setter = "SetTickLength",
    type = "number",
    min = 0,
    bigStep = 1,
    default = 30,
  },
  tick_desaturate = {
    display = L["Desaturate"],
    setter = "SetTickDesaturated",
    type = "bool",
    default = true,
  },
  tick_rotation = {
    display = L["Rotation"],
    setter = "SetTickRotation",
    type = "number",
    min = 0,
    max = 360,
    default = 0,
  },
  tick_mirror = {
    display = L["Mirror"],
    setter = "SetTickMirror",
    type = "bool",
    default = true,
  },
  tick_use_texture = {
    display = L["Use Texture"],
    setter = "SetUseTexture",
    type = "bool",
    default = true,
  },
  tick_texture = {
    display = L["Texture"],
    setter = "SetTexture",
    type = "texture"
  },
}

Private.subRegionPrototype.AddAlphaProperties(properties, "tick")
Private.subRegionPrototype.AddColorFromBooleanProperty(properties, "tick", "tick_color")


local function GetProperties(parentData, data)
  local result = CopyTable(properties)
  for i in ipairs(data.tick_placements) do

    result["tick_placements." .. i] = {
      display = #data.tick_placements > 1 and L["Placement %i"]:format(i) or L["Placement"],
      setter = "SetTickPlacementAt",
      type = "number",
      arg1 = i,
      validate = M33kAuras.ValidateNumeric,
    }
  end

  return result
end

local auraBarAnchor = {
  ["HORIZONTAL"] = "LEFT",
  ["HORIZONTAL_INVERSE"] = "RIGHT",
  ["VERTICAL"] = "TOP",
  ["VERTICAL_INVERSE"] = "BOTTOM",
}

local auraBarAnchorInverse = {
  ["HORIZONTAL"] = "RIGHT",
  ["HORIZONTAL_INVERSE"] = "LEFT",
  ["VERTICAL"] = "BOTTOM",
  ["VERTICAL_INVERSE"] = "TOP",
}

local function create()
  local subRegion = CreateFrame("Frame", nil, UIParent)
  subRegion.ticks = {}
  subRegion.positionBars = {}
  local setFrameLevel = subRegion.SetFrameLevel
  subRegion.SetFrameLevel = function(self, level)
    setFrameLevel(self, level)
    for _, bar in pairs(self.positionBars) do
      bar.clipFrame:SetFrameLevel(level)
      bar.tickFrame:SetFrameLevel(level)
    end
  end
  return subRegion
end

local function usableNumber(value)
  if type(value) ~= "number" then return false end
  if issecretvalue(value) then
    return true
  end
  return value == value and value > -math.huge and value < math.huge
end

local function createPositionBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetStatusBarTexture("Interface\\AddOns\\M33kAuras\\Media\\Textures\\Square_FullWhite")
  bar:SetAlpha(0)
  return bar
end

local function resetPositionBar(self, i)
  local bar = self.positionBars[i]
  if bar and bar.positionActive then
    bar.positionActive = nil
    bar:Hide()
    bar:ClearAllPoints()
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    if bar.offsetBar then
      bar.offsetBar:Hide()
      bar.offsetBar:ClearAllPoints()
      bar.offsetBar:SetMinMaxValues(0, 1)
      bar.offsetBar:SetValue(0)
    end
    bar.clipFrame:Hide()
    self.ticks[i]:SetParent(self)
  end
end

local function onAcquire(subRegion)
  subRegion:Show()
end

local function onRelease(subRegion)
  if subRegion.parent then
    subRegion.parent.subRegionEvents:RemoveSubscriber("FrameTick", subRegion)
    subRegion.parent.subRegionEvents:RemoveSubscriber("UpdateProgress", subRegion)
    subRegion.parent.subRegionEvents:RemoveSubscriber("OrientationChanged", subRegion)
    subRegion.parent.subRegionEvents:RemoveSubscriber("InverseChanged", subRegion)
    subRegion.parent.subRegionEvents:RemoveSubscriber("OnRegionSizeChanged", subRegion)
  end
  subRegion.FrameTick = nil
  for i, tick in ipairs(subRegion.ticks) do
    tick:Hide()
    tick:ClearAllPoints()
    resetPositionBar(subRegion, i)
  end
  subRegion.hasProgress = {}
  subRegion.progressData = {}
  subRegion.nativeProgressData = {}
  subRegion:Hide()
end

local funcs = {
  UpdateProgress = function(self, state, states)
    for i, progressSource in ipairs(self.progressSources) do
      self.progressData[i] = {}
      local native = {}
      self.nativeProgressData[i] = native
      Private.ReadProgressSource(native, progressSource, state, states, self.parent)
      if native.progressType ~= "durationObject"
        and not hasanysecretvalues(native.value, native.expirationTime)
        and not native.hasSecretTimerState
      then
        Private.UpdateProgressFrom(self.progressData[i], progressSource, {}, state, states, self.parent)
      end
    end
    self:UpdateVisible()
    self:UpdateTickPlacement();
    self:UpdateFrameTick()
  end,
  OrientationChanged = function(self)
    self.orientation = self.parent:GetEffectiveOrientation()
    self.vertical = (self.orientation == "VERTICAL") or (self.orientation == "VERTICAL_INVERSE")

    self:UpdateTickPlacement()
    self:UpdateTickSize()
  end,
  OnRegionSizeChanged = function(self)
    if self.vertical then
      self.parentMinorSize, self.parentMajorSize = self.parent.bar:GetRealSize()
    else
      self.parentMajorSize, self.parentMinorSize = self.parent.bar:GetRealSize()
    end

    self:UpdateTickPlacement()
    self:UpdateTickSize()
  end,
  InverseChanged = function(self)
    self.inverse_direction = self.parent:GetInverse()
    self:UpdateTickPlacement()
  end,
  SetVisible = function(self, visible)
    if self.tick_visible ~= visible then
      self.tick_visible = visible
      self:UpdateVisible()
    end
  end,
  UpdateVisibleOne = function(self, i)
    if self.tick_visible and self.hasProgress[i] then
      self.ticks[i]:Show()
    else
      self.ticks[i]:Hide()
    end
  end,
  UpdateVisible = function(self)
    for i in ipairs(self.ticks) do
      self:UpdateVisibleOne(i)
    end
  end,
  SetTickColor = function(self, r, g, b, a)
    self.tick_color[1], self.tick_color[2], self.tick_color[3], self.tick_color[4] = r, g, b, a or 1
    if self.use_texture then
      for _, tick in ipairs(self.ticks) do
        tick:SetVertexColor(r, g, b, a or 1)
      end
      self:UpdateTickDesaturated()
    else
      for _, tick in ipairs(self.ticks) do
        tick:SetVertexColor(r, g, b, a or 1)
        tick:SetColorTexture(r, g, b, a or 1)
      end
    end
  end,
  SetTickPlacementMode = function(self, placement_mode)
    if self.tick_placement_mode ~= placement_mode then
      self.tick_placement_mode = placement_mode
      self:UpdateTickPlacement()
      self:UpdateVisible()
      self:UpdateFrameTick()
    end
  end,
  UpdateFrameTick = function(self)
    local requiresFrameTick = false
    if self.tick_placement_mode == "ValueOffset" then
      for i, progress in ipairs(self.progressData) do
        if progress.progressType == "timed" and not progress.paused then
          requiresFrameTick = true
          break
        end
      end
    end

    if requiresFrameTick then
      if not self.FrameTick then
        self.FrameTick = self.UpdateTickPlacement
        self.parent.subRegionEvents:AddSubscriber("FrameTick", self)
      end
    else
      if self.FrameTick then
        self.FrameTick = nil
        self.parent.subRegionEvents:RemoveSubscriber("FrameTick", self)
      end
    end
  end,
  SetTickPlacementAt = function(self, tick, placement)
    placement = tonumber(placement)
    if self.tick_placements[tick] ~= placement then
      self.tick_placements[tick] = placement
      self:UpdateTickPlacementOne(tick)
    end
  end,
  -- For backwards compability
  SetTickPlacement = function(self, placement)
    self:SetTickPlacementAt(1, placement)
  end,
  UpdateTickPlacement = function(self)
    for i in ipairs(self.tick_placements) do
      self:UpdateTickPlacementOne(i)
    end
  end,
  UpdateTickPlacementOne = function(self, i)
    if self.tick_placement_mode == "AtTimestamp" then
      self:UpdateTimestampTickPlacement(i)
      return
    end
    local durationProgress = self.parent.progressType == "durationObject"
    if durationProgress and not M33kAuras.IsDurationObject(self.parent.durationObject) then
      self:HideNativeTick(i)
      return
    end
    local offsetx, offsety = 0, 0
    local width = self.parentMajorSize

    local minValue, maxValue = self.parent:GetMinMaxProgress()
    local native = self.nativeProgressData[i]
    if durationProgress or hasanysecretvalues(minValue, maxValue)
      or (self.tick_placement_mode == "ValueOffset" and native and hasanysecretvalues(native.value, native.expirationTime))
    then
      self:UpdateNativeTickPlacement(i, minValue, maxValue)
      return
    end
    resetPositionBar(self, i)
    local valueRange = maxValue - minValue
    local inverse = self.inverse_direction

    if self.parent.inverse then
      inverse = not inverse
    end

    local tick_placement
    if self.tick_placement_mode == "AtValue" then
      tick_placement = self.tick_placements[i]
    elseif self.tick_placement_mode == "AtMissingValue" then
      tick_placement = maxValue - self.tick_placements[i]
    elseif self.tick_placement_mode == "AtPercent" then
      if self.tick_placements[i] >= 0 and self.tick_placements[i] <= 100 and maxValue then
        tick_placement = minValue + self.tick_placements[i] * valueRange / 100
      end
    elseif self.tick_placement_mode == "ValueOffset" then
      if maxValue ~= 0 and self.progressData[i] then
        if self.progressData[i].progressType == "timed" then
          if self.progressData[i].paused then
            if self.progressData[i].remaining then
              tick_placement = self.progressData[i].remaining + self.tick_placements[i]
            end
          else
            tick_placement = self.progressData[i].expirationTime - GetTime() + self.tick_placements[i]
          end
        elseif self.progressData[i].progressType == "static" and not issecretvalue(self.progressData[i].value) then
          tick_placement = self.progressData[i].value + self.tick_placements[i]
        end
      end
    end

    local offset
    local percent = valueRange ~= 0 and tick_placement and (tick_placement - minValue) / valueRange
    if not percent or (percent and percent < 0 or percent > 1) then
      offset = 0
      self.hasProgress[i] = false
    else
      offset = percent * width
      self.hasProgress[i] = true
    end
    self:UpdateVisible(i)

    if (self.orientation == "HORIZONTAL_INVERSE") or (self.orientation == "VERTICAL") then
      offset = -offset
    end

    if inverse then
      offset = -offset
    end

    if (self.vertical) then
      offsety = offset
    else
      offsetx = offset
    end
    local side = inverse and auraBarAnchorInverse or auraBarAnchor
    self.ticks[i]:ClearAllPoints()
    self.ticks[i]:SetPoint("CENTER", self.parent.bar, side[self.orientation],
                       offsetx + self.tick_xOffset,
                       offsety + self.tick_yOffset)
  end,
  HideNativeTick = function(self, i)
    self.hasProgress[i] = false
    self:UpdateVisibleOne(i)
    self.ticks[i]:ClearAllPoints()
    resetPositionBar(self, i)
  end,
  UpdateTimestampTickPlacement = function(self, i)
    local progress = self.nativeProgressData[i]
    local tickTime
    if progress then
      if progress.progressType == "static" then
        tickTime = progress.value
      elseif progress.progressType == "timed" then
        tickTime = progress.expirationTime
      elseif progress.progressType == "durationObject" and M33kAuras.IsDurationObject(progress.durationObject) then
        tickTime = progress.durationObject:GetEndTime()
      end
    end
    if self.parent.progressType == "durationObject" then
      local durationObject = self.parent.durationObject
      if not M33kAuras.IsDurationObject(durationObject) then
        self:HideNativeTick(i)
        return
      end
      local minValue, maxValue = self.parent:GetMinMaxProgress()
      self:PlaceNativeTick(i, tickTime, self.tick_placements[i], true, minValue, maxValue, durationObject)
    elseif self.parent.progressType == "timed" and self.parent.secretProgress ~= "value"
      and not hasanysecretvalues(self.parent.expirationTime, self.parent.duration)
      and usableNumber(self.parent.expirationTime) and usableNumber(self.parent.duration)
      and self.parent.duration > 0
    then
      -- The interval stays fixed between state updates, including while paused.
      self:PlaceNativeTick(i, tickTime, self.tick_placements[i], true,
                          self.parent.expirationTime - self.parent.duration, self.parent.expirationTime)
    else
      self:HideNativeTick(i)
    end
  end,
  UpdateNativeTickPlacement = function(self, i, minValue, maxValue)
    local mode = self.tick_placement_mode
    local value, offset, reverse = self.tick_placements[i], 0, false
    if issecretvalue(value) or not usableNumber(value) then
      self:HideNativeTick(i)
      return
    end
    local rangeMin, rangeMax = minValue, maxValue
    local followParent = false
    if mode == "AtPercent" then
      if value < 0 or value > 100 then
        self:HideNativeTick(i)
        return
      end
      rangeMin, rangeMax = 0, 100
    elseif mode == "AtMissingValue" then
      if issecretvalue(maxValue) then
        -- Reversing a zero-based range represents max - value without secret arithmetic.
        if issecretvalue(minValue) or minValue ~= 0 then
          self:HideNativeTick(i)
          return
        end
        reverse = true
      else
        value = maxValue - value
      end
    elseif mode == "ValueOffset" then
      local native, progress = self.nativeProgressData[i], self.progressData[i]
      offset = value
      value = nil
      if native and native.progressType == "static" then
        value = native.value
      elseif native and native.progressType == "durationObject" and self.parent.progressType == "durationObject"
        and native.durationObject == self.parent.durationObject
      then
        -- Other duration objects would need rescaling to the parent's total.
        value, followParent = 0, true
      elseif native and not native.hasSecretTimerState
        and (native.progressType == "elapsedTimer" or (native.progressType == "timed"
          and usableNumber(native.expirationTime) and not issecretvalue(native.expirationTime)))
        and progress and progress.progressType == "timed"
      then
        value = progress.paused and progress.remaining or progress.expirationTime - GetTime()
      end
    elseif mode ~= "AtValue" then
      self:HideNativeTick(i)
      return
    end
    self:PlaceNativeTick(i, value, offset, reverse, rangeMin, rangeMax, nil, followParent)
  end,
  PlaceNativeTick = function(self, i, value, offset, reverse, minValue, maxValue, timestampObject, followParent)
    if not usableNumber(value) or issecretvalue(offset) or not usableNumber(offset) then
      self:HideNativeTick(i)
      return
    end
    if not hasanysecretvalues(minValue, maxValue) and maxValue <= minValue then
      self:HideNativeTick(i)
      return
    end
    if offset ~= 0 and not followParent and not issecretvalue(value) then
      value = value + offset
      offset = 0
    end
    if not usableNumber(value) then
      self:HideNativeTick(i)
      return
    end

    local span
    if offset ~= 0 then
      if not hasanysecretvalues(minValue, maxValue) then
        span = maxValue - minValue
      elseif not issecretvalue(minValue) and minValue == 0 then
        span = maxValue
      else
        self:HideNativeTick(i)
        return
      end
    end
    local positionBar = self:GetPositionBar(i)
    if timestampObject then
      positionBar:SetMinMaxValues(timestampObject:GetStartTime(), timestampObject:GetEndTime())
    else
      positionBar:SetMinMaxValues(minValue, maxValue)
    end
    if offset ~= 0 then
      local offsetBar = self:GetOffsetBar(positionBar)
      offsetBar:SetMinMaxValues(0, span)
    end
    self:AnchorNativeTick(i, value, offset, reverse, followParent)
  end,
  GetPositionBar = function(self, i)
    local positionBar = self.positionBars[i]
    if not positionBar then
      positionBar = createPositionBar(self)
      -- Keep the tick outside the transparent positioning bars to avoid inheriting their alpha.
      positionBar.clipFrame = CreateFrame("Frame", nil, self)
      positionBar.clipFrame:SetClipsChildren(true)
      positionBar.tickFrame = CreateFrame("Frame", nil, positionBar.clipFrame)
      positionBar.tickFrame:SetAllPoints(positionBar.clipFrame)
      self.positionBars[i] = positionBar
    end
    return positionBar
  end,
  GetOffsetBar = function(self, positionBar)
    if not positionBar.offsetBar then
      positionBar.offsetBar = createPositionBar(self)
    end
    return positionBar.offsetBar
  end,
  AnchorNativeTick = function(self, i, value, offset, reverse, followParent)
    local positionBar = self.positionBars[i]
    positionBar:ClearAllPoints()
    positionBar:SetAllPoints(self.parent.bar)
    local inverse = self.inverse_direction
    if reverse then
      inverse = not inverse
    end
    if self.parent.inverse then
      inverse = not inverse
    end
    local side = inverse and auraBarAnchorInverse or auraBarAnchor
    local endSide = inverse and auraBarAnchor or auraBarAnchorInverse
    local startEdge = side[self.orientation]
    local endEdge = endSide[self.orientation]
    positionBar:SetOrientation(self.vertical and "VERTICAL" or "HORIZONTAL")
    positionBar:SetReverseFill(startEdge == "RIGHT" or startEdge == "TOP")
    positionBar:SetValue(value)
    positionBar.positionActive = true
    positionBar:Show()
    local anchor = positionBar:GetStatusBarTexture()
    local anchorEdge = endEdge
    if followParent then
      anchor, anchorEdge = self.parent:GetNativeProgressAnchor()
      if not anchor then
        self:HideNativeTick(i)
        return
      end
    end
    if offset ~= 0 then
      local offsetBar = positionBar.offsetBar
      -- Each bar clamps independently; clipping only removes the final overflow.
      offsetBar:ClearAllPoints()
      offsetBar:SetSize(self.parent.bar:GetRealSize())
      local offsetStart, offsetEnd = startEdge, endEdge
      if offset < 0 then
        offsetStart, offsetEnd = endEdge, startEdge
      end
      offsetBar:SetOrientation(self.vertical and "VERTICAL" or "HORIZONTAL")
      offsetBar:SetReverseFill(offsetStart == "RIGHT" or offsetStart == "TOP")
      offsetBar:SetPoint(offsetStart, anchor, anchorEdge)
      offsetBar:SetValue(math.abs(offset))
      offsetBar:Show()
      anchor, anchorEdge = offsetBar:GetStatusBarTexture(), offsetEnd
    elseif positionBar.offsetBar then
      positionBar.offsetBar:Hide()
      positionBar.offsetBar:ClearAllPoints()
      positionBar.offsetBar:SetMinMaxValues(0, 1)
      positionBar.offsetBar:SetValue(0)
    end
    self:UpdateNativeClip(i)
    positionBar.clipFrame:SetFrameLevel(self:GetFrameLevel())
    positionBar.tickFrame:SetFrameLevel(self:GetFrameLevel())
    positionBar.clipFrame:Show()
    self.ticks[i]:SetParent(positionBar.tickFrame)
    self.ticks[i]:ClearAllPoints()
    self.ticks[i]:SetPoint("CENTER", anchor, anchorEdge,
                          self.tick_xOffset, self.tick_yOffset)
    self.hasProgress[i] = true
    self:UpdateVisibleOne(i)
  end,
  UpdateNativeClip = function(self, i)
    local positionBar = self.positionBars[i]
    if not positionBar or not positionBar.positionActive then return end
    local clip = positionBar.clipFrame
    clip:ClearAllPoints()
    -- Clip only the progress axis, allowing for tick length, rotation and offsets.
    local width, height = self.parent.bar:GetRealSize()
    local minorSize = self.vertical and width or height
    local length = self.automatic_length and minorSize or self.tick_length
    local margin = math.abs(length) + math.abs(self.tick_thickness)
      + math.abs(self.tick_xOffset) + math.abs(self.tick_yOffset)
    if self.vertical then
      clip:SetPoint("BOTTOMLEFT", self.parent.bar, "BOTTOMLEFT", -margin, 0)
      clip:SetPoint("TOPRIGHT", self.parent.bar, "TOPRIGHT", margin, 0)
    else
      clip:SetPoint("BOTTOMLEFT", self.parent.bar, "BOTTOMLEFT", 0, -margin)
      clip:SetPoint("TOPRIGHT", self.parent.bar, "TOPRIGHT", 0, margin)
    end
  end,
  SetAutomaticLength = function(self, automatic_length)
    if self.automatic_length ~= automatic_length then
      self.automatic_length = automatic_length
      self:UpdateTickSize()
    end
  end,
  SetTickThickness = function(self, thickness, forced)
    if self.tick_thickness ~= thickness then
      self.tick_thickness = thickness
      self:UpdateTickSize()
    end
  end,
  SetTickLength = function(self, length, forced)
    if self.length ~= length then
      self.tick_length = length
      self:UpdateTickSize()
    end
  end,
  UpdateTickSize = function(self)
    for i in ipairs(self.ticks) do
      self:UpdateNativeClip(i)
    end
    if self.vertical then
      for i, tick in ipairs(self.ticks) do
        tick:SetHeight(self.tick_thickness)
      end
    else
      for i, tick in ipairs(self.ticks) do
        tick:SetWidth(self.tick_thickness)
      end
    end

    local length = self.automatic_length and self.parentMinorSize or self.tick_length
    local width, height = self.parent.bar:GetRealSize()
    local nativeLength = self.automatic_length and (self.vertical and width or height) or self.tick_length
    if self.vertical then
      for i, tick in ipairs(self.ticks) do
        tick:SetWidth(self.positionBars[i] and self.positionBars[i].positionActive and nativeLength or length)
      end
    else
      for i, tick in ipairs(self.ticks) do
        tick:SetHeight(self.positionBars[i] and self.positionBars[i].positionActive and nativeLength or length)
      end
    end
  end,
  SetTickDesaturated = function(self, desaturate)
    if self.use_texture and self.tick_desaturate ~= desaturate then
      self.tick_desaturate = desaturate
      self:UpdateTickDesaturated()
    end
  end,
  UpdateTickDesaturated = function(self)
    for i, tick in ipairs(self.ticks) do
      tick:SetDesaturated(self.tick_desaturate)
    end
  end,
  SetTickRotation = function(self, degrees)
    if self.tick_rotation ~= degrees then
      self.tick_rotation = degrees
      self:UpdateTickRotation()
    end
  end,
  UpdateTickRotation = function(self)
    local rad = math.rad(self.tick_rotation)
    for _, tick in ipairs(self.ticks) do
      tick:SetRotation(rad)
    end
  end,
  SetTickMirror = function(self, mirror)
    if self.mirror ~= mirror then
      self.mirror = mirror
      self:UpdateTickMirror()
    end
  end,
  UpdateTickMirror = function(self)
    if self.mirror then
      for _, tick in ipairs(self.ticks) do
        tick:SetTexCoord(0,  1,  1,  1,  0,  0,  1,  0)
      end
    else
      for _, tick in ipairs(self.ticks) do
        tick:SetTexCoord(0,  0,  1,  0,  0,  1,  1,  1)
      end
    end
  end,
  SetTickBlendMode = function(self, mode)
    if self.tick_blend_mode ~= mode then
      self.tick_blend_mode = mode
      self:UpdateTickBlendMode()
    end
  end,
  UpdateTickBlendMode = function(self)
    if self.use_texture then
      for _, tick in ipairs(self.ticks) do
        tick:SetBlendMode(self.tick_blend_mode)
      end
    else
      for _, tick in ipairs(self.ticks) do
        tick:SetBlendMode("BLEND")
      end
    end
  end,
  UpdateTexture = function(self)
    if self.use_texture then
      for _, tick in ipairs(self.ticks) do
        Private.SetTextureOrAtlas(tick, self.tick_texture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      end
    else
      for _, tick in ipairs(self.ticks) do
        tick:SetColorTexture(self.tick_color[1], self.tick_color[2], self.tick_color[3], self.tick_color[4])
      end
    end
  end,
  SetTexture = function(self, texture)
    if self.tick_texture == texture then
      return
    end
    self.tick_texture = texture
    self:UpdateTexture()
  end,
  SetUseTexture = function(self, use)
    if self.use_texture == use then
      return
    end
    self.use_texture = use
    self:UpdateTexture()
  end,

  AnchorSubRegion = function(self, subRegion, anchorType, anchorPoint, subRegionPoint, anchorXOffset, anchorYOffset)
    subRegion:ClearAllPoints()

    if anchorType == "point" then
      local xOffset = anchorXOffset or 0
      local yOffset = anchorYOffset or 0

      subRegionPoint = Private.point_types[subRegionPoint] and subRegionPoint or "CENTER"
      local tickIndex = tonumber(anchorPoint:sub(6))
      local anchorTo = tickIndex and self.ticks[tickIndex] or nil
      if anchorTo then
        subRegion:SetPoint(subRegionPoint, anchorTo, "CENTER", xOffset, yOffset)
      end
    else
      local tickIndex = tonumber(anchorPoint:sub(10))
      local anchorTo = tickIndex and self.ticks[tickIndex] or nil
      local xOffset = anchorXOffset or 0
      local yOffset = anchorYOffset or 0
      if anchorTo then
        subRegion:SetPoint("BOTTOMLEFT", anchorTo, "BOTTOMLEFT", -xOffset, -yOffset)
        subRegion:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", xOffset,  yOffset)
      end
    end
  end
}

local function modify(parent, region, parentData, data, first)
  onRelease(region)
  region:SetParent(parent)
  region.orientation = parent.effectiveOrientation
  region.inverse_direction = parentData.inverse
  region.inverse = false
  region.vertical = region.orientation == "VERTICAL" or region.orientation == "VERTICAL_INVERSE"
  if (region.vertical) then
    region.parentMinorSize, region.parentMajorSize = parent.bar:GetRealSize()
  else
    region.parentMajorSize, region.parentMinorSize = parent.bar:GetRealSize()
  end

  region.parent = parent
  region.parentData = parentData
  region.tick_visible = data.tick_visible
  region.tick_color = CopyTable(data.tick_color)
  region.tick_placement_mode = data.tick_placement_mode
  region.tick_placements = {}
  region.progressSources = {}
  region.progressData = {}
  for i, tick_placement in ipairs(data.tick_placements) do
    local value = tonumber(tick_placement)
    if value then
      -- Keep sources available when conditions switch into either source mode.
      local progressSource = Private.AddProgressSourceMetaData(parentData,
        data.progressSources and data.progressSources[i] or {-2, ""})
      tinsert(region.tick_placements, value)
      tinsert(region.progressSources, progressSource or {})
    end

    if region.ticks[i] == nil then
      local texture = region:CreateTexture()
      texture:SetSnapToPixelGrid(false)
      texture:SetTexelSnappingBias(0)
      texture:SetDrawLayer("ARTWORK", 3)
      texture:SetAllPoints()
      region.ticks[i] = texture
    end
  end

  for i = #data.tick_placements + 1, #region.ticks do
    region.ticks[i]:Hide()
  end

  region.automatic_length = data.automatic_length
  region.tick_thickness = data.tick_thickness
  region.tick_length = data.tick_length
  region.use_texture = data.use_texture
  region.tick_texture = data.tick_texture

  region.tick_xOffset = data.tick_xOffset
  region.tick_yOffset = data.tick_yOffset

  region.hasProgress = {}

  for k, v in pairs(funcs) do
    region[k] = v
  end

  if data.use_texture then
    for _, tick in ipairs(region.ticks) do
      Private.SetTextureOrAtlas(tick, data.tick_texture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
  end

  region:SetAlpha(1)
  region:SetVisible(data.tick_visible)
  region:SetTickColor(unpack(data.tick_color))
  region:SetTickDesaturated(data.tick_desaturate)
  region:SetTickBlendMode(data.tick_blend_mode)
  region:SetTickRotation(data.tick_rotation)
  region:SetTickMirror(data.tick_mirror)

  region:UpdateTickPlacement()
  region:UpdateTickSize()
  region:UpdateVisible()
  region:Show()

  parent.subRegionEvents:AddSubscriber("UpdateProgress", region)
  parent.subRegionEvents:AddSubscriber("OrientationChanged", region)
  parent.subRegionEvents:AddSubscriber("InverseChanged", region)
  parent.subRegionEvents:AddSubscriber("OnRegionSizeChanged", region)

  region.FrameTick = nil
  region:ClearAllPoints()
  region:SetAllPoints(parent.bar)
end

local function supports(regionType)
  return regionType == "aurabar"
end

M33kAuras.RegisterSubRegionType("subtick", L["Tick"], supports, create, modify, onAcquire, onRelease,
                                default, nil, GetProperties);
