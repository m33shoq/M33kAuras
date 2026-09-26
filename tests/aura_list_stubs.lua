-- UI lifecycle doubles for the real aura-list controller and AceGUI rows.
local stubs = require("wow_stubs")
local M = {}
function M.install(T)
  stubs.install()
  local fixture = {frames = {}, timers = {}, errors = {}, previews = {}, acquired = 0, released = 0}
  local function noop() end
  local frameMethods = {}
  local function frame(parent)
    local f = {parent = parent, scripts = {}, events = {}, shown = true, enabled = true, width = 400, height = 400}
    return setmetatable(f, {__index = function(_, key)
      return frameMethods[key] or (key:match("^Set") and noop)
    end})
  end
  function frameMethods:SetScript(event, callback) self.scripts[event] = callback end
  function frameMethods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
      if previous then previous(...) end
      callback(...)
    end
  end
  function frameMethods:GetScript(event) return self.scripts[event] end
  function frameMethods:RegisterEvent(event) self.events[event] = true end
  function frameMethods:SetParent(parent) self.parent = parent end
  function frameMethods:GetParent() return self.parent end
  function frameMethods:SetWidth(w) self.width = w end
  function frameMethods:SetHeight(h) self.height = h end
  function frameMethods:SetSize(w,h) self.width,self.height=w,h end
  function frameMethods:GetWidth() return self.width end
  function frameMethods:GetHeight() return self.height end
  function frameMethods:GetFrameLevel() return 1 end
  function frameMethods:GetFrameStrata() return "DIALOG" end
  function frameMethods:GetEffectiveScale() return 1 end
  function frameMethods:GetScale() return 1 end
  function frameMethods:CreateTexture() return frame(self) end
  function frameMethods:CreateFontString() return frame(self) end
  function frameMethods:CreateAnimationGroup() return frame(self) end
  function frameMethods:CreateAnimation() return frame(self) end
  function frameMethods:SetNormalTexture(texture) self.normal = type(texture)=="table" and texture or frame(self) end
  function frameMethods:GetNormalTexture() self.normal=self.normal or frame(self); return self.normal end
  function frameMethods:SetText(text)
    local changed = text ~= self.text
    self.text = text
    if changed and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
  end
  function frameMethods:GetText() return self.text or "" end
  function frameMethods:SetFocus() self.focused=true end
  function frameMethods:HasFocus() return self.focused==true end
  function frameMethods:ClearFocus() self.focused=false end
  function frameMethods:Enable() self.enabled=true end
  function frameMethods:Disable() self.enabled=false end
  function frameMethods:IsEnabled() return self.enabled end
  function frameMethods:Hide() self.shown=false end
  function frameMethods:Show() self.shown=true end
  function frameMethods:IsRectValid() return self.rectValid~=false end
  function frameMethods:AdjustPointsOffset(x,y)
    self.pointOffsetX=(self.pointOffsetX or 0)+x
    self.pointOffsetY=(self.pointOffsetY or 0)+y
    self.rectValid=true
  end
  function frameMethods:IsShown() return self.shown end
  frameMethods.IsVisible=frameMethods.IsShown
  function frameMethods:IsMouseOver() return false end
  function frameMethods:LockHighlight() self.highlight=true end
  function frameMethods:UnlockHighlight() self.highlight=false end
  function frameMethods:IsOwned(owner) return self.owner==owner end
  function frameMethods:SetOwner(owner) self.owner=owner end
  function frameMethods:GetOwner() return self.owner end
  for _, key in ipairs({"ClearAllPoints","EnableMouse","EnableKeyboard","RegisterForDrag","RegisterForClicks","Stop","Play","AddLine","AddDoubleLine","ClearLines","ReleaseChildren"}) do frameMethods[key]=noop end
  _G.CreateFrame=function(_,name,parent)
    local f=frame(parent)
    if name then _G[name]=f end
    fixture.frames[#fixture.frames+1]=f
    return f
  end
  _G.CreateFramePool=function(_,_,_,reset)
    local free={}
    return {Acquire=function() return table.remove(free) or frame() end, Release=function(self,f)
      if reset then reset(self,f) else f:Hide();f:ClearAllPoints() end
      free[#free+1]=f
    end}
  end
  _G.UIParent=frame()
  _G.GameTooltip=frame()
  _G.M33kAuras_DropDownMenu=frame()
  _G.C_Texture={GetAtlasInfo=function() return false end}
  _G.StaticPopupDialogs={}
  _G.C_Timer={After=function(_,callback) fixture.timers[#fixture.timers+1]=callback end}
  function C_Timer.NewTimer(delay, callback)
    local timer={delay=delay,Cancel=function(self) self.cancelled=true end}
    fixture.timers[#fixture.timers+1]=function() if not timer.cancelled then callback(timer) end end
    fixture.lastTimer=timer
    return timer
  end
  _G.tIndexOf=function(list,value) for i,v in ipairs(list) do if v==value then return i end end end
  _G.geterrorhandler=function() return function(err) fixture.errors[#fixture.errors+1]=err end end
  _G.ScrollBoxConstants={AlignCenter=0.5,AlignNearest="nearest"}
  _G.GetScreenWidth=function() return 1920 end
  _G.GetScreenHeight=function() return 1080 end
  _G.InCombatLockdown=function() return false end
  _G.IsControlKeyDown=function() return false end
  _G.IsShiftKeyDown=function() return false end
  local ace={types={},pools={},num=0}
  function ace:RegisterWidgetType(name,ctor) self.types[name]=ctor end
  function ace:GetWidgetVersion() return nil end
  function ace:GetNextWidgetNum() self.num=self.num+1; return self.num end
  function ace:RegisterAsWidget(widget)
    widget.SetWidth=function(self,w) self.frame:SetWidth(w) end
    widget.SetHeight=function(self,h) self.frame:SetHeight(h) end
    return widget
  end
  function ace:RegisterLayout() end
  function ace:Create(name)
    self.pools[name]=self.pools[name] or {}
    local widget=table.remove(self.pools[name])
    if not widget then widget=assert(self.types[name],name)(); fixture.acquired=fixture.acquired+1 end
    if widget.OnAcquire then widget:OnAcquire() end
    return widget
  end
  function ace:Release(widget)
    -- AceGUI hides the frame before invoking the widget release method.
    widget.frame:Hide()
    if widget.renamebox then widget.renamebox:ClearFocus() end
    widget:OnRelease()
    assert(widget.frame,"released widget lost its reusable frame")
    self.pools[widget.type][#self.pools[widget.type]+1]=widget
    fixture.released=fixture.released+1
  end
  local dropdown={CloseDropDownMenus=noop,EasyMenu=function(_,menu) fixture.menu=menu end}
  _G.LibStub=setmetatable({GetLibrary=function(_,name) return name=="AceGUI-3.0" and ace or dropdown end},
    {__call=function(_,name) return name=="AceGUI-3.0" and ace or dropdown end})
  local nodeMethods={}
  function nodeMethods:Insert(data)
    local node=setmetatable({data=data,children={},parent=self}, {__index=nodeMethods})
    self.children[#self.children+1]=node
    return node
  end
  function nodeMethods:GetData() return self.data end
  function nodeMethods:SetCollapsed(value) self.collapsed=value end
  function nodeMethods:IsCollapsed() return self.collapsed end
  function nodeMethods:GetNodes() return self.children end
  _G.CreateTreeDataProvider=function() return setmetatable({children={}}, {__index=nodeMethods}) end
  local function flatten(provider)
    local out={}
    local function visit(node)
      out[#out+1]=node
      if not node:IsCollapsed() then for _,child in ipairs(node:GetNodes()) do visit(child) end end
    end
    for _,node in ipairs(provider.GetChildrenNodes and provider:GetChildrenNodes() or provider.children) do visit(node) end
    return out
  end
  _G.CreateScrollBoxListTreeListView=function()
    local view={containers={},first=1,count=8}
    function view:SetElementInitializer(_,init) self.init=init end
    function view:SetElementResetter(reset) self.reset=reset end
    function view:SetElementExtentCalculator(fn) self.extent=fn end
    function view:SetElementIndentCalculator(fn) self.indent=fn end
    function view:Render(first,count)
      for _,container in ipairs(self.containers) do self.reset(container) end
      self.containers={};self.first=first or self.first;self.count=count or self.count
      local nodes=flatten(self.provider)
      for i=self.first,math.min(#nodes,self.first+self.count-1) do
        local container=frame();container.node=nodes[i]
        self.containers[#self.containers+1]=container
        assert(self.extent(i,nodes[i])>0)
        self.init(container,nodes[i])
      end
    end
    function view:SetDataProvider(provider) self.provider=provider;self:Render() end
    function view:GetDataProvider() return self.provider end
    return view
  end
  _G.ScrollUtil={InitScrollBoxListWithScrollBar=function(box,bar,view)
    fixture.view=view;fixture.box=box;fixture.scrolls=0
    function box:GetScrollInterpolator() return {Cancel=function() fixture.scrollCancelled=true end} end
    function box:GetDerivedScrollOffset() return (view.first-1)*34 end
    function box:GetDerivedScrollRange() return math.max(0,(#flatten(view.provider)-view.count)*34) end
    function box:FullUpdate(immediately)
      if immediately then
        self:SetScript("OnUpdate", nil)
        view:Render()
      else
        self:SetScript("OnUpdate", function(self)
          self:SetScript("OnUpdate", nil)
          view:Render()
        end)
      end
    end
    function box:SetDataProvider(provider)
      view.provider=provider
      self:FullUpdate(true)
    end
    function box:ScrollToOffset(offset)
      local clamped=math.max(0,math.min(offset,self:GetDerivedScrollRange()))
      view:Render(1+math.floor(clamped/34))
    end
    function box:SetScrollPercentage(value) self:ScrollToOffset(value*self:GetDerivedScrollRange()) end
    function box:ScrollToElementDataByPredicate(predicate,alignment)
      if alignment==ScrollBoxConstants.AlignNearest then
        for _,container in ipairs(view.containers) do if predicate(container.node) then return end end
      end
      fixture.scrolls=fixture.scrolls+1
      for i,node in ipairs(flatten(view.provider)) do
        if predicate(node) then view:Render(math.max(1,i-2));return end
      end
    end
  end}
  _G.M33kAuras=stubs.newM33kAuras()
  M33kAuras.spellCache={Load=noop}
  M33kAuras.IsOptionsOpen=function() return true end
  M33kAuras.IsImporting=function() return false end
  M33kAuras.GetData=function(id) return M33kAurasSaved.displays[id] end
  local nextUID=0
  M33kAuras.GenerateUniqueID=function() nextUID=nextUID+1;return "generated-"..nextUID end
  M33kAuras.Add=function(data) M33kAurasSaved.displays[data.id]=data end
  M33kAuras.ClearAndUpdateOptions=noop
  M33kAuras.SetMoverSizer=noop
  M33kAuras.FillOptions=noop
  local function traversal(data,include,leafs)
    local result={}
    local function visit(d)
      if not leafs or not d.controlledChildren then result[#result+1]=d end
      for _,id in ipairs(d.controlledChildren or {}) do visit(assert(M33kAuras.GetData(id))) end
    end
    if include then visit(data) else for _,id in ipairs(data.controlledChildren or {}) do visit(assert(M33kAuras.GetData(id))) end end
    local index=0
    return function() index=index+1; return result[index] end
  end
  local private={loaded={},CompanionData={},regionOptions={},regions={},clones={},callbacks={RegisterCallback=noop},
    AuraWarnings={GetAllWarnings=function() end},AddParents=noop,ScanForLoads=noop,IsOptionsProcessingPaused=function() return false end,
    IsGroupType=function(data) return data.controlledChildren~=nil end,
    EnsureRegion=function() return {} end,FakeStatesFor=function(id,visible) fixture.previews[id]=visible end,
    PauseAllDynamicGroups=function() return {} end,ResumeAllDynamicGroups=noop,CollapseAllClones=noop,
    GetTriggerDescription=noop,Pause=noop,Resume=noop,
    GetDataByUID=function(uid) for _,data in pairs(M33kAurasSaved.displays) do if data.uid==uid then return data end end end,
    TraverseAll=function(d) return traversal(d,true,false) end,
    TraverseAllChildren=function(d) return traversal(d,false,false) end,
    TraverseLeafs=function(d) return traversal(d,false,true) end,
    TraverseParents=function(d) return function() d=d.parent and M33kAuras.GetData(d.parent);return d end end,
    splitAtOr=function(text)
      local terms={}
      for term in text:gsub(" or ","|"):gmatch("[^|]+") do terms[#terms+1]=term end
      return terms
    end,
  }
  function private:Async(_,fn)
    local co=coroutine.create(fn)
    while coroutine.status(co)~="dead" do local ok,err=coroutine.resume(co);assert(ok,err) end
    return {Finally=function(self,fn) fn();return self end}
  end
  local options={Private=private,registerRegions={},tempGroup={id={},controlledChildren={}},ResetMoverSizer=noop,ClearOptions=noop,ClearTriggerExpandState=noop}
  fixture.options,fixture.private,fixture.ace=options,private,ace
  local saved={}
  options.IsCollapsed=function(id,_,_,default) if saved[id]==nil then return default end;return saved[id] end
  options.SetCollapsed=function(id,_,_,value) saved[id]=value end
  options.SortDisplayButtons=function(filter) options.RefreshAuraList(filter or "") end
  options.IsPickedMultiple=function() return false end
  options.IsDisplayPicked=function(id) return options.displayEntries[id] and options.displayEntries[id].picked end
  require("display_button_menu_stubs").install(fixture)
  T.loadAddonFile("M33kAurasOptions/AuraListModel.lua","M33kAurasOptions",options)
  T.loadAddonFile("M33kAurasOptions/AuraList.lua","M33kAurasOptions",options)
  T.loadAddonFile("M33kAurasOptions/AuraListThumbnail.lua","M33kAurasOptions",options)
  T.loadAddonFile("M33kAurasOptions/DisplayEntryActions.lua","M33kAurasOptions",options)
  T.loadAddonFile("M33kAurasOptions/DisplayButtonMenu.lua","M33kAurasOptions",options)
  T.loadAddonFile("M33kAurasOptions/AceGUI-Widgets/AceGUIWidget-M33kAurasDisplayButton.lua","M33kAurasOptions",options)
  T.loadAddonFile("M33kAurasOptions/AceGUI-Widgets/AceGUIWidget-M33kAurasLoadedHeaderButton.lua","M33kAurasOptions",options)
  for _,kind in ipairs({"Install","Update"}) do
    T.loadAddonFile("M33kAurasOptions/AceGUI-Widgets/AceGUIWidget-M33kAurasPending"..kind.."Button.lua","M33kAurasOptions",options)
  end
  local root=frame()
  root.filterInput=frame();root.container=frame();root.moversizer=frame()
  root.ClearOptions=noop;root.ClearAndUpdateOptions=noop;root.FillOptions=noop;root.SetLoadProgressVisible=noop;root.loadProgress=frame()
  for _,key in ipairs({"loadedButton","unloadedButton","pendingInstallButton","pendingUpdateButton"}) do
    local header=ace:Create("M33kAurasLoadedHeaderButton")
    header:SetText(key);header.childButtons={};header.RecheckVisibility=noop;header:Expand()
    root[key]=header
  end
  private.OptionsFrame=function() return root end
  options.CreateAuraList(root)
  fixture.frame=root
  function fixture:flush()
    local count=0
    while #self.timers>0 do
      count=count+1;assert(count<30,"endless scheduled refresh")
      local pending=self.timers;self.timers={}
      for _,fn in ipairs(pending) do fn() end
    end
  end
  function fixture:add(id,parent,children)
    local data={id=id,uid="uid-"..id,parent=parent,controlledChildren=children,regionType=children and "group" or "icon",load={},desc="",triggers={}}
    M33kAuras.Add(data)
    return data
  end
  function fixture:loadMain()
    T.loadAddonFile("M33kAurasOptions/M33kAurasOptions.lua","M33kAurasOptions",options)
    M33kAuras.SetMoverSizer=noop
    options.ResetMoverSizer=noop
    -- Inject the options frame without constructing unrelated options panels.
    for i=1,30 do
      local name=debug.getupvalue(M33kAuras.ShowOptions,i)
      if not name then break end
      if name=="frame" then debug.setupvalue(M33kAuras.ShowOptions,i,root) end
    end
    for _,f in ipairs(self.frames) do
      if f.events.ADDON_LOADED then f.scripts.OnEvent(f,"ADDON_LOADED","M33kAurasOptions") end
    end
    local file=assert(io.open(T.repoRoot.."/M33kAurasOptions/OptionsFrames/OptionsFrame.lua"));local source=file:read("*a");file:close()
    local a=assert(source:find("  frame.ClearPick =",1,true));local b=assert(source:find("  frame.GetTargetAura =",a,true))
    local c=assert(source:find("  frame.PickDisplay =",1,true));local d=assert(source:find("  frame.GetPickedDisplay =",c,true))
    local chunk=assert(loadstring("local frame, OptionsPrivate = ...; local displayEntries = OptionsPrivate.displayEntries; local tempGroup = OptionsPrivate.tempGroup; local container = frame.container; local loadedButton, unloadedButton = frame.loadedButton, frame.unloadedButton; "..source:sub(a,b-1)..source:sub(c,d-1)))
    chunk(root,options)
    local filterStart=assert(source:find("  local lastFilterText =",1,true))
    local filterEnd=assert(source:find("  filterInput:SetHeight",filterStart,true))
    _G.SearchBoxTemplate_OnTextChanged=function() end
    assert(loadstring("local filterInput, OptionsPrivate = ...; "..source:sub(filterStart,filterEnd-1)))(root.filterInput,options)
  end
  return fixture
end
return M
