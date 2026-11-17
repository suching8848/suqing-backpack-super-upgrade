local X = ExSuQingBackpackSuperUpgrade
local eq, ok, case = Review.eq, Review.ok, Review.case
local duffel = "LD.Bag_LegendaryDuffelbag_Grey"
local lower = duffel .. "_LB"
local front = "LF.Bag_FannypackFront_Legendary_Yellow"
local back = "LF.Bag_FannypackBack_Legendary_Yellow"
local slots = { [duffel] = "Back", [lower] = "LowerBack", [front] = "WaistFront", [back] = "WaistBack" }
local scripts = {}
for fullType, partner in pairs(X.variantPairs) do
    local itemName, extra = fullType, string.match(partner, "%.([^%.]+)$")
    scripts[itemName] = {
        getDisplayName = function() return itemName end,
        getClothingItemExtra = function() return List({ extra }) end,
    }
end
function getScriptManager()
    return { getItem = function(_, fullType) return scripts[fullType] end }
end
-- The focused native regression also loads the actual ISWearClothing action.
ISWearClothing = ISBaseTimedAction:derive("ISWearClothing")
function ISWearClothing.isStopOnWalk() return false end
function ISWearClothing:new(character, item)
    local action = ISBaseTimedAction.new(self, character)
    action.item = item
    return action
end
function ISWearClothing:isValid()
    return not self.item:isBroken() and self.character:getInventory():contains(self.item)
end
function ISWearClothing:complete()
    if not self:isValid() then return false end
    self.character:removeFromHands(self.item)
    self.character:setWornItem(self.item:canBeEquipped(), self.item)
    return true
end

local originalFactory = instanceItem
function instanceItem(fullType)
    if not slots[fullType] then return originalFactory(fullType) end
    local item = Bag(nil, fullType)
    item.fluid = nil
    function item:getScriptItem() return scripts[fullType] end
    function item:canBeEquipped() return slots[fullType] end
    function item:getClothingExtraSubmenu() return "Position" end
    function item:isBroken() return false end
    return item
end

local function fixture(fullType, upgraded, wear)
    local character = Character()
    function character:getWornItems()
        local result = List()
        for slot, item in pairs(self.wornBySlot) do
            local location, wornItem = slot, item
            result:add({ getLocation = function() return location end, getItem = function() return wornItem end })
        end
        return result
    end
    local item = instanceItem(fullType)
    if upgraded then
        local record = X.NewRecord(item)
        record.paidCloth, record.paidLeather, record.paidThreadUses, record.paidPremiumUses = 40, 20, 20, 4
        item.md[X.modDataKey] = record
    end
    character.inventory:AddItem(item)
    if wear then character:setWornItem(slots[fullType], item) end
    return character, item
end

ok(X.Capacity.Install())
ok(X.Conversions.InstallVariant())

case("duffel changes both ways with its original items and paid record", function()
    local player, source = fixture(duffel, true, true)
    source.favorite, source.condition = true, 7
    local child = Bag(nil, "Base.OtherBag")
    child.weight = 65
    source.inner:AddItem(child)
    local action = ISClothingExtraAction:new(player, source, lower)
    ok(action:complete())
    local converted = player:getWornItem(slots[lower])
    ok(converted ~= source)
    eq(converted:getFullType(), lower)
    eq(source:getContainer(), nil)
    eq(X.GetRecord(source), nil)
    eq(child:getContainer(), converted.inner)
    eq(converted.inner:getEffectiveCapacity(nil), 98)
    eq(converted:getCondition(), 7)
    eq(converted:isFavorite(), true)
    eq(X.GetRecord(converted).paidPremiumUses, 4)
    eq(action:complete(), false)
    ok(ISClothingExtraAction:new(player, converted, duffel):complete())
    local returned = player:getWornItem(slots[duffel])
    eq(returned:getFullType(), duffel)
    eq(child:getContainer(), returned.inner)
    eq(X.GetRecord(returned).targetCapacity, 98)
    eq(X.GetRecord(converted), nil)
end)

case("putting an EX duffel on the same slot keeps the current items and paid records", function()
    local player, source = fixture(lower, true, false)
    local child = Bag(nil, "Base.OtherBag")
    source:getInventory():AddItem(child)
    local cooling = { token = "cooling-test", paid = true, on = true }
    source:getModData().SuQingRefrigeration = cooling
    local entitlement = X.GetRecord(source)
    local oldIsReady = X.Capacity.IsReady
    X.Capacity.IsReady = function() return false end
    local action = ISClothingExtraAction:new(player, source, lower)
    X.Capacity.IsReady = oldIsReady
    eq(action.Type, "ISWearClothing")
    ok(action:complete())
    eq(player:getWornItem(slots[lower]), source)
    eq(X.GetRecord(source), entitlement)
    eq(source:getModData().SuQingRefrigeration, cooling)
    eq(child:getContainer(), source:getInventory())
end)

case("yellow waist pack supports both putting on and changing position", function()
    local player, source = fixture(front, true, false)
    ok(ISClothingExtraAction:new(player, source, front):complete())
    local worn = player:getWornItem(slots[front])
    eq(X.GetRecord(worn).nativeBase, 10)
    ok(ISClothingExtraAction:new(player, worn, back):complete())
    local converted = player:getWornItem(slots[back])
    eq(X.GetRecord(converted).fullType, back)
    eq(X.GetRecord(converted).targetCapacity, 20)
end)

case("foreign destination and changed asset links refuse conversion", function()
    local player, source = fixture(duffel, true, true)
    eq(ISClothingExtraAction:new(player, source, back):complete(), false)
    local previous = scripts[lower].getClothingItemExtra
    scripts[lower].getClothingItemExtra = function() return List({ "Unexpected" }) end
    eq(ISClothingExtraAction:new(player, source, lower):complete(), false)
    scripts[lower].getClothingItemExtra = previous
    eq(player:getWornItem(slots[duffel]), source)
    eq(X.GetRecord(source).fullType, duffel)
end)

case("failed replacement restores items, displaced gear and EX record", function()
    local player, source = fixture(duffel, true, true)
    local occupied = instanceItem(lower)
    player.inventory:AddItem(occupied)
    player:setWornItem(slots[lower], occupied)
    local child = Bag(nil, "Base.OtherBag")
    source.inner:AddItem(child)
    local setWorn = player.setWornItem
    function player:setWornItem(slot, item)
        setWorn(self, slot, item)
        if slot == slots[lower] and item ~= occupied then error("injected equip failure") end
    end
    local action = ISClothingExtraAction:new(player, source, lower)
    eq(action:complete(), false)
    eq(player:getWornItem(slots[duffel]), source)
    eq(player:getWornItem(slots[lower]), occupied)
    eq(player.inventory.items:size(), 2)
    eq(child:getContainer(), source.inner)
    eq(X.GetRecord(source).paidCloth, 40)
    eq(action:complete(), false)
end)

case("unupgraded positions retain the native action", function()
    local player, source = fixture(front, false, false)
    ok(ISClothingExtraAction:new(player, source, back):complete())
    local target = player:getWornItem(slots[back])
    ok(target ~= source)
    eq(X.GetRecord(target), nil)
end)

case("refusing a native overflow drop keeps both worn bags", function()
    local player, source = fixture(duffel, true, true)
    local occupied = instanceItem(lower)
    occupied.weight = 80
    player.inventory:AddItem(occupied)
    player:setWornItem(slots[lower], occupied)
    eq(ISClothingExtraAction:new(player, source, lower):complete(), false)
    eq(player:getWornItem(slots[duffel]), source)
    eq(player:getWornItem(slots[lower]), occupied)
    eq(X.GetRecord(source).fullType, duffel)
    eq(player.inventory.items:size(), 2)
end)

case("known ordinary wrapping accepted, unknown overwrites fail closed", function()
    local player, subject = fixture(duffel, false, false)
    ok(X.CanUpgrade(subject, player))
    local inner = ISClothingExtraAction.complete
    local function outer(action, ...) return inner(action, ...) end
    ISClothingExtraAction.complete = outer
    local allowed, reason = X.CanUpgrade(subject, player)
    eq(allowed, false)
    eq(reason, "conversion_not_ready")
    SuQingContainerUpgrade = {
        Position = { WrapsComplete = function(complete) return complete == inner and ISClothingExtraAction.complete == outer end },
    }
    ok(X.CanUpgrade(subject, player))
    ISClothingExtraAction.complete = inner
    SuQingContainerUpgrade = nil
end)

return Review.finish()
