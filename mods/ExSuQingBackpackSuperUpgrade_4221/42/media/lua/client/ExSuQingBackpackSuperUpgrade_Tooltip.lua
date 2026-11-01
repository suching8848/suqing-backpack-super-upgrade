require "ISUI/ISToolTipInv"
require "ExSuQingBackpackSuperUpgrade/Core"
require "ExSuQingBackpackSuperUpgrade/Capacity"
local X = ExSuQingBackpackSuperUpgrade
X.Tooltip = X.Tooltip or {}
local T = X.Tooltip
if T.loaded then return T end
T.loaded = true

local function footer(panel)
    if not X.IsSinglePlayer() or not panel.item or not panel.tooltip
        or (ISContextMenu and ISContextMenu.instance and ISContextMenu.instance.visibleCheck) then return end
    local record = X.GetRecord(panel.item)
    if not X.IsValidRecord(record, panel.item) then return end
    local capacity = X.Capacity.GetEffective(panel.item, panel.tooltip:getCharacter())
    if not capacity then return end
    local font = panel.tooltip:getFont()
    local spacing = panel.tooltip:getLineSpacing()
    local lines = {
        getText("Tooltip_ExSuQing_ActualCapacity", tostring(capacity)),
        getText("Tooltip_ExSuQing_BaseCapacity", tostring(record.targetCapacity), tostring(record.nativeBase)),
    }
    local height = spacing * #lines + 8
    local width = panel:getWidth()
    for _, line in ipairs(lines) do width = math.max(width, getTextManager():MeasureStringX(font, line) + 12) end
    local y = panel:getHeight()
    if panel:getY() + y + height > getCore():getScreenHeight() then y = -height end
    panel:drawRect(0, y, width, height, 0.94, 0.04, 0.04, 0.06)
    panel:drawRectBorder(0, y, width, height, 1, 0.65, 0.45, 0.95)
    for index, line in ipairs(lines) do panel:drawText(line, 6, y + 4 + (index - 1) * spacing, 0.9, 0.75, 1, 1, font) end
end

function T.Wrap(original)
    return function(panel, ...)
        local result = original(panel, ...)
        -- Cosmetic failures cannot affect the item or its EX record.
        pcall(footer, panel)
        return result
    end
end

function T.Install()
    if not X.IsSinglePlayer() or not ISToolTipInv or not ISToolTipInv.render then return false end
    if T.installed then return ISToolTipInv.render == T.installed end
    T.installed = T.Wrap(ISToolTipInv.render)
    ISToolTipInv.render = T.installed
    return true
end

Events.OnGameStart.Add(T.Install)
return T
