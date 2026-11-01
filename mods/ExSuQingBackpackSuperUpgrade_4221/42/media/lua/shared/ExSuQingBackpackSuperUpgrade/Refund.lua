-- EX-only actual-payment accounting. Ordinary upgrade records are never read or written.
ExSuQingBackpackSuperUpgrade = ExSuQingBackpackSuperUpgrade or {}
local X = ExSuQingBackpackSuperUpgrade
X.Refund = X.Refund or {}
local R = X.Refund
if R.loaded then return R end
R.loaded = true
R.ledgerKeys = { "paidLedgerVersion", "paidCloth", "paidLeather", "paidThreadUses", "paidPremiumUses" }

local function integer(value, maximum)
    return type(value) == "number" and value == math.floor(value) and value >= 0 and value <= maximum
end

local function zero(paid)
    return paid.cloth == 0 and paid.leather == 0 and paid.threadUses == 0 and paid.premiumUses == 0
end

local function exact(paid)
    local cost = X.cost
    return paid.cloth == cost.cloth and paid.leather == cost.leather
        and paid.threadUses == cost.threadUses and paid.premiumUses == cost.premiumUses
end

function R.ReadLedger(record)
    if record == nil then return { present = false, cloth = 0, leather = 0, threadUses = 0, premiumUses = 0 } end
    if type(record) ~= "table" or record.paidLedgerVersion ~= 1
        or not integer(record.paidCloth, X.cost.cloth)
        or not integer(record.paidLeather, X.cost.leather)
        or not integer(record.paidThreadUses, X.cost.threadUses)
        or not integer(record.paidPremiumUses, X.cost.premiumUses) then return nil, "invalid_payment_ledger" end
    local paid = { present = true, cloth = record.paidCloth, leather = record.paidLeather,
        threadUses = record.paidThreadUses, premiumUses = record.paidPremiumUses }
    if not zero(paid) and not exact(paid) then return nil, "invalid_payment_ledger" end
    return paid
end

function R.CopyLedger(record, destination)
    local paid, reason = R.ReadLedger(record)
    if not paid then return false, reason end
    destination.paidLedgerVersion = 1
    destination.paidCloth, destination.paidLeather = paid.cloth, paid.leather
    destination.paidThreadUses, destination.paidPremiumUses = paid.threadUses, paid.premiumUses
    return true
end

-- A conversion failure may retain a fresh bag to protect unrecovered contents.
-- Keep its EX record valid, but revoke the duplicate refundable entitlement.
function R.DropLedger(item)
    local record = X.GetRecord(item)
    if record == nil then return true end
    if type(record) ~= "table" then return false end
    local updated = X.CopyRecord(record)
    updated.paidLedgerVersion = 1
    updated.paidCloth, updated.paidLeather, updated.paidThreadUses, updated.paidPremiumUses = 0, 0, 0, 0
    item:getModData()[X.modDataKey] = updated
    local observed = X.GetRecord(item)
    return observed == updated and observed.paidCloth == 0 and observed.paidLeather == 0
        and observed.paidThreadUses == 0 and observed.paidPremiumUses == 0
end

local function contains(container, item)
    return container ~= nil and container:getItems():contains(item)
end

-- Called only after native destruction/draining. A full premium line has four
-- uses; its integer use delta is measured independently of ordinary Thread.
function R.MeasurePayment(snapshots)
    local paid = { cloth = 0, leather = 0, threadUses = 0, premiumUses = 0 }
    for _, snapshot in ipairs(snapshots) do
        local item, fullType = snapshot.item, snapshot.fullType
        if item:getFullType() ~= fullType then return nil, "payment_input_changed" end
        if item.getWorldItem and item:getWorldItem() ~= nil then return nil, "payment_input_in_world" end
        local current = item:getContainer()
        if current ~= nil and current ~= snapshot.container then return nil, "payment_input_moved" end
        local present = contains(snapshot.container, item)
        if present and current ~= snapshot.container then return nil, "payment_input_changed" end
        if fullType == "Base.RippedSheets" or fullType == "Base.LeatherStrips" then
            if not present then
                local key = fullType == "Base.RippedSheets" and "cloth" or "leather"
                paid[key] = paid[key] + 1
            end
        elseif fullType == "Base.Thread" or fullType == "Base.PremiumFishingLine" then
            local before = snapshot.units or snapshot.threadUnits or snapshot.premiumUnits
            local now = item:getCurrentUses()
            if not integer(before, 100000) or not integer(now, before)
                or (now > 0 and not present) then return nil, "payment_line_changed" end
            local key = fullType == "Base.Thread" and "threadUses" or "premiumUses"
            paid[key] = paid[key] + before - now
        elseif not present then
            return nil, "payment_kept_input_changed"
        end
    end
    -- Fully free crafting creates no refund. Partial or unexpected payment is
    -- rejected and the crafting transaction restores the original instances.
    if not zero(paid) and not exact(paid) then return nil, "payment_cost_mismatch" end
    return paid
end

function R.CommitPayment(item, snapshots)
    local paid, reason = R.MeasurePayment(snapshots)
    if not paid then return false, reason end
    local record = X.GetRecord(item)
    if not X.IsValidRecord(record, item) then return false, "payment_record_changed" end
    local previous, previousReason = R.ReadLedger(record)
    if not previous then return false, previousReason end
    if not zero(previous) then return false, "payment_already_recorded" end
    local updated = X.CopyRecord(record)
    R.CopyLedger({ paidLedgerVersion = 1, paidCloth = paid.cloth, paidLeather = paid.leather,
        paidThreadUses = paid.threadUses, paidPremiumUses = paid.premiumUses }, updated)
    item:getModData()[X.modDataKey] = updated
    if X.GetRecord(item) ~= updated or not X.IsValidRecord(updated, item) then return false, "payment_commit" end
    return true
end

local function fresh(item, fullType)
    return item ~= nil and item:getFullType() == fullType and item:getContainer() == nil
        and (not item.getWorldItem or item:getWorldItem() == nil)
end

function R.StageRefund(record, character)
    local paid, reason = R.ReadLedger(record)
    if not paid then return nil, reason end
    local plan = { inventory = character:getInventory(), entries = {}, started = false,
        cloth = math.floor(paid.cloth / 2), leather = math.floor(paid.leather / 2),
        threadUses = math.floor(paid.threadUses / 2), premiumUses = math.floor(paid.premiumUses / 2) }
    local seen = {}
    local function create(fullType)
        local item = instanceItem(fullType)
        if not fresh(item, fullType) or seen[item] then error("refund_factory_not_fresh") end
        seen[item] = true
        return item
    end
    local function add(fullType)
        plan.entries[#plan.entries + 1] = { item = create(fullType), fullType = fullType }
    end
    for index = 1, plan.cloth do add("Base.RippedSheets") end
    for index = 1, plan.leather do add("Base.LeatherStrips") end
    local function addLine(fullType, remaining)
        while remaining > 0 do
            local item = create(fullType)
            local delta = item:getUseDelta()
            if type(delta) ~= "number" or delta ~= delta or delta <= 0 or delta > 1 then error("refund_line_delta") end
            local units = math.min(remaining, math.floor(1 / delta + 0.00001))
            if units < 1 then error("refund_line_delta") end
            item:setCurrentUsesFloat(units * delta)
            if item:getCurrentUses() ~= units then error("refund_line_amount") end
            plan.entries[#plan.entries + 1] = { item = item, fullType = fullType, uses = units }
            remaining = remaining - units
        end
    end
    addLine("Base.Thread", plan.threadUses)
    addLine("Base.PremiumFishingLine", plan.premiumUses)
    return plan
end

function R.InsertRefund(plan)
    plan.started = true
    for _, entry in ipairs(plan.entries) do
        local item = entry.item
        if not fresh(item, entry.fullType) then error("refund_output_changed") end
        entry.attempted = true
        if plan.inventory:AddItem(item) ~= item or not contains(plan.inventory, item)
            or item:getContainer() ~= plan.inventory then error("refund_output_not_added") end
    end
    for _, entry in ipairs(plan.entries) do
        if not contains(plan.inventory, entry.item) or entry.item:getContainer() ~= plan.inventory
            or entry.item:getFullType() ~= entry.fullType
            or (entry.uses and entry.item:getCurrentUses() ~= entry.uses) then error("refund_verification") end
    end
    return true
end

-- Observe exact staged instances after callbacks: absence after an attempted Add
-- can also mean its benefit was consumed. Do not reissue the old credit then.
function R.RevokeRefund(plan)
    if not plan or not plan.started then return true end
    local allOK = true
    for _, entry in ipairs(plan.entries) do
        local item = entry.item
        local inspected, wasPresent, intact = pcall(function()
            return contains(item:getContainer(), item) or contains(plan.inventory, item),
                item:getFullType() == entry.fullType and (not entry.uses or item:getCurrentUses() == entry.uses)
        end)
        if not inspected or not intact or (entry.attempted and not wasPresent) then allOK = false end
        pcall(function()
            local current = item:getContainer()
            if contains(current, item) then current:Remove(item) end
            if contains(plan.inventory, item) then plan.inventory:Remove(item) end
        end)
        local checked, absent = pcall(function()
            return not contains(item:getContainer(), item) and not contains(plan.inventory, item)
                and (not item.getWorldItem or item:getWorldItem() == nil)
                and item:getFullType() == entry.fullType
                and (not entry.uses or item:getCurrentUses() == entry.uses)
        end)
        if not checked or not absent then allOK = false end
    end
    return allOK
end

return R
