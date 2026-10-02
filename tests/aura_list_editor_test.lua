local testsDir=arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path=testsDir.."/?.lua;"..package.path
local T=require("helpers")
local f=require("aura_list_stubs").install(T)
local options=f.options
f:add("A");f:add("B")
options.RefreshAuraList("");f:loadMain()
local entry=options.GetDisplayEntry("A")
entry:BeginRename()
local input=entry.renameInput
T.expect(input.highlightStart==0 and input.highlightEnd==#entry.data.id,
  "starting a rename selects the whole name")
input:SetText("Draft name")
input:SetCursorPosition(5)
input:HighlightText(2,5)
entry:Refresh()
T.expect(input.highlightStart==2 and input.highlightEnd==5 and input:GetCursorPosition()==5,
  "refreshing a retained display button preserves selection and cursor position")
local released=f.released
f.private.loaded.A=true
options.SortDisplayButtons()
T.expect(entry:IsLoaded() and f.released>released and entry.renameInput==input and input:HasFocus()
    and input:GetText()=="Draft name",
  "moving an aura to the loaded section recycles display buttons while retaining its active editor")
T.expect(input.highlightStart==2 and input.highlightEnd==5 and input:GetCursorPosition()==5,
  "reevaluating load conditions preserves the exact selection and cursor position")
input:SetText("B")
input:GetScript("OnEnterPressed")(input)
T.expect(entry.renaming and input:IsShown() and entry.renameText=="A",
  "a duplicate name is rejected while the editor stays active")
input:SetText("Offscreen draft")
input:SetCursorPosition(8)
input:HighlightText(2,8)
f.view:Render(1000)
T.expect(not entry.row and entry.renameInput==input and input:HasFocus() and input:GetAlpha()==0
    and not input.mouseEnabled and entry.renameText=="Offscreen draft",
  "scrolling away parks the focused editor without retaining its display button")
T.expect(input.highlightStart==2 and input.highlightEnd==8 and input:GetCursorPosition()==8,
  "parking a rename preserves selection and cursor position")
options.RevealDisplay("A")
T.expect(entry.row and entry.renameInput==input and input:GetText()=="Offscreen draft" and input:HasFocus()
    and input:GetAlpha()==1 and input.mouseEnabled,
  "revealing the edited aura restores the same editor to its display button")
T.expect(input.highlightStart==2 and input.highlightEnd==8 and input:GetCursorPosition()==8,
  "returning from offscreen preserves the exact selection and cursor position")
input:ClearFocus()
input:SetFocus()
T.expect(input.highlightStart==input.highlightEnd,
  "refocusing an active rename does not select its text")
input:GetScript("OnEscapePressed")(input)
options.SortDisplayButtons()
T.expect(not entry.renaming and not entry.renameInput and not input:IsShown() and entry.row.title:IsShown(),
  "Escape releases the editor and restores the title across later rebuilds")
entry:BeginRename()
T.expect(entry.renameInput==input and input.highlightStart==0 and input.highlightEnd==#entry.data.id,
  "starting a new rename reuses its released editor and selects the whole name")
input:GetScript("OnEscapePressed")(input)

local other=options.GetDisplayEntry("B")
entry:BeginRename()
entry.renameInput:SetText("First draft")
other:BeginRename()
local otherInput=other.renameInput
otherInput:SetText("Second draft")
otherInput:SetCursorPosition(6)
otherInput:HighlightText(1,6)
options.SortDisplayButtons()
T.expect(entry.renameInput~=otherInput and entry.renameInput:GetText()=="First draft"
    and other.renameInput==otherInput and otherInput:GetText()=="Second draft",
  "simultaneous renames retain independent drafts across list rebuilds")
T.expect(otherInput:HasFocus() and not entry.renameInput:HasFocus()
    and otherInput.highlightStart==1 and otherInput.highlightEnd==6 and otherInput:GetCursorPosition()==6,
  "a rebuild preserves the focused draft without taking focus for another rename")
entry:CancelRename()
T.expect(otherInput:HasFocus() and other.renaming and otherInput:GetText()=="Second draft",
  "cancelling one draft leaves another active rename untouched")
other:CancelRename()

f:add("Deleted")
options.SortDisplayButtons()
local deleted=options.GetDisplayEntry("Deleted")
deleted:BeginRename()
local deletedInput=deleted.renameInput
M33kAurasSaved.displays.Deleted=nil
options.SortDisplayButtons()
T.expect(not deleted.renameInput and not deletedInput:IsShown() and not deletedInput:HasFocus(),
  "removing an aura releases its active rename editor")

entry:BeginRename()
f.view:Render(1000) -- Ensure the callback reuses this row, not another visible B row.
local container=CreateFrame("Frame")
options.BindAuraListRow(container,options.auraListNodes[entry.uid])
local row=container.widget
input=entry.renameInput
input:SetText("Committed name")
local renamed
M33kAuras.Rename=function(data,newid)
  renamed=newid
  -- A real rename callback can release and reuse the row synchronously.
  options.ReleaseAuraListRow(container)
  options.BindAuraListRow(container,options.auraListNodes[options.GetDisplayEntry("B").uid])
end
input:GetScript("OnEnterPressed")(input)
T.expect(renamed=="Committed name","the rename callback receives the draft captured before row recycling")
T.expect(container.widget==row and row.title:GetText()=="B","rename completion never overwrites the title of a newly rebound aura")
options.ReleaseAuraListRow(container)

local parses=0
f.private.StringToTable=function() parses=parses+1;return "invalid payload" end
local companion={encoded="broken"}
options.GetCompanionPreview(companion);options.GetCompanionPreview(companion)
T.expect(parses==1,"invalid Companion payloads are decoded only once per payload")
companion.encoded="changed"
options.GetCompanionPreview(companion)
T.expect(parses==2,"a changed Companion payload invalidates a cached decode failure")

f.private.StringToTable=function() return {d={id="preview",uid="preview",regionType="icon",load={}}} end
local previewNode={GetData=function() return {kind="M33kAurasPendingUpdateButton",id="slug",companion={encoded="valid",name="Preview"}} end}
options.BindAuraListRow(container,previewNode)
local update=container.widget
options.ReleaseAuraListRow(container)
T.expect(not update.frame:GetScript("OnEnter") and not update.frame:GetScript("OnLeave"),
  "releasing a Companion update removes its data-dependent tooltip callbacks")
T.expect(#f.errors==0,"editor and Companion lifecycle checks have no callback errors")
T.finish()
