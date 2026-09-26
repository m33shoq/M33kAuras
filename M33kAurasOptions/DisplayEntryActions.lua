if not M33kAuras.IsLibsOK() then return end
local _, OptionsPrivate = ...
local L = M33kAuras.L
local tinsert, tremove = table.insert, table.remove
local select, pairs, type = select, pairs, type
local error = error

-- Callbacks retain model entries because display button frames are recycled.
local fullName;
local clipboard = {};

local function IsRegionAGroup(data)
  return data and (data.regionType == "group" or data.regionType == "dynamicgroup");
end

local ignoreForCopyingDisplay = {
  triggers = true,
  conditions = true,
  load = true,
  actions = true,
  animation = true,
  id = true,
  parent = true,
  controlledChildren = true,
  uid = true,
  authorOptions = true,
  config = true,
  url = true,
  semver = true,
  version = true,
  internalVersion = true,
  tocversion = true
}

local function copyAuraPart(source, destination, part)
  local all = (part == "all");
  if (part == "display" or all) then
    for k, v in pairs(source) do
      if (not ignoreForCopyingDisplay[k]) then
        if (type(v) == "table") then
          destination[k] = CopyTable(v);
        else
          destination[k] = v;
        end
      end
    end
  end
  if (part == "trigger" or all) and not IsRegionAGroup(source) then
    destination.triggers = CopyTable(source.triggers);
  end
  if (part == "condition" or all) and not IsRegionAGroup(source) then
    destination.conditions = CopyTable(source.conditions);
  end
  if (part == "load" or all) and not IsRegionAGroup(source) then
    destination.load = CopyTable(source.load);
  end
  if (part == "action" or all) and not IsRegionAGroup(source) then
    destination.actions = CopyTable(source.actions);
  end
  if (part == "animation" or all) and not IsRegionAGroup(source) then
    destination.animation = CopyTable(source.animation);
  end
  if (part == "authorOptions" or all) and not IsRegionAGroup(source) then
    destination.authorOptions = CopyTable(source.authorOptions);
  end
  if (part == "config" or all) and not IsRegionAGroup(source) then
    destination.config = CopyTable(source.config);
  end

end

function OptionsPrivate.CopyDisplayButtonSettings(data, part, description)
  clipboard.part = part
  clipboard.pasteText = description
  clipboard.source = CopyTable(data)
end

function OptionsPrivate.GetDisplayButtonPasteText(data)
  if IsRegionAGroup(clipboard.source) and not IsRegionAGroup(data) then return end
  return clipboard.pasteText
end

function OptionsPrivate.PasteDisplayButtonSettings(data)
  if not OptionsPrivate.GetDisplayButtonPasteText(data) then return end
  if not IsRegionAGroup(clipboard.source) and IsRegionAGroup(data) then
    for child in OptionsPrivate.Private.TraverseLeafs(data) do
      copyAuraPart(clipboard.source, child, clipboard.part)
      M33kAuras.Add(child)
      M33kAuras.ClearAndUpdateOptions(child.id)
    end
  else
    copyAuraPart(clipboard.source, data, clipboard.part)
    M33kAuras.Add(data)
    M33kAuras.ClearAndUpdateOptions(data.id)
  end
  M33kAuras.FillOptions()
  OptionsPrivate.Private.ScanForLoads({[data.id] = true})
  OptionsPrivate.SortDisplayButtons()
  M33kAuras.PickDisplay(data.id)
  M33kAuras.UpdateThumbnail(data.id)
  M33kAuras.ClearAndUpdateOptions(data.id)
end

local function ensure(t, k, v)
  return t and k and v and t[k] == v
end

local Actions = {
  ["Group"] = function(source, groupId, target, before)
    if source and not source.data.parent then
      if groupId then
        local group = OptionsPrivate.GetDisplayEntry(groupId)
        if group and group:IsGroup() then
          local children = group.data.controlledChildren
          if target then
            local index = target:GetGroupOrder()
            if ensure(children, index, target.data.id) then
              index = before and index or index+1
              tinsert(children, index, source.data.id)
            else
              error("Calling 'Group' with invalid target. Reload your UI to fix the display list.")
            end
          else
            tinsert(children, 1, source.data.id)
          end
          source:SetGroup(groupId)
          source.data.parent = groupId
          M33kAuras.Add(source.data)
          M33kAuras.Add(group.data)
          OptionsPrivate.Private.AddParents(group.data)
          M33kAuras.UpdateGroupOrders(group.data)
          M33kAuras.ClearAndUpdateOptions(group.data.id)
          M33kAuras.ClearAndUpdateOptions(source.data.id)
          group.callbacks.UpdateExpandButton();
          group:UpdateParentWarning()
          group:ReloadTooltip()
        else
          M33kAuras.Add(source.data)
          M33kAuras.ClearAndUpdateOptions(source.data.id)
        end
      else
        M33kAuras.Add(source.data)
        M33kAuras.ClearAndUpdateOptions(source.data.id)
      end
    else
      error("Calling 'Group' with invalid source. Reload your UI to fix the display list.")
    end
  end,
  ["Ungroup"] =  function(source)
    if source and source.data.parent then
      local parent = M33kAuras.GetData(source.data.parent)
      local children = parent.controlledChildren
      local index = source:GetGroupOrder()
      if ensure(children, index, source.data.id) then
        tremove(children, index)
        source:SetGroup()
        source.data.parent = nil
        M33kAuras.Add(parent);
        OptionsPrivate.Private.AddParents(parent)
        M33kAuras.UpdateGroupOrders(parent);
        M33kAuras.ClearAndUpdateOptions(parent.id);
        local group = OptionsPrivate.GetDisplayEntry(parent.id)
        group.callbacks.UpdateExpandButton();
        group:UpdateParentWarning()
        group:ReloadTooltip()
      else
        error("Display thinks it is a member of a group which does not control it")
      end
    else
      error("Calling 'Ungroup' with invalid source. Reload your UI to fix the display list.")
    end
  end
}


local function GetAction(target, area)
  if target and area then
    if area == "GROUP" then
      return function(_source, _target)
        if _source.data.parent then
          Actions["Ungroup"](_source)
        end
        Actions["Group"](_source, _target.data.id)
      end
    else -- BEFORE or AFTER
      if target.data.parent then
        return function(_source, _target)
          if _source.data.parent then
            Actions["Ungroup"](_source)
          end
          Actions["Group"](_source, _target.data.parent, _target, area == "BEFORE")
        end
      end
    end
  end
end


local function GetDropTarget()
  local buttonList = OptionsPrivate.displayEntries

  for id, button in pairs(buttonList) do
    if button.row and not button.dragging and button:IsEnabled() and button.row.frame:IsShown() then
      local halfHeight = button.row.frame:GetHeight() / 2
      local height = button.row.frame:GetHeight()
      if button.data.controlledChildren then
        if button.data.parent == nil and button.row.frame:IsMouseOver(1, -1) then
          -- Top level group, always group into
          return id, button, "GROUP"
        end

        -- For sub groups, middle third is for grouping
        if button.row.frame:IsMouseOver(-height / 3, height / 3) then
          return id, button, "GROUP"
        end
      end

      if button.row.frame:IsMouseOver(1, height / 2) then
        return id, button, "BEFORE"
      elseif button.row.frame:IsMouseOver(-height / 2, -1) then
        return id, button, "AFTER"
      end
    end
  end
end

local function Show_DropIndicator(id)
  local indicator = OptionsPrivate.DropIndicator()
  local source = OptionsPrivate.GetDisplayEntry(id)
  local target, pos
  if source then
    target, pos = select(2, GetDropTarget())
  end
  local action = GetAction(target, pos)
  if action then
    indicator:ShowAction(target, pos)
  else
    indicator:Hide()
  end
end

OptionsPrivate.UpdateAuraDropIndicator = Show_DropIndicator

-- The mandatory profanity filter in the Chinese region can censor realm names.
local function ObfuscateName(name)
  if (GetCurrentRegion() == 5) then
    local result = ""
    for i = 1, #name do
      local b = name:byte(i)
      if (b >= 196 and i ~= 1) then
        result = result .. string.char(46, b)
      else
        result = result .. string.char(b)
      end
    end
    return result
  else
    return name
  end
end

local function IsParentRecursive(needle, parent)
  if needle.id == parent.id then
    return true
  end
  if needle.parent then
    local needleParent = M33kAuras.GetData(needle.parent)
    return IsParentRecursive(needleParent, parent)
  end
end

function OptionsPrivate.InitializeDisplayEntry(self)
    self.callbacks = {};

    function self.callbacks.OnClickNormal(_, mouseButton)
      if(IsControlKeyDown() and not self.data.controlledChildren) then
        if (OptionsPrivate.IsDisplayPicked(self.data.id)) then
          OptionsPrivate.ClearPick(self.data.id);
        else
          OptionsPrivate.PickDisplayMultiple(self.data.id);
        end
        self:ReloadTooltip();
      elseif(IsShiftKeyDown()) then
        local editbox = GetCurrentKeyBoardFocus();
        if(editbox) then
          if (not fullName) then
            local name, realm = UnitFullName("player")
            if realm then
              fullName = name.."-".. ObfuscateName(realm)
            else
              fullName = name
            end
          end

          if not (GetCurrentRegion() == 5 or GetLocale() == "zhCN") then -- China region (5), and chinese locale profanity filter doesn't allow links in chat
            local url = ""
            if self.data.url then
              url = " ".. self.data.url
            end
            editbox:Insert("[M33kAuras: "..fullName.." - "..self.data.id.."]"..url)
          else
            editbox:Insert("[M33kAuras: "..fullName.." - "..self.data.id.."]")
          end

          OptionsPrivate.Private.linked = OptionsPrivate.Private.linked or {}
          OptionsPrivate.Private.linked[self.data.id] = GetTime()
        elseif not self.data.controlledChildren then
          OptionsPrivate.PickDisplayMultipleShift(self.data.id)
        end
      else
        if(mouseButton == "RightButton") then
          GameTooltip:Hide();
          OptionsPrivate.OpenDisplayButtonMenu(self)
        else
          if (OptionsPrivate.IsDisplayPicked(self.data.id)) then
            OptionsPrivate.ClearPicks();
          else
            if self.data.controlledChildren then
              M33kAuras.PickDisplay(self.data.id, "group")
            else
              M33kAuras.PickDisplay(self.data.id);
            end
          end
          self:ReloadTooltip();
        end
      end
    end

    function self.callbacks.UpdateExpandButton()
      if(not self.data.controlledChildren or #self.data.controlledChildren == 0) then
        self:DisableExpand();
      else
        self:EnableExpand();
      end
    end


    function self.callbacks.OnClickGrouping()
      if (M33kAuras.IsImporting()) then return end;
      for index, selectedId in ipairs(self.grouping) do
        local selectedData = M33kAuras.GetData(selectedId);
        tinsert(self.data.controlledChildren, selectedId);
        local selectedButton = OptionsPrivate.GetDisplayEntry(selectedId);
        while selectedData.parent do
          selectedButton:Ungroup();
        end
        selectedButton:SetGroup(self.data.id, self.data.regionType == "dynamicgroup");
        selectedButton:SetGroupOrder(#self.data.controlledChildren, #self.data.controlledChildren);
        selectedData.parent = self.data.id;
        if (self.data.regionType == "dynamicgroup") then
          selectedData.xOffset = 0
          selectedData.yOffset = 0
        end
        M33kAuras.Add(selectedData);
        OptionsPrivate.ClearOptions(selectedId)

        if (selectedData.controlledChildren) then
          for child in OptionsPrivate.Private.TraverseAllChildren(selectedData) do
            local childButton = OptionsPrivate.GetDisplayEntry(child.id)
            childButton:UpdateOffset()
          end
        end
      end

      M33kAuras.Add(self.data);
      OptionsPrivate.Private.AddParents(self.data)
      self.callbacks.UpdateExpandButton();
      self:UpdateParentWarning();
      OptionsPrivate.StopGrouping();
      OptionsPrivate.ClearOptions(self.data.id);
      M33kAuras.FillOptions();
      M33kAuras.UpdateGroupOrders(self.data);
      OptionsPrivate.SortDisplayButtons();
      self:ReloadTooltip();
      self:Expand()
      OptionsPrivate.ResetMoverSizer();
    end

    function self.callbacks.OnClickGroupingSelf()
      OptionsPrivate.StopGrouping();
      self:ReloadTooltip();
    end

    function self.callbacks.OnGroupClick()
      OptionsPrivate.StartGrouping(self.data);
    end

    local function addParents(hash, data)
      local parent = data.parent
      if parent then
        hash[parent] = true
        local parentData = M33kAuras.GetData(parent)
        if parentData then
          addParents(hash, parentData)
        end
      end
    end

    function self.callbacks.OnDeleteClick()
      if (M33kAuras.IsImporting()) then return end;
      local toDelete = {self.data}
      local parents = {}
      addParents(parents, self.data)
      OptionsPrivate.ConfirmDelete(toDelete, parents)
    end

    local function DuplicateGroups(sourceParent, targetParent, mapping)
      for index, childId in pairs(sourceParent.controlledChildren) do
        local childData = M33kAuras.GetData(childId)
        if childData.controlledChildren then
          local newChildGroup = OptionsPrivate.DuplicateAura(childData, targetParent.id)
          mapping[childData] = newChildGroup
          DuplicateGroups(childData, newChildGroup, mapping)
        end
      end
    end

    local function DuplicateAuras(sourceParent, targetParent, mapping)
      for index, childId in pairs(sourceParent.controlledChildren) do
        local childData = M33kAuras.GetData(childId)
        if childData.controlledChildren then
          DuplicateAuras(childData, mapping[childData], mapping)
        else
          OptionsPrivate.DuplicateAura(childData, targetParent.id, true, index)
        end
      end
    end

    function self.callbacks.OnDuplicateClick()
      if (M33kAuras.IsImporting()) then return end;
      if self.data.controlledChildren then
        local newGroup = OptionsPrivate.DuplicateAura(self.data)

        local mapping = {}
        -- Create every parent group before duplicating its leaf auras.
        DuplicateGroups(self.data, newGroup, mapping)
        local suspended = OptionsPrivate.Private.PauseAllDynamicGroups()
        DuplicateAuras(self.data, newGroup, mapping)

        local button = OptionsPrivate.GetDisplayEntry(newGroup.id)
        button.callbacks.UpdateExpandButton()
        button:UpdateParentWarning()

        for old, new in pairs(mapping) do
          local button = OptionsPrivate.GetDisplayEntry(new.id)
          button.callbacks.UpdateExpandButton()
          button:UpdateParentWarning()
        end

        OptionsPrivate.SortDisplayButtons(nil, true)
        OptionsPrivate.PickAndEditDisplay(newGroup.id)
        OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)
      else
        local new = OptionsPrivate.DuplicateAura(self.data)
        OptionsPrivate.SortDisplayButtons(nil, true)
        OptionsPrivate.PickAndEditDisplay(new.id)
      end
    end

    function self.callbacks.OnDeleteAllClick()
      if (M33kAuras.IsImporting()) then return end;
      local toDelete = {}
      if(self.data.controlledChildren) then
        for child in OptionsPrivate.Private.TraverseAllChildren(self.data) do
          tinsert(toDelete, child);
        end
      end
      tinsert(toDelete, self.data)
      local parents = {}
      addParents(parents, self.data)
      OptionsPrivate.ConfirmDelete(toDelete, parents);
    end

    function self.callbacks.OnUngroupClick()
      OptionsPrivate.Ungroup(self.data);
    end

    function self.callbacks.OnUpGroupClick()
      self:MoveChild(-1)
    end

    function self.callbacks.OnDownGroupClick()
      self:MoveChild(1)
    end

    function self.callbacks.OnViewClick()
      local suspended = OptionsPrivate.Private.PauseAllDynamicGroups()
      if(self.view.visibility == 2) then
        for child in OptionsPrivate.Private.TraverseAllChildren(self.data) do
          OptionsPrivate.GetDisplayEntry(child.id):PriorityHide(2)
        end
        self:PriorityHide(2)
      else
        for child in OptionsPrivate.Private.TraverseAllChildren(self.data) do
          OptionsPrivate.GetDisplayEntry(child.id):PriorityShow(2)
        end
        self:PriorityShow(2)
      end
      self:RecheckParentVisibility()
      OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)
    end

    function self.callbacks.OnRenameClick()
      if M33kAuras.IsImporting() then return end
      self:BeginRename()
    end

    function self.callbacks.OnRenameAction(newid)
      if (M33kAuras.IsImporting()) then return end;
      self:SubmitRename(newid)
    end

    function self.callbacks.OnDragStart()
      if M33kAuras.IsImporting() then return end;
      if not OptionsPrivate.IsDisplayPicked(self.data.id) then
        M33kAuras.PickDisplay(self.data.id)
      end
      OptionsPrivate.StartDrag(self.data);
    end

    function self.callbacks.OnDragStop()
      if not self.dragging or self.dropping then return end
      self.dropping = true
      local target, area = select(2, GetDropTarget())
      local action = GetAction(target, area)
      OptionsPrivate.Drop(self.data, target, action, area)
    end

    function self.callbacks.OnKeyDown(self, key)
      if (key == "ESCAPE") then
        OptionsPrivate.DragReset()
      end
    end

end

local entryMethods = OptionsPrivate.DisplayEntryMethods
entryMethods.Ungroup = function(self)
    if (M33kAuras.IsImporting()) then return end;
    local parentData = M33kAuras.GetData(self.data.parent);
    if not parentData then return end;
    local index = tIndexOf(parentData.controlledChildren, self.data.id);
    if(index) then
      tremove(parentData.controlledChildren, index);
      M33kAuras.Add(parentData);
      OptionsPrivate.Private.AddParents(parentData)
      M33kAuras.ClearAndUpdateOptions(parentData.id);
    else
      error("Display thinks it is a member of a group which does not control it");
    end

    local newParent = parentData.parent and M33kAuras.GetData(parentData.parent)
    if newParent then
      local insertIndex = tIndexOf(newParent.controlledChildren, parentData.id)
      if not insertIndex then
        error("Parent Display thinks it is a member of a group which does not control it");
      end
      insertIndex = insertIndex + 1
      tinsert(newParent.controlledChildren, insertIndex, self.data.id)
    end

    self:SetGroup(newParent and newParent.id);
    self.data.parent = newParent and newParent.id;
    M33kAuras.Add(self.data);
    self:UpdateIconsVisible()
    if newParent then
      M33kAuras.Add(newParent)
      OptionsPrivate.Private.AddParents(newParent)
      M33kAuras.ClearAndUpdateOptions(newParent.id)
      M33kAuras.UpdateGroupOrders(newParent)
    end
    M33kAuras.ClearAndUpdateOptions(self.data.id);
    M33kAuras.UpdateGroupOrders(parentData);
    local parentButton = OptionsPrivate.GetDisplayEntry(parentData.id)
    if(#parentData.controlledChildren == 0) then
      parentButton:DisableExpand()
    end
    parentButton:UpdateParentWarning()

    for child in OptionsPrivate.Private.TraverseAllChildren(self.data) do
      local button = OptionsPrivate.GetDisplayEntry(child.id)
      button:UpdateOffset()
    end

    OptionsPrivate.SortDisplayButtons();
end

entryMethods.SyncVisibility = function(self)
    if (not M33kAuras.IsOptionsOpen()) then
      return;
    end
    if self.view.visibility >= 1 then
      if not OptionsPrivate.Private.IsGroupType(self.data) then
        OptionsPrivate.Private.FakeStatesFor(self.data.id, true)
      end
      if (OptionsPrivate.Private.personalRessourceDisplayFrame) then
        OptionsPrivate.Private.personalRessourceDisplayFrame:expand(self.data.id);
      end
      if (OptionsPrivate.Private.mouseFrame) then
        OptionsPrivate.Private.mouseFrame:expand(self.data.id);
      end
    else
      if not OptionsPrivate.Private.IsGroupType(self.data) then
        OptionsPrivate.Private.FakeStatesFor(self.data.id, false)
      end
      if (OptionsPrivate.Private.personalRessourceDisplayFrame) then
        OptionsPrivate.Private.personalRessourceDisplayFrame:collapse(self.data.id);
      end
      if (OptionsPrivate.Private.mouseFrame) then
        OptionsPrivate.Private.mouseFrame:collapse(self.data.id);
      end
    end
end

entryMethods.PriorityShow = function(self, priority)
    if (not M33kAuras.IsOptionsOpen()) then
      return;
    end
    if(priority >= self.view.visibility and self.view.visibility ~= priority) then
      self.view.visibility = priority
      self:SyncVisibility()
      self:UpdateViewTexture()
    end
    local region = OptionsPrivate.Private.EnsureRegion(self.data.id)
    if region and region.ClickToPick then
      region:ClickToPick();
    end
end

entryMethods.PriorityHide = function(self, priority)
    if (not M33kAuras.IsOptionsOpen()) then
      return;
    end
    if(priority >= self.view.visibility and self.view.visibility ~= 0) then
      self.view.visibility = 0
      self:SyncVisibility()
      self:UpdateViewTexture()
    end
end
