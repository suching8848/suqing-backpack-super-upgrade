-- Legendary's native patch action replaces the item. The EX-only transaction
-- stages that copy before payment and transfers exactly one EX entitlement.
require "ExSuQingBackpackSuperUpgrade/Core"
local X = ExSuQingBackpackSuperUpgrade
X.Conversions = X.Conversions or {}
local V = X.Conversions
if V.loaded then return V end
V.loaded = true

local function log(message) print("[ExSuQing] Legendary conversion: " .. tostring(message)) end
local function has(container, item) return container and container:getItems():contains(item) end
local function list(container)
    local result, items = {}, container:getItems()
    for index = 0, items:size() - 1 do result[#result + 1] = items:get(index) end
    return result
end
local function sameContents(container, contents)
    if container:getItems():size() ~= #contents then return false end
    for _, child in ipairs(contents) do
        if not has(container, child) or child:getContainer() ~= container then return false end
    end
    return true
end
local function fresh(item, source)
    return item ~= nil and item ~= source and X.IsSupported(item)
        and item:getFullType() == source:getFullType() and item:getContainer() == nil
        and (not item.getWorldItem or item:getWorldItem() == nil)
        and item:getInventory():getItems():size() == 0 and X.GetRecord(item) == nil
end

function V.Rollback(t)
    local allOK, targetCleared = true, true
    local function recover(label, fn)
        local ok, result = pcall(fn)
        if not ok or result == false then allOK = false; log("rollback " .. label .. ": " .. tostring(result)) end
        return ok and result ~= false
    end
    if t.target then
        targetCleared = recover("target entitlement", function()
            t.target:getModData()[X.modDataKey] = nil
            return X.GetRecord(t.target) == nil
        end)
    end
    local sourceInner = t.source:getInventory()
    local contentsOK = true
    for _, child in ipairs(t.contents) do
        if not recover("content", function()
            local current = child:getContainer()
            if current ~= sourceInner and has(current, child) then
                current:Remove(child)
                if has(current, child) then error("content_remove_failed") end
            end
            if not has(sourceInner, child) then sourceInner:AddItem(child) end
            if not has(sourceInner, child) then
                -- Preserve the exact child in a tracked container on a failed
                -- foreign AddItem; never discard a target holding that child.
                local fallback = t.target and t.target:getInventory() or t.inventory
                if not has(fallback, child) then pcall(function() fallback:AddItem(child) end) end
                error("content_restore_failed")
            end
            return child:getContainer() == sourceInner
        end) then contentsOK = false end
    end
    local targetRemoved = true
    if t.target then
        targetRemoved = recover("target inventory", function()
            t.character:removeFromHands(t.target)
            t.character:removeWornItem(t.target, false)
            if t.target:getInventory():getItems():size() ~= 0 then
                if not t.target:getContainer() then t.inventory:AddItem(t.target) end
                return false
            end
            local current = t.target:getContainer()
            if has(current, t.target) then current:Remove(t.target) end
            return t.target:getContainer() == nil and not has(t.inventory, t.target)
        end)
    end
    recover("source inventory", function()
        if not has(t.inventory, t.source) then t.inventory:AddItem(t.source) end
        return has(t.inventory, t.source) and t.source:getContainer() == t.inventory
    end)
    -- Restore refund rights only once the replacement cannot retain a copy.
    recover("source entitlement", function()
        if not targetCleared then
            t.source:getModData()[X.modDataKey] = nil
            return false
        end
        t.source:getModData()[X.modDataKey] = X.CopyRecord(t.record)
        return X.IsValidRecord(X.GetRecord(t.source), t.source)
    end)
    if t.paymentStarted then
        recover("fabric", function()
            if not has(t.inventory, t.fabric) then t.inventory:AddItem(t.fabric) end
            return has(t.inventory, t.fabric)
        end)
        recover("thread", function()
            t.thread:setCurrentUsesFloat(t.threadUses)
            if not has(t.inventory, t.thread) then t.inventory:AddItem(t.thread) end
            return has(t.inventory, t.thread) and t.thread:getCurrentUsesFloat() == t.threadUses
        end)
    end
    recover("wear", function()
        if t.wasWorn then t.character:setWornItem(t.slot, t.source, false) end
        if t.primary then t.character:setPrimaryHandItem(t.primary) end
        if t.secondary then t.character:setSecondaryHandItem(t.secondary) end
        return not t.wasWorn or t.character:getWornItem(t.slot) == t.source
    end)
    return allOK and contentsOK and targetRemoved and targetCleared
end

function V.Convert(action)
    local source, character = action.item, action.character
    local inventory = character and character:getInventory()
    if not inventory or X.locks[character] or not V.originalValid(action) then return false end
    if not X.Capacity or not X.Capacity.IsReady() then return false end
    local record = X.GetRecord(source)
    if not X.IsValidRecord(record, source) or not has(inventory, source) or source:getContainer() ~= inventory then return false end
    local plain, patched = LB_Patches.GetIndexes(source)
    if not plain or not patched then return false end
    local choice = action.addPatches and patched or plain
    if source:getVisual():getTextureChoice() == choice then return false end
    local slot = source:canBeEquipped()
    local wasWorn = character:isEquippedClothing(source)
    if wasWorn and character:getWornItem(slot) ~= source then return false end
    local transaction = { source = source, character = character, inventory = inventory,
        record = X.CopyRecord(record), contents = list(source:getInventory()),
        wasWorn = wasWorn, slot = slot, primary = character:getPrimaryHandItem(),
        secondary = character:getSecondaryHandItem() }
    if action.addPatches then
        if not has(inventory, action.fabric) or not has(inventory, action.thread)
            or not action.thread.getCurrentUsesFloat or not action.thread.getCurrentUses
            or action.thread:getCurrentUses() < 1 then return false end
        transaction.fabric, transaction.thread = action.fabric, action.thread
        transaction.threadUses = action.thread:getCurrentUsesFloat()
        transaction.threadUnits = action.thread:getCurrentUses()
    end
    X.locks[character] = true
    local ok, reason = pcall(function()
        local target = instanceItem(source:getFullType())
        if not fresh(target, source) then error("unsafe_factory_target") end
        transaction.target = target
        -- Native copy moves the original child references and copies fluids,
        -- condition, favourite, name, visuals and all foreign ModData.
        copyClothingItem(source, target)
        target:getModData()[X.modDataKey] = X.CopyRecord(transaction.record)
        target:getVisual():setTextureChoice(choice)
        target:synchWithVisual()
        if not sameContents(target:getInventory(), transaction.contents)
            or source:getInventory():getItems():size() ~= 0
            or not X.IsValidRecord(X.GetRecord(target), target) then error("copy_verification") end
        local sourceFluid, targetFluid = source:getFluidContainer(), target:getFluidContainer()
        if (sourceFluid == nil) ~= (targetFluid == nil)
            or (sourceFluid and sourceFluid:getAmount() ~= targetFluid:getAmount()) then error("fluid_copy") end
        if action.addPatches then
            transaction.paymentStarted = true
            inventory:Remove(action.fabric)
            if has(inventory, action.fabric) then error("fabric_not_removed") end
            action.thread:UseAndSync()
            if action.thread:getCurrentUses() ~= transaction.threadUnits - 1 then error("thread_payment") end
        end
        character:removeFromHands(source)
        character:removeWornItem(source, false)
        inventory:Remove(source)
        if has(inventory, source) then error("source_not_removed") end
        source:getModData()[X.modDataKey] = nil
        if X.GetRecord(source) ~= nil then error("source_credit_not_revoked") end
        inventory:AddItem(target)
        if not has(inventory, target) or target:getContainer() ~= inventory then error("target_not_added") end
        if wasWorn then
            local current = character:getWornItem(slot)
            if current ~= nil and current ~= source then error("destination_occupied") end
            character:setWornItem(slot, target, false)
            if character:getWornItem(slot) ~= target then error("target_not_worn") end
        end
        if not sameContents(target:getInventory(), transaction.contents)
            or not X.IsValidRecord(X.GetRecord(target), target) then error("commit_verification") end
    end)
    if not ok then
        local recovered, restored = pcall(V.Rollback, transaction)
        X.locks[character] = nil
        log("failed " .. tostring(reason) .. "; rollback=" .. tostring(recovered and restored))
        return false
    end
    -- SP persistence is already committed. Cosmetic/sync callbacks must not
    -- rerun the transaction or reissue its payment rights when a UI mod fails.
    local target = transaction.target
    local synced, message = pcall(function()
        if action.addPatches then
            sendRemoveItemFromContainer(inventory, action.fabric)
            addXp(character, Perks.Tailoring, 2)
        end
        sendRemoveItemFromContainer(inventory, source)
        sendAddItemToContainer(inventory, target)
        if wasWorn then sendClothing(character, slot, target) end
        syncVisuals(character)
        triggerEvent("OnClothingUpdated", character)
    end)
    X.locks[character] = nil
    if not synced then log("committed; cosmetic callback failed: " .. tostring(message)) end
    return true
end

function V.Wrap(original)
    return function(action, ...)
        -- The source no longer has EX after a committed replacement. A replay
        -- must not fall through to native complete and create a second bag.
        if action.exSuQingConversionFinished then return false end
        local source = action.item
        if not X.IsSinglePlayer() or not X.IsSupported(source)
            or X.types[source:getFullType()] ~= "legendary"
            or not X.IsValidRecord(X.GetRecord(source), source) then return original(action, ...) end
        -- Failed transactions are also terminal for this action object. The
        -- player may enqueue a fresh action after correcting the condition.
        action.exSuQingConversionFinished = true
        return V.Convert(action)
    end
end

function V.IsReady()
    return X.IsSinglePlayer() and LB_SewPatchesAction and V.installed ~= nil
        and LB_SewPatchesAction.complete == V.installed
end

function V.Install()
    if not X.IsSinglePlayer() or not LB_SewPatchesAction or not LB_Patches
        or not LB_SewPatchesAction.complete or not LB_SewPatchesAction.isValid
        or type(copyClothingItem) ~= "function" then return false end
    if V.installed then return V.IsReady() end
    V.originalValid = LB_SewPatchesAction.isValid
    V.installed = V.Wrap(LB_SewPatchesAction.complete)
    LB_SewPatchesAction.complete = V.installed
    return V.IsReady()
end

Events.OnGameStart.Add(V.Install)
return V
