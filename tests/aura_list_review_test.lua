local testsDir=arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path=testsDir.."/?.lua;"..package.path
local T=require("helpers")
local fixture=require("aura_list_stubs").install(T)
local options,model=fixture.options,fixture.options.auraListModel
fixture:add("Group",nil,{"A","B"})
local a=fixture:add("A","Group")
fixture:add("B","Group")
fixture:add("Other")
options.RefreshAuraList("")
fixture:loadMain()
local entry=options.GetDisplayEntry("A")
a.id="Renamed"
M33kAurasSaved.displays.A=nil;M33kAurasSaved.displays.Renamed=a
M33kAurasSaved.displays.Group.controlledChildren[1]="Renamed"
options.GetDisplayEntry("Renamed")
T.expect(not model.byID.A and model.byID.Renamed==entry,"in-place rename removes its previous index before rebuilding the tree")
local function upvalue(fn,key)
  for i=1,100 do local name,value=debug.getupvalue(fn,i);if not name then break end;if name==key then return value end end
  error("missing upvalue "..key)
end
local rename=upvalue(M33kAuras.ToggleOptions,"OnRename")
local ok=pcall(rename,"Rename",a.uid,"A","Renamed")
T.expect(ok and model.byUID[a.uid]==entry,"rename notification tolerates a lookup that already updated the ID index")
fixture:flush()

T.section("Pooled row ownership")
options.RevealDisplay("Renamed")
fixture.view:Render(1000)
local container=CreateFrame("Frame")
options.BindAuraListRow(container,options.auraListNodes[entry.uid])
local row=container.widget
T.expect(row and entry.row==row,"binding a row links it to its entry")
local released=fixture.released
options.ReleaseAuraListRow(container)
T.expect(not entry.row and not container.widget and fixture.released==released+1,
  "releasing a row unlinks its entry and container")
options.BindAuraListRow(container,options.auraListNodes[entry.uid])
T.expect(container.widget==row and entry.row==row,"the same container reuses its row on the next bind")
options.ReleaseAuraListRow(container)

T.section("Batch selection")
fixture.frame:ClearPicks()
fixture.frame:PickDisplayBatch({"Renamed","Renamed","Other"})
T.expect(#options.tempGroup.controlledChildren==2,"duplicate IDs in a batch cannot duplicate the selected aura")

T.section("Invalid Companion previews")
fixture.private.StringToTable=function() return {d={id="Preview",uid="preview",regionType="icon",load={}}} end
fixture.private.CompanionData.stash={good={encoded="valid",name="Valid"}}
options.SortDisplayButtons("");fixture.view:Render(1)
fixture.private.StringToTable=function() return "invalid import" end
fixture.private.CompanionData.stash={bad={encoded="invalid",name="Invalid"}}
options.SortDisplayButtons("")
fixture.view:Render(1)
local invalid
for _,row in ipairs(fixture.view.containers) do if row.widget.type=="M33kAurasPendingInstallButton" then invalid=row.widget end end
T.expect(invalid and not invalid.update:IsEnabled(),"invalid Companion rows cannot invoke their import button")
fixture.private.CompanionData.stash={}
options.SortDisplayButtons()
T.section("Deferred navigation during mutations")
local importing=false
M33kAuras.IsImporting=function() return importing end
options.SortDisplayButtons("Renamed")
local oldProvider,oldScrolls=fixture.view.provider,fixture.scrolls
importing=true
options.RevealDisplay("B")
T.expect(fixture.view.provider==oldProvider and fixture.scrolls==oldScrolls,
  "navigation cannot publish a partially imported tree")
local b=M33kAurasSaved.displays.B
b.id="B after import";M33kAurasSaved.displays.B=nil;M33kAurasSaved.displays[b.id]=b
local children=M33kAurasSaved.displays.Group.controlledChildren
children[assert(tIndexOf(children,"B"))]=b.id
rename("Rename",b.uid,"B",b.id)
importing=false
options.SortDisplayButtons()
T.expect(model.byUID[b.uid].row and options.auraListModel:Includes(model.byUID[b.uid]),
  "deferred navigation resolves the aura by UID after an import renames it")

T.section("Ownership transfer and child tooltips")
local header=fixture.frame.loadedButton
local headerNode={GetData=function() return {widget=header,height=20} end}
local first,second=CreateFrame("Frame"),CreateFrame("Frame")
options.BindAuraListRow(first,headerNode)
options.BindAuraListRow(second,headerNode)
options.ReleaseAuraListRow(first)
T.expect(not first.widget and second.widget==header and header.frame:GetParent()==second and header.frame:IsShown(),
  "releasing an old header container cannot hide the newly bound header")
GameTooltip:SetOwner(header.expand);GameTooltip:Show()
options.ReleaseAuraListRow(second)
T.expect(not GameTooltip:IsShown(),"releasing a row hides tooltips owned by its child controls")
options.BindAuraListRow(first,headerNode)
GameTooltip:SetOwner(UIParent);GameTooltip:Show()
options.ReleaseAuraListRow(first)
T.expect(GameTooltip:IsShown(),"releasing a row leaves unrelated tooltips visible")
GameTooltip:Hide()

T.section("Context menu failure isolation")
options.RevealDisplay("Renamed")
local failedHook=Menu.ModifyMenu("M33KAURAS_DISPLAY_BUTTON_MENU",function() error("injected menu failure") end)
local goodHook=Menu.ModifyMenu("M33KAURAS_DISPLAY_BUTTON_MENU",function(_,root) root:Insert(MenuUtil.CreateButton("Survivor"),#root) end)
GameTooltip:SetOwner(entry.row.frame);GameTooltip:Show()
entry.row.frame:GetScript("OnClick")(entry.row.frame,"RightButton")
T.expect(not GameTooltip:IsShown(),"right-click dispatch hides the tooltip before opening the context menu")
T.expect(fixture.menu[#fixture.menu].text=="Close" and fixture.menu[#fixture.menu-1].text=="Survivor",
  "a failing extension still opens the built-in menu and later extensions")
failedHook:Unregister()
goodHook:Unregister()
T.expect(#fixture.errors==1 and fixture.errors[1]:find("injected menu failure",1,true),"only the intentionally failing extension reports an error")

T.finish()
