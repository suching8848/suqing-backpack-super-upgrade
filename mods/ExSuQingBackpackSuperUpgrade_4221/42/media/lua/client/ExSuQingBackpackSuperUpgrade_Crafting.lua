if isServer() then return end
require "ExSuQingBackpackSuperUpgrade/Core"
require "ExSuQingBackpackSuperUpgrade/Refund"
require "Entity/TimedActions/ISHandcraftAction"

local X = ExSuQingBackpackSuperUpgrade
if X.craftingLoaded then return end
X.craftingLoaded = true

function X.RefreshInventory(character, item)
    local ok, message = pcall(function()
        if item and item.setDrawDirty then item:setDrawDirty(true) end
        local playerNum = character:getPlayerNum()
        if CodexInventoryTransferPerformance and CodexInventoryTransferPerformance.flush then
            CodexInventoryTransferPerformance.flush(playerNum)
        end
        if ISInventoryPage and ISInventoryPage.dirtyUI then ISInventoryPage.dirtyUI() end
        for _, getter in ipairs({ getPlayerInventory, getPlayerLoot }) do
            local page = getter and getter(playerNum)
            if page and page.inventoryPane then page.inventoryPane:refreshContainer() end
        end
    end)
    if not ok then print("[ExSuQingBackpackSuperUpgrade] inventory refresh: " .. tostring(message)) end
end

function X.RefreshCraftingPanel(panel)
    if not panel or not panel.logic or not ArrayList then return end
    local ok, message = pcall(function()
        local logic = panel.logic
        if not logic.getContainers or not logic.setContainers then return end
        local containers = ArrayList.new()
        containers:addAll(logic:getContainers())
        logic:setContainers(ArrayList.new())
        logic:setContainers(containers)
        if logic.autoPopulateInputs then logic:autoPopulateInputs() end
        if logic.sortRecipeList then logic:sortRecipeList() end
        local info = panel.HandCraftPanel and panel.HandCraftPanel.recipeInfoPanel
        if info and info.onRecipeChanged then info:onRecipeChanged() end
    end)
    if not ok then print("[ExSuQingBackpackSuperUpgrade] crafting refresh: " .. tostring(message)) end
end

local function attachCompletionRefresh(action)
    if action.exSuQingRefreshAttached then return end
    local original = action.onCompleteFunc
    action.onCompleteFunc = function(panel)
        if original then original(panel) end
        X.RefreshCraftingPanel(panel)
    end
    action.exSuQingRefreshAttached = true
end

function X.CaptureInputs(data)
    local inputs = data:getAllInputItems()
    local result, seen = {}, {}
    for index = 0, inputs:size() - 1 do
        local item = inputs:get(index)
        if not seen[item] then
            seen[item] = true
            local container = item:getContainer()
            if not container or not container:getItems():contains(item) then return nil, "inputs_changed" end
            local snapshot = { item = item, container = container, fullType = item:getFullType() }
            if instanceof(item, "DrainableComboItem") then snapshot.uses = item:getCurrentUsesFloat() end
            if snapshot.fullType == "Base.Thread" or snapshot.fullType == "Base.PremiumFishingLine" then
                if not item.getCurrentUses or snapshot.uses == nil then return nil, "line_api" end
                snapshot.units = item:getCurrentUses()
            end
            result[#result + 1] = snapshot
        end
    end
    return result
end

-- Keep the real original objects; rollback never manufactures replacement inputs.
function X.RestoreInputs(snapshots)
    local allOK = true
    for _, snapshot in ipairs(snapshots or {}) do
        local ok, message = pcall(function()
            local item, destination = snapshot.item, snapshot.container
            -- A foreign callback may have dropped this exact object into the
            -- world. Preserve it there and report incomplete recovery instead
            -- of adding the same object to a second inventory/world location.
            if item.getWorldItem and item:getWorldItem() ~= nil then error("Input moved into the world") end
            local current = item:getContainer()
            if current and current ~= destination and current:getItems():contains(item) then current:Remove(item) end
            if snapshot.uses ~= nil then item:setCurrentUsesFloat(snapshot.uses) end
            if not destination:getItems():contains(item) then destination:AddItem(item) end
            if not destination:getItems():contains(item) or item:getContainer() ~= destination
                or item:getFullType() ~= snapshot.fullType
                or (snapshot.uses ~= nil and item:getCurrentUsesFloat() ~= snapshot.uses)
                or (snapshot.units ~= nil and item:getCurrentUses() ~= snapshot.units) then
                error("Input instance was not restored")
            end
        end)
        if not ok then
            allOK = false
            print("[ExSuQingBackpackSuperUpgrade] input rollback failed: " .. tostring(message))
        end
    end
    return allOK
end

local function logFailure(reason)
    print("[ExSuQingBackpackSuperUpgrade] craft stopped: " .. tostring(reason))
    return false, reason
end

local function performLocked(action, mode)
    if not action.logic then return logFailure("no_recipe_data") end
    local refund = X.Refund
    if not refund then return logFailure("refund_unavailable") end
    local data = action.logic:getRecipeData()
    local target, targetReason = X.FindTarget(data)
    if not target then return logFailure(targetReason) end
    local ledger, ledgerReason = refund.ReadLedger(X.GetRecord(target))
    if not ledger then return logFailure(ledgerReason) end
    local ready, reason, targetSnapshot, expected = X.ProbeChange(target, action.character, mode)
    if not ready then return logFailure(reason) end
    local inputs, inputReason = X.CaptureInputs(data)
    if not inputs then return logFailure(inputReason) end
    local refundPlan
    if mode == "restore" then
        local staged, plan, stageReason = pcall(refund.StageRefund, targetSnapshot.record, action.character)
        if not staged or not plan then return logFailure(staged and stageReason or plan) end
        refundPlan = plan
    end

    local stoppedReason
    local ok, message = pcall(function()
        -- craftStarted reserves this action's own keep+ItemCount input. Calling
        -- canPerformCurrentRecipe again here falsely counts it as unavailable.
        -- The real native perform still validates and consumes current inputs.
        if not action.logic:performCurrentRecipe() then stoppedReason = "ingredients" return end
        local changed, changedItem
        if mode == "restore" then changed, changedItem = X.Restore(data, action.character)
        else changed, changedItem = X.Upgrade(data, action.character) end
        if not changed or changedItem ~= target then
            stoppedReason = changed and "inputs_changed" or changedItem
            return
        end
        data:processDestroyAndUsedItems(action.character)
        local record = X.GetRecord(target)
        if mode == "restore" then
            if record ~= nil then stoppedReason = "verification" return end
            refund.InsertRefund(refundPlan)
        else
            if not X.IsValidRecord(record, target) or record.targetCapacity ~= expected
                or not X.Capacity or not X.Capacity.IsReady()
                or X.Capacity.GetEffective(target, nil) ~= expected then
                stoppedReason = "verification"
                return
            end
            local recorded, paymentReason = refund.CommitPayment(target, inputs)
            if not recorded then stoppedReason = paymentReason end
        end
    end)
    if not ok or stoppedReason then
        local revokedOK, revoked = pcall(refund.RevokeRefund, refundPlan)
        local canRestoreCredit = revokedOK and revoked == true
        local targetOK, restoredTarget
        if canRestoreCredit then
            targetOK, restoredTarget = pcall(X.RestoreTarget, targetSnapshot)
        else
            -- Any refund output whose benefit might remain consumes EX credit.
            -- Clearing only our own record avoids ever duplicating that credit.
            targetOK, restoredTarget = pcall(function()
                target:getModData()[X.modDataKey] = nil
                return X.GetRecord(target) == nil
            end)
        end
        local inputsOK, restoredInputs = pcall(X.RestoreInputs, inputs)
        restoredTarget = targetOK and restoredTarget == true
        restoredInputs = inputsOK and restoredInputs == true
        print("[ExSuQingBackpackSuperUpgrade] aborted " .. tostring(stoppedReason or message)
            .. " targetRestored=" .. tostring(restoredTarget) .. " inputsRestored=" .. tostring(restoredInputs)
            .. " refundRevoked=" .. tostring(canRestoreCredit) .. " ledgerConsumed=" .. tostring(not canRestoreCredit))
        X.RefreshInventory(action.character, target)
        return logFailure((canRestoreCredit and restoredTarget and restoredInputs) and (stoppedReason or "exception") or "rollback")
    end
    X.RefreshInventory(action.character, target)
    if mode == "restore" then
        print("[ExSuQingBackpackSuperUpgrade] restored " .. target:getFullType()
            .. " refundCloth=" .. refundPlan.cloth .. " refundLeather=" .. refundPlan.leather
            .. " refundThreadUses=" .. refundPlan.threadUses .. " refundPremiumUses=" .. refundPlan.premiumUses)
    else
        print("[ExSuQingBackpackSuperUpgrade] upgraded " .. target:getFullType() .. " targetCapacity=" .. tostring(expected))
    end
    return true
end

function X.PerformUpgradeAction(action, mode)
    if action.exSuQingFinished then return false, "action_replay" end
    action.exSuQingFinished = true
    attachCompletionRefresh(action)
    if not X.IsSinglePlayer() then return logFailure("multiplayer") end
    local locks = X.locks
    if not locks or not action.character then return logFailure("no_character") end
    if locks[action.character] then return logFailure("nested_owned_action") end
    locks[action.character] = action
    local ok, result, reason = pcall(performLocked, action, mode)
    if locks[action.character] == action then locks[action.character] = nil end
    if not ok then
        print("[ExSuQingBackpackSuperUpgrade] action exception; recovery not assumed: " .. tostring(result))
        return logFailure("exception")
    end
    return result, reason
end

function X.InstallCraftGuard()
    if X.craftGuardInstalled or not ISHandcraftAction or not ISHandcraftAction.performRecipe then return end
    local original = ISHandcraftAction.performRecipe
    ISHandcraftAction.performRecipe = function(self, ...)
        local mode = X.GetRecipeMode(self.craftRecipe)
        if mode == nil then return original(self, ...) end
        local ok, result, reason = pcall(X.PerformUpgradeAction, self, mode)
        if not ok then
            print("[ExSuQingBackpackSuperUpgrade] action exception; recovery not assumed: " .. tostring(result))
            return logFailure("exception")
        end
        return result, reason
    end
    X.craftGuardInstalled = true
    print("[ExSuQingBackpackSuperUpgrade] " .. X.version .. " ready; EX-only native crafting guard")
end

Events.OnGameStart.Add(X.InstallCraftGuard)
