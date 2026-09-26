local testsDir=arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path=testsDir.."/?.lua;"..package.path
local T=require("helpers")
local f=require("aura_list_stubs").install(T)
local options,private=f.options,f.private
f:add("Root",nil,{"A","Nested","B"})
f:add("Nested","Root",{"C"})
for _,id in ipairs({"A","B"}) do f:add(id,"Root") end
f:add("C","Nested")
options.RefreshAuraList("");f:loadMain()
local root=options.GetDisplayEntry("Root")
local a=options.GetDisplayEntry("A")
local paused,resumed=0,0
local outstanding={}
private.PauseAllDynamicGroups=function() paused=paused+1;local token={};outstanding[token]=true;return token end
private.ResumeAllDynamicGroups=function(token) assert(outstanding[token]);outstanding[token]=nil;resumed=resumed+1 end
root.callbacks.OnViewClick()
T.expect(paused==1 and resumed==1 and a:GetVisibility()==2 and options.GetDisplayEntry("C"):GetVisibility()==2,
  "group preview activates every descendant and resumes dynamic groups")
T.expect(f.previews.A==true,"group preview displays the aura")
root.callbacks.OnViewClick()
T.expect(paused==2 and resumed==2 and a:GetVisibility()==0 and options.GetDisplayEntry("C"):GetVisibility()==0,
  "group preview toggles every descendant off and resumes dynamic groups")
T.expect(f.previews.A==false,"toggling group preview off hides the aura")
f:flush()
paused,resumed=0,0
root.callbacks.OnDuplicateClick()
f:flush()
local copy=M33kAuras.GetData("Root 2")
T.expect(copy and table.concat(copy.controlledChildren,",")=="A 2,Nested 2,B 2",
  "duplicating a mixed group preserves leaf and nested-group order")
T.expect(M33kAuras.GetData("C 2").parent=="Nested 2" and copy.uid~=root.uid and M33kAuras.GetData("C 2").uid~=M33kAuras.GetData("C").uid,
  "nested duplicates receive independent identities and parent links")
T.expect(paused>0 and paused==resumed,"successful group duplication resumes dynamic groups")

_G.IsShiftKeyDown=function() return true end
_G.GetCurrentRegion=function() return 1 end
_G.GetLocale=function() return "enUS" end
_G.UnitFullName=function() return "Player","Realm" end
_G.GetTime=function() return 123 end
local inserted
_G.GetCurrentKeyBoardFocus=function() return {Insert=function(_,text) inserted=text end} end
a.data.url="https://example.test/aura"
a.callbacks.OnClickNormal(nil,"LeftButton")
T.expect(inserted=="[M33kAuras: Player-Realm - A] https://example.test/aura" and private.linked.A==123,
  "shift-click builds the chat link and records the linked aura")
_G.GetCurrentRegion=function() return 5 end
a.callbacks.OnClickNormal(nil,"LeftButton")
T.expect(inserted=="[M33kAuras: Player-Realm - A]","restricted-region chat links omit the URL")
_G.IsShiftKeyDown=function() return false end
_G.IsControlKeyDown=function() return true end
f.frame:ClearPicks()
a.callbacks.OnClickNormal(nil,"LeftButton")
T.expect(options.IsDisplayPicked("A"),"control-click selects through the entry action")
a.callbacks.OnClickNormal(nil,"LeftButton")
T.expect(not options.IsDisplayPicked("A"),"control-click deselects through the entry action")
_G.IsControlKeyDown=function() return false end
local function menuItem(menu,text)
  for _,item in ipairs(menu) do if item.text==text then return item end end
  error("missing menu entry "..text)
end
options.RevealDisplay("A")
options.OpenDisplayButtonMenu(a)
a.data.triggers={marker={value=42}}
menuItem(menuItem(f.menu,"Copy settings...").menuList,"Trigger").func()
a.data.triggers.marker.value=99
options.RevealDisplay("Root")
options.OpenDisplayButtonMenu(root)
menuItem(f.menu,"Paste Trigger Settings").func()
T.expect(M33kAuras.GetData("B").triggers.marker.value==42 and M33kAuras.GetData("C").triggers.marker.value==42,
  "clipboard captures a snapshot and pastes triggers into nested leaf auras")
M33kAuras.GetData("B").triggers.marker.value=10
T.expect(M33kAuras.GetData("C").triggers.marker.value==42 and not root.data.triggers.marker,
  "pasted settings are independent per leaf and leave group triggers unchanged")

-- Install actual header handlers without constructing unrelated options panels.
local file=assert(io.open(T.repoRoot.."/M33kAurasOptions/OptionsFrames/OptionsFrame.lua"))
local source=file:read("*a");file:close()
for _,key in ipairs({"loadedButton","unloadedButton"}) do
  local first=assert(source:find("  "..key..":SetViewClick(function()",1,true))
  local last=assert(source:find("  "..key..":SetViewDescription",first,true))
  assert(loadstring("local OptionsPrivate,loadedButton,unloadedButton=...;"..source:sub(first,last-1)))(options,f.frame.loadedButton,f.frame.unloadedButton)
end
f:add("Loaded");private.loaded.Loaded=true
f:add("Unloaded")
options.SortDisplayButtons("")
f.view:Render(1000)
for _,case in ipairs({{"loadedButton","Loaded"},{"unloadedButton","Unloaded"}}) do
  local header,leaf=f.frame[case[1]],options.GetDisplayEntry(case[2])
  for _,child in ipairs(header.childButtons) do child.view.visibility=0 end
  header:RecheckVisibility()
  local beforePaused,beforeResumed=paused,resumed
  header.view:GetScript("OnClick")()
  f:flush()
  T.expect(leaf:GetVisibility()==2,case[1].." previews offscreen leaves through its real callback")
  header.view:GetScript("OnClick")()
  f:flush()
  T.expect(leaf:GetVisibility()==0,case[1].." hides explicit previews through its real callback")
  T.expect(paused-beforePaused==2 and resumed-beforeResumed==2,case[1].." resumes groups after each preview toggle")
end
T.expect(#f.errors==0,"action checks report no unexpected UI callback errors")
T.finish()
