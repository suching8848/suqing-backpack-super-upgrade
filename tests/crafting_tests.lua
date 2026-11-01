local X=ExSuQingBackpackSuperUpgrade
local eq,ok,case=Review.eq,Review.ok,Review.case
X.Conversions={IsReady=function()return true end}
ok(X.Capacity.Install());X.InstallCraftGuard()
local function paidRecord(b)
    local r=X.NewRecord(b);r.paidCloth=40;r.paidLeather=20;r.paidThreadUses=20;r.paidPremiumUses=4;return r
end
local function fixture(mode,id,options)
    options=options or{};mode=mode or"upgrade"
    local p=options.character or Character();local b=options.bag or Bag(p,id)
    if mode=="restore"and not X.GetRecord(b)then b.md[X.modDataKey]=paidRecord(b)end
    local kept={b};local all={b};local cloth,leather,thread,premium={},{},{},{}
    local needle
    local function material(fullType,uses,dest)
        local m=Material(fullType,uses);p.inventory:AddItem(m);all[#all+1]=m
        if dest then dest[#dest+1]=m end
        return m
    end
    if mode=="upgrade"then
        needle=material("Base.Needle");kept[#kept+1]=needle
        for i=1,40 do material("Base.RippedSheets",nil,cloth)end
        for i=1,20 do material("Base.LeatherStrips",nil,leather)end
        for _,u in ipairs(options.threadUnits or{20})do material("Base.Thread",u,thread)end
        for _,u in ipairs(options.premiumUnits or{4})do material("Base.PremiumFishingLine",u,premium)end
    end
    local originals={};for _,m in ipairs(all)do originals[m]=m.uses end
    local data={kept=List(kept),all=List(all),engine=0,processed=0,testOnly=0,history=0}
    function data:getAllKeepInputItems()return self.kept end
    function data:getAllInputItems()return self.all end
    function data:processDestroyAndUsedItems(character)
        self.processed=self.processed+1
        if mode=="upgrade"and not options.free then
            for _,set in ipairs({thread,premium})do
                for _,m in ipairs(set)do
                    m.uses=m.uses-(options.partial and m.fullType=="Base.PremiumFishingLine"and 2 or m.uses)
                    if m.uses==0 then p.inventory:Remove(m)end
                end
            end
        end
        if self.onProcess then self:onProcess()end
        if self.throwProcess then error("injected native drain failure")end
    end
    local logic={}
    function logic:getRecipeData()return data end
    function logic:canPerformCurrentRecipe()data.testOnly=data.testOnly+1;return false end
    function logic:performCurrentRecipe()
        data.engine=data.engine+1
        if data.beforeEngine then data:beforeEngine()end
        local allowed
        if mode=="restore"then allowed=X.CanRestore(b,p)else allowed=X.CanUpgrade(b,p)end
        if not allowed then return false end
        if mode=="upgrade"and not options.free then
            for _,set in ipairs({cloth,leather})do for _,m in ipairs(set)do p.inventory:Remove(m)end end
        end
        if data.onEngine then data:onEngine()end
        if data.throwEngine then error("injected native destroy failure")end
        if data.engineFalse then return false end
        data.history=data.history+1;return true
    end
    local action={logic=logic,character=p,craftStarted=true,craftRecipe=Recipe(mode=="restore"and"ExSuQingRestore"or"ExSuQingSuperUpgrade")}
    return{p=p,b=b,data=data,logic=logic,action=action,all=all,cloth=cloth,leather=leather,thread=thread,premium=premium,needle=needle,originals=originals,mode=mode}
end
local function restored(f)
    for _,m in ipairs(f.all)do eq(m:getContainer(),f.p.inventory);eq(f.p.inventory:contains(m),true);if m.uses~=nil then eq(m.uses,f.originals[m])end end
    eq(X.GetRecord(f.b),nil);eq(f.b.capacityWrites,0);eq(f.b.reductionWrites,0)
    eq(f.b.md.SuQingContainerUpgrade.sentinel,"ordinary untouched");eq(f.b.md.foreign.value,42)
end
local function totals(p)
    local r={cloth=0,leather=0,threadUses=0,premiumUses=0}
    for _,m in ipairs(p.inventory.items.values)do
        if m.fullType=="Base.RippedSheets"then r.cloth=r.cloth+1
        elseif m.fullType=="Base.LeatherStrips"then r.leather=r.leather+1
        elseif m.fullType=="Base.Thread"then r.threadUses=r.threadUses+m.uses
        elseif m.fullType=="Base.PremiumFishingLine"then r.premiumUses=r.premiumUses+m.uses end
    end
    return r
end
case("real payment captures both independent line use quantities",function()
    local f=fixture();local b=f.b;local ordinary=b.md.SuQingContainerUpgrade
    ok(ISHandcraftAction.performRecipe(f.action));local r=X.GetRecord(b)
    eq(f.data.engine,1);eq(f.data.processed,1);eq(f.data.testOnly,0);eq(r.paidCloth,40);eq(r.paidLeather,20);eq(r.paidThreadUses,20);eq(r.paidPremiumUses,4)
    eq(b.md.SuQingContainerUpgrade,ordinary);eq(b.inner.capacity,49);eq(b.wr,99);eq(b.capacityWrites,0);eq(b.reductionWrites,0)
    eq(f.p.inventory:contains(b),true);eq(f.p.inventory:contains(f.needle),true)
end)
case("partial spools totaling recipe use counts pay correctly",function()
    local f=fixture(nil,nil,{threadUnits={3,7,10},premiumUnits={1,3}})
    ok(ISHandcraftAction.performRecipe(f.action));eq(X.GetRecord(f.b).paidThreadUses,20);eq(X.GetRecord(f.b).paidPremiumUses,4)
end)
case("completed timed action replay cannot double charge",function()
    local f=fixture();ok(ISHandcraftAction.performRecipe(f.action));eq(ISHandcraftAction.performRecipe(f.action),false)
    eq(f.data.engine,1);eq(f.data.processed,1)
end)
case("second fresh EX action on same item is refused before payment",function()
    local f=fixture();ok(ISHandcraftAction.performRecipe(f.action))
    local next=fixture(nil,nil,{character=f.p,bag=f.b});eq(ISHandcraftAction.performRecipe(next.action),false);eq(next.data.engine,0)
    for _,m in ipairs(next.all)do eq(f.p.inventory:contains(m),true)end
end)
case("restore refunds 20 cloth 10 leather 10 thread uses 2 premium uses",function()
    local f=fixture("restore");local ordinary=f.b.md.SuQingContainerUpgrade
    ok(ISHandcraftAction.performRecipe(f.action));eq(X.GetRecord(f.b),nil)
    local count=totals(f.p);eq(count.cloth,20);eq(count.leather,10);eq(count.threadUses,10);eq(count.premiumUses,2)
    eq(f.b.md.SuQingContainerUpgrade,ordinary);eq(f.b.inner.capacity,49);eq(f.b.capacityWrites,0)
end)
case("repeated restore cannot claim payment twice",function()
    local f=fixture("restore");ok(ISHandcraftAction.performRecipe(f.action));eq(ISHandcraftAction.performRecipe(f.action),false)
    local before=totals(f.p)
    local a={logic=f.logic,character=f.p,craftStarted=true,craftRecipe=Recipe("ExSuQingRestore")}
    eq(ISHandcraftAction.performRecipe(a),false);local after=totals(f.p)
    eq(after.cloth,before.cloth);eq(after.leather,before.leather);eq(after.threadUses,before.threadUses);eq(after.premiumUses,before.premiumUses)
end)
case("free crafting records zero refundable entitlement",function()
    local f=fixture(nil,nil,{free=true});ok(ISHandcraftAction.performRecipe(f.action));local r=X.GetRecord(f.b)
    eq(r.paidCloth,0);eq(r.paidLeather,0);eq(r.paidThreadUses,0);eq(r.paidPremiumUses,0)
    local restore=fixture("restore",nil,{character=f.p,bag=f.b});local before=totals(f.p)
    ok(ISHandcraftAction.performRecipe(restore.action));local after=totals(f.p)
    eq(after.cloth,before.cloth);eq(after.premiumUses,before.premiumUses)
end)
case("partial payment is rejected and restores original object identities",function()
    local f=fixture(nil,nil,{partial=true});eq(ISHandcraftAction.performRecipe(f.action),false);restored(f)
end)
case("native false after partial destruction rolls materials back",function()
    local f=fixture();f.data.engineFalse=true;eq(ISHandcraftAction.performRecipe(f.action),false);restored(f);eq(f.data.processed,0)
end)
case("throw after cloth destruction restores original cloth and leather objects",function()
    local f=fixture();f.data.throwEngine=true;eq(ISHandcraftAction.performRecipe(f.action),false);restored(f)
end)
case("throw after both line consumptions restores partial uses and originals",function()
    local f=fixture(nil,nil,{threadUnits={10,10},premiumUnits={1,3}});f.data.throwProcess=true
    eq(ISHandcraftAction.performRecipe(f.action),false);restored(f);eq(f.data.processed,1)
end)
case("postprocess own-record corruption rejects result and rolls back",function()
    local f=fixture();f.data.onProcess=function()f.b.md[X.modDataKey].targetCapacity=999 end
    eq(ISHandcraftAction.performRecipe(f.action),false);restored(f)
end)
case("target becoming worn during native validation refuses before destruction",function()
    local f=fixture();f.data.beforeEngine=function()f.p.worn[f.b]=true end
    eq(ISHandcraftAction.performRecipe(f.action),false);restored(f);eq(f.data.processed,0)
end)
case("missing inputs are caught before entering native recipe",function()
    local f=fixture();f.p.inventory:Remove(f.premium[1]);eq(ISHandcraftAction.performRecipe(f.action),false)
    eq(f.data.engine,0);eq(X.GetRecord(f.b),nil);eq(#f.cloth,40)
end)
case("duplicate input references are captured only once",function()
    local f=fixture();local expected=#f.all;f.data.all:add(f.thread[1]);local snapshots=X.CaptureInputs(f.data);eq(#snapshots,expected)
    ok(ISHandcraftAction.performRecipe(f.action));eq(X.GetRecord(f.b).paidThreadUses,20)
end)
case("no callback before completion means canceled craft changes nothing",function()
    local f=fixture();eq(f.data.engine,0);restored(f)
end)
case("preflight conversion and capacity hook failures do not charge",function()
    local f=fixture();local old=X.Conversions.IsReady;X.Conversions.IsReady=function()return false end
    eq(ISHandcraftAction.performRecipe(f.action),false);X.Conversions.IsReady=old;restored(f);eq(f.data.engine,0)
    local next=fixture();local cap=X.Capacity.IsReady;X.Capacity.IsReady=function()return false end
    eq(ISHandcraftAction.performRecipe(next.action),false);X.Capacity.IsReady=cap;restored(next);eq(next.data.engine,0)
end)
case("foreign recipe same short name delegates unchanged",function()
    local before=Native.otherCrafts or 0
    eq(ISHandcraftAction.performRecipe({craftRecipe=Recipe("Foreign.ExSuQingSuperUpgrade")},"foreign"),"foreign")
    eq(Native.otherCrafts,before+1)
end)
case("ordinary recipe delegates unchanged without importing ordinary code",function()
    local before=Native.otherCrafts or 0
    eq(ISHandcraftAction.performRecipe({craftRecipe=Recipe("SuQingContainerUpgrade.SuQingUpgrade1")},"ordinary"),"ordinary")
    eq(Native.otherCrafts,before+1)
end)
case("MP action is rejected before ingredient handling",function()
    local f=fixture();MPClient=true;eq(ISHandcraftAction.performRecipe(f.action),false);MPClient=false
    eq(f.data.engine,0);restored(f)
end)
case("callback reentry cannot redeem same actor while a craft is locked",function()
    local f=fixture();local other=fixture(nil,nil,{character=f.p})
    f.data.onEngine=function()eq(ISHandcraftAction.performRecipe(other.action),false)end
    ok(ISHandcraftAction.performRecipe(f.action));eq(other.data.engine,0);eq(X.GetRecord(other.b),nil)
end)
case("ambiguous refund insertion failure revokes outputs without reissuing credit",function()
    local f=fixture("restore");local credit=X.CopyRecord(X.GetRecord(f.b));local n=0
    f.p.inventory.onAdd=function(self,item)n=n+1;if n==4 then error("refund insertion fails before insertion")end end
    eq(ISHandcraftAction.performRecipe(f.action),false);f.p.inventory.onAdd=nil
    -- Attempted-but-absent output is deliberately ambiguous. Do not restore credit.
    eq(X.GetRecord(f.b),nil);local t=totals(f.p);eq(t.cloth,0);eq(t.leather,0)
    eq(f.b.md.SuQingContainerUpgrade.sentinel,"ordinary untouched")
end)
case("refund factory failure occurs before clearing EX or native action",function()
    local f=fixture("restore");local before=X.GetRecord(f.b);local factory=instanceItem
    instanceItem=function()error("factory unavailable")end
    eq(ISHandcraftAction.performRecipe(f.action),false);instanceItem=factory
    eq(X.GetRecord(f.b).paidCloth,before.paidCloth);eq(X.GetRecord(f.b).paidPremiumUses,before.paidPremiumUses)
    eq(X.GetRecord(f.b).targetCapacity,before.targetCapacity);eq(f.data.engine,0)
end)
case("EX refund drop preserves EX effect and ordinary record but consumes only own credit",function()
    local f=fixture("restore");local ordinary=f.b.md.SuQingContainerUpgrade
    ok(X.Refund.DropLedger(f.b));eq(X.GetRecord(f.b).paidCloth,0);eq(X.GetRecord(f.b).targetCapacity,98)
    eq(f.b.md.SuQingContainerUpgrade,ordinary);ok(X.IsValidRecord(X.GetRecord(f.b),f.b))
end)
case("foreign world move does not duplicate original input into inventory on rollback",function()
    local f=fixture();local moved=f.thread[1]
    f.data.onProcess=function()moved.getWorldItem=function()return{world=true}end;error("foreign callback moved input to world")end
    eq(ISHandcraftAction.performRecipe(f.action),false)
    eq(f.p.inventory:contains(moved),false);eq(X.GetRecord(f.b),nil)
    eq(moved:getWorldItem()~=nil,true)
    -- The same instance remains world-owned; recovery is correctly uncertain.
end)
return Review.finish()
