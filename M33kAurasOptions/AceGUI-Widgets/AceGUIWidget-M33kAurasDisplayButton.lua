if not M33kAuras.IsLibsOK() then return end
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

local tinsert = table.insert
local pairs, type, unpack = pairs, type, unpack

local Type, Version = "M33kAurasDisplayButton", 64
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local L = M33kAuras.L;
local function Hide_Tooltip()
  GameTooltip:Hide();
end

local function Show_Tooltip(owner, line1, line2)
  GameTooltip:SetOwner(owner, "ANCHOR_NONE");
  GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("LEFT", owner, "RIGHT");
  GameTooltip:ClearLines();
  GameTooltip:AddLine(line1);
  GameTooltip:AddLine(line2, 1, 1, 1, 1);
  GameTooltip:Show();
end

local function Show_Long_Tooltip(owner, description)
  GameTooltip:SetOwner(owner, "ANCHOR_NONE");
  GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("LEFT", owner, "RIGHT");
  GameTooltip:ClearLines();
  local line = 1;
  for i,v in pairs(description) do
    if(type(v) == "string") then
      if(line > 1) then
        GameTooltip:AddLine(v, 1, 1, 1, 1);
      else
        GameTooltip:AddLine(v);
      end
    elseif(type(v) == "table") then
      if(i == 1) then
        GameTooltip:AddDoubleLine(v[1], v[2]..(v[3] and (" |T"..v[3]..":12:12:0:0:64:64:4:60:4:60|t") or ""));
      else
        GameTooltip:AddDoubleLine(v[1], v[2]..(v[3] and (" |T"..v[3]..":12:12:0:0:64:64:4:60:4:60|t") or ""),
                                  1, 1, 1, 1, 1, 1, 1, 1);
      end
    end
    line = line + 1;
  end
  GameTooltip:Show();
end

local statusIconPool = CreateFramePool("Button", nil, nil, function(_, button)
  button:Hide()
  button:ClearAllPoints()
  button:SetScript("OnClick", nil)
  button:SetScript("OnEnter", nil)
  button:SetScript("OnLeave", nil)
  button:SetParent(UIParent)
  button.key, button.prio = nil, nil
end)

local tabsForWarning = {
  tts_condition = "conditions",
  sound_condition = "conditions",
  tts_action = "action",
  sound_action = "action",
  spammy_event_warning = "trigger"
}

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
  ["OnAcquire"] = function(self)
    self:SetWidth(1000);
    self:SetHeight(32);
    self.hasThumbnail = false
    self.first = false
    self.last = false
  end,
  ["SetNormalTooltip"] = function(self)
    local data = self.data;
    local namestable = {};
    if(data.controlledChildren) then
      namestable[1] = "";
      local function addChildrenNames(data, indent)
        for index, childId in pairs(data.controlledChildren) do
          tinsert(namestable, indent .. childId);
          local childData = M33kAuras.GetData(childId)
          if not childData then
            return
          end
          if (childData.controlledChildren) then
            addChildrenNames(childData, indent .. "  ")
          end
        end
      end
      addChildrenNames(data, "  ")

      if (#namestable > 30) then
        local size = #namestable;
        namestable[26] = {" ", "[...]"};
        namestable[27] = {L[string.format(L["%s total auras"], #namestable)], " " }
        for i = 28, size do
          namestable[i] = nil;
        end
      end

      if(#namestable > 1) then
        namestable[1] = L["Children:"];
      else
        namestable[1] = L["No Children"];
      end
    else
      OptionsPrivate.Private.GetTriggerDescription(data, -1, namestable)
    end

    local hasDescription = data.desc and data.desc ~= "";
    local hasUrl = data.url and data.url ~= "";
    local hasVersion = (data.semver and data.semver ~= "") or (data.version and data.version ~= "");

    if(hasDescription or hasUrl or hasVersion) then
      tinsert(namestable, " ");
    end

    if(hasDescription) then
      tinsert(namestable, "|cFFFFD100\""..data.desc.."\"");
    end

    if (hasUrl) then
      tinsert(namestable, "|cFFFFD100" .. data.url .. "|r");
    end

    if (hasVersion) then
      tinsert(namestable, "|cFFFFD100" .. L["Version: "]  .. (data.semver or data.version) .. "|r");
    end

    tinsert(namestable, " ");
    tinsert(namestable, {" ", "|cFF00FFFF"..L["Right-click for more options"]});
    tinsert(namestable, {" ", "|cFF00FFFF"..L["Drag to move"]});
    if not(data.controlledChildren) then
      tinsert(namestable, {" ", "|cFF00FFFF"..L["Control-click to select multiple displays"]});
    end
    tinsert(namestable, {" ", "|cFF00FFFF"..L["Shift-click to create chat link"]});
    local regionData = OptionsPrivate.Private.regionOptions[data.regionType or ""]
    local displayName = regionData and regionData.displayName or "";
    self:SetDescription({data.id, displayName}, unpack(namestable));
  end,
  ["ReloadTooltip"] = function(self)
    if(OptionsPrivate.IsPickedMultiple() and OptionsPrivate.IsDisplayPicked(self.data.id)) then
      Show_Long_Tooltip(self.frame, OptionsPrivate.MultipleDisplayTooltipDesc());
    else
      Show_Long_Tooltip(self.frame, self.frame.description);
    end
  end,
  ["UpdateIconsVisible"] = function(self)
    if self.dragging or self.grouping then
      self.downgroup:Hide()
      self.group:Hide()
      self.ungroup:Hide()
      self.upgroup:Hide()
    else
      self.group:Show()
      if self.data.parent then
        self.downgroup:Show()
        self.ungroup:Show()
        self.upgroup:Show()
      else
        self.downgroup:Hide()
        self.ungroup:Hide()
        self.upgroup:Hide()
      end
    end
  end,
  ["ShowTooltip"] = function(self)
  end,
  ["UpdateOffset"] = function(self)
    self.offset:SetWidth(1) -- TreeListView owns indentation.
  end,
  ["GetOffset"] = function(self)
    return self.offset:GetWidth()
  end,
  ["GetGroupOrCopying"] = function(self)
    return self.group;
  end,
  ["SetTitle"] = function(self, title)
    self.titletext = title;
    self.title:SetText(title);
  end,
  ["GetTitle"] = function(self)
    return self.titletext;
  end,
  ["SetDescription"] = function(self, ...)
    self.frame.description = {...};
  end,
  ["EnableGroup"] = function(self)

  end,
  ["SetGroup"] = function(self, group)
    self.frame.dgroup = group;
    if(group) then
      self.icon:SetPoint("LEFT", self.ungroup, "RIGHT");
      self.background:SetPoint("LEFT", self.offset, "RIGHT");
    else
      self.icon:SetPoint("LEFT", self.frame, "LEFT");
      self.background:SetPoint("LEFT", self.frame, "LEFT");
    end
    self:UpdateIconsVisible()
    self:UpdateOffset()
  end,
  ["GetGroup"] = function(self)
    return self.frame.dgroup;
  end,
  ["IsGroup"] = function(self)
    return self.data.regionType == "group" or self.data.regionType == "dynamicgroup"
  end,
  ["SetData"] = function(self, data)
    self.data = data;
    self.frame.id = data.id;
  end,
  ["GetData"] = function(self)
    return self.data;
  end,
  ["Expand"] = function(self)
    self.entry:Expand()
  end,
  ["Collapse"] = function(self)
    self.entry:Collapse()
  end,
  ["SetOnExpandCollapse"] = function(self, func)
    self.expand.func = func;
  end,
  ["GetExpanded"] = function(self)
    return self.entry:GetExpanded()
  end,
  ["DisableExpand"] = function(self)
    if self.expand.disabled then
      return
    end
    self.expand:Disable();
    self.expand.disabled = true;
    self.expand.expanded = false;
    self.expand:SetNormalTexture("Interface\\BUTTONS\\UI-PlusButton-Disabled.blp");
  end,
  ["EnableExpand"] = function(self)
    self.expand.disabled = false
    self.expand:Enable()
    local expanded = self:GetExpanded()
    self.expand:SetNormalTexture(expanded and "Interface/Buttons/UI-MinusButton-Up" or "Interface/Buttons/UI-PlusButton-Up")
    self.expand:SetPushedTexture(expanded and "Interface/Buttons/UI-MinusButton-Down" or "Interface/Buttons/UI-PlusButton-Down")
    self.expand.title = expanded and L["Collapse"] or L["Expand"]
    self.expand.desc = expanded and L["Hide this group's children"] or L["Show this group's children"]
    self.expand:SetScript("OnClick", function()
      if self.entry:GetExpanded() then self.entry:Collapse() else self.entry:Expand() end
    end)
  end,
  ["UpdateStatusIcon"] = function(self, key, prio, icon, title, tooltip, onClick)
    local iconButton
    for _, button in ipairs(self.statusIcons.buttons) do
      if button.key == key then
        iconButton = button
        break
      end
    end
    if not iconButton then
      iconButton = statusIconPool:Acquire()
      iconButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      tinsert(self.statusIcons.buttons, iconButton)
      iconButton:SetParent(self.statusIcons)
      iconButton.key = key
      iconButton:SetSize(16, 16)
    end
    iconButton.prio = prio
    if C_Texture.GetAtlasInfo(icon) then
      iconButton:SetNormalAtlas(icon)
    else
      iconButton:SetNormalTexture(icon)
    end
    if title then
      iconButton:SetScript("OnEnter", function()
        Show_Tooltip(
          self.frame,
          title,
          tooltip
        )
      end)
      iconButton:SetScript("OnLeave", Hide_Tooltip)
    else
      iconButton:SetScript("OnEnter", nil)
    end
    iconButton:SetScript("OnClick", onClick)
    iconButton:Show()
  end,
  ["ClearStatusIcon"] = function(self, key)
    for index, button in ipairs(self.statusIcons.buttons) do
      if button.key == key then
        statusIconPool:Release(button)
        table.remove(self.statusIcons.buttons, index)
        return
      end
    end
  end,
  ["SortStatusIcons"] = function(self)
    table.sort(self.statusIcons.buttons, function(a, b)
      return a.prio < b.prio
    end)
    local lastAnchor = self.statusIcons
    if self:IsGroup() then
      self.statusIcons:SetWidth(17)
    else
      self.statusIcons:SetWidth(1)
    end
    for _, button in ipairs(self.statusIcons.buttons) do
      button:ClearAllPoints()
      button:SetPoint("BOTTOMLEFT", lastAnchor, "BOTTOMRIGHT", 4, 0)
      lastAnchor = button
    end
  end,
  ["UpdateWarning"] = function(self)
    local uid = self.data.uid
    local warnings = OptionsPrivate.Private.AuraWarnings.GetAllWarnings(uid)
    local warningTypes = {"info", "sound", "tts", "warning", "error"}
    for _, key in ipairs(warningTypes) do
      self:ClearStatusIcon(key)
    end
    if warnings then
      for severity, warning in pairs(warnings) do
        local onClick
        if severity == "sound" or severity == "tts" then
          local soundText = L["Show Sound Setting"]
          local removeText = L["Remove All Sounds"]
          if severity == "tts" then
            soundText = L["Show Text To Speech Setting"]
            removeText = L["Remove All Text To Speech"]
          end
          onClick = function()
            MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, root)
              root:CreateButton(soundText, function()
                M33kAuras.PickDisplay(warning.auraId, tabsForWarning[warning.key] or "information")
              end)
              root:CreateButton(removeText, function()
                OptionsPrivate.Private.ClearSounds(uid, severity)
              end)
            end)
          end
        else
          onClick = function()
            M33kAuras.PickDisplay(warning.auraId, tabsForWarning[warning.key] or "information")
          end
        end

        self:UpdateStatusIcon(severity, warning.prio, warning.icon, warning.title, warning.message, onClick)
      end
    end
    self:SortStatusIcons()
  end,
  ["UpdateParentWarning"] = function(self)
    self:UpdateWarning()
    for parent in OptionsPrivate.Private.TraverseParents(self.data) do
      local parentButton = OptionsPrivate.GetDisplayEntry(parent.id)
      if parentButton then
        parentButton:UpdateWarning()
      end
    end
  end,
  ["SetGroupOrder"] = function(self, order, max)
    self.first = (order == 1)
    self.last = (order == max)
    self.frame.dgrouporder = order;
    self:UpdateUpDownButtons()
  end,
  ["UpdateUpDownButtons"] = function(self)
    if self.first or not self:IsEnabled() then
      self.upgroup:Disable();
      self.upgroup.texture:SetVertexColor(0.3, 0.3, 0.3);
    else
      self.upgroup:Enable();
      self.upgroup.texture:SetVertexColor(1, 1, 1);
    end

    if self.last or not self:IsEnabled() then
      self.downgroup:Disable();
      self.downgroup.texture:SetVertexColor(0.3, 0.3, 0.3);
    else
      self.downgroup:Enable();
      self.downgroup.texture:SetVertexColor(1, 1, 1);
    end
  end,
  ["GetGroupOrder"] = function(self)
    return self.frame.dgrouporder;
  end,
  ["ClearLoaded"] = function(self)
    self:ClearStatusIcon("load")
    self:SortStatusIcons()
  end,
  ["SetLoaded"] = function(self, prio, file, title, description)
    self:UpdateStatusIcon("load", prio, "Interface\\AddOns\\M33kAuras\\Media\\Textures\\" .. file, title, description, nil)
    self:SortStatusIcons()
  end,
  ["IsLoaded"] = function(self)
    return OptionsPrivate.Private.loaded[self.data.id] == true
  end,
  ["IsStandby"] = function(self)
    return OptionsPrivate.Private.loaded[self.data.id] == false
  end,
  ["IsUnloaded"] = function(self)
    return OptionsPrivate.Private.loaded[self.data.id] == nil
  end,
  ["UpdateViewTexture"] = function(self)
    local visibility = self.view.visibility
    if(visibility == 2) then
      self.view.texture:SetTexture("Interface\\LFGFrame\\BattlenetWorking0.blp");
    elseif(visibility == 1) then
      self.view.texture:SetTexture("Interface\\LFGFrame\\BattlenetWorking2.blp");
    else
      self.view.texture:SetTexture("Interface\\LFGFrame\\BattlenetWorking4.blp");
    end
  end,
  ["Disable"] = function(self)
    self.background:Hide();
    self.frame:Disable();
    self.view:Disable();
    self.group:Disable();
    self.ungroup:Disable();
    self.expand:Disable();
    for _, button in ipairs(self.statusIcons.buttons) do
      button:Disable();
    end
    self:UpdateUpDownButtons()
  end,
  ["Enable"] = function(self)
    self.background:Show();
    self.frame:Enable();
    self.view:Enable();
    self.group:Enable();
    self.ungroup:Enable();
    for _, button in ipairs(self.statusIcons.buttons) do
      button:Enable();
    end
    self:UpdateUpDownButtons()
    if not(self.expand.disabled) then
      self.expand:Enable();
    end
  end,
  ["IsEnabled"] = function(self)
    return self.frame:IsEnabled();
  end,
  ["OnRelease"] = function(self)
    self:ReleaseThumbnail()
    self:Enable();
    self:SetGroup();
    self:ClearEntryCallbacks()
    self.title:Show();
    self.frame:ClearAllPoints();
    self.frame:Hide();
    for _, button in ipairs(self.statusIcons.buttons) do
      statusIconPool:Release(button)
    end
    wipe(self.statusIcons.buttons)
    self.frame:EnableKeyboard(false)
    self.frame:UnlockHighlight()
    self.frame.description = nil
    self.entry = nil
    self.callbacks = nil
    self.grouping = nil
    self.dragging = nil
    self.iconRegion = nil
    self.orgIcon = nil
    self.data = nil;
  end,
  ["UpdateThumbnail"] = OptionsPrivate.AuraListThumbnail.Update,
  ["ReleaseThumbnail"] = OptionsPrivate.AuraListThumbnail.Release,
  ["AcquireThumbnail"] = OptionsPrivate.AuraListThumbnail.Acquire,
  ["SetIcon"] = function(self, icon)
    self.orgIcon = icon;
    if(type(icon) == "string" or type(icon) == "number") then
      self.icon:SetTexture(icon);
      self.icon:Show();
      if(self.iconRegion and self.iconRegion.Hide) then
        self.iconRegion:Hide();
      end
    else
      self.iconRegion = icon;
      icon:SetAllPoints(self.icon);
      icon:SetParent(self.frame);
      icon:Show()
      self.iconRegion:Show();
      self.icon:Hide();
    end
  end,
  ["OverrideIcon"] = function(self)
    self.icon:SetTexture("Interface\\Addons\\M33kAuras\\Media\\Textures\\icon.blp")
    self.icon:Show()
    if(self.iconRegion and self.iconRegion.Hide) then
      self.iconRegion:Hide();
    end
  end,
  ["RestoreIcon"] = function(self)
    self:SetIcon(self.orgIcon);
  end,
  ["BindEntryCallbacks"] = function(self)
    self.frame:SetScript("OnEnter", function()
      if OptionsPrivate.IsPickedMultiple() and OptionsPrivate.IsDisplayPicked(self.data.id) then
        Show_Long_Tooltip(self.frame, OptionsPrivate.MultipleDisplayTooltipDesc())
      else
        self:SetNormalTooltip()
        Show_Long_Tooltip(self.frame, self.frame.description)
      end
    end)
    self.frame:SetScript("OnLeave", Hide_Tooltip)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.callbacks.OnDragStart)
    self.frame:SetScript("OnDragStop", nil)
    self.group:SetScript("OnClick", self.callbacks.OnGroupClick)
    self.ungroup:SetScript("OnClick", self.callbacks.OnUngroupClick)
    self.upgroup:SetScript("OnClick", self.callbacks.OnUpGroupClick)
    self.downgroup:SetScript("OnClick", self.callbacks.OnDownGroupClick)
    self.view:SetScript("OnClick", self.callbacks.OnViewClick)
  end,
  ["ClearEntryCallbacks"] = function(self)
    for _, script in ipairs({"OnEnter", "OnLeave", "OnClick", "OnDragStart", "OnDragStop", "OnUpdate", "OnKeyDown"}) do
      self.frame:SetScript(script, nil)
    end
    for _, control in ipairs({self.group, self.ungroup, self.upgroup, self.downgroup, self.view, self.expand}) do
      control:SetScript("OnClick", nil)
    end
    self.expand.func = nil
  end,
  ["Initialize"] = function(self)
    self.entry:EnsureInitialized()
    self.callbacks = self.entry.callbacks
    self:BindEntryCallbacks()
    self:RefreshEntry()
  end,
  ["RefreshEntry"] = function(self)
    local entry = self.entry
    self:SetData(entry.data)
    self:SetTitle(entry.data.id)
    self.callbacks = entry.callbacks
    self.grouping, self.dragging = entry.grouping, entry.dragging
    self:SetGroup(entry.data.parent)
    local parent = entry.data.parent and M33kAuras.GetData(entry.data.parent)
    self:SetGroupOrder(entry:GetGroupOrder(), parent and #parent.controlledChildren or 0)
    if entry.data.controlledChildren then
      self.expand:Show()
      if #entry.data.controlledChildren > 0 then self:EnableExpand() else self:DisableExpand() end
    else
      self.expand:Hide()
    end
    if entry.enabled then self:Enable() else self:Disable() end
    self.frame:SetScript("OnClick", entry.click or self.callbacks.OnClickNormal)
    self.view.visibility = entry.view.visibility
    self:UpdateViewTexture()
    if entry.picked then self.frame:LockHighlight() else self.frame:UnlockHighlight() end
    self.background:SetVertexColor(entry.neverLoad and 1 or 0.5, entry.neverLoad and 0.12 or 0.5,
      entry.neverLoad and 0.12 or 0.5, 0.25)
    entry:RenderLoadStatus(self)
    self:UpdateWarning()
    self:UpdateThumbnail()
    if entry.renaming then
      self.title:Hide()
      OptionsPrivate.AttachAuraRename(entry, self)
    else
      self.title:Show()
    end
  end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]

local function Constructor()
  local name = "M33kAurasDisplayButton"..AceGUI:GetNextWidgetNum(Type);
  ---@class Button
  local button = CreateFrame("Button", name, UIParent, "OptionsListButtonTemplate");
  button:SetHeight(32);
  button:SetWidth(1000);
  button.dgroup = nil;
  button.data = {};

  local offset = CreateFrame("Frame", nil, button)
  button.offset = offset
  offset:SetPoint("TOP", button, "TOP");
  offset:SetPoint("BOTTOM", button, "BOTTOM");
  offset:SetPoint("LEFT", button, "LEFT");
  offset:SetWidth(1)

  local background = button:CreateTexture(nil, "BACKGROUND");
  button.background = background;
  background:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight2.blp");
  background:SetBlendMode("ADD");
  background:SetVertexColor(0.5, 0.5, 0.5, 0.25);
  background:SetPoint("TOP", button, "TOP");
  background:SetPoint("BOTTOM", button, "BOTTOM");
  background:SetPoint("LEFT", button, "LEFT")
  background:SetPoint("RIGHT", button, "RIGHT");

  local icon = button:CreateTexture(nil, "OVERLAY");
  button.icon = icon;
  icon:SetWidth(32);
  icon:SetHeight(32);
  icon:SetPoint("LEFT", offset, "RIGHT");

  local title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal");
  button.title = title;
  title:SetHeight(14);
  title:SetJustifyH("LEFT");
  title:SetPoint("TOP", button, "TOP", 0, -2);
  title:SetPoint("LEFT", icon, "RIGHT", 2, 0);
  title:SetPoint("RIGHT", button, "RIGHT");

  button.description = {};

  ---@class Button
  local view = CreateFrame("Button", nil, button);
  button.view = view;
  view:SetWidth(16);
  view:SetHeight(16);
  view:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 0);
  local viewTexture = view:CreateTexture()
  view.texture = viewTexture;
  viewTexture:SetTexture("Interface\\LFGFrame\\BattlenetWorking4.blp");
  viewTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9);
  viewTexture:SetAllPoints(view);
  view:SetNormalTexture(viewTexture);
  view:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight.blp");
  view:SetScript("OnEnter", function() Show_Tooltip(button, L["View"], L["Toggle the visibility of this display"]) end);
  view:SetScript("OnLeave", Hide_Tooltip);

  view.visibility = 0;

  local group = CreateFrame("Button", nil, button);
  button.group = group;
  group:SetWidth(16);
  group:SetHeight(16);
  group:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -18, 0);
  local grouptexture = group:CreateTexture(nil, "OVERLAY");
  group.texture = grouptexture;
  grouptexture:SetTexture("Interface\\GLUES\\CharacterCreate\\UI-RotationRight-Big-Up.blp");
  grouptexture:SetTexCoord(0.15, 0.85, 0.15, 0.85);
  grouptexture:SetAllPoints(group);
  group:SetNormalTexture(grouptexture);
  group:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight.blp");
  group:SetScript("OnEnter", function() Show_Tooltip(button, L["Group (verb)"], L["Put this display in a group"]) end);
  group:SetScript("OnLeave", Hide_Tooltip);

  local ungroup = CreateFrame("Button", nil, button);
  button.ungroup = ungroup;
  ungroup:SetWidth(11);
  ungroup:SetHeight(11);
  ungroup:SetPoint("LEFT", offset, "RIGHT", 0, 0);
  local ungrouptexture = group:CreateTexture(nil, "OVERLAY");
  ungrouptexture:SetTexture("Interface\\MoneyFrame\\Arrow-Left-Down.blp");
  ungrouptexture:SetTexCoord(0.5, 0, 0.5, 1, 1, 0, 1, 1);
  ungrouptexture:SetAllPoints(ungroup);
  ungroup:SetNormalTexture(ungrouptexture);
  ungroup:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight.blp");
  ungroup:SetScript("OnEnter", function() Show_Tooltip(button, L["Ungroup"], L["Remove this display from its group"]) end);
  ungroup:SetScript("OnLeave", Hide_Tooltip);
  ungroup:Hide();

  local upgroup = CreateFrame("Button", nil, button);
  button.upgroup = upgroup;
  upgroup:SetWidth(11);
  upgroup:SetHeight(11);
  upgroup:SetPoint("TOPLEFT", offset, "TOPRIGHT", 0, 0);
  local upgrouptexture = group:CreateTexture(nil, "OVERLAY");
  upgroup.texture = upgrouptexture;
  upgrouptexture:SetTexture("Interface\\MoneyFrame\\Arrow-Left-Down.blp");
  upgrouptexture:SetTexCoord(0.5, 1, 1, 1, 0.5, 0, 1, 0);
  upgrouptexture:SetVertexColor(1, 1, 1);
  upgrouptexture:SetAllPoints(upgroup);
  upgroup:SetNormalTexture(upgrouptexture);
  upgroup:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight.blp");
  upgroup:SetScript("OnEnter", function() Show_Tooltip(button, L["Move Up"], L["Move this display up in its group's order"]) end);
  upgroup:SetScript("OnLeave", Hide_Tooltip);
  upgroup:Hide();

  local downgroup = CreateFrame("Button", nil, button);
  button.downgroup = downgroup;
  downgroup:SetWidth(11);
  downgroup:SetHeight(11);
  downgroup:SetPoint("BOTTOMLEFT", offset, "BOTTOMRIGHT", 0, 0);
  local downgrouptexture = group:CreateTexture(nil, "OVERLAY");
  downgroup.texture = downgrouptexture;
  downgrouptexture:SetTexture("Interface\\MoneyFrame\\Arrow-Left-Down.blp");
  downgrouptexture:SetTexCoord(1, 0, 0.5, 0, 1, 1, 0.5, 1);
  downgrouptexture:SetAllPoints(downgroup);
  downgroup:SetNormalTexture(downgrouptexture);
  downgroup:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight.blp");
  downgroup:SetScript("OnEnter", function()
    Show_Tooltip(button, L["Move Down"], L["Move this display down in its group's order"])
  end)
  downgroup:SetScript("OnLeave", Hide_Tooltip);
  downgroup:Hide();

  ---@class Button
  local expand = CreateFrame("Button", nil, button);
  button.expand = expand;
  expand.expanded = true;
  expand.disabled = true;
  expand.func = function() end;
  expand:SetNormalTexture("Interface\\BUTTONS\\UI-PlusButton-Disabled.blp");
  expand:Disable();
  expand:SetWidth(16);
  expand:SetHeight(16);
  expand:SetPoint("BOTTOM", button, "BOTTOM");
  expand:SetPoint("LEFT", icon, "RIGHT", 0, 0);
  expand:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight.blp");
  expand.title = L["Disabled"];
  expand.desc = L["Expansion is disabled because this group has no children"];
  expand:SetScript("OnEnter", function() Show_Tooltip(button, expand.title, expand.desc) end);
  expand:SetScript("OnLeave", Hide_Tooltip);

  local statusIcons = CreateFrame("Frame", nil, button);
  button.statusIcons = statusIcons
  statusIcons:SetPoint("BOTTOM", button, "BOTTOM", 0, 1);
  statusIcons:SetPoint("LEFT", icon, "RIGHT");
  statusIcons:SetSize(1,1)
  statusIcons.buttons = {}

  local widget = {
    frame = button,
    title = title,
    icon = icon,
    view = view,
    group = group,
    ungroup = ungroup,
    upgroup = upgroup,
    downgroup = downgroup,
    background = background,
    expand = expand,
    statusIcons = statusIcons,
    type = Type,
    offset = offset
  }
  for method, func in pairs(methods) do
    widget[method] = func
  end

  return AceGUI:RegisterAsWidget(widget);
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
