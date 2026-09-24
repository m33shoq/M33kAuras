if not M33kAuras.IsLibsOK() then return end
local _, OptionsPrivate = ...

-- Shared by aura and Companion rows. Thumbnail ownership ends before calling
-- region code, so an error cannot retain the old aura or release it twice.
local Thumbnail = {}
OptionsPrivate.AuraListThumbnail = Thumbnail

function Thumbnail.Release(self)
  local thumbnail, option = self.thumbnail, self.thumbnailOptions
  local desaturated = self.thumbnailDesaturated
  self.hasThumbnail, self.thumbnail, self.thumbnailType = false, nil, nil
  self.thumbnailOptions, self.thumbnailDesaturated = nil, nil
  if not thumbnail then return end
  local ok = xpcall(function()
    if desaturated and thumbnail.icon then thumbnail.icon:SetDesaturated(false) end
    option.releaseThumbnail(thumbnail)
  end, geterrorhandler())
  if not ok then
    -- The region owns its internal pool. We can hide its failed resource and
    -- finish releasing the row, but cannot safely return it to that pool.
    thumbnail:Hide()
  end
end

function Thumbnail.Acquire(self, desaturate)
  if self.hasThumbnail or not self.data then return end
  local regionType = self.data.regionType
  local option = OptionsPrivate.Private.regionOptions[regionType]
  local thumbnail
  if option and option.acquireThumbnail then
    thumbnail = option.acquireThumbnail(self.frame, self.data)
  end
  self.hasThumbnail, self.thumbnailType = true, regionType
  self.thumbnail, self.thumbnailOptions = thumbnail, option
  self.thumbnailDesaturated = desaturate
  if thumbnail then
    if desaturate and thumbnail.icon then thumbnail.icon:SetDesaturated(true) end
    self:SetIcon(thumbnail)
  else
    self:SetIcon("Interface\\Icons\\INV_Misc_QuestionMark")
  end
end

function Thumbnail.Update(self)
  if not self.hasThumbnail then return end
  if self.data.regionType ~= self.thumbnailType then
    self:ReleaseThumbnail()
    self:AcquireThumbnail()
  else
    local option = self.thumbnailOptions
    if self.thumbnail and option and option.modifyThumbnail then
      option.modifyThumbnail(self.frame, self.thumbnail, self.data)
    end
  end
end
