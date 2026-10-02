local testsDir=arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path=testsDir.."/?.lua;"..package.path
local T=require("helpers")
local f=require("aura_list_stubs").install(T)
local options=f.options
for i=1,40 do f:add(("Aura %02d"):format(i)) end
-- Simulate the native rect invalidation: only a nonzero point adjustment
-- restores the viewport extent. FullUpdate alone cannot repair it.
local adjust=f.box.AdjustPointsOffset
f.box.AdjustPointsOffset=function(self,x,y)
  assert(x~=0 or y~=0)
  adjust(self,x,y)
  f.view.count=8
end
f.box.rectValid=false
-- A hidden pane can populate before its viewport has a usable extent.
f.view.count=0
options.RefreshAuraList("")
T.expect(#f.view.containers==0,"initial hidden layout has no visible rows")
f.box:GetScript("OnShow")(f.box)

T.expect(#f.view.containers==8 and not f.box:GetScript("OnUpdate"),
  "show validates the rect before immediate layout without a timer")
T.expect(f.box.pointOffsetX==0.0001 and #f.timers==0,"invalid rect receives one minimal point adjustment")
f.box:GetScript("OnShow")(f.box)
T.expect(f.box.pointOffsetX==0.0001,"valid rect is not adjusted on subsequent shows")
f.box.rectValid=false;f.view.count=0
f.box:GetScript("OnShow")(f.box)
T.expect(f.box.pointOffsetX==0 and f.box.pointOffsetY==0 and #f.view.containers==8,
  "the next invalid rect reverses the offset instead of accumulating drift")
-- A parent resize can leave the still-visible box without a valid rect.
local resize=f.frame:GetScript("OnSizeChanged")
local currentProvider=f.view:GetDataProvider()
local released=f.released
local pointOffset=f.box.pointOffsetX
for i=1,50 do resize(f.frame,400+i,400+i) end
f:flush()
T.expect(f.released==released and f.box.pointOffsetX==pointOffset,
  "valid resize geometry does not reinitialize rows or adjust anchors")
f.box.rectValid=false;f.view:Render(1,0)
resize(f.frame,500,500)
local superseded=f.lastTimer
resize(f.frame,501,501)
T.expect(superseded.cancelled and f.lastTimer.delay==0.05 and not f.box:IsRectValid(),
  "resize debounce cancels the prior timer and waits 50ms after the last event")
f:flush()
T.expect(f.box:IsRectValid() and #f.view.containers==8 and f.view:GetDataProvider()==currentProvider,
  "parent resize repairs an invalid visible viewport without replacing the provider")
f.box.rectValid=false;f.view:Render(1,0)
resize(f.frame,510,510)
f:flush()
T.expect(f.box.pointOffsetX==pointOffset and f.box.pointOffsetY==pointOffset,
  "repeated resize repairs reverse the point adjustment without drift")
f.box:Hide();f.box.rectValid=false
resize(f.frame,520,520)
f:flush()
T.expect(not f.box:IsRectValid(),"hidden viewport waits for the existing show-time repair")
f.box:Show();f.box:GetScript("OnShow")(f.box)
f:loadMain()
-- Execute the real search handler with the repeated notifications observed
-- during native resize, including when a nonempty search is active.
local refresh=options.RefreshAuraList
local refreshCount=0
options.RefreshAuraList=function(...)
  refreshCount=refreshCount+1
  return refresh(...)
end
local providerBefore=f.view:GetDataProvider()
local releasesBefore=f.released
for i=1,222 do f.frame.filterInput:GetScript("OnTextChanged")(f.frame.filterInput,false) end
T.expect(refreshCount==0 and f.view:GetDataProvider()==providerBefore and f.released==releasesBefore,
  "resize text notifications do not rebuild the provider or recycle thumbnails")
f.frame.filterInput:SetText("aUrA 01")
T.expect(refreshCount==1 and options.auraListModel.filter=="aura 01",
  "changed search text still refreshes case-insensitive results")
providerBefore=f.view:GetDataProvider();releasesBefore=f.released
for i=1,222 do f.frame.filterInput:GetScript("OnTextChanged")(f.frame.filterInput,false) end
T.expect(refreshCount==1 and f.view:GetDataProvider()==providerBefore and f.released==releasesBefore,
  "resizing with an active search also retains the provider and rows")
options.SortDisplayButtons()
T.expect(refreshCount==2 and f.view:GetDataProvider()~=providerBefore,
  "data-driven refreshes still rebuild with unchanged search text")
f.frame.filterInput:SetText("")
T.expect(refreshCount==3 and options.auraListModel.filter=="",
  "clearing search restores the full list")
options.RefreshAuraList=refresh
local entry=options.GetDisplayEntry("Aura 02")
local before=f.scrolls
M33kAuras.PickDisplay(entry.data.id)
T.expect(f.scrolls==before,"clicking a fully visible aura does not scroll the list")
f.view:Render(12)
local offset=f.box:GetDerivedScrollOffset()
f.scrollCancelled=false
options.SortDisplayButtons()
T.expect(f.scrollCancelled,"provider rebuild cancels navigation aimed at the previous list")
T.expect(f.box:GetDerivedScrollOffset()==offset,"provider rebuild retains the pixel scroll offset")
options.SortDisplayButtons("Aura 01")
T.expect(#f.view.containers>0 and f.box:GetDerivedScrollOffset()==0,"shorter search results clamp the old scroll offset instead of leaving an empty list")
local created=f:add("New unrelated aura")
M33kAuras.NewDisplayButton(created);f:flush()
options.PickAndEditDisplay(created.id)
T.expect(f.frame.filterInput:GetText()=="Aura 01" and options.auraListModel.filter=="aura 01",
  "creating and selecting a nonmatching aura preserves search text and results")
T.expect(f.frame.pickedDisplay==created.id and #f.view.containers>0,"the created aura is selected without emptying the filtered list")
options.SortDisplayButtons("")
options.RevealDisplay(entry.data.id)
entry:BeginRename()
local input=entry.renameInput
input:SetText("Offscreen committed")
f.view:Render(1000)
T.expect(entry.renameInput==input and input:HasFocus() and input:GetText()=="Offscreen committed",
  "rename input stays focused when its display button is released")
local renamed
M33kAuras.Rename=function(_,text) renamed=text end
input:GetScript("OnEnterPressed")(input)
T.expect(renamed=="Offscreen committed" and not entry.renaming and not input:HasFocus(),"Enter confirms an offscreen rename and releases its focus")
options.RevealDisplay(entry.data.id)
entry:BeginRename()
input=entry.renameInput
input:SetText("Cancelled draft")
f.view:Render(1000)
input:GetScript("OnEscapePressed")(input)
T.expect(not entry.renaming and not input:HasFocus(),"Escape cancels an offscreen rename")

-- Import replaces the provider while the list pane is hidden.
f.view:Render(1,0)
f.box.rectValid=false
f:add("Imported aura")
options.RefreshAuraList("")
T.expect(#f.view.containers==0,"import can finish while the viewport is hidden")
local provider=f.view:GetDataProvider()
local scrolls=f.scrolls
f.box:GetScript("OnShow")(f.box)
-- Selecting the imported aura can expand ancestors and replace the provider
-- after showing the pane; the rect must already be valid.
options.RefreshAuraList("")
provider=f.view:GetDataProvider()

T.expect(#f.view.containers==8 and f.view:GetDataProvider()==provider and f.scrolls==scrolls,
  "import selection retains the validated viewport")
for i=1,4 do
  f.view:Render(1,0)
  f.box.rectValid=false
  f:add("Repeated import "..i)
  options.RefreshAuraList("")
  f.box:GetScript("OnShow")(f.box)
  if i%2==0 then options.RefreshAuraList("") end
  local currentProvider=f.view:GetDataProvider()

  T.expect(#f.view.containers==8 and f.view:GetDataProvider()==currentProvider and f.scrolls==scrolls,
    "repeated import "..i.." renders without scrolling regardless of a same-frame refresh")
end

-- A ScrollBox reset hides its old rows during both scrolling and load changes.
options.RevealDisplay(entry.data.id)
local row=entry.row
local held,rightHeld=true,false
_G.IsMouseButtonDown=function(button)
  if button=="RightButton" then return rightHeld end
  return held
end
_G.GetCursorPosition=function() return 100,100 end
local drops=0
local stop=entry.callbacks.OnDragStop
entry.callbacks.OnDragStop=function() drops=drops+1;options.EndAuraDrag() end
options.StartAuraDrag(entry)
local ghost=f.frames[#f.frames]
ghost.SetPropagateKeyboardInput=function(self,value) self.propagates=value end
local nativeStop=row.frame:GetScript("OnDragStop")
f.view:Render(1000)
if nativeStop then nativeStop() end
ghost:GetScript("OnUpdate")(ghost,0.016)
T.expect(drops==0 and ghost:IsShown(),"recycling the drag source cannot drop while the mouse is held")
options.SortDisplayButtons()
ghost:GetScript("OnUpdate")(ghost,0.016)
T.expect(drops==0 and ghost:IsShown(),"a load-style provider rebuild does not terminate the drag")
ghost:GetScript("OnKeyDown")(ghost,"W")
T.expect(ghost.propagates==true,"ordinary keyboard input propagates during dragging")
held=false;ghost:GetScript("OnUpdate")(ghost,0.016)
T.expect(drops==1 and not ghost:IsShown(),"the physical mouse release commits exactly one drop")
held=true;options.StartAuraDrag(entry)
ghost:GetScript("OnKeyDown")(ghost,"ESCAPE")
T.expect(drops==1 and not ghost:IsShown(),"Escape cancels dragging without dropping")
options.StartAuraDrag(entry)
rightHeld=true;ghost:GetScript("OnUpdate")(ghost,0.016)
T.expect(drops==1 and not ghost:IsShown(),"right-click cancels dragging without dropping")
rightHeld=false;held=false;ghost:GetScript("OnUpdate")(ghost,0.016)
T.expect(drops==1,"left release after right-click cancellation cannot commit a drop")
held=true;options.StartAuraDrag(entry)
held=false;rightHeld=true;ghost:GetScript("OnUpdate")(ghost,0.016)
T.expect(drops==1 and not ghost:IsShown(),"right-click cancellation wins over a simultaneous left release")
rightHeld=false
options.StartAuraDrag(entry);options.DragReset()
held=false;ghost:GetScript("OnUpdate")(ghost,0.016)
T.expect(drops==1,"closing/resetting drag never places an aura in the hovered group")
entry.callbacks.OnDragStop=stop

-- Reproduce the reported queued-preview/deletion sequence with strict warnings.
local parent=f:add("Deleting group",nil,{"Deleting child"})
local child=f:add("Deleting child",parent.id)
options.SortDisplayButtons("");options.RevealDisplay(child.id)
f.private.AuraWarnings.GetAllWarnings=function(uid)
 assert(f.private.GetDataByUID(uid),"warnings requested for deleted aura")
end
options.GetDisplayEntry(child.id):RecheckParentVisibility()
options.massDelete=true
M33kAurasSaved.displays[child.id]=nil
f:flush()
T.expect(#f.errors==0,"queued preview refresh does not read deleted auras during a mutation")
options.auraListModel:Remove(child.uid)
options.massDelete=nil
options.RefreshAuraPreviews()
T.expect(#f.errors==0,"preview traversal skips removed entries still present in an old child list")
T.finish()
