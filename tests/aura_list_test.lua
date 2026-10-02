local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
local fixture = require("aura_list_stubs").install(T)
local options, model = fixture.options, fixture.options.auraListModel
fixture:add("Group",nil,{"Alpha","Beta"})
local alpha=fixture:add("Alpha","Group")
fixture:add("Beta","Group")
fixture:add("Other")
fixture.private.loaded.Alpha=true
fixture.private.loaded.Beta=false
options.RefreshAuraList("")
T.expect(model.byID.Group.activeCount==1 and model.byID.Group.standbyCount==1,"group load indicators aggregate leaves without changing runtime load states")
T.expect(fixture.private.loaded.Group==nil,"UI aggregation does not mutate runtime group loading")
local entry=options.GetDisplayEntry("Alpha")
local scrolls=fixture.scrolls
entry:Pick();entry:PriorityShow(2)
T.expect(entry.picked and entry:GetVisibility()==2 and fixture.previews.Alpha,"offscreen selection and explicit preview work without a row")
T.expect(not entry.row and fixture.scrolls==scrolls,"lookup and preview never scroll to acquire a frame")
options.GetDisplayEntry("Group"):Expand();fixture:flush()
T.expect(entry.row~=nil,"expansion materializes only visible rows")
local firstRow=entry.row
fixture.view:Render(20,8)
T.expect(not entry.row and entry.picked and entry:GetVisibility()==2,"releasing a row retains selection and preview state")
fixture.view:Render(1,8)
T.expect(entry.row and entry.row.frame.highlight and entry.row.view.visibility==2,"reacquired rows render retained state")
local count=fixture.acquired
for i=1,20 do fixture.view:Render(20,8);fixture.view:Render(1,8) end
T.expect(fixture.acquired==count,"repeated scrolling reuses AceGUI frames")
options.RefreshAuraList("ALPHA")
T.expect(model:Includes(entry) and model:Includes(model.byID.Group) and not model:Includes(model.byID.Beta),"case-insensitive filtering keeps ancestor paths")
options.RefreshAuraList("b")
T.expect(model:Includes(model.byID.Beta) and not model:Includes(entry),"one-character search filters the list")
options.RefreshAuraList("alpha or other")
T.expect(model:Includes(entry) and model:Includes(model.byID.Other),"existing OR search syntax is preserved")
M33kAurasSaved.displays.Alpha=nil;alpha.id="Renamed";M33kAurasSaved.displays.Renamed=alpha
M33kAurasSaved.displays.Group.controlledChildren[1]="Renamed"
options.RefreshAuraList("renamed")
T.expect(model.byID.Renamed==entry and model.byID.Alpha==nil and entry.picked and entry:GetVisibility()==2,"renaming preserves stable UID state and updates indexes and filtering")
fixture.private.loaded.Renamed=nil;fixture.private.loaded.Beta=nil
options.RefreshAuraList("renamed")
T.expect(model.byID.Group.section=="unloaded","load transitions update filtered projections too")
fixture:loadMain()
options.RefreshAuraList("")
M33kAuras.PickDisplay("Renamed")
T.expect(fixture.frame.pickedDisplay=="Renamed" and entry.picked,"real options selection selects a formerly offscreen aura")
options.PickDisplayMultiple("Beta")
T.expect(entry.picked and model.byID.Beta.picked and options.IsPickedMultiple(),"multiple selection is independent of rows")
options.ClearPicks()
T.expect(not entry.picked and not model.byID.Beta.picked,"clearing selection reaches offscreen entries")
entry:MoveChild(1);fixture:flush()
T.expect(M33kAurasSaved.displays.Group.controlledChildren[2]=="Renamed" and model.byID.Group.children[2]==entry,"reordering synchronizes data and tree children")
entry:Ungroup();fixture:flush()
T.expect(not entry.data.parent and not entry.parent,"ungrouping synchronizes the canonical tree")
options.RevealDisplay("Renamed")
Menu.ModifyMenu("M33KAURAS_DISPLAY_BUTTON_MENU",function(_,root,context)
  root:Insert(MenuUtil.CreateButton(context.auraId..":"..#context.selectedIds),#root)
end)
options.OpenDisplayButtonMenu(entry)
T.expect(fixture.menu[#fixture.menu-1].text=="Renamed:1" and fixture.menu[#fixture.menu].text=="Close","single context menus insert public extensions before Close")
options.PickDisplayMultiple("Other")
options.OpenDisplayButtonMenu(entry)
T.expect(fixture.menu[#fixture.menu-1].text=="Renamed:2","multiple-selection menus supply both selected identities")
-- Execute the real import/update phase-two methods with no row for the imported aura.
T.loadAddonFile("M33kAurasOptions/OptionsFrames/Update.lua","M33kAurasOptions",options)
local function upvalue(fn,wanted)
  for i=1,100 do local name,value=debug.getupvalue(fn,i);if not name then break end;if name==wanted then return value end end
  error("missing upvalue "..wanted)
end
local methods=upvalue(upvalue(options.UpdateFrame,"ConstructUpdateFrame"),"methods")
local imported=fixture:add("Imported")
M33kAuras.NewDisplayButton(imported,true)
local importer=setmetatable({IncProgress=function() end,IncProgress10=function() end},{__index=methods})
local map={GetPhase2Data=function() return imported end,GetParentIsDynamicGroup=function() return false end,GetGroupOrder=function() return nil,nil end}
local copies={}
fixture.private:Async({},function() importer:ImportPhase2(map,{imported.uid},copies) end)
fixture.private:Async({},function() importer:UpdatePhase2(map,function() return imported end,{imported.uid},copies) end)
T.expect(#copies==2 and model.byID.Imported.data==imported,"import and update phase two complete without forcing any row to exist")
fixture:flush()
T.section("Companion rows are pooled and retain complete linked-aura data")
local decoded=0
fixture.private.StringToTable=function(encoded)
  decoded=decoded+1
  return {d={id=encoded,uid="preview-"..encoded,regionType="icon",load={}}}
end
fixture.private.CompanionData.stash={stash={encoded="install",name="Install"}}
fixture.private.CompanionData.slugs={slug={encoded="update",name="Update",wagoVersion=2}}
M33kAurasSaved.displays.Group.url="https://wago.io/slug/1"
M33kAurasSaved.displays.Beta.url="https://wago.io/slug/1"
options.SortDisplayButtons("")
fixture.view:Render(1,8)
local updates, installs
for _,container in ipairs(fixture.view.containers) do
  if container.widget.type=="M33kAurasPendingUpdateButton" then updates=container.widget end
  if container.widget.type=="M33kAurasPendingInstallButton" then installs=container.widget end
end
T.expect(updates and installs,"pending install and update sections have visible pooled controls")
T.expect(updates.linkedAuras.Group and updates.linkedAuras.Beta and updates.linkedChildren.Beta,"updates preserve linked roots and descendants")
local parsed=decoded
for i=1,5 do fixture.view:Render(50,8);fixture.view:Render(1,8) end
T.expect(decoded==parsed,"scrolling never redecodes cached Companion imports")
fixture.private.CompanionData.stash={};fixture.private.CompanionData.slugs={}
options.SortDisplayButtons("")
T.section("Batch selection and operations span offscreen rows")
for i=1,40 do fixture:add(("Top %02d"):format(i)) end
options.SortDisplayButtons("")
M33kAuras.PickDisplay("Top 01")
options.PickDisplayMultipleShift("Top 40")
T.expect(#options.tempGroup.controlledChildren==40,"range selection includes rows outside the viewport")
options.GetDisplayEntry("Top 01"):PriorityShow(2)
options.ClearPicks()
T.expect(not options.GetDisplayEntry("Top 40").picked and options.GetDisplayEntry("Top 01"):GetVisibility()==2,"clearing offscreen selections retains explicitly enabled previews")
M33kAuras.PickDisplay("Top 01")
options.ClearPick("Top 01")
T.expect(fixture.frame.pickedDisplay==nil,"control-deselecting the single selection clears the options selection")
M33kAuras.PickDisplay("Top 01")
options.PickDisplayMultiple("Top 40")
local source=options.GetDisplayEntry("Top 01")
local destination=options.GetDisplayEntry("Group")
-- The drag ghost is a rendering detail; exercise the real data-only batch drop.
options.StartAuraDrag=function() end
options.StartDrag(source.data)
local moved={}
options.Drop(source.data,destination,function(item,target)
  item.data.parent=target.data.id
  table.insert(target.data.controlledChildren,item.data.id)
  moved[#moved+1]=item.data.id
end,"GROUP")
fixture:flush()
T.expect(#moved==2 and moved[1]=="Top 40" and moved[2]=="Top 01","batch drop executes in stable tree order without materializing selected rows")
T.expect(model.byID["Top 40"].parent==destination and not source.dragging,"batch drop refreshes parents and clears drag state")
T.section("Edits preserve model identity and existing option state")
local duplicate=options.DuplicateAura(model.byID.Beta.data)
fixture:flush()
T.expect(duplicate.uid~=model.byID.Beta.uid and model.byID[duplicate.id].parent==destination,"duplication gives the copy independent identity and preserves its parent")
local converted=options.GetDisplayEntry("Imported")
converted:PriorityShow(2)
fixture.private.Convert=function(data,kind) data.regionType=kind end
options.ConvertDisplay(converted.data,"text")
T.expect(converted.data.regionType=="text" and converted:GetVisibility()==2,"conversion works without a row and retains explicit preview priority")
options.SortDisplayButtons("NEW MATCH")
local added=fixture:add("New Match")
M33kAuras.NewDisplayButton(added)
fixture:flush()
T.expect(model:Includes(model.byID[added.id]) and model.filter=="new match","creating an aura updates the active filtered projection without clearing search")
local kept=options.GetDisplayEntry("Group"):GetExpanded()
options.SortDisplayButtons("")
T.expect(options.GetDisplayEntry("Group"):GetExpanded()==kept,"clearing search preserves group expansion state")
options.RevealDisplay("Imported")
local node=options.auraListNodes[converted.uid]
local container=CreateFrame("Frame")
local beforeRebind=fixture.acquired
options.BindAuraListRow(container,node)
options.BindAuraListRow(container,node)
options.ReleaseAuraListRow(container)
T.expect(not container.widget and fixture.acquired<=beforeRebind+1,"reinitializing a retained container releases its previous widget")
local importing=true
M33kAuras.IsImporting=function() return importing end
local provider=fixture.view.provider
M33kAuras.NewDisplayButton(fixture:add("Bulk Import"),true)
options.SortDisplayButtons()
T.expect(fixture.view.provider==provider,"bulk import defers rebuilding the visible provider")
importing=false
options.SortDisplayButtons()
T.expect(options.auraListNodes[model.byID["Bulk Import"].uid]~=nil,"the completed import publishes its nodes")
-- Exercise the actual event callbacks, including a collapsed/offscreen target.
local function upvalue(fn, key)
  for i=1,60 do
    local name,value=debug.getupvalue(fn,i)
    if not name then break end
    if name==key then return value end
  end
  error("missing upvalue: "..key)
end
local onRename=upvalue(M33kAuras.ToggleOptions,"OnRename")
local onDelete=upvalue(M33kAuras.ToggleOptions,"OnAboutToDelete")
local renamed=model.byID["Bulk Import"]
renamed:PriorityShow(2)
fixture.frame.OnRename=function(self,uid,oldid,newid)
  if self.pickedDisplay==oldid then self.pickedDisplay=newid end
end
options.SortDisplayButtons("bulk")
M33kAurasSaved.displays["Bulk Import"]=nil
renamed.data.id="Bulk Renamed"
M33kAuras.Add(renamed.data)
onRename("Rename",renamed.uid,"Bulk Import","Bulk Renamed")
T.expect(model.byID["Bulk Renamed"]==renamed and not model.byID["Bulk Import"] and renamed:GetVisibility()==2,
  "real rename callback preserves UID identity and preview state")
T.expect(model.filter=="bulk" and model:Includes(renamed),"real rename callback synchronizes the active search")
onDelete("AboutToDelete",renamed.uid,renamed.data.id)
M33kAurasSaved.displays[renamed.data.id]=nil
fixture:flush()
T.expect(not model.byUID[renamed.uid] and not model.byID[renamed.data.id] and not options.auraListNodes[renamed.uid],
  "real deletion callback removes a filtered aura from all indexes and the provider")
local parent=model.byID.Group
fixture.view:Render(1000)
parent:SetNormalTooltip()
T.expect(not parent.row,"post-deletion tooltip updates tolerate a parent with no row")
T.section("Thumbnail and warning lifetime")
local acquiredThumbnails,releasedThumbnails=0,0
fixture.private.regionOptions.icon={
  acquireThumbnail=function() acquiredThumbnails=acquiredThumbnails+1;return CreateFrame("Frame") end,
  modifyThumbnail=function() end,
  releaseThumbnail=function(thumbnail) releasedThumbnails=releasedThumbnails+1;thumbnail:Hide() end,
}
local warned=options.GetDisplayEntry("Top 04")
fixture.private.AuraWarnings.GetAllWarnings=function(uid)
  if uid==warned.uid then return {sound={prio=1,icon="test",title="Sound",message="test",auraId=warned.data.id}} end
end
options.RevealDisplay(warned.data.id)
local warnedRow=warned.row
local warningIcon
for _,icon in ipairs(warnedRow.statusIcons.buttons) do if icon.key=="sound" then warningIcon=icon end end
local removeSound
MenuUtil={CreateContextMenu=function(_,builder)
  builder(nil,{CreateButton=function(_,label,callback) if label==M33kAuras.L["Remove All Sounds"] then removeSound=callback end end})
end}
warningIcon:GetScript("OnClick")()
fixture.view:Render(1000)
T.expect(acquiredThumbnails>0 and acquiredThumbnails==releasedThumbnails,"every visible thumbnail is released when its row leaves the viewport")
T.expect(not warningIcon:GetScript("OnClick") and not warnedRow.view:GetScript("OnClick"),
  "released status icons and row controls retain no aura callbacks")
local clearedUID
fixture.private.ClearSounds=function(uid) clearedUID=uid end
fixture.view:Render(30)
removeSound()
T.expect(clearedUID==warned.uid,"an already-open warning action retains the correct UID after row reuse")
fixture.view:Render(1000)
T.section("Asynchronous preview scheduling")
local async=fixture.private.Async
local previewThread,cleanup
fixture.private.Async=function(_,_,fn)
  previewThread=coroutine.create(fn)
  return {Finally=function(_,fn) cleanup=fn end}
end
local layout=upvalue(M33kAuras.ShowOptions,"LayoutDisplayButtons")
layout()
assert(coroutine.resume(previewThread))
M33kAuras.NewDisplayButton(fixture:add("Created between preview slices"))
options.SortDisplayButtons()
local resumed=true
while coroutine.status(previewThread)~="dead" do
  local ok=coroutine.resume(previewThread)
  if not ok then resumed=false;break end
end
cleanup()
fixture.private.Async=async
fixture:flush()
T.expect(resumed,"preview scheduling tolerates rebuilding the UID/ID indexes between coroutine slices")
T.expect(#fixture.errors==0,"no hidden UI callback errors occurred")
T.finish()
