if not M33kAuras.IsLibsOK() then return end
local _, OptionsPrivate = ...
local L = M33kAuras.L
local AceGUI = LibStub("AceGUI-3.0")
local methods = {}
OptionsPrivate.DisplayEntryMethods = methods

function OptionsPrivate.CreateDisplayEntry(data)
  return setmetatable({data = data, uid = data.uid, view = {visibility = 0}, enabled = true}, {__index = methods})
end

local model = OptionsPrivate.CreateAuraListModel(OptionsPrivate.CreateDisplayEntry)
OptionsPrivate.auraListModel = model
OptionsPrivate.displayEntries = model.byID

function OptionsPrivate.GetDisplayEntry(id)
  local data = id and M33kAuras.GetData(id)
  if not data then return end
  local entry = model:Ensure(data)
  entry:EnsureInitialized()
  return entry
end

function methods:EnsureInitialized()
  if not self.initialized or not self.callbacks then self:Initialize() end
end

function methods:Initialize()
  self.initialized = nil
  OptionsPrivate.InitializeDisplayEntry(self)
  self.initialized = true
  self:Refresh()
end

function methods:Refresh()
  if self.row then self.row:RefreshEntry() end
end

function methods:SetData(data)
  self.data = data
  self:Refresh()
end

function methods:SetTitle() self:Refresh() end
function methods:GetData() return self.data end
function methods:GetGroup() return self.data.parent end
function methods:IsGroup() return self.data.controlledChildren ~= nil end
function methods:IsLoaded() return OptionsPrivate.Private.loaded[self.data.id] == true end
function methods:IsStandby() return OptionsPrivate.Private.loaded[self.data.id] == false end
function methods:IsUnloaded() return OptionsPrivate.Private.loaded[self.data.id] == nil end
function methods:IsEnabled() return self.enabled end
function methods:GetVisibility() return self.view.visibility end
function methods:GetGroupOrder()
  local parent = self.data.parent and M33kAuras.GetData(self.data.parent)
  return parent and tIndexOf(parent.controlledChildren, self.data.id)
end

function methods:SetGroup() self:Refresh() end
function methods:SetGroupOrder() self:Refresh() end
function methods:UpdateOffset() self:Refresh() end
function methods:UpdateIconsVisible() self:Refresh() end
function methods:UpdateViewTexture()
  self:Refresh()
  self:RecheckParentVisibility()
end
function methods:DisableExpand() self:Refresh() end
function methods:EnableExpand() self:Refresh() end
function methods:Disable() self.enabled = false; self:Refresh() end
function methods:Enable() self.enabled = true; self:Refresh() end
function methods:UpdateWarning() if self.row then self.row:UpdateWarning() end end
function methods:UpdateThumbnail() if self.row then self.row:UpdateThumbnail() end end
function methods:SetNormalTooltip()
  if self.row then self.row:SetNormalTooltip() end
end
function methods:ReloadTooltip()
  if self.row and self.row.frame:IsMouseOver() then
    self.row:SetNormalTooltip()
    self.row:ReloadTooltip()
  end
end

function methods:UpdateParentWarning()
  self:UpdateWarning()
  for parent in OptionsPrivate.Private.TraverseParents(self.data) do
    local entry = model.byID[parent.id]
    if entry then entry:UpdateWarning() end
  end
end

function methods:GetExpanded()
  return not OptionsPrivate.IsCollapsed(self.data.id, "displayButton", "", true)
end

function methods:Expand()
  OptionsPrivate.SetCollapsed(self.data.id, "displayButton", "", false)
  OptionsPrivate.RequestAuraListRefresh()
end

function methods:Collapse()
  OptionsPrivate.SetCollapsed(self.data.id, "displayButton", "", true)
  OptionsPrivate.RequestAuraListRefresh()
end

function methods:Pick()
  self.picked = true
  self:PriorityShow(1)
  self:Refresh()
  self:RecheckParentVisibility()
end

function methods:ClearPick(noHide)
  self.picked = nil
  if not noHide then self:PriorityHide(1) end
  self:Refresh()
  self:RecheckParentVisibility()
end

function methods:BeginRename()
  -- Keep the search when a newly created aura is outside its results.
  if model.filter ~= "" and not model:Includes(self) then return end
  self.renaming = true
  self.renameText = self.data.id
  self.renameFocusRequested = true
  OptionsPrivate.RevealDisplay(self.data.id, true)
  self:Refresh()
end

function methods:SetRenameDraft(text)
  if self.renaming then self.renameText = text end
end

function methods:CancelRename()
  OptionsPrivate.ClearParkedAuraRename(self)
  self.renaming, self.renameText, self.renameFocusRequested = nil, nil, nil
end

function methods:SubmitRename(newid)
  if M33kAuras.IsImporting() then return end
  self:CancelRename()
  if newid ~= self.data.id then M33kAuras.Rename(self.data, newid) end
  self:UpdateParentWarning()
end

function methods:RetainRenameFocus(hasFocus)
  if self.renaming and hasFocus then self.renameFocusRequested = true end
end

function methods:ConsumeRenameFocus()
  OptionsPrivate.ClearParkedAuraRename(self)
  local requested = self.renameFocusRequested
  self.renameFocusRequested = nil
  return requested
end

-- A focused EditBox cannot belong to a recyclable row while it is offscreen.
-- Transfer its input to this persistent host until the row returns.
local parkedRename, renameInput
function OptionsPrivate.ClearParkedAuraRename(entry)
  if parkedRename ~= entry then return end
  parkedRename = nil
  renameInput:ClearFocus()
  renameInput:Hide()
end

function OptionsPrivate.ParkAuraRename(entry)
  if not renameInput then
    renameInput = CreateFrame("EditBox", nil, OptionsPrivate.Private.OptionsFrame())
    renameInput:SetSize(1, 1)
    renameInput:SetPoint("TOPLEFT")
    renameInput:SetAlpha(0)
    renameInput:SetAutoFocus(false)
    renameInput:SetFont(STANDARD_TEXT_FONT, 10, "")
    renameInput:SetScript("OnTextChanged", function(box)
      if parkedRename then parkedRename:SetRenameDraft(box:GetText()) end
    end)
    renameInput:SetScript("OnEnterPressed", function(box)
      local current, text = parkedRename, box:GetText()
      if not current then return end
      if text == "" or (text ~= current.data.id and M33kAuras.GetData(text)) then
        box:SetText(current.data.id)
        return
      end
      current:SubmitRename(text)
    end)
    renameInput:SetScript("OnEscapePressed", function()
      local current = parkedRename
      if current then current:CancelRename(); current:Refresh() end
    end)
  end
  parkedRename = entry
  renameInput:SetText(entry.renameText or entry.data.id)
  renameInput:Show()
  renameInput:SetFocus()
end

function methods:MoveChild(direction)
  if M33kAuras.IsImporting() then return end
  local parent = self.data.parent and M33kAuras.GetData(self.data.parent)
  local index = self:GetGroupOrder()
  if not parent or not index or index + direction < 1 or index + direction > #parent.controlledChildren then return end
  table.remove(parent.controlledChildren, index)
  table.insert(parent.controlledChildren, index + direction, self.data.id)
  M33kAuras.Add(parent)
  OptionsPrivate.Private.AddParents(parent)
  M33kAuras.ClearAndUpdateOptions(parent.id)
  OptionsPrivate.SortDisplayButtons(nil, true)
  M33kAuras.FillOptions()
end

function methods:StartGrouping(ids, selected, group, descendant)
  self:EnsureInitialized()
  self.grouping = ids
  self.enabled = selected or (not descendant and self:IsGroup() and not (group and self.data.regionType == "dynamicgroup"))
  self.click = selected and self.callbacks.OnClickGroupingSelf or self.callbacks.OnClickGrouping
  self:Refresh()
end

function methods:StopGrouping()
  self.grouping, self.click, self.enabled = nil, nil, true
  self:Refresh()
end

function methods:DragStart(mode, picked, mainAura)
  self.dragging = picked
  local parent = self.data.parent and M33kAuras.GetData(self.data.parent)
  self.enabled = picked or ((self.data.parent or self:IsGroup()) and
    not (mode == "GROUP" and (self.data.regionType == "dynamicgroup" or (parent and parent.regionType == "dynamicgroup"))))
  self:Refresh()
  if self.data.id == mainAura.id then OptionsPrivate.StartAuraDrag(self) end
end

function methods:IsDragging() return self.dragging end
function methods:Drop(mode, mainAura, target, action)
  if self.dragging and (mode ~= "GROUP" or mainAura.id == self.data.id) and action and target then
    action(self, target)
  end
  self:DropEnd()
end
function methods:DropEnd()
  self.dragging, self.dropping, self.enabled = nil, nil, true
  self:Refresh()
end
function methods:DragReset() self:DropEnd() end

function methods:RenderLoadStatus(row)
  local active, standby, unloaded = self.activeCount or 0, self.standbyCount or 0, self.unloadedCount or 0
  if self:IsGroup() then
    if active > 0 then
      row:SetLoaded(1, "loaded", L["Loaded"], L["%d displays loaded"]:format(active))
    elseif standby > 0 then
      row:SetLoaded(2, "standby", L["Standby"], L["%d displays on standby"]:format(standby))
    elseif unloaded > 0 then
      row:SetLoaded(3, "unloaded", L["Not Loaded"], L["%d displays not loaded"]:format(unloaded))
    else
      row:ClearLoaded()
    end
  elseif self:IsLoaded() then
    row:SetLoaded(1, "loaded", L["Loaded"], L["This display is currently loaded"])
  elseif self:IsStandby() then
    row:SetLoaded(2, "standby", L["Standby"], L["This display is on standby, it will be loaded when needed."])
  else
    row:SetLoaded(3, "unloaded", L["Not Loaded"], L["This display is not currently loaded"])
  end
end

local previewQueued
function OptionsPrivate.RefreshAuraPreviews()
  previewQueued = nil
  if OptionsPrivate.IsAuraListBusy() then return end
  local function visit(entry)
    if model.byUID[entry.uid] ~= entry then return end
    if entry.data.controlledChildren then
      local all, none = #entry.children > 0, true
      for _, child in ipairs(entry.children) do
        visit(child)
        all = all and child.view.visibility == 2
        none = none and child.view.visibility == 0
      end
      entry.view.visibility = all and 2 or none and 0 or 1
      entry:Refresh()
    end
  end
  for _, entry in ipairs(model.roots) do visit(entry) end
  local frame = OptionsPrivate.Private.OptionsFrame()
  if frame then
    frame.loadedButton:RecheckVisibility()
    frame.unloadedButton:RecheckVisibility()
  end
end

function methods:RecheckParentVisibility()
  if previewQueued then return end
  previewQueued = true
  C_Timer.After(0, OptionsPrivate.RefreshAuraPreviews)
end
methods.RecheckVisibility = methods.RecheckParentVisibility

-- Decoding an import can be expensive; scrolling must not repeatedly decode it.
local companionPreviews = setmetatable({}, {__mode = "k"})
function OptionsPrivate.GetCompanionPreview(companion)
  local cached = companionPreviews[companion]
  if not cached or cached.encoded ~= companion.encoded then
    local decoded = OptionsPrivate.Private.StringToTable(companion.encoded, true)
    local data = type(decoded) == "table" and type(decoded.d) == "table" and decoded.d or nil
    if data then M33kAuras.PreAdd(data) end
    cached = {encoded = companion.encoded, data = data}
    companionPreviews[companion] = cached
  end
  return cached.data
end

local function companionSections(frame, provider)
  local companion = OptionsPrivate.Private.CompanionData
  local installs = {}
  for id, data in pairs(companion.stash or {}) do installs[#installs + 1] = {id = id, data = data} end
  table.sort(installs, function(a, b) return tostring(a.id) < tostring(b.id) end)
  if #installs > 0 then
    local header = provider:Insert({widget = frame.pendingInstallButton, height = 20})
    header:SetCollapsed(not frame.pendingInstallButton:GetExpanded())
    for _, item in ipairs(installs) do
      header:Insert({kind = "M33kAurasPendingInstallButton", id = item.id, companion = item.data, height = 32})
    end
  end
  local updates = {}
  for id, data in pairs(M33kAurasSaved.displays) do
    if not data.ignoreWagoUpdate and data.url then
      local slug, version = data.url:match("wago.io/([^/]+)/([0-9]+)")
      if not slug then slug, version = data.url:match("wago.io/([^/]+)$"), 1 end
      local update = slug and companion.slugs and companion.slugs[slug]
      if update and tonumber(update.wagoVersion) and tonumber(update.wagoVersion) > tonumber(version) then
        local item = updates[slug]
        if not item then
          item = {kind = "M33kAurasPendingUpdateButton", id = slug, companion = update, auras = {}, children = {}, height = 32}
          updates[slug] = item
        end
        item.auras[id] = true
        for child in OptionsPrivate.Private.TraverseAllChildren(data) do item.children[child.id] = true end
      end
    end
  end
  local slugs = {}
  for slug in pairs(updates) do slugs[#slugs + 1] = slug end
  table.sort(slugs)
  if #slugs > 0 then
    local header = provider:Insert({widget = frame.pendingUpdateButton, height = 20})
    header:SetCollapsed(not frame.pendingUpdateButton:GetExpanded())
    for _, slug in ipairs(slugs) do header:Insert(updates[slug]) end
  end
end

function OptionsPrivate.ReleaseAuraListRow(container)
  local widget = container.widget
  if not widget then return end
  local owned = container.owned
  container.widget, container.owned = nil, nil
  if widget.auraListContainer ~= container then return end
  -- AceGUI:Release hides the frame before OnRelease, clearing EditBox focus.
  -- Move the draft's focus while the row is still visible.
  if widget.entry and widget.entry.renaming and widget.renamebox:HasFocus() then
    widget.entry:RetainRenameFocus(true)
    OptionsPrivate.ParkAuraRename(widget.entry)
  end
  widget.auraListContainer = nil
  if widget.entry and widget.entry.row == widget then widget.entry.row = nil end
  local owner = GameTooltip:GetOwner()
  while owner do
    if owner == widget.frame then GameTooltip:Hide(); break end
    owner = owner:GetParent()
  end
  if owned then
    AceGUI:Release(widget)
  else
    widget.frame:Hide()
    widget.frame:SetParent(UIParent)
  end
end

function OptionsPrivate.BindAuraListRow(container, node)
  -- Blizzard may reinitialize a retained frame without releasing it first.
  OptionsPrivate.ReleaseAuraListRow(container)
  local item = node:GetData()
  local widget = item.widget
  if widget and widget.auraListContainer then
    OptionsPrivate.ReleaseAuraListRow(widget.auraListContainer)
  elseif item.entry and item.entry.row and item.entry.row.auraListContainer then
    OptionsPrivate.ReleaseAuraListRow(item.entry.row.auraListContainer)
  end
  widget = widget or AceGUI:Create(item.entry and "M33kAurasDisplayButton" or item.kind)
  container.widget, container.owned = widget, not item.widget
  widget.auraListContainer = container
  if item.entry then
    widget.entry = item.entry
    item.entry.row = widget
    widget:SetData(item.entry.data)
    widget:Initialize()
    widget:AcquireThumbnail()
  elseif item.kind then
    widget:Initialize(item.id, item.companion)
    if item.companion.logo then widget:SetLogo(item.companion.logo) end
    if item.companion.refreshLogo then widget:SetRefreshLogo(item.companion.refreshLogo) end
    for id in pairs(item.auras or {}) do widget:MarkLinkedAura(id) end
    for id in pairs(item.children or {}) do widget:MarkLinkedChildren(id) end
    widget:AcquireThumbnail()
  end
  widget.frame:SetParent(container)
  widget.frame:ClearAllPoints()
  widget.frame:SetAllPoints(container)
  widget.frame:Show()
end

function OptionsPrivate.CreateAuraList(parent)
  local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
  box:SetPoint("TOPLEFT", 0, 0)
  box:SetPoint("BOTTOMRIGHT", -18, 0)
  local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
  bar:SetPoint("TOPRIGHT", -3, -2)
  bar:SetPoint("BOTTOMRIGHT", -3, 2)
  local view = CreateScrollBoxListTreeListView(8, 0, 0, 0, 0, 2)
  view:SetElementIndentCalculator(function(node)
    -- Section headers are structural parents, not aura groups.
    return math.max(0, node:GetDepth() - 2) * 8
  end)
  view:SetElementInitializer("Frame", OptionsPrivate.BindAuraListRow)
  view:SetElementExtentCalculator(function(_, node) return node:GetData().height end)
  view:SetElementResetter(OptionsPrivate.ReleaseAuraListRow)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
  local function validateRect()
    if box:IsRectValid() then return false end
    -- A shown box can retain an invalid rect. Zero offsets do not repair it;
    -- alternate a small offset to trigger validation without accumulating drift.
    local offset = box.pointsAdjusted and -0.0001 or 0.0001
    box.pointsAdjusted = not box.pointsAdjusted
    box:AdjustPointsOffset(offset, offset)
    return true
  end
  box:HookScript("OnHide", function() OptionsPrivate.CloseDisplayButtonMenu() end)
  box:HookScript("OnShow", function(self)
    validateRect()
    self:FullUpdate(true)
  end)
  -- Resizing can invalidate the rect without hiding/showing the ScrollBox.
  -- Watch the parent: an already-zero-sized box may emit no size change itself.
  local resizeTimer
  parent:HookScript("OnSizeChanged", function()
    if resizeTimer then resizeTimer:Cancel() end
    resizeTimer = C_Timer.NewTimer(0.05, function()
      resizeTimer = nil
      if box:IsVisible() and validateRect() then
        box:FullUpdate(true)
      end
    end)
  end)
  OptionsPrivate.ScrollBox, OptionsPrivate.ScrollView = box, view
  return box
end

local refreshQueued, refreshing, pendingReveal
function OptionsPrivate.RequestAuraListRefresh()
  if refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0, function()
    refreshQueued = nil
    if OptionsPrivate.Private.OptionsFrame() then OptionsPrivate.SortDisplayButtons(nil, true) end
  end)
end

function OptionsPrivate.IsAuraListBusy()
  return OptionsPrivate.Private.IsOptionsProcessingPaused() or M33kAuras.IsImporting()
    or OptionsPrivate.massDelete or OptionsPrivate.movingAuras
end

function OptionsPrivate.RefreshAuraList(filter)
  local frame = OptionsPrivate.Private.OptionsFrame()
  if not frame or refreshing then return end
  if OptionsPrivate.IsAuraListBusy() then frame.needsSort = true; return end
  refreshing = true
  model:Sync(M33kAurasSaved.displays, OptionsPrivate.Private.loaded, filter)
  local provider = CreateTreeDataProvider()
  companionSections(frame, provider)
  local loaded = provider:Insert({widget = frame.loadedButton, height = 20})
  local unloaded = provider:Insert({widget = frame.unloadedButton, height = 20})
  loaded:SetCollapsed(not frame.loadedButton:GetExpanded())
  unloaded:SetCollapsed(not frame.unloadedButton:GetExpanded())
  wipe(frame.loadedButton.childButtons)
  wipe(frame.unloadedButton.childButtons)
  local nodes = {}
  local function insert(entry, parent)
    if not model:Includes(entry) then return end
    local node = parent:Insert({entry = entry, height = 32})
    nodes[entry.uid] = node
    node:SetCollapsed(not entry:GetExpanded())
    for _, child in ipairs(entry.children) do insert(child, node) end
  end
  local function collectLeaves(entry, children)
    if not entry.data.controlledChildren then children[#children + 1] = entry end
    for _, child in ipairs(entry.children) do collectLeaves(child, children) end
  end
  for _, root in ipairs(model.roots) do
    local isLoaded = root.section == "loaded"
    collectLeaves(root, isLoaded and frame.loadedButton.childButtons or frame.unloadedButton.childButtons)
    insert(root, isLoaded and loaded or unloaded)
  end
  OptionsPrivate.auraListNodes = nodes
  local box = OptionsPrivate.ScrollBox
  local offset = box:GetDerivedScrollOffset()
  box:GetScrollInterpolator():Cancel()
  box:SetDataProvider(provider, true)
  -- Provider replacement can change the range. Restore a pixel offset, rather
  -- than retaining an old percentage or an in-flight navigation animation.
  if box:GetDerivedScrollRange() > 0 then
    box:ScrollToOffset(offset, true)
  else
    box:SetScrollPercentage(0, true)
  end
  OptionsPrivate.RefreshAuraPreviews()
  refreshing = nil
  if pendingReveal then
    local request = pendingReveal
    local entry = model.byUID[request.uid]
    pendingReveal = nil
    if entry then OptionsPrivate.RevealDisplay(entry.data.id, request.preserveFilter, request.alignment) end
  end
end

function OptionsPrivate.RevealDisplay(id, preserveFilter, alignment)
  local entry = OptionsPrivate.GetDisplayEntry(id)
  local frame = OptionsPrivate.Private.OptionsFrame()
  if not entry or not frame then return end
  if refreshing or OptionsPrivate.IsAuraListBusy() then
    pendingReveal = {uid = entry.uid, preserveFilter = preserveFilter, alignment = alignment}
    frame.needsSort = true
    return
  end
  local changed = false
  if model.filter ~= "" and not model:Includes(entry) then
    if preserveFilter then return end
    frame.filterInput:SetText("")
    changed = true
  end
  for parent in OptionsPrivate.Private.TraverseParents(entry.data) do
    if OptionsPrivate.IsCollapsed(parent.id, "displayButton", "", true) then
      OptionsPrivate.SetCollapsed(parent.id, "displayButton", "", false)
      changed = true
    end
  end
  local root = entry
  while root.parent do root = root.parent end
  local header = root.section == "unloaded" and frame.unloadedButton or frame.loadedButton
  if not header:GetExpanded() then header:Expand(); changed = true end
  if changed or not OptionsPrivate.auraListNodes or not OptionsPrivate.auraListNodes[entry.uid] then
    OptionsPrivate.RefreshAuraList(frame.filterInput:GetText())
  end
  OptionsPrivate.ScrollBox:ScrollToElementDataByPredicate(function(node)
    return node:GetData().entry == entry
  end, alignment or ScrollBoxConstants.AlignNearest, 0, true)
end

local dragGhost, dragEntry
function OptionsPrivate.IsAuraDragging()
  return dragEntry ~= nil
end

function OptionsPrivate.StartAuraDrag(entry)
  if dragEntry then return end
  OptionsPrivate.CloseDisplayButtonMenu()
  dragEntry = entry
  if not dragGhost then
    dragGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplateM33kAuras")
    dragGhost:EnableMouse(false)
    dragGhost:SetSize(260, 32)
    dragGhost:SetFrameStrata("FULLSCREEN_DIALOG")
    dragGhost:SetBackdrop({bgFile = "Interface/Buttons/WHITE8X8"})
    dragGhost:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    dragGhost.text = dragGhost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dragGhost.text:SetAllPoints()
    dragGhost:SetScript("OnHide", function()
      if dragEntry then OptionsPrivate.DragReset() end
    end)
    dragGhost:SetScript("OnKeyDown", function(_, key)
      dragGhost:SetPropagateKeyboardInput(key ~= "ESCAPE")
      if key == "ESCAPE" then OptionsPrivate.DragReset() end
    end)
    dragGhost:SetScript("OnUpdate", function(_, elapsed)
      -- Cancellation takes priority if both mouse buttons change this frame.
      if IsMouseButtonDown("RightButton") then
        OptionsPrivate.DragReset()
        return
      end
      -- A recycled row can emit OnDragStop while the button is still held.
      -- Only the physical mouse release commits the drag.
      if not IsMouseButtonDown("LeftButton") then
        if dragEntry then dragEntry.callbacks.OnDragStop() end
        return
      end
      local x, y = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      dragGhost:ClearAllPoints()
      dragGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
      local box = OptionsPrivate.ScrollBox
      if box:IsMouseOver(0, 0, 0, 0) then
        local localY = y / box:GetEffectiveScale()
        if localY > box:GetTop() - 24 then box:ScrollToOffset(math.max(0, box:GetDerivedScrollOffset() - elapsed * 300))
        elseif localY < box:GetBottom() + 24 then box:ScrollToOffset(box:GetDerivedScrollOffset() + elapsed * 300) end
      end
      if dragEntry then OptionsPrivate.UpdateAuraDropIndicator(dragEntry.data.id) end
    end)
  end
  local count = OptionsPrivate.IsPickedMultiple() and #OptionsPrivate.tempGroup.controlledChildren
  dragGhost.text:SetText(count and L["%i auras selected"]:format(count) or entry.data.id)
  dragGhost:EnableKeyboard(true)
  dragGhost:SetPropagateKeyboardInput(true)
  dragGhost:Show()
end

function OptionsPrivate.EndAuraDrag()
  dragEntry = nil
  if dragGhost then dragGhost:Hide(); dragGhost:EnableKeyboard(false) end
  local frame = OptionsPrivate.Private.OptionsFrame()
  if frame and frame.dropIndicator then frame.dropIndicator:Hide() end
end
