local X=ExSuQingBackpackSuperUpgrade
local eq,ok,case=Review.eq,Review.ok,Review.case
ok(X.Capacity.Install());ok(X.Conversions.Install())
local function fixture(ex,add,withContents)
    local p=Character();local b=Bag(p)
    if ex then local r=X.NewRecord(b);r.paidCloth=40;r.paidLeather=20;r.paidThreadUses=20;r.paidPremiumUses=4;b.md[X.modDataKey]=r end
    if not add then b.visual.choice=1 end
    local needle=Material("Base.Needle");local thread=Material("Base.Thread",10)
    local fabric=Material("Base.RippedSheets");local cutter=Material("Base.Scissors")
    for _,m in ipairs({needle,thread,fabric,cutter})do p.inventory:AddItem(m)end
    local contents={}
    if withContents then
        for i=1,3 do local m=Material("Base.Stone");m.weight=25;b.inner:AddItem(m);contents[#contents+1]=m end
        b.fluid={getAmount=function()return 1.0 end}
    end
    local a=LB_SewPatchesAction:new(p,b,add,needle,thread,fabric,cutter)
    return{p=p,b=b,action=a,needle=needle,thread=thread,fabric=fabric,cutter=cutter,contents=contents}
end
local function replacements(f)
    local result={};for _,m in ipairs(f.p.inventory.items.values)do if X.IsSupported(m)then result[#result+1]=m end end;return result
end
local function verifySuccess(f,expectedChoice,paid)
    local found=replacements(f);eq(#found,1);local target=found[1];ok(target~=f.b)
    eq(f.b:getContainer(),nil);eq(f.b.inner.items:size(),0);eq(target.visual.choice,expectedChoice)
    eq(target.inner.items:size(),#f.contents)
    for _,child in ipairs(f.contents)do eq(target.inner.items:contains(child),true);eq(child:getContainer(),target.inner)end
    eq(target.md.foreign.value,42);eq(target.md.SuQingContainerUpgrade.sentinel,"ordinary untouched")
    if paid then eq(X.GetRecord(target).paidPremiumUses,4);eq(X.GetRecord(target).targetCapacity,98);eq(X.GetRecord(f.b),nil)
    else eq(X.GetRecord(target),nil)end
    if f.b.fluid then eq(target.fluid:getAmount(),f.b.fluid:getAmount())end
    return target
end
case("nonEX native LB action remains delegated including contents",function()
    local f=fixture(false,true,true);ok(f.action:complete());verifySuccess(f,1,false)
    eq(f.thread.uses,9);eq(f.p.inventory:contains(f.fabric),false)
end)
case("EX patch preserves over50 contents fluids own payment and ordinary data",function()
    local f=fixture(true,true,true);ok(f.action:complete());local t=verifySuccess(f,1,true)
    eq(t.inner:getContentsWeight(),75);eq(t.inner:getEffectiveCapacity(nil),98)
    eq(f.thread.uses,9);eq(f.p.inventory:contains(f.fabric),false)
end)
case("EX removal of patches keeps exact content identities and does not charge sewing materials",function()
    local f=fixture(true,false,true);ok(f.action:complete());verifySuccess(f,0,true)
    eq(f.thread.uses,10);eq(f.p.inventory:contains(f.fabric),true)
end)
case("worn EX patch replacement returns to original slot with entitlement once",function()
    local f=fixture(true,true,true);f.p:setWornItem("Back",f.b)
    ok(f.action:complete());local t=verifySuccess(f,1,true);eq(f.p:getWornItem("Back"),t)
end)
case("conversion failure after material debit restores source exact children and inputs",function()
    local f=fixture(true,true,true);f.p:setWornItem("Back",f.b);f.p.primary=f.b
    f.p.inventory.onAdd=function(self,item)if X.IsSupported(item)and item~=f.b then error("injected replacement add failure")end end
    eq(f.action:complete(),false);f.p.inventory.onAdd=nil
    eq(f.p.inventory:contains(f.b),true);eq(f.b.inner.items:size(),3);eq(f.thread.uses,10);eq(f.p.inventory:contains(f.fabric),true)
    eq(X.GetRecord(f.b).paidPremiumUses,4);eq(f.p:getWornItem("Back"),f.b);eq(f.p.primary,f.b)
    for _,child in ipairs(f.contents)do eq(child:getContainer(),f.b.inner)end
    eq(#replacements(f),1)
end)
case("invalid copy verification is caught before sewing payment",function()
    local f=fixture(true,true,true)
    Native.onCopy=function(source,target)target.inner:AddItem(Material("Base.Unexpected"))end
    eq(f.action:complete(),false);Native.onCopy=nil
    eq(f.thread.uses,10);eq(f.p.inventory:contains(f.fabric),true);eq(f.p.inventory:contains(f.b),true)
    eq(X.GetRecord(f.b).paidCloth,40)
    -- Unknown extra contents may require retaining a target; only source may carry credit.
    local credits=0;for _,b in ipairs(replacements(f))do local r=X.GetRecord(b);if r and r.paidCloth>0 then credits=credits+1 end end
    eq(credits,1)
end)
case("unsafe factory result same as source is rejected without touching anything",function()
    local f=fixture(true,true,true);local factory=instanceItem;instanceItem=function()return f.b end
    eq(f.action:complete(),false);instanceItem=factory
    eq(f.b.inner.items:size(),3);eq(f.thread.uses,10);eq(f.p.inventory:contains(f.fabric),true);eq(X.GetRecord(f.b).paidCloth,40)
end)
case("nested callback cannot start second conversion for same character",function()
    local f=fixture(true,true,false);local secondResult
    Native.onCopy=function()secondResult=f.action:complete()end
    ok(f.action:complete());Native.onCopy=nil;eq(secondResult,false);eq(#replacements(f),1)
end)
case("cosmetic callback failure does not undo committed entitlement or create duplicates",function()
    local f=fixture(true,true,true);local event=triggerEvent;triggerEvent=function()error("UI callback failure")end
    ok(f.action:complete());triggerEvent=event;verifySuccess(f,1,true);eq(f.thread.uses,9)
end)
case("native patch tools and texture guards remain required for EX",function()
    local f=fixture(true,true,false);f.p.inventory:Remove(f.fabric)
    eq(f.action:complete(),false);eq(f.thread.uses,10);eq(X.GetRecord(f.b).paidCloth,40)
    local f2=fixture(true,true,false);f2.b.visual.choice=1;eq(f2.action:complete(),false);eq(f2.thread.uses,10)
end)
case("successful EX conversion action replay cannot fall through native and mint empty duplicate",function()
    local f=fixture(true,true,true);ok(f.action:complete());local count=#replacements(f)
    eq(f.action:complete(),false);eq(#replacements(f),count);eq(f.thread.uses,9)
    local credits=0;for _,b in ipairs(replacements(f))do if X.GetRecord(b)then credits=credits+1 end end;eq(credits,1)
end)
case("failed EX conversion action is terminal but new action can retry",function()
    local f=fixture(true,true,true);local factory=instanceItem
    instanceItem=function()return f.b end;eq(f.action:complete(),false);instanceItem=factory
    eq(f.action:complete(),false);eq(f.thread.uses,10)
    local retry=LB_SewPatchesAction:new(f.p,f.b,true,f.needle,f.thread,f.fabric,f.cutter)
    ok(retry:complete());verifySuccess(f,1,true)
end)
case("EX transfer wrapper queues guarded normal action beyond50",function()
    local p=Character();local b=Bag(p);b.md[X.modDataKey]=X.NewRecord(b);b.inner.contentsWeight=60
    local source=Container();local m=Material("Base.Stone");m.weight=30;source:AddItem(m)
    local count=#ISTimedActionQueue.added
    javaTransferItems(p,m,source,b.inner)
    eq(#ISTimedActionQueue.added,count+1);local a=ISTimedActionQueue.added[#ISTimedActionQueue.added]
    eq(a.item,m);eq(a.source,source);eq(a.destination,b.inner);eq(source:contains(m),true)
    -- Queueing is NOT execution: contents must not be moved here.
    eq(b.inner:contains(m),false)
end)
case("EX transfer wrapper refuses full target cycles missing source and unsupported fallback",function()
    local p=Character();local b=Bag(p);b.md[X.modDataKey]=X.NewRecord(b);b.inner.contentsWeight=97
    local source=Container();local m=Material("Base.Stone");m.weight=2;source:AddItem(m)
    local count=#ISTimedActionQueue.added;javaTransferItems(p,m,source,b.inner);eq(#ISTimedActionQueue.added,count)
    b.inner.contentsWeight=0;source:Remove(m);javaTransferItems(p,m,source,b.inner);eq(#ISTimedActionQueue.added,count)
    local native=Native.javaTransfers or 0;eq(javaTransferItems(p,m,source,Container()),"native transfer");eq(Native.javaTransfers,native+1)
end)
return Review.finish()
