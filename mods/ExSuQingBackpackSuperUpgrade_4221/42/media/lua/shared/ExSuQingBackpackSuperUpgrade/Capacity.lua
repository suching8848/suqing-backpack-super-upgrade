-- An instance-only SP overlay. Physical/script capacities are never changed.
require "ExSuQingBackpackSuperUpgrade/Core"
local X = ExSuQingBackpackSuperUpgrade
X.Capacity = X.Capacity or {}
local C = X.Capacity
if C.loaded then return C end
C.loaded = true

local function number(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function owned(item)
    if not X.IsSinglePlayer() or not X.IsSupported(item) then return nil end
    local record = X.GetRecord(item)
    if X.IsValidRecord(record, item) then return record end
end

local function adjusted(capacity, character)
    if character then
        if character:hasTrait(CharacterTrait.ORGANIZED) then return math.ceil(capacity * 1.3) end
        if character:hasTrait(CharacterTrait.DISORGANIZED) then return math.ceil(capacity * 0.7) end
    end
    return capacity
end

function C.GetEffective(item, character)
    local record = owned(item)
    if not record then return nil end
    local baseline = X.GetNativeBase(item)
    if not number(baseline) or baseline < 1 then return nil end
    local capacity = adjusted(math.max(record.targetCapacity, baseline), character)
    -- The continuation already applies its own traits. Never multiply it again.
    if C.originalEffective then
        local existing = C.originalEffective(item:getInventory(), character)
        if not number(existing) then return nil end
        capacity = math.max(capacity, existing)
    end
    return capacity
end

function C.WrapEffective(original)
    return function(container, character, ...)
        local item = container:getContainingItem()
        if owned(item) then
            local capacity = C.GetEffective(item, character)
            if capacity then return capacity end
        end
        return original(container, character, ...)
    end
end

local function corrected(value)
    if not number(value) then return nil end
    return ItemContainer.floatingPointCorrection(value)
end

-- Mirror the B42.21 Java room guards, replacing only its final effective
-- capacity. Java's invokevirtual does not dispatch through the Lua getter.
local function room(container, character, incoming, floorDelta, explicitFloorDelta)
    local bag = container:getContainingItem()
    local capacity = C.GetEffective(bag, character)
    if not capacity then return false end
    local item, weight
    if type(incoming) == "number" then
        weight = incoming
    elseif incoming and instanceof(incoming, "InventoryItem") then
        item, weight = incoming, incoming:getUnequippedWeight()
    else
        return false
    end
    if not number(weight) then return false end
    if item then
        if item == bag or container:isInside(item) or not container:isItemAllowed(item) then return false end
        if character and character:getVehicle() and instanceof(container:getParent(), "IsoGameCharacter") then
            if item:isHumanCorpse() or item:hasTag(ItemTag.HEAVY_ITEM) then return false end
        end
        local owner = bag:getEquipParent()
        local inventory = owner and owner:getInventory()
        if inventory and not inventory:contains(item) then
            if not character then return false end
            local current = corrected(inventory:getCapacityWeight())
            if not current or current + weight > inventory:getEffectiveCapacity(character) then return false end
        end
    end
    local maximum = bag:getMaxItemSize()
    -- Java enables this limit only for positive values; zero and a negative
    -- script sentinel both mean unrestricted.
    if not finite(maximum) or (maximum > 0 and weight > maximum) then return false end

    if not explicitFloorDelta then
        floorDelta = weight
        if item and container:hasWorldItem() then
            local square = container:getWorldItem():getSquare()
            if square and (item:isOnGroundOnSquare(square) or item:isInsideBagOnSquare(square)) then floorDelta = 0 end
        end
    end
    -- The third native overload is a net change on this floor square; a caller
    -- may legitimately supply a negative delta while consolidating transfers.
    if not finite(floorDelta) then return false end
    if character and not container:isInCharacterInventory(character) then
        local world = container:getWorldItem()
        local square = world and world:getSquare()
        if square and square:getTotalWeightOfItemsOnFloor() + floorDelta > 50 then return false end
    end
    local outer = bag:getContainer()
    if outer and outer:getVehiclePart() then
        local total = corrected(outer:getCapacityWeight() + weight)
        if not total or total > outer:getEffectiveCapacity(character) then return false end
    end
    local current = corrected(container:getCapacityWeight())
    return current ~= nil and current + weight <= capacity
end

function C.WrapRoom(original)
    return function(container, ...)
        local bag = container:getContainingItem()
        if not owned(bag) then return original(container, ...) end
        local count = select("#", ...)
        local first, second, third = ...
        local character, incoming, floorDelta, explicitFloorDelta
        if count == 1 then
            incoming = first
            -- Native transfer serialization also asks hasRoomFor(item).
            character = bag:getEquipParent()
        elseif count == 2 or count == 3 then
            character, incoming = first, second
            if character ~= nil and not instanceof(character, "IsoGameCharacter") then return false end
            if count == 3 then floorDelta, explicitFloorDelta = third, true end
        else
            return false
        end
        local ok, result = pcall(room, container, character, incoming, floorDelta, explicitFloorDelta)
        -- A failed EX guard must never convert an uncertain result into success.
        return ok and result == true
    end
end

-- Vanilla's Java-facing queue helper contains a separate physical-capacity
-- precheck. Route only owned EX destinations through the same guarded action.
function C.WrapTransfer(original)
    return function(character, item, source, destination, ...)
        local target = destination
        if target and instanceof(target, "InventoryContainer") then target = target:getInventory() end
        local bag = target and target:getContainingItem()
        if not owned(bag) then return original(character, item, source, destination, ...) end
        if source and instanceof(source, "InventoryContainer") then source = source:getInventory() end
        if not source or source == target or not item or not source:contains(item)
            or item:getContainer() ~= source or target:isInside(item)
            or not target:hasRoomFor(character, item) then return end
        ISTimedActionQueue.add(ISInventoryTransferAction:new(character, item, source, target, 10))
    end
end

function C.InstallTransfer()
    if type(javaTransferItems) ~= "function" or not ISTimedActionQueue or not ISInventoryTransferAction then return false end
    if C.installedTransfer then return javaTransferItems == C.installedTransfer end
    C.installedTransfer = C.WrapTransfer(javaTransferItems)
    javaTransferItems = C.installedTransfer
    return true
end

local function indexTable()
    local meta = __classmetatables and ItemContainer and __classmetatables[ItemContainer.class]
    return meta and meta.__index
end

function C.IsReady()
    local index = indexTable()
    return X.IsSinglePlayer() and index ~= nil and C.installedEffective ~= nil
        and index.getEffectiveCapacity == C.installedEffective and index.hasRoomFor == C.installedRoom
        and C.installedTransfer ~= nil and javaTransferItems == C.installedTransfer
end

function C.Install()
    if not X.IsSinglePlayer() then return false end
    local index = indexTable()
    if not index or not index.getEffectiveCapacity or not index.hasRoomFor then return false end
    if C.installedEffective or C.installedRoom then
        if index.getEffectiveCapacity ~= C.installedEffective or index.hasRoomFor ~= C.installedRoom then return false end
        -- Client classes may become available after the shared module loaded.
        -- Repair only the missing helper, never stack another capacity layer.
        C.InstallTransfer()
        return C.IsReady()
    end
    -- Do not stack ourselves again beneath an unknown foreign wrapper: its
    -- continuation could call our prior layer and recurse. Refuse new payment.
    C.originalEffective, C.originalRoom = index.getEffectiveCapacity, index.hasRoomFor
    C.installedEffective = C.WrapEffective(C.originalEffective)
    C.installedRoom = C.WrapRoom(C.originalRoom)
    index.getEffectiveCapacity, index.hasRoomFor = C.installedEffective, C.installedRoom
    C.InstallTransfer()
    return C.IsReady()
end

Events.OnGameStart.Add(C.Install)
Events.OnServerStarted.Add(C.Install)
return C
