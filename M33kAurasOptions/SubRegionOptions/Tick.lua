if not M33kAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

local L = M33kAuras.L;

local function createOptions(parentData, data, index, subIndex)
  local hiddentickextras = function()
    return OptionsPrivate.IsCollapsed("subtext", "subtext", "tickextras" .. index, true)
  end
  local options = {
    __title = L["Tick %s"]:format(subIndex),
    __order = 1,
    tick_visible = {
      type = "toggle",
      width = M33kAuras.normalWidth,
      name = L["Show Tick"],
      order = 1,
    },
    tick_color = {
      type = "color",
      width = M33kAuras.normalWidth,
      name = L["Color"],
      order = 2,
      hasAlpha = true,
    },

    tick_thickness = {
      type = "range",
      control = "M33kAurasSpinBox",
      width = M33kAuras.normalWidth,
      name = L["Thickness"],
      order = 2.5,
      min = 0,
      softMax = 20,
      step = 1,
    },

    tick_progress_source_space = {
      type = "description",
      name = "",
      order = 3,
      width = M33kAuras.normalWidth,
    },

    tick_placement_mode = {
      type = "select",
      width = M33kAuras.normalWidth,
      name = L["Tick Mode"],
      order = 3.1,
      values = OptionsPrivate.Private.tick_placement_modes,
    },


    tick_progress_source_space_2 = {
      type = "description",
      name = "",
      order = 3.2,
      width = M33kAuras.normalWidth,
    },

    tick_add = {
      type = "execute",
      name = L["Add"],
      order = 5,
      width = M33kAuras.normalWidth,
      func = function()
        tinsert(data.tick_placements, 0)
        M33kAuras.Add(parentData)
        M33kAuras.ClearAndUpdateOptions(parentData.id)
      end
    },

    tick_extrasDescription = {
      type = "execute",
      control = "M33kAurasExpandSmall",
      name = function()
        local lengthtext = ""
        if data.automatic_length then
          lengthtext = L["|cFFFF0000Automatic|r length"]
        else
          lengthtext = L["Length of |cFFFF0000%s|r"]:format(data.tick_length)
        end

        local texturetext = ""
        if data.use_texture then
          local desaturatetext = data.tick_desaturate and L["|cFFFF0000desaturated|r "] or ""
          local blendtext = OptionsPrivate.Private.blend_types[data.tick_blend_mode]
          local rotationtext = data.tick_rotation ~= 0 and L[" rotated |cFFFF0000%s|r degrees"]:format(data.tick_rotation) or ""
          local mirrortext = data.tick_mirror and L[" and |cFFFF0000mirrored|r"] or ""
          texturetext = L["%s|cFFFF0000custom|r texture with |cFFFF0000%s|r blend mode%s%s"]:format(desaturatetext, blendtext, rotationtext, mirrortext)
        else
          texturetext = L["|cFFFF0000default|r texture"]
        end

        local offsettext = ""
        if data.tick_xOffset ~=0 or data.tick_yOffset ~=0 then
          offsettext = L["Offset by |cFFFF0000%s|r/|cFFFF0000%s|r"]:format(data.tick_xOffset, data.tick_yOffset)
        end

        local description = L["|cFFffcc00Extra:|r %s and %s %s"]:format(lengthtext, texturetext, offsettext)

        return description
      end,
      width = M33kAuras.doubleWidth,
      order = 7,
      func = function(info, button)
        local collapsed = OptionsPrivate.IsCollapsed("subtext", "subtext", "tickextras" .. index, true)
        OptionsPrivate.SetCollapsed("subtext", "subtext", "tickextras" .. index, not collapsed)
      end,
      image = function()
        local collapsed = OptionsPrivate.IsCollapsed("subtext", "subtext", "tickextras" .. index, true)
        return collapsed and "collapsed" or "expanded"
      end,
      imageWidth = 15,
      imageHeight = 15,
      arg = {
        expanderName = "tick" .. index .. "#" .. subIndex
      }
    },
    automatic_length = {
      type = "toggle",
      width = M33kAuras.normalWidth,
      name = L["Automatic length"],
      order = 8,
      desc = L["Matches the height setting of a horizontal bar or width for a vertical bar."],
      hidden = hiddentickextras,
    },
    tick_length = {
      type = "range",
      control = "M33kAurasSpinBox",
      width = M33kAuras.normalWidth,
      name = L["Length"],
      order = 9,
      min = 0,
      softMax = 50,
      step = 1,
      disabled = function() return data.automatic_length end,
      hidden = hiddentickextras,
    },
    use_texture = {
      type = "toggle",
      width = M33kAuras.normalWidth,
      name = L["Use Texture"],
      order = 10,
      hidden = hiddentickextras,
    },
    tick_blend_mode = {
      type = "select",
      width = M33kAuras.normalWidth,
      name = L["Blend Mode"],
      order = 11,
      values = OptionsPrivate.Private.blend_types,
      disabled = function() return not data.use_texture end,
      hidden = hiddentickextras,
    },
    tick_texture = {
      type = "input",
      name = L["Texture"],
      order = 12,
      width = M33kAuras.doubleWidth - 0.15,
      disabled = function() return not data.use_texture end,
      hidden = hiddentickextras,
    },
    texture_chooser = {
      type = "execute",
      name = L["Choose"],
      width = 0.15,
      order = 12.5,
      func = function()
        local path = { "subRegions", index }
        local paths = {}
        for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
          paths[child.id] = path
        end
        OptionsPrivate.OpenTexturePicker(parentData, paths, {
          texture = "tick_texture",
          color = "tick_color",
          blendMode = "tick_blend_mode"
        }, OptionsPrivate.Private.texture_types);
      end,
      disabled = function() return not data.use_texture end,
      hidden = hiddentickextras,
      imageWidth = 24,
      imageHeight = 24,
      control = "M33kAurasIcon",
      image = "Interface\\AddOns\\M33kAuras\\Media\\Textures\\browse",
    },
    tick_desaturate = {
      type = "toggle",
      width = M33kAuras.doubleWidth,
      name = L["Desaturate"],
      order = 13,
      hidden = hiddentickextras,
    },
    tick_rotation = {
      type = "range",
      control = "M33kAurasSpinBox",
      width = M33kAuras.normalWidth,
      name = L["Rotation"],
      min = 0,
      max = 360,
      step = 1,
      order = 14,
      hidden = hiddentickextras,
    },
    tick_mirror = {
      type = "toggle",
      width = M33kAuras.normalWidth,
      name = L["Mirror"],
      order = 15,
      disabled = function() return not data.use_texture end,
      hidden = hiddentickextras,
    },
    tick_xOffset = {
      type = "range",
      control = "M33kAurasSpinBox",
      width = M33kAuras.normalWidth,
      name = L["x-Offset"],
      order = 16,
      softMin = -200,
      softMax = 200,
      step = 1,
      hidden = hiddentickextras,
    },
    tick_yOffset = {
      type = "range",
      control = "M33kAurasSpinBox",
      width = M33kAuras.normalWidth,
      name = L["y-Offset"],
      order = 17,
      softMin = -200,
      softMax = 200,
      step = 1,
      hidden = hiddentickextras,
    },

    tick_anchor = {
      type = "description",
      name = "",
      order = 18,
      hidden = hiddentickextras,
      control = "M33kAurasExpandAnchor",
      arg = {
        expanderName = "tick" .. index .. "#" .. subIndex
      }
    }
  }

  if data then
    for i in ipairs(data.tick_placements) do
      options["tick_progress_source" .. i] = {
        type = "select",
        width = M33kAuras.normalWidth,
        name = function()
          return data.tick_placement_mode == "AtTimestamp" and L["Timestamp Source"] or L["Progress Source"]
        end,
        order = 4 + i / 100,
        control = "M33kAurasTwoColumnDropdown",
        values = OptionsPrivate.Private.GetProgressSourcesForUi(parentData, true),
        get = function(info)
          return OptionsPrivate.Private.GetProgressValueConstant(data.progressSources[i] or {-2, ""})
        end,
        set = function(info, value)
          if value then
            data.progressSources = data.progressSources or {}
            data.progressSources[i] = data.progressSources[i] or {}
            -- Copy only trigger + property
            data.progressSources[i][1] = value[1]
            data.progressSources[i][2] = value[2]
          else
            data.progressSources[i] = nil
          end
          M33kAuras.Add(parentData)
        end,
        hidden = function()
          return data.tick_placement_mode ~= "ValueOffset" and data.tick_placement_mode ~= "AtTimestamp"
        end
      }

      options["tick_placement" .. i] = {
        type = "input",
        width = M33kAuras.normalWidth - 0.15,
        name = function()
          return data.tick_placement_mode == "AtTimestamp" and L["Time Offset"] or L["Tick Placement"]
        end,
        order = 4 + i / 100 + 0.001,
        validate = M33kAuras.ValidateNumeric,
        desc = function()
          if data.tick_placement_mode == "AtTimestamp" then
            return L["Offset in seconds from the selected absolute timestamp. Requires timed or duration-object progress. Auto uses the parent's end time."]
          end
          return L["Enter in a value for the tick's placement."]
        end,
        get = function(info)
          return data.tick_placements[i] or ""
        end,
        set = function(info, value)
          data.tick_placements[i] = value
          M33kAuras.Add(parentData)
        end
      }

      options["tick_placement_delete" .. i] = {
        type = "execute",
        width = 0.15,
        name = L["Delete"],
        order = 4 + i / 100 + 0.002,
        func = function()
          tremove(data.tick_placements, i)
          if data.progressSources then
            for sourceIndex = i, #data.tick_placements do
              data.progressSources[sourceIndex] = data.progressSources[sourceIndex + 1]
            end
            data.progressSources[#data.tick_placements + 1] = nil
          end
          M33kAuras.Add(parentData)
          M33kAuras.ClearAndUpdateOptions(parentData.id)
        end,
        image = "Interface\\AddOns\\M33kAuras\\Media\\Textures\\delete",
        imageWidth = 24,
        imageHeight = 24,
        control = "M33kAurasIcon",
        disabled = function()
          return #data.tick_placements < 2
        end
      }
    end
  end

  OptionsPrivate.AddUpDownDeleteDuplicate(options, parentData, index, "subtick")

  return options
end

local getAnchors = function(data)
  local anchors = {}
  for i in ipairs(data.tick_placements) do
    anchors["tick."..i] = {
      display = L["Tick Center %s"]:format(i),
      type = "point"
    }
    anchors["tickarea."..i] = {
      display = L["Tick Area %s"]:format(i),
      type = "area"
    }
  end
  return anchors
end

M33kAuras.RegisterSubRegionOptions("subtick", createOptions, L["Places a tick on the bar"], getAnchors)
