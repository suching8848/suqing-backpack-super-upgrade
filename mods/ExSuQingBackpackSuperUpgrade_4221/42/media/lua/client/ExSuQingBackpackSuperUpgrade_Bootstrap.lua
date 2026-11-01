-- Modules belong to EX alone; the ordinary upgrade mod is optional.
require "TimedActions/ISInventoryTransferAction"
require "ExSuQingBackpackSuperUpgrade/Core"
require "ExSuQingBackpackSuperUpgrade/Capacity"
require "ExSuQingBackpackSuperUpgrade/Conversions"

local X = ExSuQingBackpackSuperUpgrade
Events.OnGameStart.Add(function()
    if not X.IsSinglePlayer() then
        print("[ExSuQingBackpackSuperUpgrade] single player only; EX inactive")
        return
    end
    print("[ExSuQingBackpackSuperUpgrade] " .. X.version
        .. " capacityReady=" .. tostring(X.Capacity.IsReady())
        .. " conversionsReady=" .. tostring(X.Conversions.IsReady())
        .. "; no physical-stat writes; no personal-save migration")
end)
