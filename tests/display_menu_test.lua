local testsDir=arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path=testsDir.."/?.lua;"..package.path
local T=require("helpers")
local f=require("aura_list_stubs").install(T)
local options=f.options
f:add("A");f:add("B")
f:add("Group",nil,{"Child"});f:add("Child","Group")
f:add("Dynamic",nil,{"D1","D2"}).regionType="dynamicgroup";f:add("D1","Dynamic");f:add("D2","Dynamic")
options.RefreshAuraList("");f:loadMain()
local tag="M33KAURAS_DISPLAY_BUTTON_MENU"
local function item(root,text)
  for _,entry in root:EnumerateElementDescriptions() do if entry.text==text then return entry end end
end
local function tagged(root,wanted)
  for i,entry in root:EnumerateElementDescriptions() do if entry:GetTag()==wanted then return entry,i end end
end
local function open(id)
  options.RevealDisplay(id)
  options.OpenDisplayButtonMenu(options.GetDisplayEntry(id))
  return f.menu
end
local function build(ids)
  local uids={}
  for _,id in ipairs(ids) do uids[#uids+1]=M33kAuras.GetData(id).uid end
  local root=f.menuDescription()
  options.BuildDisplayButtonMenu(root,{auraId=ids[1],auraUID=uids[1],selectedIds=ids,selectedUIDs=uids})
  return root
end
local seen
local hook=Menu.ModifyMenu(tag,function(owner,root,context)
  seen=context
  local _,index=tagged(root,"M33KAURAS_DISPLAY_BUTTON_DELETE_SECTION")
  root:Insert(MenuUtil.CreateButton("WASync Send"),index)
  root:Insert(MenuUtil.CreateButton("WASync Version"),index+1)
end)
local root=open("A")
T.expect(root:GetTag()==tag and f.menuOwner==options.ScrollBox and f.menuOwner~=options.GetDisplayEntry("A").row.frame,
  "native display button menu exposes a stable owner and tagged context")
T.expect(seen.auraId=="A" and seen.auraUID=="uid-A" and seen.selectedIds[1]=="A" and seen.selectedUIDs[1]=="uid-A",
  "single display button context contains matching ID/UID snapshots")
local _,index=tagged(root,"M33KAURAS_DISPLAY_BUTTON_DELETE_SECTION")
T.expect(root[index-2].text=="WASync Send" and root[index-1].text=="WASync Version" and root[index].divider,
  "extensions insert an ordered block before the deletion divider")
T.expect(tagged(root,"M33KAURAS_DISPLAY_BUTTON_DELETE").text=="Delete"
  and root[#root]:GetTag()=="M33KAURAS_DISPLAY_BUTTON_CLOSE","destructive and close tags are stable")
T.expect(not M33kAuras.RegisterDisplayButtonMenuHook and not M33kAuras.UnregisterDisplayButtonMenuHook,
  "the obsolete custom registration API is absent")
hook:Unregister()
root=open("A")
T.expect(not item(root,"WASync Send"),"native registration handles remove extensions from future menus")
local lateCalls=0
local late=Menu.ModifyMenu(tag,function() lateCalls=lateCalls+1 end)
T.expect(lateCalls==1,"late registration immediately receives the last generated description")
late:Unregister()
local lateOK=pcall(Menu.ModifyMenu,tag,function() error("late registration failure") end)
root=open("A")
T.expect(not lateOK and lateCalls==1 and #f.errors==0,
  "late registration errors propagate without registering a broken callback")
local row=options.GetDisplayEntry("A").row
local refreshRow=row.RefreshEntry
row.RefreshEntry=function() error("menu opening refreshed a display button") end
local ok=pcall(options.OpenDisplayButtonMenu,options.GetDisplayEntry("A"))
row.RefreshEntry=refreshRow
T.expect(ok,"opening an already-selected display button menu does not refresh its thumbnail")

local exported
options.ExportToString=function(id) exported=id end
root=open("A")
local export=item(root,"Export...")
f.view:Render(1000)
export:Pick()
T.expect(exported=="A","an action still targets the original aura after its display button is recycled")
root=open("A");export=item(root,"Export...")
local data=M33kAuras.GetData("A")
M33kAurasSaved.displays.A=nil;data.id="Renamed A";M33kAurasSaved.displays[data.id]=data
export:Pick()
T.expect(exported=="Renamed A","actions resolve renamed auras by UID")
root=open("B");export=item(root,"Export...")
M33kAurasSaved.displays.B=nil
exported=nil;export:Pick()
T.expect(exported==nil,"a stale action cannot target a deleted aura or its replacement")
f:add("B")

local regionOptions=options.Private.regionOptions
options.Private.regionOptions={icon={displayName="Icon"},text={displayName="Text"},
  texture={displayName="Texture"},group={displayName="Group"},dynamicgroup={displayName="Dynamic Group"}}
local convertDisplay=options.ConvertDisplay
local converted={}
options.ConvertDisplay=function(current,kind) converted[#converted+1]={current.id,kind} end
root=open("B")
local convert=item(root,"Convert to...")
item(convert,"Text"):Pick();item(convert,"Texture"):Pick()
T.expect(#convert==2 and converted[1][1]=="B" and converted[1][2]=="text" and converted[2][2]=="texture",
  "conversion choices exclude the current type and groups and retain distinct target types")
options.Private.regionOptions=regionOptions;options.ConvertDisplay=convertDisplay

root=build({"Group","B"})
T.expect(item(root,"Add to new Group"):IsEnabled() and not item(root,"Add to new Dynamic Group"):IsEnabled(),
  "multi-selection containing a group disables dynamic grouping")
root=build({"D1","D2"})
T.expect(not item(root,"Add to new Group"):IsEnabled() and not item(root,"Add to new Dynamic Group"):IsEnabled(),
  "siblings inside a dynamic group cannot be wrapped in another group")
root=build({"Renamed A","B"})
local targets
options.DuplicateDisplayButtonSelection=function(ids) targets=ids end
-- Rebuild after replacing the action function, then change live selection.
root=build({"Renamed A","B"})
options.tempGroup.controlledChildren={"Child"}
item(root,"Duplicate All"):Pick()
T.expect(table.concat(targets,",")=="Renamed A,B","batch actions use the menu-open selection rather than live selection")
root=build({"Renamed A","B"})
targets=nil
local originalB=M33kAurasSaved.displays.B
M33kAurasSaved.displays.B={id="B",uid="replacement-B",regionType="icon"}
item(root,"Duplicate All"):Pick()
T.expect(targets==nil,"batch actions abort if a selected UID was deleted, even when its name is reused")
M33kAurasSaved.displays.B=originalB

options.ClearPicks()
root=open("Group")
T.expect(item(root,"Delete children and group") and not item(root,"Convert to...")
  and #item(root,"Copy settings...")==1,"group display button menus preserve their action restrictions")
item(item(root,"Copy settings..."),"Group"):Pick()
root=open("B")
T.expect(not item(root,"Paste Group Settings"),"group settings cannot be pasted into a nongroup aura")
root=open("Dynamic")
T.expect(item(root,"Paste Group Settings")~=nil,"normal/dynamic group settings paste remains available")

root=open("B");local menu=f.nativeMenu
options.SortDisplayButtons()
T.expect(not menu.closed,"rebuilding the provider keeps the display button menu open")
f.private.loaded.B=true
options.RequestAuraListRefresh();f:flush()
T.expect(not menu.closed,"load-condition refresh keeps the menu open when an aura changes sections")
exported=nil
item(root,"Export..."):Pick()
T.expect(exported=="B" and menu.closed,"menu actions retain their target after load-condition refresh")
root=open("B");menu=f.nativeMenu
options.ScrollBox:GetScript("OnHide")(options.ScrollBox)
T.expect(menu.closed,"hiding the list closes its display button menu")
root=open("B");menu=f.nativeMenu
Menu.GetManager():CloseMenus()
local unrelated=MenuUtil.CreateContextMenu(UIParent,function(_,description) description:CreateButton("Unrelated") end)
options.CloseDisplayButtonMenu()
T.expect(menu.closed and not unrelated.closed,"native dismissal clears ownership without closing a later unrelated menu")
root=open("B");menu=f.nativeMenu
options.StartAuraDrag(options.GetDisplayEntry("B"))
T.expect(menu.closed,"starting a drag closes the display button menu")
options.EndAuraDrag()
local contextHook=Menu.ModifyMenu(tag,function(_,_,context)
  context.auraUID="uid-Child";context.selectedUIDs[1]="uid-Child"
end)
root=open("B");item(root,"Export..."):Pick()
T.expect(exported=="B","extension edits to context do not redirect built-in actions")
contextHook:Unregister()

-- Exercise WASync menu integration with spies for its external actions.
local requests={}
local sent,checked,filter,quickCopy
_G.AddonDB={WeakAuras=M33kAuras,RGAPI={IsCustomSender=function() return true end,
  ClassColorName=function(_,unit) return unit end},GetFullName=function(_,unit) return unit.."-Realm" end,
  IterateGroupMembers=function() local i=0;return function() i=i+1;return ({"Player1","Player2"})[i] end end}
_G.MRT={Options={Open=function() end,OpenByModuleName=function() end}}
_G.module={options={filterEdit={SetText=function(_,text) filter=text end}},
  GetWAVer=function(_,id) checked=id end,ExternalExportWA=function(_,id) sent=id end,
  DisplayToString=function(data,forImport) assert(forImport);return "encoded:"..data.id end}
AddonDB.Async=function(_,fn) return fn() end
AddonDB.QuickCopy=function(_,text) quickCopy=text end
for _,name in ipairs({"RequestWA","SendSetLoadNever","SendDeleteWA","RequestDisplayTable","RequestDebugLog"}) do
  module[name]=function(_,id,target,value) requests[#requests+1]={name,id,target,value} end
end
T.loadAddonFile("tests/fixtures/wasync-display-button-menu.lua","WASync",{})
root=open("B")
local custom=item(root,"|cFF8855FFWASync|r Custom options...")
item(root,"|cFF8855FFWASync|r Send..."):Pick()
item(root,"|cFF8855FFWASync|r Check Version"):Pick()
item(root,"|cFF8855FFWASync|r Get AutoImport String"):Pick()
T.expect(sent=="B" and checked=="B" and filter=="B","WASync Send and Check Version use the clicked aura")
T.expect(quickCopy=='id = "B",\n\t\t\texrtLastSync = 0,\n\t\t\tdataStr = [[encoded:B]]',
  "WASync AutoImport preserves the payload format and default sync value")
item(custom[1],"Request WA"):Pick()
item(custom[2],"Set Load Never (|cffff0000true|r)"):Pick()
T.expect(requests[1][2]=="B" and requests[1][3]=="Player1-Realm"
  and requests[2][3]=="Player2-Realm" and requests[2][4]==true,
  "WASync native player submenus retain distinct recipients and the clicked aura")
item(custom[2],"Set Load Never (|cff00ff00false|r)"):Pick()
item(custom[1],"Archive and Delete"):Pick()
item(custom[2],"Edit"):Pick()
item(custom[1],"Get Debug Log"):Pick()
T.expect(requests[3][1]=="SendSetLoadNever" and requests[3][4]==false
  and requests[4][1]=="SendDeleteWA" and requests[4][3]=="Player1-Realm"
  and requests[5][1]=="RequestDisplayTable" and requests[5][3]=="Player2-Realm"
  and requests[6][1]=="RequestDebugLog" and requests[6][3]=="Player1-Realm",
  "all WASync player actions dispatch the correct method, recipient and load flag")
local _,deleteIndex=tagged(root,"M33KAURAS_DISPLAY_BUTTON_DELETE_SECTION")
T.expect(root[deleteIndex-1]==custom and #custom[1]==6 and #custom[2]==6,
  "the complete WASync block precedes Delete with all six per-player actions")
local sendIndex
for i,entry in ipairs(root) do if entry.text=="|cFF8855FFWASync|r Send..." then sendIndex=i end end
T.expect(root[sendIndex-1].divider,"WASync retains the separator above its action block")
AddonDB.RGAPI.IsCustomSender=function() return false end
root=open("B")
T.expect(item(root,"|cFF8855FFWASync|r Send...") and item(root,"|cFF8855FFWASync|r Check Version")
  and not item(root,"|cFF8855FFWASync|r Custom options...")
  and not item(root,"|cFF8855FFWASync|r Get AutoImport String"),
  "WASync restricts custom sender actions while keeping Send and Check Version")
T.expect(#f.errors==0,"display button menu actions complete without callback errors")
T.finish()
