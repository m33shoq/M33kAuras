local testsDir=arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path=testsDir.."/?.lua;"..package.path
local T=require("helpers")
local f=require("aura_list_stubs").install(T)
local options=f.options
f:add("A")
options.RefreshAuraList("")
f.view:Render(1000)
local entry=options.GetDisplayEntry("A")
f.private.StringToTable=function() return {d={id="Preview",uid="preview",regionType="icon",load={}}} end
for _,kind in ipairs({"M33kAurasDisplayButton","M33kAurasPendingInstallButton","M33kAurasPendingUpdateButton"}) do
  local container=CreateFrame("Frame")
  local thumbnail,releases,failRelease=nil,0,false
  f.private.regionOptions.icon={
    acquireThumbnail=function()
      thumbnail=CreateFrame("Frame")
      thumbnail.icon={SetDesaturated=function(_,value) thumbnail.desaturated=value end}
      return thumbnail
    end,
    releaseThumbnail=function(frame)
      releases=releases+1
      if failRelease then error("injected thumbnail release failure") end
      frame:Hide()
    end,
  }
  local node={GetData=function()
    if kind=="M33kAurasDisplayButton" then return {entry=entry} end
    return {kind=kind,id="preview",companion={encoded="valid",name="Preview"}}
  end}
  options.BindAuraListRow(container,node)
  local row=container.widget
  T.expect(row.thumbnail==thumbnail and (kind=="M33kAurasDisplayButton" or thumbnail.desaturated),kind.." acquires its own thumbnail")
  local errors=#f.errors
  failRelease=true
  local releaseStack
  local getHandler=geterrorhandler
  _G.geterrorhandler=function()
    local report=getHandler()
    return function(err) releaseStack=debugstack(2);report(err) end
  end
  local released=pcall(options.ReleaseAuraListRow,container)
  _G.geterrorhandler=getHandler
  T.expect(released and #f.errors==errors+1,kind.." reports a release failure without aborting row cleanup")
  T.expect(releaseStack and releaseStack:find("in function 'error'",1,true),
    kind.." reports release errors before their original stack unwinds")
  T.expect(not row.data and not row.thumbnail and not row.callbacks and not row.frame:GetScript("OnEnter"),kind.." clears old aura references after failed thumbnail release")
  T.expect(not container.widget and not row.frame:IsShown() and not thumbnail:IsShown(),kind.." hides and detaches the failed binding")
  failRelease=false
  options.BindAuraListRow(container,node)
  T.expect(container.widget==row and row.thumbnail~=nil,kind.." can reuse the row after a release error")
  options.ReleaseAuraListRow(container)
  T.expect(kind=="M33kAurasDisplayButton" or thumbnail.desaturated==false,kind.." restores Companion desaturation on successful release")
  local original=f.private.regionOptions.icon
  options.BindAuraListRow(container,node)
  local countBefore=releases
  f.private.regionOptions.icon={releaseThumbnail=function() error("wrong thumbnail owner") end}
  options.ReleaseAuraListRow(container)
  T.expect(releases==countBefore+1 and #f.errors==errors+1,kind.." returns the resource to the owner that acquired it")
  f.private.regionOptions.icon={acquireThumbnail=function() error("injected acquire failure") end}
  local acquireErrors=#f.errors
  local acquired,message=pcall(options.BindAuraListRow,container,node)
  T.expect(acquired and message==nil and #f.errors==acquireErrors+1 and tostring(f.errors[acquireErrors+1]):find("injected acquire failure",1,true) and not container.widget,
    kind.." failed acquisition clears its binding and preserves the error")
  f.private.regionOptions.icon=original
  options.BindAuraListRow(container,node)
  row=container.widget
  T.expect(row.thumbnail and row.data,kind.." recovers on the next acquisition")
  local otherReleased=0
  f.private.regionOptions.other={acquireThumbnail=function() return CreateFrame("Frame") end,
    releaseThumbnail=function(frame) otherReleased=otherReleased+1;frame:Hide() end}
  countBefore=releases
  row.data.regionType="other"
  row:UpdateThumbnail()
  T.expect(releases==countBefore+1 and row.thumbnailType=="other",kind.." replaces the thumbnail when the aura type changes")
  options.ReleaseAuraListRow(container)
  T.expect(otherReleased==1,kind.." releases the replacement thumbnail exactly once")
  entry.data.regionType="icon"
  local count=releases
  options.ReleaseAuraListRow(container)
  T.expect(releases==count,kind.." repeated release never returns a thumbnail twice")
end
-- Exercise the real registration wrapper: it owns resources until acquisition
-- returns them to a row, including errors inside modifyThumbnail.
local file=assert(io.open(T.repoRoot.."/M33kAuras/M33kAuras.lua"))
local source=file:read("*a");file:close()
local first=assert(source:find("function Private.RegisterRegionOptions(",1,true))
local last=assert(source:find("\n---@private",first,true))
local active,created=0,0
_G.CreateObjectPool=function(create)
  local free={}
  return {Acquire=function() active=active+1;return table.remove(free) or create() end,
    Release=function(_,frame) active=active-1;free[#free+1]=frame end}
end
assert(loadstring("local Private,regionOptions=...;"..source:sub(first,last-1)))(f.private,f.private.regionOptions)
local fail=true
local resource
f.private.RegisterRegionOptions("registered",function() end,"icon","Registered",
  function() created=created+1;resource=CreateFrame("Frame");return resource end,
  function() if fail then error("injected registered modify failure") end end)
local registered=f.private.regionOptions.registered
local modifyErrors=#f.errors
local ok,message=pcall(registered.acquireThumbnail,UIParent,{})
T.expect(ok and message==nil and #f.errors==modifyErrors+1 and tostring(f.errors[modifyErrors+1]):find("injected registered modify failure",1,true),"registered thumbnail modification errors report once")
T.expect(active==0 and not resource:IsShown(),"failed registered acquisition returns the hidden resource to its pool")
fail=false
local recovered=registered.acquireThumbnail(UIParent,{})
T.expect(recovered==resource and created==1 and active==1,"registered acquisition reuses its resource after failure")
registered.releaseThumbnail(recovered)
T.expect(active==0,"registered thumbnail release balances its acquisition")
T.finish()
