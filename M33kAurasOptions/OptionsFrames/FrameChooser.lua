if not M33kAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

-- Lua APIs
local pairs = pairs

-- WoW APIs
local CreateFrame, IsMouseButtonDown, SetCursor, ResetCursor
  = CreateFrame, IsMouseButtonDown, SetCursor, ResetCursor

---@class M33kAuras
local M33kAuras = M33kAuras
local L = M33kAuras.L

local frameChooserFrame
local frameChooserBox

local oldFocus
local oldFocusName

-- if frame doesn't have a name, try to use the key from it's parent
local function recurseGetName(frame)
  local name = frame.GetName and frame:GetName() or nil
  if name then
     return name
  end
  local parent = frame.GetParent and frame:GetParent()
  if parent then
     for key, child in pairs(parent) do
        if child == frame then
           return (recurseGetName(parent) or "") .. "." .. key
        end
     end
  end
end

function OptionsPrivate.StartFrameChooser(data, path)
  local frame = OptionsPrivate.Private.OptionsFrame();
  if not(frameChooserFrame) then
    frameChooserFrame = CreateFrame("Frame");
    frameChooserBox = CreateFrame("Frame", nil, frameChooserFrame, "BackdropTemplateM33kAuras");
    frameChooserBox:SetFrameStrata("TOOLTIP");
    frameChooserBox:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = {left = 0, right = 0, top = 0, bottom = 0}
    });
    frameChooserBox:SetBackdropBorderColor(0, 1, 0);
    frameChooserBox:Hide();
  end
  local givenValue = OptionsPrivate.Private.ValueFromPath(data, path);

  frameChooserFrame:SetScript("OnUpdate", function()
    if(IsMouseButtonDown("RightButton")) then
      OptionsPrivate.Private.ValueToPath(data, path, givenValue);
      OptionsPrivate.StopFrameChooser(data);
      M33kAuras.FillOptions()
    elseif(IsMouseButtonDown("LeftButton") and oldFocusName) then
      OptionsPrivate.StopFrameChooser(data);
    else
      SetCursor("CAST_CURSOR");

      local focus
      if GetMouseFoci then
        local foci = GetMouseFoci()
        focus = foci[1] or nil
      end
      local focusName;

      if(focus) then
        focusName = recurseGetName(focus)
        if(focusName == "WorldFrame" or not focusName) then
          focusName = nil;
          local focusIsGroup = false;
          for id, regionData in pairs(OptionsPrivate.Private.regions) do
            if(regionData.region and regionData.region:IsVisible() and regionData.region:IsMouseOver()) then
              local isGroup = regionData.regionType == "group" or regionData.regionType == "dynamicgroup";
              if (not focusName or (not isGroup and focusIsGroup)) then
                focus = regionData.region;
                focusName = "WeakAuras:"..id;
                focusIsGroup = focusIsGroup;
              end
            end
          end
        end

        if(focus ~= oldFocus) then
          if(focusName) then
            frameChooserBox:ClearAllPoints();
            frameChooserBox:SetPoint("bottomleft", focus, "bottomleft", -4, -4);
            frameChooserBox:SetPoint("topright", focus, "topright", 4, 4);
            frameChooserBox:Show();
          end

          if(focusName ~= oldFocusName) then
            OptionsPrivate.Private.ValueToPath(data, path, focusName);
            oldFocusName = focusName;
            M33kAuras.FillOptions()
          end
          oldFocus = focus;
        end
      end

      if not(focusName) then
        frameChooserBox:Hide();
      end
    end
  end);
end

function OptionsPrivate.StopFrameChooser(data)
  if(frameChooserFrame) then
    frameChooserFrame:SetScript("OnUpdate", nil);
    frameChooserBox:Hide();
  end
  ResetCursor();
  M33kAuras.Add(data);
end
