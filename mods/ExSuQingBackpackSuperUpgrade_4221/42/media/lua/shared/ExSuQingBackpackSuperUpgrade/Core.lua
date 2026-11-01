-- Independent EX entitlement. Never writes physical capacity, weight, or another
-- mod's record. Disabling this mod leaves only inert, re-readable EX ModData.
ExSuQingBackpackSuperUpgrade = ExSuQingBackpackSuperUpgrade or {}
local X = ExSuQingBackpackSuperUpgrade
if X.loaded then return X end
X.loaded = true
X.version = "1.0.0-rc.2"
X.modDataKey = "ExSuQingBackpackSuperUpgrade"
X.cost = { cloth = 40, leather = 20, threadUses = 20, premiumUses = 4, skill = 5 }
X.locks = setmetatable({}, { __mode = "k" })
X.types = {
    ["LB.Bag_LegendaryBackpack"] = "legendary",
    ["LB.Bag_LegendaryBackpack_Black"] = "legendary",
    ["LB.Bag_LegendaryBackpack_Blue"] = "legendary",
    ["LB.Bag_LegendaryBackpack_Brown"] = "legendary",
    ["LB.Bag_LegendaryBackpack_Green"] = "legendary",
    ["LB.Bag_LegendaryBackpack_Orange"] = "legendary",
    ["LB.Bag_LegendaryBackpack_Pink"] = "legendary",
    ["LB.Bag_LegendaryBackpack_Purple"] = "legendary",
    ["LB.Bag_LegendaryBackpack_Red"] = "legendary",
    ["LB.Bag_LegendaryBackpack_White"] = "legendary",
    ["Base.ResidentEvilBackPack"] = "raccoon",
}
X.supported = {}
for fullType in pairs(X.types) do X.supported[fullType] = true end

function X.IsInteger(value, low, high)
    return type(value) == "number" and value == value and value == math.floor(value)
        and value >= low and value <= high
end

function X.IsSinglePlayer()
    return not (type(isClient) == "function" and isClient())
        and not (type(isServer) == "function" and isServer())
end

function X.IsSupported(item)
    return item ~= nil and instanceof(item, "InventoryContainer")
        and X.types[item:getFullType()] ~= nil and item:getInventory() ~= nil
end

function X.GetRecord(item)
    if not X.IsSupported(item) then return nil end
    return item:getModData()[X.modDataKey]
end

function X.CopyRecord(record)
    if type(record) ~= "table" then return record end
    local seen = {}
    local function copy(value)
        if type(value) ~= "table" then return value end
        if seen[value] then return seen[value] end
        local result = {}
        seen[value] = result
        for key, child in pairs(value) do result[key] = copy(child) end
        return result
    end
    return copy(record)
end

-- Business baselines, before traits and before either ordinary or EX upgrades.
-- Legendary's original sandbox script clamps 10..100. Raccoon is 1..1000.
-- Explicit invalid values fail closed rather than charging a guessed result.
function X.GetNativeBase(item)
    if not X.IsSupported(item) then return nil, "unsupported" end
    local kind = X.types[item:getFullType()]
    local value
    if kind == "legendary" then
        value = SandboxVars and SandboxVars.LBO and SandboxVars.LBO.BagCapacity
        if value == nil then value = 49 end
        if not X.IsInteger(value, -100000, 100000) then return nil, "invalid_native_capacity" end
        return math.max(10, math.min(100, value))
    end
    value = SandboxVars and SandboxVars.ResidentEvilBackpackCapacity
    if value == nil then value = 49 end
    if not X.IsInteger(value, 1, 1000) then return nil, "invalid_native_capacity" end
    return value
end

function X.IsValidRecord(record, item)
    if type(record) ~= "table" or record.schema ~= 1 or not X.types[record.fullType]
        or type(record.version) ~= "string" or #record.version > 64
        or not X.IsInteger(record.nativeBase, 1, 1000)
        or record.targetCapacity ~= record.nativeBase * 2
        or record.paidLedgerVersion ~= 1 then return false end
    if X.types[record.fullType] == "legendary"
        and not X.IsInteger(record.nativeBase, 10, 100) then return false end
    if item and (not X.IsSupported(item) or item:getFullType() ~= record.fullType) then return false end
    local empty = record.paidCloth == 0 and record.paidLeather == 0
        and record.paidThreadUses == 0 and record.paidPremiumUses == 0
    local full = record.paidCloth == X.cost.cloth and record.paidLeather == X.cost.leather
        and record.paidThreadUses == X.cost.threadUses and record.paidPremiumUses == X.cost.premiumUses
    return empty or full
end

function X.NewRecord(item)
    local base, reason = X.GetNativeBase(item)
    if not base then return nil, reason end
    return { schema = 1, fullType = item:getFullType(), version = X.version,
        nativeBase = base, targetCapacity = base * 2,
        paidLedgerVersion = 1, paidCloth = 0, paidLeather = 0,
        paidThreadUses = 0, paidPremiumUses = 0 }
end

local function effectiveCapacity(item)
    local ok, value = pcall(function() return item:getInventory():getEffectiveCapacity(nil) end)
    if ok and X.IsInteger(value, 0, 100000) then return value end
    return nil
end

function X.GetState(item)
    if not X.IsSupported(item) then return nil end
    local record = X.GetRecord(item)
    local valid = X.IsValidRecord(record, item)
    return { record = record, upgraded = valid,
        corruptRecord = record ~= nil and not valid,
        nativeBase = valid and record.nativeBase or nil,
        targetCapacity = valid and record.targetCapacity or nil,
        effectiveCapacity = effectiveCapacity(item) }
end

local function checkTarget(item, character)
    if not X.IsSinglePlayer() then return false, "multiplayer" end
    if not X.IsSupported(item) then return false, "unsupported" end
    if not character or not character.getInventory then return false, "no_character" end
    if item:getContainer() ~= character:getInventory()
        or not character:getInventory():getItems():contains(item) then return false, "not_carried" end
    if character:isEquipped(item) or character:getPrimaryHandItem() == item
        or character:getSecondaryHandItem() == item then return false, "equipped" end
    if item:getInventory():getItems():size() ~= 0 then return false, "not_empty" end
    if item.getFluidContainer then
        local fluid = item:getFluidContainer()
        if fluid then
            local amount = fluid:getAmount()
            if type(amount) ~= "number" or amount ~= amount or amount < 0 then return false, "invalid_fluid" end
            if amount > 0 then return false, "fluid_not_empty" end
        end
    end
    local state = X.GetState(item)
    if not state or state.corruptRecord then return false, "invalid_record" end
    return true, nil, state
end

function X.CanUpgrade(item, character)
    local ok, reason, state = checkTarget(item, character)
    if not ok then return false, reason end
    if state.upgraded then return false, "already_ex" end
    if not X.Capacity or not X.Capacity.IsReady() then return false, "capacity_not_ready" end
    if X.types[item:getFullType()] == "legendary" and (not X.Conversions
        or not X.Conversions.IsReady or not X.Conversions.IsReady()) then return false, "conversion_not_ready" end
    if character:getPerkLevel(Perks.Tailoring) < X.cost.skill then return false, "skill" end
    local record, nativeReason = X.NewRecord(item)
    if not record then return false, nativeReason end
    if state.effectiveCapacity == nil then return false, "capacity_unreadable" end
    if record.targetCapacity <= state.effectiveCapacity then return false, "no_capacity_gain" end
    return true, nil, state, record
end

function X.CanRestore(item, character)
    local ok, reason, state = checkTarget(item, character)
    if not ok then return false, reason end
    if not state.upgraded then return false, "not_ex" end
    return true, nil, state
end

function X.FindTarget(data)
    if not data or not data.getAllKeepInputItems then return nil, "no_recipe_data" end
    local items = data:getAllKeepInputItems()
    if not items then return nil, "no_recipe_data" end
    local target
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if X.IsSupported(item) then
            if target and target ~= item then return nil, "multiple_targets" end
            target = item
        end
    end
    if not target then return nil, "no_target" end
    return target
end

local function recordsEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not recordsEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function X.CaptureTarget(item)
    return { item = item, record = X.CopyRecord(X.GetRecord(item)) }
end

function X.RestoreTarget(snapshot)
    if not snapshot or not X.IsSupported(snapshot.item) then return false end
    snapshot.item:getModData()[X.modDataKey] = X.CopyRecord(snapshot.record)
    return recordsEqual(X.GetRecord(snapshot.item), snapshot.record)
end

-- Craft completion preflight only. Menu OnTest functions never write ModData.
-- Temporarily exercise the real wrapper with an unpaid EX record and immediately
-- restore our own key, without mutating any physical attribute or foreign key.
function X.ProbeChange(item, character, mode)
    local ok, reason, state, proposed
    if mode == "upgrade" then ok, reason, state, proposed = X.CanUpgrade(item, character)
    elseif mode == "restore" then ok, reason, state = X.CanRestore(item, character)
    else return false, "unknown_mode" end
    if not ok then return false, reason end
    local snapshot = X.CaptureTarget(item)
    local worked, message = pcall(function()
        item:getModData()[X.modDataKey] = mode == "upgrade" and proposed or nil
        if mode == "upgrade" then
            local observed = effectiveCapacity(item)
            if not observed or observed < proposed.targetCapacity then error("capacity_not_applied") end
        elseif X.GetRecord(item) ~= nil then error("record_not_cleared") end
    end)
    local recovered, restored = pcall(X.RestoreTarget, snapshot)
    if not recovered or not restored then return false, "probe_rollback" end
    if not worked then return false, tostring(message) end
    return true, nil, snapshot, proposed and proposed.targetCapacity or nil
end

function X.Upgrade(data, character)
    local item, reason = X.FindTarget(data)
    if not item then return false, reason end
    local ok, errorCode, state, record = X.CanUpgrade(item, character)
    if not ok then return false, errorCode end
    item:getModData()[X.modDataKey] = record
    return true, item
end

function X.Restore(data, character)
    local item, reason = X.FindTarget(data)
    if not item then return false, reason end
    local ok, errorCode = X.CanRestore(item, character)
    if not ok then return false, errorCode end
    item:getModData()[X.modDataKey] = nil
    return true, item
end

function X.TestUpgrade(item, character)
    if not X.IsSinglePlayer() then return false end
    if not X.IsSupported(item) then return true end -- also tested for needle/material inputs
    return X.CanUpgrade(item, character)
end

function X.TestRestore(item, character)
    if not X.IsSinglePlayer() then return false end
    if not X.IsSupported(item) then return true end
    return X.CanRestore(item, character)
end

function X.CreateUpgrade(data, character) return X.Upgrade(data, character) end
function X.CreateRestore(data, character) return X.Restore(data, character) end

function X.GetRecipeMode(recipe)
    if not recipe then return nil end
    local name = recipe.getScriptObjectFullType and recipe:getScriptObjectFullType() or recipe:getName()
    if name == "ExSuQingBackpackSuperUpgrade.ExSuQingSuperUpgrade" then return "upgrade" end
    if name == "ExSuQingBackpackSuperUpgrade.ExSuQingRestore" then return "restore" end
    return nil
end

function X.CanComplete(data, character, mode)
    local item, reason = X.FindTarget(data)
    if not item then return false, reason end
    if mode == "restore" then return X.CanRestore(item, character) end
    if mode == "upgrade" then return X.CanUpgrade(item, character) end
    return false, "unknown_mode"
end

require "ExSuQingBackpackSuperUpgrade/Refund"
return X
